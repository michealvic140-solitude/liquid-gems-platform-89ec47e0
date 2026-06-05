-- Comprehensive admin audit + private media helpers + leaderboard/referral/xp repairs

-- 1) Add optional fields needed by current UI/admin requests.
ALTER TABLE public.seasons
  ADD COLUMN IF NOT EXISTS banner_url text;

ALTER TABLE public.audit_logs
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS actor_email text,
  ADD COLUMN IF NOT EXISTS actor_name text,
  ADD COLUMN IF NOT EXISTS target_name text,
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS route text,
  ADD COLUMN IF NOT EXISTS source text;

CREATE INDEX IF NOT EXISTS idx_audit_action_created ON public.audit_logs(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_target ON public.audit_logs(target_type, target_id);

-- 2) Role helpers.
CREATE OR REPLACE FUNCTION public.current_admin_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin') THEN 'admin'
    WHEN EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'moderator') THEN 'moderator'
    ELSE NULL
  END
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_moderator(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('admin','moderator'))
$$;

-- 3) Storage path/public URL helpers. Existing rows stored broken public URLs while buckets are private.
CREATE OR REPLACE FUNCTION public.storage_path_from_url(_url text, _bucket text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  marker text := '/storage/v1/object/public/' || _bucket || '/';
  marker2 text := '/storage/v1/object/sign/' || _bucket || '/';
  pos int;
  out_path text;
BEGIN
  IF _url IS NULL OR trim(_url) = '' THEN RETURN NULL; END IF;
  IF position('://' in _url) = 0 AND _url NOT LIKE '/storage/%' THEN
    RETURN ltrim(_url, '/');
  END IF;
  pos := position(marker in _url);
  IF pos > 0 THEN
    out_path := substring(_url from pos + length(marker));
  ELSE
    pos := position(marker2 in _url);
    IF pos > 0 THEN
      out_path := substring(_url from pos + length(marker2));
    ELSE
      RETURN _url;
    END IF;
  END IF;
  IF position('?' in out_path) > 0 THEN
    out_path := split_part(out_path, '?', 1);
  END IF;
  RETURN out_path;
END $$;

CREATE OR REPLACE FUNCTION public.signed_storage_url(_bucket text, _path_or_url text, _expires integer DEFAULT 3600)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  p text;
  signed text;
BEGIN
  IF _path_or_url IS NULL OR trim(_path_or_url) = '' THEN RETURN NULL; END IF;
  p := public.storage_path_from_url(_path_or_url, _bucket);
  IF p IS NULL OR p = '' THEN RETURN NULL; END IF;
  SELECT storage.sign(_bucket, p, GREATEST(60, LEAST(COALESCE(_expires, 3600), 604800))) INTO signed;
  RETURN signed;
EXCEPTION WHEN others THEN
  RETURN _path_or_url;
END $$;

GRANT EXECUTE ON FUNCTION public.signed_storage_url(text, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.storage_path_from_url(text, text) TO anon, authenticated;

CREATE OR REPLACE VIEW public.events_public
WITH (security_invoker = on) AS
SELECT e.*, public.signed_storage_url('event-banners', e.banner_url, 3600) AS banner_signed_url
FROM public.events e;

CREATE OR REPLACE VIEW public.highlights_public
WITH (security_invoker = on) AS
SELECT h.*, public.signed_storage_url('highlights', h.media_url, 3600) AS media_signed_url
FROM public.highlights h;

CREATE OR REPLACE VIEW public.announcements_public
WITH (security_invoker = on) AS
SELECT a.*, public.signed_storage_url('announcements', a.image_url, 3600) AS image_signed_url
FROM public.announcements a;

CREATE OR REPLACE VIEW public.advertisements_public
WITH (security_invoker = on) AS
SELECT a.*, public.signed_storage_url('ads', a.image_url, 3600) AS image_signed_url
FROM public.advertisements a;

CREATE OR REPLACE VIEW public.seasons_public
WITH (security_invoker = on) AS
SELECT s.*, public.signed_storage_url('season-banners', s.banner_url, 3600) AS banner_signed_url
FROM public.seasons s;

GRANT SELECT ON public.events_public TO anon, authenticated;
GRANT SELECT ON public.highlights_public TO anon, authenticated;
GRANT SELECT ON public.announcements_public TO anon, authenticated;
GRANT SELECT ON public.advertisements_public TO anon, authenticated;
GRANT SELECT ON public.seasons_public TO anon, authenticated;

-- 4) Robust explicit audit function. If an automatic row was just created for the same target, upgrade it instead of duplicating.
CREATE OR REPLACE FUNCTION public.admin_log_action(
  _action text,
  _target_type text DEFAULT NULL,
  _target_id text DEFAULT NULL,
  _metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  role_name text;
  actor public.profiles%ROWTYPE;
  target_profile public.profiles%ROWTYPE;
  merged jsonb;
  target_label text;
  reason_text text;
  route_text text;
  existing_id uuid;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'unauthenticated');
  END IF;

  SELECT public.current_admin_role() INTO role_name;
  IF role_name IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_admin_or_moderator');
  END IF;

  SELECT * INTO actor FROM public.profiles WHERE id = uid;

  IF COALESCE(_metadata->>'target_user_id', CASE WHEN _target_type = 'user' THEN _target_id ELSE NULL END) IS NOT NULL THEN
    SELECT * INTO target_profile
    FROM public.profiles
    WHERE id = COALESCE(_metadata->>'target_user_id', CASE WHEN _target_type = 'user' THEN _target_id ELSE NULL END)::uuid;
  END IF;

  target_label := COALESCE(
    _metadata->>'target_name',
    _metadata->>'target_user_name',
    _metadata->>'name',
    target_profile.ingame_name,
    target_profile.full_name,
    target_profile.email,
    _target_id
  );
  reason_text := NULLIF(COALESCE(_metadata->>'reason', _metadata->>'note', _metadata->>'review_note'), '');
  route_text := NULLIF(COALESCE(_metadata->>'route', _metadata->>'where'), '');

  merged := COALESCE(_metadata, '{}'::jsonb)
    || jsonb_build_object(
      'actor_id', uid,
      'actor_email', actor.email,
      'actor_name', COALESCE(actor.ingame_name, actor.full_name, actor.email),
      'actor_role', role_name,
      'target_name', target_label,
      'target_id', _target_id,
      'target_type', _target_type,
      'reason', reason_text,
      'route', route_text,
      'timestamp_iso', now()
    );

  SELECT id INTO existing_id
  FROM public.audit_logs
  WHERE actor_id = uid
    AND COALESCE(target_id, '') = COALESCE(_target_id, '')
    AND COALESCE(target_type, '') = COALESCE(_target_type, '')
    AND metadata->>'auto_audit' = 'true'
    AND created_at > now() - interval '8 seconds'
  ORDER BY created_at DESC
  LIMIT 1;

  IF existing_id IS NOT NULL THEN
    UPDATE public.audit_logs
    SET action = _action,
        metadata = merged,
        actor_role = role_name,
        actor_email = actor.email,
        actor_name = COALESCE(actor.ingame_name, actor.full_name, actor.email),
        target_name = target_label,
        reason = reason_text,
        route = route_text,
        source = COALESCE(_metadata->>'source', 'admin_panel')
    WHERE id = existing_id;
    RETURN jsonb_build_object('ok', true, 'id', existing_id, 'deduped', true);
  END IF;

  INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata, actor_role, actor_email, actor_name, target_name, reason, route, source)
  VALUES (uid, _action, _target_type, _target_id, merged, role_name, actor.email, COALESCE(actor.ingame_name, actor.full_name, actor.email), target_label, reason_text, route_text, COALESCE(_metadata->>'source', 'admin_panel'))
  RETURNING id INTO existing_id;

  RETURN jsonb_build_object('ok', true, 'id', existing_id, 'deduped', false);
