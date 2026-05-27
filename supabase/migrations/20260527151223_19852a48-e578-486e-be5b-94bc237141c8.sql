
CREATE TABLE IF NOT EXISTS public.notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, title text NOT NULL, body text, link text, is_read boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.notification_prefs (user_id uuid PRIMARY KEY, bets boolean NOT NULL DEFAULT true, results boolean NOT NULL DEFAULT true, promos boolean NOT NULL DEFAULT true, chat boolean NOT NULL DEFAULT true, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.challenges (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kind text NOT NULL, title text NOT NULL, description text, target int NOT NULL DEFAULT 1, reward_tokens bigint NOT NULL DEFAULT 0, reward_xp int NOT NULL DEFAULT 0, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.user_challenge_progress (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, challenge_id uuid NOT NULL, progress int NOT NULL DEFAULT 0, claimed_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (user_id, challenge_id));
CREATE TABLE IF NOT EXISTS public.events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, description text, banner_url text, ends_at timestamptz, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.announcements (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, body text, image_url text, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.highlights (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, media_url text NOT NULL, media_type text NOT NULL DEFAULT 'image', is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.advertisements (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, image_url text NOT NULL, link_url text, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.chat_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), room text NOT NULL DEFAULT 'global', user_id uuid NOT NULL, content text, image_url text, created_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz, deleted_by uuid);
CREATE TABLE IF NOT EXISTS public.chat_message_reactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), message_id uuid NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE, user_id uuid NOT NULL, emoji text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (message_id, user_id, emoji));
CREATE TABLE IF NOT EXISTS public.ban_appeals (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, message text NOT NULL, status text NOT NULL DEFAULT 'pending', admin_response text, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.watchlist (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, entity_type text NOT NULL, entity_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (user_id, entity_type, entity_id));
CREATE TABLE IF NOT EXISTS public.support_tickets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, subject text NOT NULL, category text, status text NOT NULL DEFAULT 'open', created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.ticket_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ticket_id uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE, user_id uuid NOT NULL, content text, image_url text, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.seasons (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, description text, starts_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.season_points (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), season_id uuid NOT NULL REFERENCES public.seasons(id) ON DELETE CASCADE, user_id uuid NOT NULL, points bigint NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (season_id, user_id));
CREATE TABLE IF NOT EXISTS public.referrals (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), referrer_id uuid NOT NULL, referee_id uuid NOT NULL, referrer_bonus bigint NOT NULL DEFAULT 0, referee_bonus bigint NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.user_achievements (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, code text NOT NULL, title text NOT NULL, description text, icon text, awarded_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.user_tasks (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, title text NOT NULL, description text, reward_tokens bigint NOT NULL DEFAULT 0, status text NOT NULL DEFAULT 'pending', completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.promo_codes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, amount bigint NOT NULL DEFAULT 0, usage_limit int NOT NULL DEFAULT 1, used_count int NOT NULL DEFAULT 0, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.promo_redemptions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), promo_id uuid NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE, user_id uuid NOT NULL, amount bigint NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (promo_id, user_id));
CREATE TABLE IF NOT EXISTS public.promo_code_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, amount bigint NOT NULL DEFAULT 0, usage_limit int NOT NULL DEFAULT 1, reason text, status text NOT NULL DEFAULT 'pending', reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.promo_code_usage_v2 (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), promo_id uuid NOT NULL REFERENCES public.promo_codes(id) ON DELETE CASCADE, user_id uuid NOT NULL, amount bigint NOT NULL DEFAULT 0, redeemed_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.broadcasts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, body text, audience text NOT NULL DEFAULT 'all', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.spotlights (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, body text, image_url text, link_url text, is_active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), user_id uuid, headline text, message text, expires_at timestamptz, created_by uuid);
CREATE TABLE IF NOT EXISTS public.gang_emblems (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, image_url text NOT NULL, status text NOT NULL DEFAULT 'pending', reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.leaderboard_overrides (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, kind text NOT NULL, manual_rank int, bonus_points bigint NOT NULL DEFAULT 0, note text, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (user_id, kind));
CREATE TABLE IF NOT EXISTS public.players (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, team_id uuid REFERENCES public.teams(id) ON DELETE SET NULL, position text, avatar_url text, is_substitute boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.virtual_house_wallet (id int PRIMARY KEY DEFAULT 1, balance bigint NOT NULL DEFAULT 0, total_in bigint NOT NULL DEFAULT 0, total_out bigint NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now());
INSERT INTO public.virtual_house_wallet (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
CREATE TABLE IF NOT EXISTS public.virtual_house_transactions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kind text NOT NULL, amount bigint NOT NULL, balance_after bigint NOT NULL DEFAULT 0, reason text, user_id uuid, bet_id uuid, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.virtual_payout_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, bet_id uuid, match_id uuid, stake bigint NOT NULL DEFAULT 0, amount bigint NOT NULL DEFAULT 0, status text NOT NULL DEFAULT 'pending', reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());

ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS virtual_round_duration_seconds int NOT NULL DEFAULT 60;
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS virtual_concurrent_rounds int NOT NULL DEFAULT 1;

-- GRANTs
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'notifications','notification_prefs','challenges','user_challenge_progress',
    'events','announcements','highlights','advertisements',
    'chat_messages','chat_message_reactions','ban_appeals','watchlist',
    'support_tickets','ticket_messages','seasons','season_points',
    'referrals','user_achievements','user_tasks',
    'promo_codes','promo_redemptions','promo_code_requests','promo_code_usage_v2',
    'broadcasts','spotlights','gang_emblems','leaderboard_overrides','players',
    'virtual_house_wallet','virtual_house_transactions','virtual_payout_requests'
  ]) LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
  END LOOP;
  FOR t IN SELECT unnest(ARRAY[
    'events','announcements','highlights','advertisements','challenges','seasons',
    'season_points','broadcasts','spotlights','leaderboard_overrides','players',
    'virtual_house_wallet'
  ]) LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO anon', t);
  END LOOP;
END $$;

-- Enable RLS
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'notifications','notification_prefs','challenges','user_challenge_progress',
    'events','announcements','highlights','advertisements',
    'chat_messages','chat_message_reactions','ban_appeals','watchlist',
    'support_tickets','ticket_messages','seasons','season_points',
    'referrals','user_achievements','user_tasks',
    'promo_codes','promo_redemptions','promo_code_requests','promo_code_usage_v2',
    'broadcasts','spotlights','gang_emblems','leaderboard_overrides','players',
    'virtual_house_wallet','virtual_house_transactions','virtual_payout_requests'
  ]) LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- Public read policies for content tables
