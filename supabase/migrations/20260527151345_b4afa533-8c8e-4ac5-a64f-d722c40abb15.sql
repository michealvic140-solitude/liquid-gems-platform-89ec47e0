
-- Recreate hot_bets_v1 with security_invoker
DROP VIEW IF EXISTS public.hot_bets_v1;
CREATE VIEW public.hot_bets_v1 WITH (security_invoker=true) AS
SELECT
  m.id AS match_id, m.name AS match_name, mk.name AS market_name,
  o.label AS selection_label, o.value AS odds,
  AVG(o.value)::numeric AS avg_odds,
  COUNT(DISTINCT b.user_id)::bigint AS users_count,
  COUNT(DISTINCT b.id)::bigint AS bets_count,
  COUNT(bs.id)::bigint AS picks,
  COALESCE(SUM(b.stake),0)::bigint AS stake_volume,
  COALESCE(SUM(b.stake),0)::bigint AS total_stake,
  MAX(b.created_at) AS last_picked_at,
  m.start_time AS match_start
FROM public.bet_selections bs
JOIN public.bets b ON b.id = bs.bet_id
JOIN public.matches m ON m.id = bs.match_id
JOIN public.markets mk ON mk.id = bs.market_id
JOIN public.odds o ON o.id = bs.odd_id
WHERE m.status IN ('upcoming','live','scheduled')
GROUP BY m.id, m.name, mk.name, o.label, o.value, m.start_time
ORDER BY bets_count DESC, total_stake DESC;
GRANT SELECT ON public.hot_bets_v1 TO anon, authenticated;

-- RPC stubs / implementations
CREATE OR REPLACE FUNCTION public.server_now() RETURNS timestamptz LANGUAGE sql STABLE SET search_path = public AS $$ SELECT now() $$;

CREATE OR REPLACE FUNCTION public.claim_daily_login() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); reward bigint := 0; today date := current_date; p public.profiles%ROWTYPE;
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  SELECT * INTO p FROM public.profiles WHERE id = uid;
  IF p.last_login_date = today THEN RETURN jsonb_build_object('ok', false, 'error', 'already_claimed'); END IF;
  SELECT daily_login_base_reward INTO reward FROM public.app_settings WHERE id = 1;
  UPDATE public.profiles SET last_login_date = today, streak_days = CASE WHEN p.last_login_date = today - 1 THEN p.streak_days + 1 ELSE 1 END,
    longest_streak = GREATEST(p.longest_streak, CASE WHEN p.last_login_date = today - 1 THEN p.streak_days + 1 ELSE 1 END),
    token_balance = p.token_balance + COALESCE(reward,0) WHERE id = uid;
  IF reward IS NOT NULL AND reward > 0 THEN
    INSERT INTO public.token_transactions (user_id, amount, balance_after, kind, description)
    VALUES (uid, reward, p.token_balance + reward, 'daily_login', 'Daily login reward');
  END IF;
  RETURN jsonb_build_object('ok', true, 'reward', COALESCE(reward,0));
END $$;