END $$;

REVOKE EXECUTE ON FUNCTION public.admin_log_action(text, text, text, jsonb) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_log_action(text, text, text, jsonb) TO authenticated;

-- 5) Automatic audit for admin/moderator DML on core admin tables. Excludes automatic virtual round churn.
CREATE OR REPLACE FUNCTION public.audit_admin_dml()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  role_name text;
  row_id text;
  row_name text;
  act text;
  meta jsonb := '{}'::jsonb;
  actor public.profiles%ROWTYPE;
BEGIN
  IF uid IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  SELECT public.current_admin_role() INTO role_name;
  IF role_name IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_TABLE_NAME = 'audit_logs' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Do not auto-log virtual rounds; manual virtual round functions/logs are kept.
  IF TG_TABLE_NAME = 'matches' AND COALESCE((to_jsonb(COALESCE(NEW, OLD))->>'is_virtual')::boolean, false) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  row_id := to_jsonb(COALESCE(NEW, OLD))->>'id';
  row_name := COALESCE(
    to_jsonb(COALESCE(NEW, OLD))->>'title',
    to_jsonb(COALESCE(NEW, OLD))->>'name',
    to_jsonb(COALESCE(NEW, OLD))->>'full_name',
    to_jsonb(COALESCE(NEW, OLD))->>'email',
    to_jsonb(COALESCE(NEW, OLD))->>'code',
    row_id
  );

  act := TG_TABLE_NAME || '_' || lower(TG_OP);
  IF TG_TABLE_NAME = 'profiles' THEN
    IF TG_OP = 'UPDATE' AND COALESCE((OLD).is_banned, false) IS DISTINCT FROM COALESCE((NEW).is_banned, false) THEN act := CASE WHEN (NEW).is_banned THEN 'user_banned' ELSE 'user_unbanned' END; END IF;
    IF TG_OP = 'UPDATE' AND COALESCE((OLD).is_restricted, false) IS DISTINCT FROM COALESCE((NEW).is_restricted, false) THEN act := CASE WHEN (NEW).is_restricted THEN 'user_restricted' ELSE 'user_unrestricted' END; END IF;
    IF TG_OP = 'UPDATE' AND COALESCE((OLD).is_muted, false) IS DISTINCT FROM COALESCE((NEW).is_muted, false) THEN act := CASE WHEN (NEW).is_muted THEN 'user_muted' ELSE 'user_unmuted' END; END IF;
    row_name := COALESCE((NEW).ingame_name, (NEW).full_name, (NEW).email, row_id);
    meta := meta || jsonb_build_object('target_user_id', (NEW).id, 'target_user_email', (NEW).email, 'reason', COALESCE((NEW).ban_reason, (NEW).restrict_reason, (NEW).mute_reason));
  ELSIF TG_TABLE_NAME = 'user_roles' THEN
    act := CASE WHEN TG_OP = 'INSERT' THEN 'role_added' WHEN TG_OP = 'DELETE' THEN 'role_removed' ELSE 'role_updated' END;
    row_id := COALESCE(to_jsonb(COALESCE(NEW, OLD))->>'user_id', row_id);
    meta := meta || jsonb_build_object('role', to_jsonb(COALESCE(NEW, OLD))->>'role', 'target_user_id', row_id);
  ELSIF TG_TABLE_NAME = 'token_requests' THEN
    IF TG_OP = 'UPDATE' AND (OLD).status IS DISTINCT FROM (NEW).status THEN act := 'token_request_' || (NEW).status; END IF;
    meta := meta || jsonb_build_object('target_user_id', COALESCE((NEW).user_id, (OLD).user_id), 'amount', COALESCE((NEW).amount, (OLD).amount));
  ELSIF TG_TABLE_NAME = 'withdrawal_requests' THEN
    IF TG_OP = 'UPDATE' AND (OLD).status IS DISTINCT FROM (NEW).status THEN act := 'withdrawal_' || (NEW).status; END IF;
    meta := meta || jsonb_build_object('target_user_id', COALESCE((NEW).user_id, (OLD).user_id), 'amount', COALESCE((NEW).amount, (OLD).amount), 'reason', COALESCE((NEW).admin_note, (OLD).admin_note));
  ELSIF TG_TABLE_NAME = 'promo_code_requests' THEN
    IF TG_OP = 'UPDATE' AND (OLD).status IS DISTINCT FROM (NEW).status THEN act := 'promo_request_' || (NEW).status; END IF;
    meta := meta || jsonb_build_object('target_user_id', COALESCE((NEW).user_id, (OLD).user_id), 'amount', COALESCE((NEW).amount, (OLD).amount));
  ELSIF TG_TABLE_NAME = 'bets' THEN
    IF TG_OP = 'UPDATE' AND (OLD).status IS DISTINCT FROM (NEW).status THEN act := 'bet_' || (NEW).status; END IF;
    meta := meta || jsonb_build_object('target_user_id', COALESCE((NEW).user_id, (OLD).user_id), 'tracking_id', COALESCE((NEW).tracking_id, (OLD).tracking_id), 'stake', COALESCE((NEW).stake, (OLD).stake));
  ELSIF TG_TABLE_NAME = 'app_settings' THEN
    act := 'settings_' || lower(TG_OP);
  ELSIF TG_TABLE_NAME = 'notifications' THEN
    act := 'notify_' || lower(TG_OP);
    meta := meta || jsonb_build_object('target_user_id', COALESCE((NEW).user_id, (OLD).user_id));
  END IF;

  SELECT * INTO actor FROM public.profiles WHERE id = uid;
  meta := meta || jsonb_build_object(
    'auto_audit', true,
    'actor_role', role_name,
    'actor_email', actor.email,
    'actor_name', COALESCE(actor.ingame_name, actor.full_name, actor.email),
    'target_name', row_name,
    'table', TG_TABLE_NAME,
    'operation', TG_OP,
    'timestamp_iso', now()
  );

  INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata, actor_role, actor_email, actor_name, target_name, reason, source)
  VALUES (uid, act, TG_TABLE_NAME, row_id, meta, role_name, actor.email, COALESCE(actor.ingame_name, actor.full_name, actor.email), row_name, meta->>'reason', 'auto_admin_dml');

  RETURN COALESCE(NEW, OLD);
