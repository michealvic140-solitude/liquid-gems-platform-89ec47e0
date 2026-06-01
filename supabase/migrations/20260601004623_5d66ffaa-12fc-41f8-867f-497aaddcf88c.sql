-- ============================================================
-- 1. Extend user_sessions with richer activity tracking
-- ============================================================
ALTER TABLE public.user_sessions
  ADD COLUMN IF NOT EXISTS session_start timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS signed_in_at timestamptz,
  ADD COLUMN IF NOT EXISTS ip_address text,
  ADD COLUMN IF NOT EXISTS device_type text,
  ADD COLUMN IF NOT EXISTS browser text,
  ADD COLUMN IF NOT EXISTS os text;

-- ============================================================
-- 2. Referral redemptions (one per user)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.referral_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  referrer_id uuid NOT NULL,
  code text NOT NULL,
  referee_bonus bigint NOT NULL DEFAULT 0,
  referrer_bonus bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT ON public.referral_redemptions TO authenticated;
GRANT ALL ON public.referral_redemptions TO service_role;

ALTER TABLE public.referral_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own referral redemption read"
  ON public.referral_redemptions FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = referrer_id OR public.is_admin(auth.uid()));

CREATE POLICY "referral redemption admin"
  ON public.referral_redemptions FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE INDEX IF NOT EXISTS idx_referral_redemptions_referrer ON public.referral_redemptions(referrer_id);

-- ============================================================
-- 3. redeem_referral_code RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.redeem_referral_code(_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid();
  ref_profile public.profiles%ROWTYPE;
  cfg record;
  normalized text := upper(trim(_code));
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  IF normalized = '' OR normalized IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_code');
  END IF;

  IF EXISTS (SELECT 1 FROM public.referral_redemptions WHERE user_id = uid) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_redeemed');
  END IF;

  SELECT * INTO ref_profile FROM public.profiles
   WHERE upper(referral_code) = normalized LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'code_not_found'); END IF;
  IF ref_profile.id = uid THEN
    RETURN jsonb_build_object('ok', false, 'error', 'self_referral');
  END IF;

  SELECT COALESCE(referral_bonus_referee, 0) AS referee_bonus,
         COALESCE(referral_bonus_referrer, 0) AS referrer_bonus
    INTO cfg FROM public.app_settings WHERE id = 1;

  INSERT INTO public.referral_redemptions (user_id, referrer_id, code, referee_bonus, referrer_bonus)
    VALUES (uid, ref_profile.id, normalized, cfg.referee_bonus, cfg.referrer_bonus);

  INSERT INTO public.referrals (referrer_id, referee_id, referrer_bonus, referee_bonus)
    VALUES (ref_profile.id, uid, cfg.referrer_bonus, cfg.referee_bonus);

  UPDATE public.profiles SET token_balance = token_balance + cfg.referee_bonus,
                              referred_by = normalized WHERE id = uid;
  UPDATE public.profiles SET token_balance = token_balance + cfg.referrer_bonus WHERE id = ref_profile.id;

  IF cfg.referee_bonus > 0 THEN
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
      SELECT uid, cfg.referee_bonus, token_balance, 'referral_redeem', 'Redeemed referral ' || normalized
        FROM public.profiles WHERE id = uid;
  END IF;
  IF cfg.referrer_bonus > 0 THEN
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
      SELECT ref_profile.id, cfg.referrer_bonus, token_balance, 'referral_bonus', 'Referral bonus from ' || uid::text
        FROM public.profiles WHERE id = ref_profile.id;
    INSERT INTO public.notifications (user_id, title, body, link)
      VALUES (ref_profile.id, 'Referral bonus', cfg.referrer_bonus || ' tokens credited for a referred sign-up.', '/dashboard');
  END IF;

  RETURN jsonb_build_object('ok', true, 'referee_bonus', cfg.referee_bonus, 'referrer_bonus', cfg.referrer_bonus);
END $$;

-- Auto-apply referral code from signup metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  meta_code text;
BEGIN
  INSERT INTO public.profiles (id, email, full_name, referral_code)
  VALUES (
    NEW.id, NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    'LSL-' || upper(substr(replace(NEW.id::text, '-', ''), 1, 6))
  ) ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'viewer') ON CONFLICT DO NOTHING;

  meta_code := COALESCE(NEW.raw_user_meta_data->>'referral_code', NEW.raw_user_meta_data->>'referred_by');
  IF meta_code IS NOT NULL AND length(trim(meta_code)) > 0 THEN
    UPDATE public.profiles SET referred_by = upper(trim(meta_code)) WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END $$;

