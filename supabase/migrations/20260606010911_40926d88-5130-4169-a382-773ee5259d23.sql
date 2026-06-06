-- Fix leaderboard wipe RPCs: add explicit WHERE TRUE to satisfy pg_safeupdate
-- and ensure gang_faction wipe clears computed scores as well as manual overrides.

CREATE OR REPLACE FUNCTION public.admin_clear_leaderboard_scope(_scope text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized text := lower(trim(_scope));
  deleted_overrides int := 0;
  deleted_points int := 0;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_allowed');
  END IF;

  IF normalized IN ('gang','gangs','faction','gang_faction','gang_and_faction') THEN
    DELETE FROM public.season_points WHERE TRUE;
    GET DIAGNOSTICS deleted_points = ROW_COUNT;
    DELETE FROM public.leaderboard_overrides WHERE kind IN ('gang','faction','gang_faction');
    GET DIAGNOSTICS deleted_overrides = ROW_COUNT;
    PERFORM public.admin_log_action(
      'leaderboard_wipe_gang_faction', 'leaderboard', NULL,
      jsonb_build_object('scope', normalized, 'overrides_deleted', deleted_overrides, 'season_points_deleted', deleted_points, 'reason', 'Admin wipe button')
    );
  ELSIF normalized IN ('shooter','shooters') THEN
    DELETE FROM public.leaderboard_overrides WHERE kind IN ('shooter','player');
    GET DIAGNOSTICS deleted_overrides = ROW_COUNT;
    PERFORM public.admin_log_action(
      'leaderboard_wipe_shooters', 'leaderboard', NULL,
      jsonb_build_object('scope', normalized, 'overrides_deleted', deleted_overrides, 'reason', 'Admin wipe button')
    );
  ELSIF normalized IN ('hall','hall_of_fame','fame') THEN
    UPDATE public.bets SET cashout_amount = 0, potential_payout = 0
      WHERE status IN ('won','cashed_out');
    GET DIAGNOSTICS deleted_overrides = ROW_COUNT;
    PERFORM public.admin_log_action(
      'leaderboard_wipe_hall_of_fame', 'leaderboard', NULL,
      jsonb_build_object('scope', normalized, 'affected_winning_bets', deleted_overrides, 'reason', 'Admin wipe button')
    );
  ELSE
    RETURN jsonb_build_object('ok', false, 'error', 'unknown_scope');
  END IF;

  RETURN jsonb_build_object('ok', true, 'scope', normalized, 'overrides_deleted', deleted_overrides, 'season_points_deleted', deleted_points);
END $$;

CREATE OR REPLACE FUNCTION public.admin_clear_leaderboard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'not_allowed');
  END IF;
  DELETE FROM public.season_points WHERE TRUE;
  DELETE FROM public.leaderboard_overrides WHERE TRUE;
  PERFORM public.admin_log_action('leaderboard_wipe_all', 'leaderboard', NULL,
    jsonb_build_object('scope', 'all', 'reason', 'Admin wipe all'));
  RETURN jsonb_build_object('ok', true);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_clear_leaderboard_scope(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_clear_leaderboard() TO authenticated;