END $$;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles','user_roles','announcements','highlights','advertisements','events','seasons','categories','teams','players','matches','markets','odds','bets','bet_selections','token_requests','withdrawal_requests','promo_codes','promo_code_requests','support_tickets','ticket_messages','notifications','app_settings','house_wallet','house_transactions','leaderboard_overrides','user_tasks','user_achievements','ban_appeals','broadcasts','gang_emblems'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_admin_dml_%I ON public.%I', t, t);
    EXECUTE format('CREATE TRIGGER trg_audit_admin_dml_%I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.audit_admin_dml()', t, t);
  END LOOP;
END $$;

-- 6) Fix manual virtual RPCs to audit only manual virtual actions.
CREATE OR REPLACE FUNCTION public.admin_lock_virtual_round(match_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE m record;
BEGIN
  IF NOT public.is_admin_or_moderator(auth.uid()) THEN RETURN jsonb_build_object('ok', false, 'error', 'not_allowed'); END IF;
  UPDATE public.matches SET status='live', lock_time = LEAST(COALESCE(lock_time, now()), now()), locked_by = auth.uid(), locked_at = now() WHERE id = match_id RETURNING * INTO m;
  PERFORM public.admin_log_action('virtual_round_locked', 'match', match_id::text, jsonb_build_object('name', m.name, 'manual', true, 'source', 'virtual_admin'));
  RETURN jsonb_build_object('ok', true);
END $$;

-- 7) Leaderboard wipe buttons.
CREATE OR REPLACE FUNCTION public.admin_clear_leaderboard_scope(_scope text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE normalized text := lower(trim(_scope));
DECLARE deleted_overrides int := 0;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false, 'error', 'not_allowed'); END IF;

  IF normalized IN ('gang','gangs','faction','gang_faction','gang_and_faction') THEN
    DELETE FROM public.season_points;
    DELETE FROM public.leaderboard_overrides WHERE kind IN ('gang','faction','gang_faction');
    GET DIAGNOSTICS deleted_overrides = ROW_COUNT;
    PERFORM public.admin_log_action('leaderboard_wipe_gang_faction', 'leaderboard', NULL, jsonb_build_object('scope', normalized, 'reason', 'Admin wipe button'));
  ELSIF normalized IN ('shooter','shooters') THEN
    DELETE FROM public.leaderboard_overrides WHERE kind IN ('shooter','player');
    GET DIAGNOSTICS deleted_overrides = ROW_COUNT;
    PERFORM public.admin_log_action('leaderboard_wipe_shooters', 'leaderboard', NULL, jsonb_build_object('scope', normalized, 'reason', 'Admin wipe button'));
  ELSIF normalized IN ('hall','hall_of_fame','fame') THEN
    UPDATE public.bets SET cashout_amount = 0, potential_payout = 0 WHERE status IN ('won','cashed_out');
    GET DIAGNOSTICS deleted_overrides = ROW_COUNT;
    PERFORM public.admin_log_action('leaderboard_wipe_hall_of_fame', 'leaderboard', NULL, jsonb_build_object('scope', normalized, 'affected_winning_bets', deleted_overrides, 'reason', 'Admin wipe button'));
  ELSE
    RETURN jsonb_build_object('ok', false, 'error', 'unknown_scope');
  END IF;

  RETURN jsonb_build_object('ok', true, 'scope', normalized, 'affected', deleted_overrides);
