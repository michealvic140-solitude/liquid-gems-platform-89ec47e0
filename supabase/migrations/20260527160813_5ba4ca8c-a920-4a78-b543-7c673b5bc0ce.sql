
-- ============ SCHEMA ADDITIONS ============
ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS virtual_cycle_running boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS virtual_animation_seconds integer NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS virtual_cycle_last_tick timestamptz,
  ADD COLUMN IF NOT EXISTS virtual_max_score integer NOT NULL DEFAULT 8,
  ADD COLUMN IF NOT EXISTS virtual_min_selections integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS virtual_max_selections integer NOT NULL DEFAULT 20,
  ADD COLUMN IF NOT EXISTS virtual_max_payout bigint NOT NULL DEFAULT 60000000;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_kicked_at timestamptz;
ALTER TABLE public.spotlights ALTER COLUMN title SET DEFAULT '';
ALTER TABLE public.withdrawal_requests ADD COLUMN IF NOT EXISTS admin_note text;

CREATE TABLE IF NOT EXISTS public.virtual_payout_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id uuid,
  user_id uuid NOT NULL,
  match_id uuid,
  stake bigint NOT NULL DEFAULT 0,
  amount bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  reviewed_by uuid,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.virtual_payout_requests TO authenticated;
GRANT ALL ON public.virtual_payout_requests TO service_role;
ALTER TABLE public.virtual_payout_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vpr admin" ON public.virtual_payout_requests;
CREATE POLICY "vpr admin" ON public.virtual_payout_requests FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
DROP POLICY IF EXISTS "vpr own" ON public.virtual_payout_requests;
CREATE POLICY "vpr own" ON public.virtual_payout_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- ============ ADMIN RPCs (frontend-aligned signatures) ============

DROP FUNCTION IF EXISTS public.admin_broadcast(text, text, text);
CREATE OR REPLACE FUNCTION public.admin_broadcast(title text, _body text DEFAULT '', _link text DEFAULT NULL, _segment text DEFAULT 'all')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  INSERT INTO public.broadcasts (title, body, audience) VALUES (title, _body, _segment);
  INSERT INTO public.notifications (user_id, title, body, link) SELECT id, title, _body, _link FROM public.profiles;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.admin_broadcast(text, text, text, text) FROM anon;