-- ============================================================
-- 4. Leaderboard admin RPCs
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_clear_leaderboard()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  TRUNCATE TABLE public.season_points;
  TRUNCATE TABLE public.leaderboard_overrides;
  RETURN jsonb_build_object('ok', true);
END $$;

ALTER TABLE public.leaderboard_overrides
  ADD COLUMN IF NOT EXISTS name text,
  ADD COLUMN IF NOT EXISTS top_player text,
  ADD COLUMN IF NOT EXISTS wins integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS losses integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS draws integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS played integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS points bigint NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.admin_upsert_leaderboard_override(
  _id uuid, _kind text, _name text, _top_player text,
  _wins integer, _losses integer, _draws integer, _played integer,
  _points bigint, _manual_rank integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  IF _id IS NULL THEN
    INSERT INTO public.leaderboard_overrides
      (kind, name, top_player, wins, losses, draws, played, points, manual_rank, user_id)
      VALUES (_kind, _name, _top_player, _wins, _losses, _draws, _played, _points, _manual_rank, auth.uid())
      RETURNING id INTO new_id;
  ELSE
    UPDATE public.leaderboard_overrides SET
      kind = _kind, name = _name, top_player = _top_player,
      wins = _wins, losses = _losses, draws = _draws, played = _played,
      points = _points, manual_rank = _manual_rank
      WHERE id = _id RETURNING id INTO new_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', new_id);
END $$;

CREATE OR REPLACE FUNCTION public.admin_delete_leaderboard_override(_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  DELETE FROM public.leaderboard_overrides WHERE id = _id;
  RETURN jsonb_build_object('ok', true);
END $$;

-- ============================================================
-- 5. virtual_tick: respect admin concurrent_rounds; only Winner + First Blood markets
-- ============================================================
CREATE OR REPLACE FUNCTION public.virtual_tick()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cfg record;
  dur_sec integer;
  anim_sec integer;
  conc integer;
  open_count integer;
  scheduled_row record;
  live_row record;
  team_a record;
  team_b record;
  cat_id uuid;
  batch_id uuid;
  new_match_id uuid;
  mk_id uuid;
  spawned integer := 0;
  resolved integer := 0;
  promoted integer := 0;
BEGIN
  SELECT COALESCE(virtual_cycle_running,false) AS running,
         GREATEST(10, COALESCE(virtual_round_duration_seconds,60)) AS dur,
         GREATEST(8, COALESCE(virtual_animation_seconds,30)) AS anim,
         GREATEST(1, COALESCE(virtual_concurrent_rounds,4)) AS conc
    INTO cfg FROM public.app_settings WHERE id = 1;
  UPDATE public.app_settings SET virtual_cycle_last_tick = now() WHERE id = 1;
  IF NOT cfg.running THEN RETURN jsonb_build_object('ok', true, 'running', false); END IF;

  dur_sec := cfg.dur; anim_sec := cfg.anim; conc := cfg.conc;

  UPDATE public.matches
     SET status='scheduled',
         lock_time = COALESCE(lock_time, now() + (dur_sec || ' seconds')::interval),
         virtual_round_batch_id = COALESCE(virtual_round_batch_id, id),
         updated_at = now()
   WHERE is_virtual = true AND status = 'upcoming';

  FOR scheduled_row IN
    SELECT id FROM public.matches
     WHERE is_virtual=true AND status='scheduled' AND COALESCE(lock_time, now()) <= now()
     ORDER BY lock_time ASC
  LOOP
    UPDATE public.matches SET status='live', locked_at = now(), updated_at=now() WHERE id = scheduled_row.id;
    promoted := promoted + 1;
  END LOOP;

  FOR live_row IN
    SELECT id FROM public.matches
     WHERE is_virtual=true AND status='live'
       AND COALESCE(locked_at, lock_time, start_time, created_at, now()) + (anim_sec || ' seconds')::interval <= now()
     ORDER BY COALESCE(locked_at, lock_time, start_time, created_at) ASC LIMIT 50
  LOOP
    PERFORM public.resolve_virtual_round(live_row.id, NULL, NULL, NULL);
    resolved := resolved + 1;
  END LOOP;

  SELECT COUNT(*) INTO open_count FROM public.matches WHERE is_virtual=true AND status IN ('scheduled','live');

  IF open_count = 0 THEN
    batch_id := gen_random_uuid();
    WHILE spawned < conc LOOP
      SELECT id, name INTO team_a FROM public.teams ORDER BY random() LIMIT 1;
      SELECT id, name INTO team_b FROM public.teams WHERE id <> team_a.id ORDER BY random() LIMIT 1;
      EXIT WHEN team_a.id IS NULL OR team_b.id IS NULL;
      SELECT id INTO cat_id FROM public.categories WHERE name = 'Virtual Gangs' LIMIT 1;
      IF cat_id IS NULL THEN
        INSERT INTO public.categories (name, icon) VALUES ('Virtual Gangs', '🎲') RETURNING id INTO cat_id;
      END IF;

      INSERT INTO public.matches (name, home_team_id, away_team_id, category_id, status, is_virtual, start_time, lock_time, virtual_round_batch_id, home_score, away_score)
        VALUES (team_a.name || ' vs ' || team_b.name, team_a.id, team_b.id, cat_id, 'scheduled', true, now(), now() + (dur_sec || ' seconds')::interval, batch_id, 0, 0)
        RETURNING id INTO new_match_id;

      INSERT INTO public.markets (match_id, name, is_open) VALUES (new_match_id, 'Match Winner', true) RETURNING id INTO mk_id;
      INSERT INTO public.odds (market_id, label, value) VALUES (mk_id, team_a.name, 1.95), (mk_id, 'Draw', 3.40), (mk_id, team_b.name, 1.95);

      INSERT INTO public.markets (match_id, name, is_open) VALUES (new_match_id, 'First Blood', true) RETURNING id INTO mk_id;
      INSERT INTO public.odds (market_id, label, value) VALUES (mk_id, team_a.name, 1.95), (mk_id, team_b.name, 1.95);

      spawned := spawned + 1;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'running', true, 'spawned', spawned, 'promoted', promoted, 'resolved', resolved, 'open_count', open_count);
END $$;

-- ============================================================
-- 6. Remove existing Total Kills + Correct Score markets from currently open virtual matches
-- ============================================================
DELETE FROM public.odds WHERE market_id IN (
  SELECT mk.id FROM public.markets mk
  JOIN public.matches m ON m.id = mk.match_id
  WHERE m.is_virtual = true AND (mk.name ILIKE '%total%kill%' OR mk.name ILIKE '%correct%score%')
);
DELETE FROM public.markets WHERE id IN (
  SELECT mk.id FROM public.markets mk
  JOIN public.matches m ON m.id = mk.match_id
  WHERE m.is_virtual = true AND (mk.name ILIKE '%total%kill%' OR mk.name ILIKE '%correct%score%')
);

-- ============================================================
-- 7. Repair stuck pending vouchers (run now + reusable RPC)
-- ============================================================
CREATE OR REPLACE FUNCTION public.fix_pending_virtual_bets()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  bet record;
  total_sel int;
  ended_sel int;
  lost_sel int;
  fixed int := 0;
BEGIN
  FOR bet IN
    SELECT DISTINCT b.* FROM public.bets b
    JOIN public.bet_selections bs ON bs.bet_id = b.id
    WHERE b.status = 'pending'
  LOOP
    -- Settle any selections whose match has ended but selection result is null
    UPDATE public.bet_selections bs
      SET result = CASE WHEN o.is_winner IS TRUE THEN 'won'::public.selection_result
                        ELSE 'lost'::public.selection_result END
      FROM public.odds o, public.matches m
      WHERE bs.bet_id = bet.id
        AND bs.odd_id = o.id
        AND bs.match_id = m.id
        AND m.status = 'ended'
        AND bs.result IS NULL;

    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE m.status = 'ended'),
           COUNT(*) FILTER (WHERE bs.result = 'lost'::public.selection_result)
      INTO total_sel, ended_sel, lost_sel
      FROM public.bet_selections bs JOIN public.matches m ON m.id = bs.match_id
     WHERE bs.bet_id = bet.id;

    IF lost_sel > 0 THEN
      UPDATE public.bets SET status='lost', settled_at = COALESCE(settled_at, now()) WHERE id = bet.id;
      fixed := fixed + 1;
    ELSIF ended_sel = total_sel AND total_sel > 0 THEN
      UPDATE public.bets SET status='won', settled_at = COALESCE(settled_at, now()) WHERE id = bet.id;
      fixed := fixed + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'fixed', fixed);
END $$;

SELECT public.fix_pending_virtual_bets();

-- ============================================================
-- 8. Wipe leaderboard data (user requested full reset)
-- ============================================================
TRUNCATE TABLE public.season_points;
TRUNCATE TABLE public.leaderboard_overrides;