END $$;

CREATE OR REPLACE FUNCTION public.admin_clear_leaderboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false, 'error', 'not_allowed'); END IF;
  DELETE FROM public.season_points;
  DELETE FROM public.leaderboard_overrides;
  PERFORM public.admin_log_action('leaderboard_wipe_all', 'leaderboard', NULL, jsonb_build_object('scope', 'all', 'reason', 'Admin wipe all'));
  RETURN jsonb_build_object('ok', true);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_clear_leaderboard_scope(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_clear_leaderboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_lock_virtual_round(uuid) TO authenticated;

-- 8) XP and referral fixes.
CREATE OR REPLACE FUNCTION public.redeem_referral_code(_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  ref_profile public.profiles%ROWTYPE;
  cfg record;
  normalized text := upper(trim(_code));
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  IF normalized = '' OR normalized IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'invalid_code'); END IF;
  IF EXISTS (SELECT 1 FROM public.referral_redemptions WHERE user_id = uid) THEN RETURN jsonb_build_object('ok', false, 'error', 'already_redeemed'); END IF;

  SELECT * INTO ref_profile FROM public.profiles WHERE upper(referral_code) = normalized LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'code_not_found'); END IF;
  IF ref_profile.id = uid THEN RETURN jsonb_build_object('ok', false, 'error', 'self_referral'); END IF;

  SELECT COALESCE(referral_bonus_referee, 0) AS referee_bonus,
         COALESCE(referral_bonus_referrer, 0) AS referrer_bonus,
         COALESCE(xp_per_referral, 0) AS xp_bonus
    INTO cfg FROM public.app_settings WHERE id = 1;

  INSERT INTO public.referral_redemptions (user_id, referrer_id, code, referee_bonus, referrer_bonus)
    VALUES (uid, ref_profile.id, normalized, cfg.referee_bonus, cfg.referrer_bonus);
  INSERT INTO public.referrals (referrer_id, referee_id, referrer_bonus, referee_bonus)
    VALUES (ref_profile.id, uid, cfg.referrer_bonus, cfg.referee_bonus);

  UPDATE public.profiles SET token_balance = token_balance + cfg.referee_bonus, referred_by = normalized WHERE id = uid;
  UPDATE public.profiles SET token_balance = token_balance + cfg.referrer_bonus, xp = COALESCE(xp,0) + cfg.xp_bonus WHERE id = ref_profile.id;

  IF cfg.referee_bonus > 0 THEN
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
      SELECT uid, cfg.referee_bonus, token_balance, 'referral_redeem', 'Redeemed referral ' || normalized FROM public.profiles WHERE id = uid;
  END IF;
  IF cfg.referrer_bonus > 0 THEN
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
      SELECT ref_profile.id, cfg.referrer_bonus, token_balance, 'referral_bonus', 'Referral bonus from ' || uid::text FROM public.profiles WHERE id = ref_profile.id;
    INSERT INTO public.notifications (user_id, title, body, link)
      VALUES (ref_profile.id, 'Referral bonus', cfg.referrer_bonus || ' tokens credited for a referred sign-up.', '/dashboard');
  END IF;

  RETURN jsonb_build_object('ok', true, 'referee_bonus', cfg.referee_bonus, 'referrer_bonus', cfg.referrer_bonus, 'xp_bonus', cfg.xp_bonus);
