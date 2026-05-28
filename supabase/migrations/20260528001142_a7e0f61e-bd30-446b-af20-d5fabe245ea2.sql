
-- 1) Chat: add missing columns used by the UI
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS reply_to_id uuid REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS edited_at timestamptz;

-- 2) Virtual payout requests: one active request per bet
CREATE UNIQUE INDEX IF NOT EXISTS virtual_payout_requests_bet_unique
  ON public.virtual_payout_requests(bet_id)
  WHERE status = 'pending' OR status = 'approved';

-- 3) Fix resolve_virtual_round: correct bet status logic + no auto-credit for virtual
CREATE OR REPLACE FUNCTION public.resolve_virtual_round(
  _match_id uuid,
  _home_score integer DEFAULT NULL,
  _away_score integer DEFAULT NULL,
  _first_blood_team_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  m public.matches%ROWTYPE;
  hs integer; as_ integer; fb uuid; max_score integer; winner uuid;
  bet record;
  unresolved_count integer;
  has_lost boolean;
  all_won boolean;
  is_virtual_bet boolean;
BEGIN
  SELECT * INTO m FROM public.matches WHERE id = _match_id AND is_virtual = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;
  IF m.status = 'ended' THEN RETURN jsonb_build_object('ok', true, 'already_ended', true); END IF;

  SELECT COALESCE(virtual_max_score, 8) INTO max_score FROM public.app_settings WHERE id = 1;
  hs := COALESCE(_home_score, floor(random() * (max_score + 1))::integer);
  as_ := COALESCE(_away_score, floor(random() * (max_score + 1))::integer);
  winner := CASE WHEN hs > as_ THEN m.home_team_id WHEN as_ > hs THEN m.away_team_id ELSE NULL END;
  fb := COALESCE(_first_blood_team_id, CASE WHEN random() < 0.5 THEN m.home_team_id ELSE m.away_team_id END);

  UPDATE public.odds o SET is_winner = CASE
    WHEN winner IS NULL AND lower(o.label) = 'draw' THEN true
    WHEN winner = m.home_team_id AND lower(o.label) = lower(COALESCE((SELECT name FROM public.teams WHERE id = m.home_team_id), '')) THEN true
    WHEN winner = m.away_team_id AND lower(o.label) = lower(COALESCE((SELECT name FROM public.teams WHERE id = m.away_team_id), '')) THEN true
    ELSE false END
    FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = _match_id AND mk.name ILIKE '%winner%';

  UPDATE public.odds o SET is_winner = (
    (fb = m.home_team_id AND lower(o.label) = lower(COALESCE((SELECT name FROM public.teams WHERE id = m.home_team_id), '')))
    OR (fb = m.away_team_id AND lower(o.label) = lower(COALESCE((SELECT name FROM public.teams WHERE id = m.away_team_id), '')))
  ) FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = _match_id AND mk.name ILIKE '%first%blood%';

  UPDATE public.odds o SET is_winner = (o.label = hs || ':' || as_)
    FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = _match_id AND mk.name ILIKE '%correct%score%';

  UPDATE public.odds o SET is_winner = CASE
    WHEN o.label ILIKE 'Over%' THEN (hs + as_) > COALESCE(NULLIF(regexp_replace(o.label, '[^0-9.]', '', 'g'), '')::numeric, 4.5)
    WHEN o.label ILIKE 'Under%' THEN (hs + as_) < COALESCE(NULLIF(regexp_replace(o.label, '[^0-9.]', '', 'g'), '')::numeric, 4.5)
    ELSE false END
    FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = _match_id AND mk.name ILIKE '%total%';

  UPDATE public.matches SET status='ended', home_score = hs, away_score = as_,
    winner_team_id = winner, virtual_first_blood_team_id = fb, settled_at = now(), updated_at = now()
   WHERE id = _match_id;

  FOR bet IN SELECT DISTINCT b.* FROM public.bets b
    JOIN public.bet_selections bs ON bs.bet_id = b.id
    WHERE bs.match_id = _match_id AND b.status IN ('pending','open')
  LOOP
    -- Set per-selection result for this match
    UPDATE public.bet_selections bs
      SET result = CASE WHEN o.is_winner IS TRUE
        THEN 'won'::public.selection_result
        ELSE 'lost'::public.selection_result END
      FROM public.odds o
      WHERE bs.odd_id = o.id AND bs.bet_id = bet.id AND bs.match_id = _match_id;

    -- Determine bet status with proper NULL handling
    SELECT
      COUNT(*) FILTER (WHERE bs2.result IS NULL),
      bool_or(bs2.result = 'lost'::public.selection_result)
    INTO unresolved_count, has_lost
    FROM public.bet_selections bs2 WHERE bs2.bet_id = bet.id;

    -- Is this a virtual ticket?
    SELECT bool_or(mt.is_virtual) INTO is_virtual_bet
      FROM public.bet_selections bs3
      JOIN public.matches mt ON mt.id = bs3.match_id
     WHERE bs3.bet_id = bet.id;

    IF has_lost IS TRUE THEN
      UPDATE public.bets SET status='lost', settled_at=now() WHERE id = bet.id;
    ELSIF unresolved_count = 0 THEN
      -- All selections settled and none lost → all won
      UPDATE public.bets SET status='won', settled_at=now() WHERE id = bet.id;
      IF is_virtual_bet IS TRUE THEN
        -- Virtual wins require user claim + admin approval. Do NOT credit balance.
        INSERT INTO public.notifications (user_id, title, body, link)
          VALUES (bet.user_id, 'Virtual ticket won — claim now',
                  bet.tracking_id || ' is eligible for a ' || bet.potential_payout::text || ' token payout (admin approval required).',
                  '/ticket/' || bet.id::text);
      ELSE
        -- Real-match win: credit immediately (existing behavior)
        UPDATE public.profiles SET token_balance = token_balance + bet.potential_payout WHERE id = bet.user_id;
        INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
          SELECT bet.user_id, bet.potential_payout, token_balance, 'bet_won', 'Win ' || bet.tracking_id
            FROM public.profiles WHERE id = bet.user_id;
        INSERT INTO public.notifications (user_id, title, body, link)
          VALUES (bet.user_id, 'Ticket won', bet.tracking_id || ' paid ' || bet.potential_payout::text || ' tokens.', '/ticket/' || bet.id::text);
      END IF;
    END IF;
    -- else: still pending, leave as-is
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'home', hs, 'away', as_);
END
$$;

