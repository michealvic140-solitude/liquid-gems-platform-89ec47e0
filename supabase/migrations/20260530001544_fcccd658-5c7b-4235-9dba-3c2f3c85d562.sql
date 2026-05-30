CREATE OR REPLACE FUNCTION public.virtual_score_for_match(_match_id uuid)
RETURNS TABLE(home_score integer, away_score integer, first_blood_team_id uuid)
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  m public.matches%ROWTYPE;
  event_count integer;
  home_target integer;
  away_target integer;
  home_left integer;
  away_left integer;
  i integer;
  event_at numeric;
  first_at numeric := 2;
  side text;
BEGIN
  SELECT * INTO m FROM public.matches WHERE id = _match_id;
  IF NOT FOUND THEN
    home_score := 0;
    away_score := 0;
    first_blood_team_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  event_count := 4 + floor(public.virtual_seed_rand(_match_id::text, 901) * 5)::integer;
  home_target := 1 + floor(public.virtual_seed_rand(_match_id::text, 902) * GREATEST(1, event_count - 1))::integer;
  home_target := LEAST(event_count - 1, GREATEST(1, home_target));
  away_target := GREATEST(1, event_count - home_target);
  home_left := home_target;
  away_left := away_target;

  home_score := 0;
  away_score := 0;
  first_blood_team_id := NULL;

  FOR i IN 0..GREATEST(0, event_count - 1) LOOP
    event_at := 0.08 + public.virtual_seed_rand(_match_id::text, 920 + i) * 0.86;

    IF home_left <= 0 THEN
      side := 'away';
    ELSIF away_left <= 0 THEN
      side := 'home';
    ELSIF public.virtual_seed_rand(_match_id::text, 960 + i) < (home_left::numeric / GREATEST(1, home_left + away_left)) THEN
      side := 'home';
    ELSE
      side := 'away';
    END IF;

    IF side = 'home' THEN
      home_score := home_score + 1;
      home_left := home_left - 1;
    ELSE
      away_score := away_score + 1;
      away_left := away_left - 1;
    END IF;

    IF event_at < first_at THEN
      first_at := event_at;
      first_blood_team_id := CASE WHEN side = 'home' THEN m.home_team_id ELSE m.away_team_id END;
    END IF;
  END LOOP;

  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_virtual_round(_match_id uuid, _home_score integer DEFAULT NULL::integer, _away_score integer DEFAULT NULL::integer, _first_blood_team_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  m public.matches%ROWTYPE;
  planned record;
  hs integer;
  as_ integer;
  fb uuid;
  winner uuid;
  bet record;
  unresolved_count integer;
  has_lost boolean;
  is_virtual_bet boolean;
BEGIN
  SELECT * INTO m FROM public.matches WHERE id = _match_id AND is_virtual = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;

  SELECT * INTO planned FROM public.virtual_score_for_match(_match_id);

  hs := COALESCE(_home_score, CASE WHEN m.status = 'ended' THEN m.home_score ELSE NULL END, planned.home_score, 0);
  as_ := COALESCE(_away_score, CASE WHEN m.status = 'ended' THEN m.away_score ELSE NULL END, planned.away_score, 0);
  fb := COALESCE(_first_blood_team_id, CASE WHEN m.status = 'ended' THEN m.virtual_first_blood_team_id ELSE NULL END, planned.first_blood_team_id,
                 CASE WHEN hs >= as_ THEN m.home_team_id ELSE m.away_team_id END);
  winner := CASE WHEN hs > as_ THEN m.home_team_id WHEN as_ > hs THEN m.away_team_id ELSE NULL END;

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
    winner_team_id = winner, virtual_first_blood_team_id = fb,
    settled_at = COALESCE(settled_at, now()), updated_at = now()
   WHERE id = _match_id;

  FOR bet IN SELECT DISTINCT b.* FROM public.bets b
    JOIN public.bet_selections bs ON bs.bet_id = b.id
    WHERE bs.match_id = _match_id AND b.status IN ('pending','open','won','lost')
  LOOP
    UPDATE public.bet_selections bs
      SET result = CASE WHEN o.is_winner IS TRUE
        THEN 'won'::public.selection_result
        ELSE 'lost'::public.selection_result END
      FROM public.odds o
      WHERE bs.odd_id = o.id AND bs.bet_id = bet.id AND bs.match_id = _match_id AND bs.result IS NULL;

    SELECT
      COUNT(*) FILTER (WHERE bs2.result IS NULL),
      bool_or(bs2.result = 'lost'::public.selection_result)
    INTO unresolved_count, has_lost
    FROM public.bet_selections bs2 WHERE bs2.bet_id = bet.id;

    SELECT bool_or(mt.is_virtual) INTO is_virtual_bet
      FROM public.bet_selections bs3
      JOIN public.matches mt ON mt.id = bs3.match_id
     WHERE bs3.bet_id = bet.id;

    IF has_lost IS TRUE THEN
      UPDATE public.bets SET status='lost'::public.bet_status, settled_at=COALESCE(settled_at, now()) WHERE id = bet.id AND status IN ('pending','open','won','lost');
    ELSIF unresolved_count = 0 THEN
      UPDATE public.bets SET status='won'::public.bet_status, settled_at=COALESCE(settled_at, now()) WHERE id = bet.id AND status IN ('pending','open','won','lost');
      IF bet.status <> 'won' THEN
        IF is_virtual_bet IS TRUE THEN
          INSERT INTO public.notifications (user_id, title, body, link)
            VALUES (bet.user_id, 'Virtual ticket won — claim now',
                    bet.tracking_id || ' is eligible for a ' || bet.potential_payout::text || ' token payout (admin approval required).',
                    '/ticket/' || bet.id::text);
        ELSE
          UPDATE public.profiles SET token_balance = token_balance + bet.potential_payout WHERE id = bet.user_id;
          INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
            SELECT bet.user_id, bet.potential_payout, token_balance, 'bet_won', 'Win ' || bet.tracking_id
              FROM public.profiles WHERE id = bet.user_id;
          INSERT INTO public.notifications (user_id, title, body, link)
            VALUES (bet.user_id, 'Ticket won', bet.tracking_id || ' paid ' || bet.potential_payout::text || ' tokens.', '/ticket/' || bet.id::text);
        END IF;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'home', hs, 'away', as_);