END $$;

CREATE OR REPLACE FUNCTION public.claim_task(task_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE uid uuid := auth.uid(); t public.user_tasks%ROWTYPE;
BEGIN
  SELECT * INTO t FROM public.user_tasks WHERE id = task_id AND user_id = uid;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;
  IF t.status = 'claimed' THEN RETURN jsonb_build_object('ok', false, 'error', 'already_claimed'); END IF;
  IF t.status <> 'completed' THEN RETURN jsonb_build_object('ok', false, 'error', 'not_completed'); END IF;

  UPDATE public.user_tasks SET status='claimed', completed_at=COALESCE(completed_at, now()) WHERE id = task_id;
  UPDATE public.profiles SET token_balance = token_balance + COALESCE(t.reward_tokens, 0), xp = COALESCE(xp,0) + COALESCE(t.reward_tokens,0) WHERE id = uid;

  IF COALESCE(t.reward_tokens, 0) > 0 THEN
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
      SELECT uid, t.reward_tokens, token_balance, 'task_reward', 'Task reward: ' || t.title FROM public.profiles WHERE id = uid;
  END IF;

  RETURN jsonb_build_object('ok', true, 'reward', COALESCE(t.reward_tokens,0), 'xp', COALESCE(t.reward_tokens,0));
END $$;

CREATE OR REPLACE FUNCTION public.verify_xp_consistency(user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE fixed_count int := 0;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_allowed');
  END IF;

  WITH cfg AS (SELECT COALESCE(xp_per_bet,0) xp_bet, COALESCE(xp_per_win,0) xp_win, COALESCE(xp_per_referral,0) xp_ref FROM public.app_settings WHERE id=1),
  calc AS (
    SELECT p.id,
      COALESCE((SELECT count(*) * (SELECT xp_bet FROM cfg) FROM public.bets b WHERE b.user_id=p.id),0)
      + COALESCE((SELECT count(*) * (SELECT xp_win FROM cfg) FROM public.bets b WHERE b.user_id=p.id AND b.status IN ('won','cashed_out')),0)
      + COALESCE((SELECT count(*) * (SELECT xp_ref FROM cfg) FROM public.referrals r WHERE r.referrer_id=p.id),0)
      + COALESCE((SELECT sum(ut.reward_tokens) FROM public.user_tasks ut WHERE ut.user_id=p.id AND ut.status='claimed'),0) AS xp_total
    FROM public.profiles p
    WHERE user_id IS NULL OR p.id = user_id
  ), upd AS (
    UPDATE public.profiles p SET xp = GREATEST(0, calc.xp_total)
    FROM calc
    WHERE p.id=calc.id AND COALESCE(p.xp,0) IS DISTINCT FROM GREATEST(0, calc.xp_total)
    RETURNING p.id
  ) SELECT count(*) INTO fixed_count FROM upd;

  RETURN jsonb_build_object('ok', true, 'fixed', fixed_count);
END $$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_task(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_xp_consistency(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.apply_pending_referral_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE code text;
BEGIN
  IF NEW.referred_by IS NULL OR EXISTS (SELECT 1 FROM public.referral_redemptions WHERE user_id = NEW.id) THEN
    RETURN NEW;
  END IF;
  code := upper(trim(NEW.referred_by));
  -- Cannot impersonate the new user in a trigger, so apply equivalent logic safely.
  DECLARE ref public.profiles%ROWTYPE;
  DECLARE cfg record;
  BEGIN
    SELECT * INTO ref FROM public.profiles WHERE upper(referral_code)=code LIMIT 1;
    IF FOUND AND ref.id <> NEW.id THEN
      SELECT COALESCE(referral_bonus_referee,0) referee_bonus, COALESCE(referral_bonus_referrer,0) referrer_bonus, COALESCE(xp_per_referral,0) xp_bonus INTO cfg FROM public.app_settings WHERE id=1;
      INSERT INTO public.referral_redemptions (user_id, referrer_id, code, referee_bonus, referrer_bonus) VALUES (NEW.id, ref.id, code, cfg.referee_bonus, cfg.referrer_bonus) ON CONFLICT DO NOTHING;
      INSERT INTO public.referrals (referrer_id, referee_id, referrer_bonus, referee_bonus) VALUES (ref.id, NEW.id, cfg.referrer_bonus, cfg.referee_bonus) ON CONFLICT DO NOTHING;
      UPDATE public.profiles SET token_balance = token_balance + cfg.referee_bonus WHERE id = NEW.id;
      UPDATE public.profiles SET token_balance = token_balance + cfg.referrer_bonus, xp = COALESCE(xp,0) + cfg.xp_bonus WHERE id = ref.id;
    END IF;
  END;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_apply_pending_referral_code ON public.profiles;
CREATE TRIGGER trg_apply_pending_referral_code
AFTER INSERT OR UPDATE OF referred_by ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.apply_pending_referral_code();