-- 4) User claim function: creates payout request after checking house funding
CREATE OR REPLACE FUNCTION public.user_claim_virtual_payout(bet_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid();
  b public.bets%ROWTYPE;
  house_balance bigint;
  existing_id uuid;
  new_id uuid;
  is_virt boolean;
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  SELECT * INTO b FROM public.bets WHERE id = bet_id AND user_id = uid;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;
  IF b.status <> 'won' THEN RETURN jsonb_build_object('ok', false, 'error', 'not_won'); END IF;

  SELECT bool_or(m.is_virtual) INTO is_virt
    FROM public.bet_selections bs JOIN public.matches m ON m.id = bs.match_id
   WHERE bs.bet_id = bet_id;
  IF NOT COALESCE(is_virt, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_virtual');
  END IF;

  SELECT id INTO existing_id FROM public.virtual_payout_requests
   WHERE virtual_payout_requests.bet_id = user_claim_virtual_payout.bet_id
     AND status IN ('pending','approved') LIMIT 1;
  IF existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_claimed', 'request_id', existing_id);
  END IF;

  SELECT balance INTO house_balance FROM public.virtual_house_wallet WHERE id = 1;
  IF COALESCE(house_balance, 0) < b.potential_payout THEN
    RETURN jsonb_build_object('ok', false, 'error', 'house_underfunded',
                              'house_balance', COALESCE(house_balance,0),
                              'needed', b.potential_payout);
  END IF;

  INSERT INTO public.virtual_payout_requests (user_id, bet_id, match_id, stake, amount, status)
    SELECT uid, b.id, bs.match_id, b.stake, b.potential_payout, 'pending'
      FROM public.bet_selections bs WHERE bs.bet_id = b.id LIMIT 1
    RETURNING id INTO new_id;
  RETURN jsonb_build_object('ok', true, 'request_id', new_id);
END $$;

-- 5) Admin review of virtual payout: also debit the virtual house wallet on approve
CREATE OR REPLACE FUNCTION public.admin_review_virtual_payout(id uuid, _approve boolean, _reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.virtual_payout_requests%ROWTYPE; house_balance bigint;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO r FROM public.virtual_payout_requests WHERE virtual_payout_requests.id = admin_review_virtual_payout.id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;
  IF r.status <> 'pending' THEN RETURN jsonb_build_object('ok', false, 'error', 'already_reviewed'); END IF;

  IF _approve THEN
    SELECT balance INTO house_balance FROM public.virtual_house_wallet WHERE id = 1;
    IF COALESCE(house_balance,0) < r.amount THEN
      RETURN jsonb_build_object('ok', false, 'error', 'house_underfunded');
    END IF;
    UPDATE public.virtual_house_wallet
      SET balance = balance - r.amount, total_out = total_out + r.amount, updated_at = now() WHERE id = 1;
    INSERT INTO public.virtual_house_transactions (kind, amount, balance_after, reason)
      SELECT 'payout', -r.amount, balance, 'Approved payout ' || r.id::text FROM public.virtual_house_wallet WHERE id = 1;
    UPDATE public.profiles SET token_balance = token_balance + r.amount WHERE id = r.user_id;
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
      SELECT r.user_id, r.amount, token_balance, 'virtual_payout', 'Approved virtual payout ' || r.id::text
        FROM public.profiles WHERE id = r.user_id;
    INSERT INTO public.notifications (user_id, title, body, link)
      VALUES (r.user_id, 'Virtual payout approved', r.amount::text || ' tokens credited.', '/ticket/' || r.bet_id::text);
  ELSE
    INSERT INTO public.notifications (user_id, title, body, link)
      VALUES (r.user_id, 'Virtual payout declined', COALESCE(_reason, 'Contact support for details.'), '/ticket/' || r.bet_id::text);
  END IF;

  UPDATE public.virtual_payout_requests
    SET status = CASE WHEN _approve THEN 'approved' ELSE 'declined' END,
        reviewed_by = auth.uid(), reviewed_at = now(), review_note = _reason
    WHERE virtual_payout_requests.id = admin_review_virtual_payout.id;

  RETURN jsonb_build_object('ok', true);
END $$;

REVOKE ALL ON FUNCTION public.user_claim_virtual_payout(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_claim_virtual_payout(uuid) TO authenticated;