CREATE POLICY "read events" ON public.events FOR SELECT USING (true);
CREATE POLICY "read announcements" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "read highlights" ON public.highlights FOR SELECT USING (true);
CREATE POLICY "read advertisements" ON public.advertisements FOR SELECT USING (true);
CREATE POLICY "read challenges" ON public.challenges FOR SELECT USING (true);
CREATE POLICY "read seasons" ON public.seasons FOR SELECT USING (true);
CREATE POLICY "read season_points" ON public.season_points FOR SELECT USING (true);
CREATE POLICY "read broadcasts" ON public.broadcasts FOR SELECT USING (true);
CREATE POLICY "read spotlights" ON public.spotlights FOR SELECT USING (true);
CREATE POLICY "read leaderboard_overrides" ON public.leaderboard_overrides FOR SELECT USING (true);
CREATE POLICY "read players" ON public.players FOR SELECT USING (true);

-- Admin-all policies
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'notifications','notification_prefs','challenges','user_challenge_progress',
    'events','announcements','highlights','advertisements',
    'chat_messages','chat_message_reactions','ban_appeals','watchlist',
    'support_tickets','ticket_messages','seasons','season_points',
    'referrals','user_achievements','user_tasks',
    'promo_codes','promo_redemptions','promo_code_requests','promo_code_usage_v2',
    'broadcasts','spotlights','gang_emblems','leaderboard_overrides','players',
    'virtual_house_wallet','virtual_house_transactions','virtual_payout_requests'
  ]) LOOP
    EXECUTE format('CREATE POLICY "%s admin" ON public.%I FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()))', t, t);
  END LOOP;
END $$;

-- Own-row policies
CREATE POLICY "own notifications" ON public.notifications FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "update own notifications" ON public.notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "delete own notifications" ON public.notifications FOR DELETE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "insert own notifications" ON public.notifications FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own notification_prefs" ON public.notification_prefs FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own progress" ON public.user_challenge_progress FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own watchlist" ON public.watchlist FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own ban_appeal create" ON public.ban_appeals FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own ban_appeal read" ON public.ban_appeals FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "read chat" ON public.chat_messages FOR SELECT TO authenticated USING (true);
CREATE POLICY "own chat insert" ON public.chat_messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own chat delete" ON public.chat_messages FOR DELETE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "read reactions" ON public.chat_message_reactions FOR SELECT TO authenticated USING (true);
CREATE POLICY "own reactions" ON public.chat_message_reactions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own reactions del" ON public.chat_message_reactions FOR DELETE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own tickets create" ON public.support_tickets FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own tickets read" ON public.support_tickets FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own tickets update" ON public.support_tickets FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own ticket msgs read" ON public.ticket_messages FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.support_tickets t WHERE t.id = ticket_messages.ticket_id AND (t.user_id = auth.uid() OR public.is_admin(auth.uid()))));
CREATE POLICY "own ticket msgs insert" ON public.ticket_messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own achievements" ON public.user_achievements FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own tasks read" ON public.user_tasks FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own tasks update" ON public.user_tasks FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own redemptions read" ON public.promo_redemptions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "read promo_codes" ON public.promo_codes FOR SELECT TO authenticated USING (true);
CREATE POLICY "own promo req create" ON public.promo_code_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own promo req read" ON public.promo_code_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own emblem create" ON public.gang_emblems FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own emblem read" ON public.gang_emblems FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own referrals read" ON public.referrals FOR SELECT TO authenticated USING (auth.uid() = referrer_id OR auth.uid() = referee_id);
CREATE POLICY "own virtual payout read" ON public.virtual_payout_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "read virtual wallet" ON public.virtual_house_wallet FOR SELECT TO authenticated USING (true);

-- Hot bets view
CREATE OR REPLACE VIEW public.hot_bets_v1 AS
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