END;
$$;

WITH ended_virtual AS (
  SELECT id FROM public.matches WHERE is_virtual = true AND status = 'ended'
)
UPDATE public.odds o
SET is_winner = CASE
  WHEN mk.name ILIKE '%winner%' THEN (
    (m.home_score > m.away_score AND lower(o.label) = lower(ht.name)) OR
    (m.away_score > m.home_score AND lower(o.label) = lower(at.name)) OR
    (m.home_score = m.away_score AND lower(o.label) = 'draw')
  )
  WHEN mk.name ILIKE '%first%blood%' THEN (
    (m.virtual_first_blood_team_id = m.home_team_id AND lower(o.label) = lower(ht.name)) OR
    (m.virtual_first_blood_team_id = m.away_team_id AND lower(o.label) = lower(at.name))
  )
  WHEN mk.name ILIKE '%correct%score%' THEN o.label = m.home_score || ':' || m.away_score
  WHEN mk.name ILIKE '%total%' AND o.label ILIKE 'Over%' THEN (m.home_score + m.away_score) > COALESCE(NULLIF(regexp_replace(o.label, '[^0-9.]', '', 'g'), '')::numeric, 4.5)
  WHEN mk.name ILIKE '%total%' AND o.label ILIKE 'Under%' THEN (m.home_score + m.away_score) < COALESCE(NULLIF(regexp_replace(o.label, '[^0-9.]', '', 'g'), '')::numeric, 4.5)
  ELSE false
END
FROM public.markets mk
JOIN public.matches m ON m.id = mk.match_id
JOIN ended_virtual ev ON ev.id = m.id
LEFT JOIN public.teams ht ON ht.id = m.home_team_id
LEFT JOIN public.teams at ON at.id = m.away_team_id
WHERE o.market_id = mk.id;

UPDATE public.bet_selections bs
SET result = CASE WHEN o.is_winner IS TRUE THEN 'won'::public.selection_result ELSE 'lost'::public.selection_result END
FROM public.odds o, public.matches m
WHERE bs.odd_id = o.id
  AND bs.match_id = m.id
  AND m.is_virtual = true
  AND m.status = 'ended'
  AND bs.result IS NULL;

WITH agg AS (
  SELECT b.id,
         COUNT(*) FILTER (WHERE bs.result IS NULL) AS unresolved_count,
         bool_or(bs.result = 'lost'::public.selection_result) AS has_lost
  FROM public.bets b
  JOIN public.bet_selections bs ON bs.bet_id = b.id
  JOIN public.matches m ON m.id = bs.match_id
  WHERE m.is_virtual = true AND b.status IN ('pending','open','won','lost')
  GROUP BY b.id
)
UPDATE public.bets b
SET status = CASE WHEN agg.has_lost IS TRUE THEN 'lost'::public.bet_status ELSE 'won'::public.bet_status END,
    settled_at = COALESCE(b.settled_at, now())
FROM agg
WHERE b.id = agg.id
  AND agg.unresolved_count = 0
  AND b.status IN ('pending','open','won','lost');

REVOKE EXECUTE ON FUNCTION public.virtual_score_for_match(uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.virtual_score_for_match(uuid) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.resolve_virtual_round(uuid, integer, integer, uuid) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_virtual_round(uuid, integer, integer, uuid) TO authenticated, service_role;