DROP FUNCTION IF EXISTS public.review_gang_emblem(uuid, text);
CREATE OR REPLACE FUNCTION public.review_gang_emblem(id uuid, _approve boolean, _note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE e public.gang_emblems%ROWTYPE;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO e FROM public.gang_emblems WHERE gang_emblems.id = review_gang_emblem.id;
  UPDATE public.gang_emblems SET status = CASE WHEN _approve THEN 'approved' ELSE 'declined' END,
    reviewed_by = auth.uid(), reviewed_at = now() WHERE gang_emblems.id = review_gang_emblem.id;
  IF _approve THEN
    UPDATE public.profiles SET gang_emblem_url = e.image_url, emblem_status = 'approved' WHERE profiles.id = e.user_id;
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.review_gang_emblem(uuid, boolean, text) FROM anon;

DROP FUNCTION IF EXISTS public.admin_adjust_xp(uuid, integer, text);
CREATE OR REPLACE FUNCTION public.admin_adjust_xp(user_id uuid, _delta integer, _reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.profiles SET xp = GREATEST(0, xp + _delta) WHERE profiles.id = user_id;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.admin_adjust_xp(uuid, integer, text) FROM anon;

DROP FUNCTION IF EXISTS public.house_manual_adjust(bigint, text);
CREATE OR REPLACE FUNCTION public.house_manual_adjust(amount bigint, _reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.house_wallet SET balance = balance + amount, updated_at = now() WHERE id = 1;
  INSERT INTO public.house_transactions (kind, amount, balance_after, actor_id, reason)
    SELECT 'manual_adjust', amount, balance, auth.uid(), _reason FROM public.house_wallet WHERE id=1;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.house_manual_adjust(bigint, text) FROM anon;

DROP FUNCTION IF EXISTS public.review_withdrawal_request(uuid, text, text);
CREATE OR REPLACE FUNCTION public.review_withdrawal_request(id uuid, _approve boolean, _note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.withdrawal_requests%ROWTYPE;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO r FROM public.withdrawal_requests WHERE withdrawal_requests.id = review_withdrawal_request.id;
  UPDATE public.withdrawal_requests
     SET status = (CASE WHEN _approve THEN 'approved' ELSE 'declined' END)::request_status,
         reviewed_by = auth.uid(), reviewed_at = now(), admin_note = _note
   WHERE withdrawal_requests.id = review_withdrawal_request.id;
  IF NOT _approve THEN
    UPDATE public.profiles SET token_balance = token_balance + r.amount WHERE profiles.id = r.user_id;
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.review_withdrawal_request(uuid, boolean, text) FROM anon;

DROP FUNCTION IF EXISTS public.approve_promo_request(uuid);
CREATE OR REPLACE FUNCTION public.approve_promo_request(id uuid, _note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.promo_code_requests SET status='approved', reviewed_by=auth.uid(), reviewed_at=now()
    WHERE promo_code_requests.id = approve_promo_request.id;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.approve_promo_request(uuid, text) FROM anon;

DROP FUNCTION IF EXISTS public.decline_promo_request(uuid);
CREATE OR REPLACE FUNCTION public.decline_promo_request(id uuid, _note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.promo_code_requests SET status='declined', reviewed_by=auth.uid(), reviewed_at=now()
    WHERE promo_code_requests.id = decline_promo_request.id;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.decline_promo_request(uuid, text) FROM anon;

DROP FUNCTION IF EXISTS public.admin_review_virtual_payout(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_review_virtual_payout(id uuid, _approve boolean, _reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.virtual_payout_requests%ROWTYPE;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO r FROM public.virtual_payout_requests WHERE virtual_payout_requests.id = admin_review_virtual_payout.id;
  UPDATE public.virtual_payout_requests SET status = CASE WHEN _approve THEN 'approved' ELSE 'declined' END,
    reviewed_by = auth.uid(), reviewed_at = now(), review_note = _reason
    WHERE virtual_payout_requests.id = admin_review_virtual_payout.id;
  IF _approve THEN
    UPDATE public.profiles SET token_balance = token_balance + r.amount WHERE id = r.user_id;
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.admin_review_virtual_payout(uuid, boolean, text) FROM anon;

DROP FUNCTION IF EXISTS public.claim_challenge(uuid);
CREATE OR REPLACE FUNCTION public.claim_challenge(progress_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); p public.user_challenge_progress%ROWTYPE; c public.challenges%ROWTYPE;
BEGIN
  SELECT * INTO p FROM public.user_challenge_progress WHERE id = progress_id AND user_id = uid;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;
  IF p.claimed_at IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'already_claimed'); END IF;
  SELECT * INTO c FROM public.challenges WHERE id = p.challenge_id;
  IF p.progress < c.target THEN RETURN jsonb_build_object('ok', false, 'error', 'incomplete'); END IF;
  UPDATE public.user_challenge_progress SET claimed_at = now() WHERE id = progress_id;
  UPDATE public.profiles SET token_balance = token_balance + COALESCE(c.reward_tokens,0),
                              xp = xp + COALESCE(c.reward_xp,0) WHERE id = uid;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.claim_challenge(uuid) FROM anon;

DROP FUNCTION IF EXISTS public.admin_pnl_summary();
DROP FUNCTION IF EXISTS public.admin_pnl_summary(integer);
CREATE OR REPLACE FUNCTION public.admin_pnl_summary(days integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb; cutoff timestamptz := now() - (days || ' days')::interval;
BEGIN
  SELECT jsonb_build_object(
    'total_stakes', COALESCE(SUM(stake),0),
    'total_payouts', COALESCE(SUM(CASE WHEN status='won' THEN potential_payout ELSE 0 END),0),
    'pending_count', COUNT(*) FILTER (WHERE status='pending'),
    'days', days
  ) INTO r FROM public.bets WHERE created_at >= cutoff;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION public.admin_pnl_summary(integer) FROM anon;

DROP FUNCTION IF EXISTS public.verify_xp_consistency();
DROP FUNCTION IF EXISTS public.verify_xp_consistency(uuid);
CREATE OR REPLACE FUNCTION public.verify_xp_consistency(user_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('ok', true, 'user_id', user_id);
$$;
REVOKE EXECUTE ON FUNCTION public.verify_xp_consistency(uuid) FROM anon;

DROP FUNCTION IF EXISTS public.create_withdrawal_request(bigint, text, text, text);
CREATE OR REPLACE FUNCTION public.create_withdrawal_request(amount bigint, _ingame text, _gang text, _ticket text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); bal bigint; minw bigint; new_id uuid;
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  SELECT token_balance INTO bal FROM public.profiles WHERE id = uid;
  SELECT min_withdrawal INTO minw FROM public.app_settings WHERE id = 1;
  IF amount < COALESCE(minw,0) THEN RETURN jsonb_build_object('ok', false, 'error', 'below_min'); END IF;
  IF bal < amount THEN RETURN jsonb_build_object('ok', false, 'error', 'insufficient'); END IF;
  INSERT INTO public.withdrawal_requests (user_id, amount, ingame_name, gang_name, ticket_ref)
    VALUES (uid, amount, _ingame, _gang, _ticket) RETURNING id INTO new_id;
  UPDATE public.profiles SET token_balance = token_balance - amount WHERE id = uid;
  INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
    SELECT uid, -amount, token_balance, 'withdrawal_hold', 'Withdrawal ' || new_id FROM public.profiles WHERE id = uid;
  RETURN jsonb_build_object('ok', true, 'id', new_id);
END $$;
REVOKE EXECUTE ON FUNCTION public.create_withdrawal_request(bigint, text, text, text) FROM anon;

-- ============ BET PLACEMENT (REAL TICKET) ============

CREATE OR REPLACE FUNCTION public.place_bet_ticket(_selections jsonb, _stake bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid();
  cfg record;
  p public.profiles%ROWTYPE;
  sel jsonb;
  odd_row record;
  total_odds numeric := 1;
  raw_payout bigint;
  capped_payout bigint;
  bet_id uuid;
  tracking text;
  booking text;
  selection_count integer := COALESCE(jsonb_array_length(_selections), 0);
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauthenticated'); END IF;
  SELECT * INTO p FROM public.profiles WHERE id = uid FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'profile_not_found'); END IF;
  IF COALESCE(p.is_banned, false) OR COALESCE(p.is_restricted, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'account_restricted');
  END IF;

  SELECT COALESCE(min_stake, 1000)::bigint AS min_stake,
         COALESCE(NULLIF(max_payout,0), 100000000)::bigint AS max_payout,
         COALESCE(min_selections_per_ticket, 1)::integer AS min_sel,
         COALESCE(max_selections_per_ticket, 20)::integer AS max_sel
    INTO cfg FROM public.app_settings WHERE id = 1;

  IF selection_count < cfg.min_sel THEN RETURN jsonb_build_object('ok', false, 'error', 'not_enough_selections', 'min', cfg.min_sel); END IF;
  IF selection_count > cfg.max_sel THEN RETURN jsonb_build_object('ok', false, 'error', 'too_many_selections', 'max', cfg.max_sel); END IF;
  IF _stake < cfg.min_stake THEN RETURN jsonb_build_object('ok', false, 'error', 'min_stake', 'min', cfg.min_stake); END IF;
  IF p.token_balance < _stake THEN RETURN jsonb_build_object('ok', false, 'error', 'insufficient_balance'); END IF;

  FOR sel IN SELECT * FROM jsonb_array_elements(_selections) LOOP
    SELECT o.id AS odd_id, o.value, o.label, mk.id AS market_id, m.id AS match_id, m.status, m.lock_time, m.is_virtual
      INTO odd_row
      FROM public.odds o
      JOIN public.markets mk ON mk.id = o.market_id
      JOIN public.matches m ON m.id = mk.match_id
     WHERE o.id = (sel->>'odd_id')::uuid;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'invalid_selection'); END IF;
    IF odd_row.is_virtual THEN RETURN jsonb_build_object('ok', false, 'error', 'use_virtual_ticket'); END IF;
    IF odd_row.status NOT IN ('upcoming','scheduled') OR (odd_row.lock_time IS NOT NULL AND odd_row.lock_time <= now()) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'market_locked');
    END IF;
    total_odds := total_odds * odd_row.value;
  END LOOP;

  raw_payout := floor(_stake * total_odds)::bigint;
  capped_payout := LEAST(raw_payout, cfg.max_payout);
  tracking := 'LSL-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  booking := 'B' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  INSERT INTO public.bets (user_id, tracking_id, booking_code, stake, total_odds, potential_payout, status)
    VALUES (uid, tracking, booking, _stake, round(total_odds,2), capped_payout, 'pending')
    RETURNING id INTO bet_id;

  FOR sel IN SELECT * FROM jsonb_array_elements(_selections) LOOP
    SELECT o.id AS odd_id, o.value, o.label, mk.id AS market_id, m.id AS match_id
      INTO odd_row
      FROM public.odds o JOIN public.markets mk ON mk.id = o.market_id JOIN public.matches m ON m.id = mk.match_id
     WHERE o.id = (sel->>'odd_id')::uuid;
    INSERT INTO public.bet_selections (bet_id, match_id, market_id, odd_id, locked_odds, selection_label)
      VALUES (bet_id, odd_row.match_id, odd_row.market_id, odd_row.odd_id, odd_row.value, odd_row.label);
  END LOOP;

  UPDATE public.profiles SET token_balance = token_balance - _stake WHERE id = uid;
  INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description, metadata)
    SELECT uid, -_stake, token_balance, 'bet_stake', 'Ticket ' || tracking,
           jsonb_build_object('bet_id', bet_id, 'tracking_id', tracking, 'payout', capped_payout)
    FROM public.profiles WHERE id = uid;
  INSERT INTO public.notifications (user_id, title, body, link)
    VALUES (uid, 'Bet placed', tracking || ' · ' || _stake::text || ' tokens', '/ticket/' || bet_id::text);

  RETURN jsonb_build_object('ok', true, 'bet_id', bet_id, 'tracking_id', tracking, 'booking_code', booking, 'payout', capped_payout);
END $$;
REVOKE EXECUTE ON FUNCTION public.place_bet_ticket(jsonb, bigint) FROM anon;

-- ============ VIRTUAL TICKETS ============

DROP FUNCTION IF EXISTS public.place_virtual_ticket(jsonb);
CREATE OR REPLACE FUNCTION public.place_virtual_ticket(_selections jsonb, _stake bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid(); cfg record; p public.profiles%ROWTYPE;
  sel jsonb; odd_row record; first_match uuid := NULL;
  total_odds numeric := 1; raw_payout bigint; capped_payout bigint;
  bet_id uuid; tracking text; booking text;
  selection_count integer := COALESCE(jsonb_array_length(_selections), 0);
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauthenticated'); END IF;
  SELECT * INTO p FROM public.profiles WHERE id = uid FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'profile_not_found'); END IF;
  IF COALESCE(p.is_banned,false) OR COALESCE(p.is_restricted,false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'account_restricted'); END IF;

  SELECT COALESCE(virtual_min_stake, min_stake, 0)::bigint AS min_stake,
         COALESCE(NULLIF(virtual_max_payout,0), max_payout, 100000000)::bigint AS max_payout,
         COALESCE(virtual_min_selections,1)::integer AS min_sel,
         COALESCE(virtual_max_selections,20)::integer AS max_sel,
         COALESCE(virtual_payout_multiplier,1)::numeric AS mult
    INTO cfg FROM public.app_settings WHERE id = 1;

  IF selection_count < cfg.min_sel THEN RETURN jsonb_build_object('ok', false, 'error', 'not_enough_selections','min',cfg.min_sel); END IF;
  IF selection_count > cfg.max_sel THEN RETURN jsonb_build_object('ok', false, 'error', 'too_many_selections','max',cfg.max_sel); END IF;
  IF _stake < cfg.min_stake THEN RETURN jsonb_build_object('ok', false, 'error', 'min_stake','min',cfg.min_stake); END IF;
  IF p.token_balance < _stake THEN RETURN jsonb_build_object('ok', false, 'error', 'insufficient_balance'); END IF;

  FOR sel IN SELECT * FROM jsonb_array_elements(_selections) LOOP
    SELECT o.id AS odd_id, o.value, o.label, mk.id AS market_id, m.id AS match_id, m.status, m.lock_time, m.is_virtual
      INTO odd_row
      FROM public.odds o JOIN public.markets mk ON mk.id = o.market_id JOIN public.matches m ON m.id = mk.match_id
     WHERE o.id = (sel->>'odd_id')::uuid;
    IF NOT FOUND OR NOT odd_row.is_virtual THEN RETURN jsonb_build_object('ok', false, 'error', 'invalid_selection'); END IF;
    IF odd_row.status <> 'scheduled' OR odd_row.lock_time IS NULL OR odd_row.lock_time <= now() THEN
      RETURN jsonb_build_object('ok', false, 'error', 'round_locked'); END IF;
    IF first_match IS NULL THEN first_match := odd_row.match_id;
    ELSIF first_match <> odd_row.match_id THEN
      RETURN jsonb_build_object('ok', false, 'error', 'one_virtual_round_only'); END IF;
    total_odds := total_odds * odd_row.value;
  END LOOP;

  raw_payout := floor(_stake * total_odds * cfg.mult)::bigint;
  capped_payout := LEAST(raw_payout, cfg.max_payout);
  tracking := 'VT-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  booking := 'VB' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  INSERT INTO public.bets (user_id, tracking_id, booking_code, stake, total_odds, potential_payout, status)
    VALUES (uid, tracking, booking, _stake, round(total_odds,2), capped_payout, 'pending') RETURNING id INTO bet_id;

  FOR sel IN SELECT * FROM jsonb_array_elements(_selections) LOOP
    SELECT o.id AS odd_id, o.value, o.label, mk.id AS market_id, m.id AS match_id INTO odd_row
      FROM public.odds o JOIN public.markets mk ON mk.id = o.market_id JOIN public.matches m ON m.id = mk.match_id
     WHERE o.id = (sel->>'odd_id')::uuid;
    INSERT INTO public.bet_selections (bet_id, match_id, market_id, odd_id, locked_odds, selection_label)
      VALUES (bet_id, odd_row.match_id, odd_row.market_id, odd_row.odd_id, odd_row.value, odd_row.label);
  END LOOP;

  UPDATE public.profiles SET token_balance = token_balance - _stake WHERE id = uid;
  INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description, metadata)
    SELECT uid, -_stake, token_balance, 'virtual_bet_stake', 'Virtual ' || tracking,
           jsonb_build_object('bet_id', bet_id, 'tracking_id', tracking, 'payout', capped_payout) FROM public.profiles WHERE id = uid;

  RETURN jsonb_build_object('ok', true, 'bet_id', bet_id, 'tracking_id', tracking, 'booking_code', booking, 'payout', capped_payout);
END $$;
REVOKE EXECUTE ON FUNCTION public.place_virtual_ticket(jsonb, bigint) FROM anon;

CREATE OR REPLACE FUNCTION public.place_virtual_ticket(payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN public.place_virtual_ticket(
    COALESCE(payload->'_selections', payload->'selections', '[]'::jsonb),
    COALESCE((payload->>'_stake')::bigint, (payload->>'stake')::bigint, 0)
  );
END $$;
REVOKE EXECUTE ON FUNCTION public.place_virtual_ticket(jsonb) FROM anon;

-- ============ VIRTUAL ENGINE ============

DROP FUNCTION IF EXISTS public.admin_set_virtual_cycle(integer);
DROP FUNCTION IF EXISTS public.admin_set_virtual_cycle(boolean);
CREATE OR REPLACE FUNCTION public.admin_set_virtual_cycle(_running boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false, 'error', 'forbidden'); END IF;
  UPDATE public.app_settings SET virtual_cycle_running = _running, updated_at = now() WHERE id = 1;
  RETURN jsonb_build_object('ok', true, 'running', _running);
END $$;
REVOKE EXECUTE ON FUNCTION public.admin_set_virtual_cycle(boolean) FROM anon;

DROP FUNCTION IF EXISTS public.admin_lock_virtual_round(uuid);
CREATE OR REPLACE FUNCTION public.admin_lock_virtual_round(match_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.matches SET status='live', lock_time = LEAST(COALESCE(lock_time, now()), now()),
    locked_by = auth.uid(), locked_at = now() WHERE id = match_id;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.admin_lock_virtual_round(uuid) FROM anon;

DROP FUNCTION IF EXISTS public.resolve_virtual_round(uuid);
DROP FUNCTION IF EXISTS public.resolve_virtual_round(uuid, integer, integer, uuid);
CREATE OR REPLACE FUNCTION public.resolve_virtual_round(match_id uuid, _home_score integer DEFAULT NULL, _away_score integer DEFAULT NULL, _first_blood_team_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  m public.matches%ROWTYPE; hs integer; as_ integer; fb uuid; max_score integer;
  winner uuid; bet record; all_won boolean;
BEGIN
  SELECT * INTO m FROM public.matches WHERE id = match_id AND is_virtual = true;
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
    FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = match_id AND mk.name ILIKE '%winner%';

  UPDATE public.odds o SET is_winner = (
    (fb = m.home_team_id AND lower(o.label) = lower(COALESCE((SELECT name FROM public.teams WHERE id = m.home_team_id), '')))
    OR (fb = m.away_team_id AND lower(o.label) = lower(COALESCE((SELECT name FROM public.teams WHERE id = m.away_team_id), '')))
  ) FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = match_id AND mk.name ILIKE '%first%blood%';

  UPDATE public.odds o SET is_winner = (o.label = hs || ':' || as_)
    FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = match_id AND mk.name ILIKE '%correct%score%';

  UPDATE public.odds o SET is_winner = CASE
    WHEN o.label ILIKE 'Over%' THEN (hs + as_) > 4.5
    WHEN o.label ILIKE 'Under%' THEN (hs + as_) < 4.5
    ELSE false END
    FROM public.markets mk WHERE o.market_id = mk.id AND mk.match_id = match_id AND mk.name ILIKE '%total%';

  UPDATE public.matches SET status='ended', home_score = hs, away_score = as_,
    winner_team_id = winner, virtual_first_blood_team_id = fb, settled_at = now(), updated_at = now()
   WHERE id = match_id;

  FOR bet IN SELECT DISTINCT b.* FROM public.bets b JOIN public.bet_selections bs ON bs.bet_id = b.id
    WHERE bs.match_id = match_id AND b.status IN ('pending','open')
  LOOP
    UPDATE public.bet_selections bs SET result = CASE WHEN o.is_winner IS TRUE THEN 'won'::public.selection_result ELSE 'lost'::public.selection_result END
      FROM public.odds o WHERE bs.odd_id = o.id AND bs.bet_id = bet.id AND bs.match_id = match_id;
    SELECT bool_and(bs2.result = 'won'::public.selection_result) INTO all_won FROM public.bet_selections bs2 WHERE bs2.bet_id = bet.id;
    IF all_won IS TRUE THEN
      UPDATE public.bets SET status='won', settled_at=now() WHERE id = bet.id;
      UPDATE public.profiles SET token_balance = token_balance + bet.potential_payout WHERE id = bet.user_id;
      INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
        SELECT bet.user_id, bet.potential_payout, token_balance, 'bet_won', 'Virtual win ' || bet.tracking_id FROM public.profiles WHERE id = bet.user_id;
      INSERT INTO public.notifications (user_id, title, body, link)
        VALUES (bet.user_id, 'Ticket won', bet.tracking_id || ' paid ' || bet.potential_payout::text || ' tokens.', '/ticket/' || bet.id::text);
    ELSIF all_won IS FALSE THEN
      UPDATE public.bets SET status='lost', settled_at=now() WHERE id = bet.id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'home', hs, 'away', as_);
END $$;
REVOKE EXECUTE ON FUNCTION public.resolve_virtual_round(uuid, integer, integer, uuid) FROM anon;

DROP FUNCTION IF EXISTS public.virtual_tick();
CREATE OR REPLACE FUNCTION public.virtual_tick()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cfg record; dur_sec integer; anim_sec integer; conc integer; open_count integer;
  scheduled_row record; live_row record; team_a record; team_b record;
  cat_id uuid; new_match_id uuid; mk_id uuid; h int; a int;
  spawned integer := 0; resolved integer := 0; promoted integer := 0;
BEGIN
  SELECT COALESCE(virtual_cycle_running,false) AS running,
         GREATEST(10, COALESCE(virtual_round_duration_seconds,60)) AS dur,
         GREATEST(8, COALESCE(virtual_animation_seconds,30)) AS anim,
         GREATEST(4, LEAST(6, COALESCE(virtual_concurrent_rounds,4))) AS conc
    INTO cfg FROM public.app_settings WHERE id = 1;
  UPDATE public.app_settings SET virtual_cycle_last_tick = now() WHERE id = 1;
  IF NOT cfg.running THEN RETURN jsonb_build_object('ok', true, 'running', false); END IF;

  dur_sec := cfg.dur; anim_sec := cfg.anim; conc := cfg.conc;

  UPDATE public.matches SET status='scheduled', lock_time = COALESCE(lock_time, now() + (dur_sec || ' seconds')::interval), updated_at = now()
    WHERE is_virtual = true AND status = 'upcoming';

  FOR scheduled_row IN SELECT id FROM public.matches WHERE is_virtual=true AND status='scheduled' AND COALESCE(lock_time, now()) <= now() ORDER BY lock_time ASC LOOP
    UPDATE public.matches SET status='live', locked_at = COALESCE(locked_at, now()), updated_at=now() WHERE id = scheduled_row.id;
    promoted := promoted + 1;
  END LOOP;

  FOR live_row IN SELECT id FROM public.matches WHERE is_virtual=true AND status='live'
    AND COALESCE(locked_at, lock_time, start_time, created_at, now()) + (anim_sec || ' seconds')::interval <= now()
    ORDER BY COALESCE(locked_at, lock_time, start_time, created_at) ASC LIMIT 20 LOOP
    PERFORM public.resolve_virtual_round(live_row.id, NULL, NULL, NULL);
    resolved := resolved + 1;
  END LOOP;

  SELECT COUNT(*) INTO open_count FROM public.matches WHERE is_virtual=true AND status IN ('scheduled','live');

  WHILE open_count < conc LOOP
    SELECT id, name INTO team_a FROM public.teams ORDER BY random() LIMIT 1;
    SELECT id, name INTO team_b FROM public.teams WHERE id <> team_a.id ORDER BY random() LIMIT 1;
    EXIT WHEN team_a.id IS NULL OR team_b.id IS NULL;
    SELECT id INTO cat_id FROM public.categories WHERE name = 'Virtual Gangs' LIMIT 1;
    IF cat_id IS NULL THEN
      INSERT INTO public.categories (name, icon) VALUES ('Virtual Gangs', '🎲') RETURNING id INTO cat_id;
    END IF;
    INSERT INTO public.matches (name, home_team_id, away_team_id, category_id, status, is_virtual, start_time, lock_time, home_score, away_score)
      VALUES (team_a.name || ' vs ' || team_b.name, team_a.id, team_b.id, cat_id, 'scheduled', true, now(), now() + (dur_sec || ' seconds')::interval, 0, 0)
      RETURNING id INTO new_match_id;
    INSERT INTO public.markets (match_id, name, is_open) VALUES (new_match_id, 'Match Winner', true) RETURNING id INTO mk_id;
    INSERT INTO public.odds (market_id, label, value) VALUES (mk_id, team_a.name, 1.95), (mk_id, 'Draw', 3.40), (mk_id, team_b.name, 1.95);
    INSERT INTO public.markets (match_id, name, is_open) VALUES (new_match_id, 'First Blood', true) RETURNING id INTO mk_id;
    INSERT INTO public.odds (market_id, label, value) VALUES (mk_id, team_a.name, 1.95), (mk_id, team_b.name, 1.95);
    INSERT INTO public.markets (match_id, name, is_open) VALUES (new_match_id, 'Total Kills O/U 4.5', true) RETURNING id INTO mk_id;
    INSERT INTO public.odds (market_id, label, value) VALUES (mk_id, 'Over 4.5', 1.85), (mk_id, 'Under 4.5', 1.85);
    INSERT INTO public.markets (match_id, name, is_open) VALUES (new_match_id, 'Correct Score', true) RETURNING id INTO mk_id;
    FOR h IN 0..4 LOOP FOR a IN 0..4 LOOP
      INSERT INTO public.odds (market_id, label, value) VALUES (mk_id, h::text || ':' || a::text, 8.50);
    END LOOP; END LOOP;
    spawned := spawned + 1;
    open_count := open_count + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'running', true, 'spawned', spawned, 'promoted', promoted, 'resolved', resolved);
END $$;
REVOKE EXECUTE ON FUNCTION public.virtual_tick() FROM anon;

-- Ensure default app_settings row is sensible for engine
UPDATE public.app_settings SET
  virtual_concurrent_rounds = GREATEST(4, COALESCE(virtual_concurrent_rounds, 4)),
  virtual_round_duration_seconds = GREATEST(30, COALESCE(virtual_round_duration_seconds, 60)),
  virtual_animation_seconds = GREATEST(8, COALESCE(virtual_animation_seconds, 30))
WHERE id = 1;