CREATE OR REPLACE FUNCTION public.claim_challenge(challenge_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.claim_task(task_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); t public.user_tasks%ROWTYPE;
BEGIN
  SELECT * INTO t FROM public.user_tasks WHERE id = task_id AND user_id = uid;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_found'); END IF;
  IF t.status = 'completed' THEN RETURN jsonb_build_object('ok', false, 'error', 'already_claimed'); END IF;
  UPDATE public.user_tasks SET status='completed', completed_at=now() WHERE id = task_id;
  UPDATE public.profiles SET token_balance = token_balance + t.reward_tokens WHERE id = uid;
  RETURN jsonb_build_object('ok', true, 'reward', t.reward_tokens);
END $$;

CREATE OR REPLACE FUNCTION public.apply_referral_code(code text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.redeem_promo_code(code text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); pc public.promo_codes%ROWTYPE;
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  SELECT * INTO pc FROM public.promo_codes WHERE promo_codes.code = redeem_promo_code.code AND is_active=true;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'invalid'); END IF;
  IF EXISTS (SELECT 1 FROM public.promo_redemptions WHERE promo_id=pc.id AND user_id=uid) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_used');
  END IF;
  IF pc.used_count >= pc.usage_limit THEN RETURN jsonb_build_object('ok', false, 'error', 'limit'); END IF;
  INSERT INTO public.promo_redemptions (promo_id, user_id, amount) VALUES (pc.id, uid, pc.amount);
  UPDATE public.promo_codes SET used_count = used_count + 1 WHERE id = pc.id;
  UPDATE public.profiles SET token_balance = token_balance + pc.amount WHERE id = uid;
  RETURN jsonb_build_object('ok', true, 'amount', pc.amount);
END $$;

CREATE OR REPLACE FUNCTION public.approve_promo_request(req_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.promo_code_requests SET status='approved', reviewed_by=auth.uid(), reviewed_at=now() WHERE id=req_id;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.decline_promo_request(req_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.promo_code_requests SET status='declined', reviewed_by=auth.uid(), reviewed_at=now() WHERE id=req_id;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.create_withdrawal_request(amount bigint, ingame_name text, gang_name text, ticket_ref text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); bal bigint; minw bigint; new_id uuid;
BEGIN
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'unauth'); END IF;
  SELECT token_balance INTO bal FROM public.profiles WHERE id=uid;
  SELECT min_withdrawal INTO minw FROM public.app_settings WHERE id=1;
  IF amount < COALESCE(minw,0) THEN RETURN jsonb_build_object('ok', false, 'error', 'below_min'); END IF;
  IF bal < amount THEN RETURN jsonb_build_object('ok', false, 'error', 'insufficient'); END IF;
  INSERT INTO public.withdrawal_requests (user_id, amount, ingame_name, gang_name, ticket_ref) VALUES (uid, amount, ingame_name, gang_name, ticket_ref) RETURNING id INTO new_id;
  UPDATE public.profiles SET token_balance = token_balance - amount WHERE id=uid;
  RETURN jsonb_build_object('ok', true, 'id', new_id);
END $$;

CREATE OR REPLACE FUNCTION public.review_withdrawal_request(req_id uuid, decision text, note text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r public.withdrawal_requests%ROWTYPE;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO r FROM public.withdrawal_requests WHERE id=req_id;
  UPDATE public.withdrawal_requests SET status=decision::request_status, reviewed_by=auth.uid(), reviewed_at=now(), admin_note=note WHERE id=req_id;
  IF decision = 'declined' OR decision = 'denied' THEN
    UPDATE public.profiles SET token_balance = token_balance + r.amount WHERE id=r.user_id;
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.review_gang_emblem(emblem_id uuid, decision text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN UPDATE public.gang_emblems SET status=decision, reviewed_by=auth.uid(), reviewed_at=now() WHERE id=emblem_id; RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.admin_adjust_xp(target_user uuid, delta int, reason text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.profiles SET xp = GREATEST(0, xp + delta) WHERE id=target_user;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.admin_broadcast(title text, body text, audience text DEFAULT 'all') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  INSERT INTO public.broadcasts (title, body, audience) VALUES (title, body, audience) RETURNING id INTO new_id;
  INSERT INTO public.notifications (user_id, title, body) SELECT id, title, body FROM public.profiles;
  RETURN jsonb_build_object('ok', true, 'id', new_id); END $$;

CREATE OR REPLACE FUNCTION public.admin_delete_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  DELETE FROM public.bets WHERE id=bet_id; RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.admin_refund_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.bets%ROWTYPE;
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO b FROM public.bets WHERE id=bet_id;
  UPDATE public.bets SET status='refunded', settled_at=now() WHERE id=bet_id;
  UPDATE public.profiles SET token_balance = token_balance + b.stake WHERE id=b.user_id;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.admin_suspend_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.bets SET status='void' WHERE id=bet_id; RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.admin_unsuspend_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.bets SET status='pending' WHERE id=bet_id; RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.admin_void_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.bets%ROWTYPE;
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO b FROM public.bets WHERE id=bet_id;
  UPDATE public.bets SET status='void', settled_at=now() WHERE id=bet_id;
  UPDATE public.profiles SET token_balance = token_balance + b.stake WHERE id=b.user_id;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.settle_pay_winning_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.bets%ROWTYPE;
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  SELECT * INTO b FROM public.bets WHERE id=bet_id;
  UPDATE public.bets SET status='won', settled_at=now() WHERE id=bet_id;
  UPDATE public.profiles SET token_balance = token_balance + b.potential_payout WHERE id=b.user_id;
  RETURN jsonb_build_object('ok', true, 'paid', b.potential_payout); END $$;

CREATE OR REPLACE FUNCTION public.user_cashout_bet(bet_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); b public.bets%ROWTYPE; payout bigint;
BEGIN
  SELECT * INTO b FROM public.bets WHERE id=bet_id AND user_id=uid AND status='pending';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'not_cashable'); END IF;
  payout := (b.stake * 0.8)::bigint;
  UPDATE public.bets SET status='cashed_out', cashout_amount=payout, cashed_out_at=now() WHERE id=bet_id;
  UPDATE public.profiles SET token_balance = token_balance + payout WHERE id=uid;
  RETURN jsonb_build_object('ok', true, 'amount', payout);
END $$;

CREATE OR REPLACE FUNCTION public.admin_pnl_summary() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_stakes', COALESCE(SUM(stake),0),
    'total_payouts', COALESCE(SUM(CASE WHEN status='won' THEN potential_payout ELSE 0 END),0),
    'pending_count', COUNT(*) FILTER (WHERE status='pending')
  ) INTO r FROM public.bets;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.admin_risk_summary() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('open_exposure', COALESCE(SUM(potential_payout),0)) FROM public.bets WHERE status='pending';
$$;

CREATE OR REPLACE FUNCTION public.admin_exposure_per_match() RETURNS TABLE(match_id uuid, match_name text, exposure bigint, picks bigint)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.id, m.name, COALESCE(SUM(b.potential_payout),0)::bigint, COUNT(DISTINCT b.id)::bigint
  FROM public.matches m
  LEFT JOIN public.bet_selections bs ON bs.match_id = m.id
  LEFT JOIN public.bets b ON b.id = bs.bet_id AND b.status='pending'
  WHERE m.status IN ('upcoming','live')
  GROUP BY m.id, m.name
  ORDER BY 3 DESC;
$$;

CREATE OR REPLACE FUNCTION public.verify_xp_consistency() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('ok', true);
$$;

CREATE OR REPLACE FUNCTION public.wipe_all_tokens() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.profiles SET token_balance = 0; RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.house_manual_adjust(delta bigint, reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.house_wallet SET balance = balance + delta, total_in = total_in + GREATEST(delta,0), total_out = total_out + GREATEST(-delta,0), updated_at=now() WHERE id=1;
  INSERT INTO public.house_transactions (kind, amount, balance_after, actor_id, reason)
    SELECT 'manual_adjust', delta, balance, auth.uid(), reason FROM public.house_wallet WHERE id=1;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.house_set_paused(paused boolean, reason text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.house_wallet SET payouts_paused = paused, pause_reason = reason WHERE id=1;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.virtual_tick() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$ SELECT jsonb_build_object('ok', true) $$;
CREATE OR REPLACE FUNCTION public.resolve_virtual_round(match_id uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$ SELECT jsonb_build_object('ok', true) $$;
CREATE OR REPLACE FUNCTION public.admin_lock_virtual_round(match_id uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$ SELECT jsonb_build_object('ok', true) $$;
CREATE OR REPLACE FUNCTION public.admin_set_virtual_cycle(seconds int) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$ SELECT jsonb_build_object('ok', true) $$;

CREATE OR REPLACE FUNCTION public.admin_review_virtual_payout(req_id uuid, decision text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN UPDATE public.virtual_payout_requests SET status=decision, reviewed_by=auth.uid(), reviewed_at=now() WHERE id=req_id; RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.virtual_wallet_admin_adjust(delta bigint, reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN IF NOT public.is_admin(auth.uid()) THEN RETURN jsonb_build_object('ok', false); END IF;
  UPDATE public.virtual_house_wallet SET balance = balance + delta, updated_at=now() WHERE id=1;
  INSERT INTO public.virtual_house_transactions (kind, amount, balance_after, reason)
    SELECT 'manual_adjust', delta, balance, reason FROM public.virtual_house_wallet WHERE id=1;
  RETURN jsonb_build_object('ok', true); END $$;

CREATE OR REPLACE FUNCTION public.place_virtual_ticket(payload jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$ SELECT jsonb_build_object('ok', true) $$;

-- Lock down: revoke anon execute on all sensitive functions
REVOKE EXECUTE ON FUNCTION public.claim_daily_login() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_challenge(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_task(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_referral_code(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.redeem_promo_code(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_withdrawal_request(bigint, text, text, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.user_cashout_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.wipe_all_tokens() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.house_manual_adjust(bigint, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.house_set_paused(boolean, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_adjust_xp(uuid, int, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_broadcast(text, text, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_delete_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_refund_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_suspend_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_unsuspend_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_void_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.settle_pay_winning_bet(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.review_withdrawal_request(uuid, text, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.review_gang_emblem(uuid, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.approve_promo_request(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.decline_promo_request(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_review_virtual_payout(uuid, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.virtual_wallet_admin_adjust(bigint, text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_lock_virtual_round(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_set_virtual_cycle(int) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.resolve_virtual_round(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.virtual_tick() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.place_virtual_ticket(jsonb) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_pnl_summary() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_risk_summary() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_exposure_per_match() FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.verify_xp_consistency() FROM anon, PUBLIC;

GRANT EXECUTE ON FUNCTION public.claim_daily_login() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_challenge(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_task(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_promo_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_withdrawal_request(bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_cashout_bet(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.place_virtual_ticket(jsonb) TO authenticated;
