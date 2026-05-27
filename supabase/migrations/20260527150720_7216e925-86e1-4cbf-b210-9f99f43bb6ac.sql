
CREATE TYPE public.app_role AS ENUM ('viewer','shooter','gang_leader','registered','sponsor','moderator','admin');
CREATE TYPE public.gang_type AS ENUM ('G','F');
CREATE TYPE public.match_status AS ENUM ('upcoming','live','ended','cancelled');
CREATE TYPE public.bet_status AS ENUM ('pending','won','lost','void','cashed_out');
CREATE TYPE public.selection_result AS ENUM ('won','lost','void');
CREATE TYPE public.request_status AS ENUM ('pending','approved','declined','denied');

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  email TEXT,
  phone TEXT,
  discord_username TEXT,
  country TEXT,
  server TEXT,
  gang_name TEXT,
  gang_type public.gang_type,
  avatar_url TEXT,
  token_balance BIGINT NOT NULL DEFAULT 0,
  is_banned BOOLEAN NOT NULL DEFAULT false,
  ban_reason TEXT,
  is_muted BOOLEAN NOT NULL DEFAULT false,
  mute_reason TEXT,
  is_restricted BOOLEAN NOT NULL DEFAULT false,
  restrict_reason TEXT,
  accepted_terms BOOLEAN NOT NULL DEFAULT false,
  ingame_name TEXT,
  discord_full_name TEXT,
  streak_days INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_login_date DATE,
  referral_code TEXT UNIQUE,
  referred_by TEXT,
  xp BIGINT NOT NULL DEFAULT 0,
  vip_tier TEXT NOT NULL DEFAULT 'bronze',
  gang_emblem_url TEXT,
  emblem_status TEXT,
  chat_color TEXT,
  profile_banner_url TEXT,
  profile_title TEXT,
  showcase_achievement_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
GRANT ALL ON public.profiles TO service_role;
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.is_admin(_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('admin','moderator'))
$$;

CREATE TABLE public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  logo_url TEXT,
  gang_type public.gang_type,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.teams TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.teams TO authenticated;
GRANT ALL ON public.teams TO service_role;

CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  icon TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.categories TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.categories TO authenticated;
GRANT ALL ON public.categories TO service_role;

CREATE TABLE public.matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT,
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  home_team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  away_team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  location TEXT,
  start_time TIMESTAMPTZ,
  status public.match_status NOT NULL DEFAULT 'upcoming',
  home_score INT NOT NULL DEFAULT 0,
  away_score INT NOT NULL DEFAULT 0,
  winner_team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  is_virtual BOOLEAN NOT NULL DEFAULT false,
  lock_time TIMESTAMPTZ,
  virtual_first_blood_team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  locked_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  locked_at TIMESTAMPTZ,
  settled_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.matches TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.matches TO authenticated;
GRANT ALL ON public.matches TO service_role;
CREATE TRIGGER trg_matches_updated BEFORE UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE INDEX idx_matches_status ON public.matches(status);
CREATE INDEX idx_matches_start_time ON public.matches(start_time);

CREATE TABLE public.markets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_open BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.markets TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.markets TO authenticated;
GRANT ALL ON public.markets TO service_role;
CREATE INDEX idx_markets_match ON public.markets(match_id);

CREATE TABLE public.odds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id UUID NOT NULL REFERENCES public.markets(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  value NUMERIC(10,2) NOT NULL,
  is_winner BOOLEAN,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.odds TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.odds TO authenticated;
GRANT ALL ON public.odds TO service_role;
CREATE INDEX idx_odds_market ON public.odds(market_id);

CREATE TABLE public.bets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tracking_id TEXT UNIQUE,
  booking_code TEXT,
  stake BIGINT NOT NULL,
  total_odds NUMERIC(10,2) NOT NULL,
  potential_payout BIGINT NOT NULL,
  status public.bet_status NOT NULL DEFAULT 'pending',
  cashout_amount BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at TIMESTAMPTZ,
  cashed_out_at TIMESTAMPTZ
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bets TO authenticated;
GRANT ALL ON public.bets TO service_role;
CREATE INDEX idx_bets_user ON public.bets(user_id);
CREATE INDEX idx_bets_status ON public.bets(status);

CREATE TABLE public.bet_selections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id UUID NOT NULL REFERENCES public.bets(id) ON DELETE CASCADE,
  match_id UUID REFERENCES public.matches(id) ON DELETE SET NULL,
  market_id UUID REFERENCES public.markets(id) ON DELETE SET NULL,
  odd_id UUID REFERENCES public.odds(id) ON DELETE SET NULL,
  locked_odds NUMERIC(10,2) NOT NULL,
  selection_label TEXT NOT NULL,
  result public.selection_result,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bet_selections TO authenticated;
GRANT ALL ON public.bet_selections TO service_role;
CREATE INDEX idx_bet_sel_bet ON public.bet_selections(bet_id);
CREATE INDEX idx_bet_sel_match ON public.bet_selections(match_id);

CREATE TABLE public.token_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  kind TEXT NOT NULL,
  description TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.token_transactions TO authenticated;
GRANT ALL ON public.token_transactions TO service_role;
CREATE INDEX idx_tt_user ON public.token_transactions(user_id);

CREATE TABLE public.token_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount BIGINT NOT NULL,
  proof_image_url TEXT,
  note TEXT,
  status public.request_status NOT NULL DEFAULT 'pending',
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  review_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.token_requests TO authenticated;
GRANT ALL ON public.token_requests TO service_role;

CREATE TABLE public.withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ingame_name TEXT NOT NULL,
  gang_name TEXT NOT NULL,
  amount BIGINT NOT NULL,
  ticket_ref TEXT,
  status public.request_status NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.withdrawal_requests TO authenticated;
GRANT ALL ON public.withdrawal_requests TO service_role;

CREATE TABLE public.app_settings (
  id INT PRIMARY KEY DEFAULT 1,
  maintenance_mode BOOLEAN NOT NULL DEFAULT false,
  maintenance_message TEXT,
  terms_content TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  contact_whatsapp TEXT,
  about_us TEXT,
  why_trust_us TEXT,
  hero_tagline TEXT,
  popup_ad_active BOOLEAN NOT NULL DEFAULT false,
  popup_ad_image TEXT,
  popup_ad_text TEXT,
  popup_ad_link TEXT,
  popup_ad_size TEXT,
  min_stake BIGINT NOT NULL DEFAULT 1000,
  max_payout BIGINT NOT NULL DEFAULT 60000000,
  vapid_public_key TEXT,
  vapid_subject TEXT,
  push_endpoint_url TEXT,
  daily_login_enabled BOOLEAN NOT NULL DEFAULT true,
  daily_login_base_reward BIGINT NOT NULL DEFAULT 0,
  daily_login_bonus_per_day BIGINT NOT NULL DEFAULT 0,
  daily_login_max_streak INT NOT NULL DEFAULT 7,
  xp_per_bet INT NOT NULL DEFAULT 0,
  xp_per_win INT NOT NULL DEFAULT 0,
  xp_per_login INT NOT NULL DEFAULT 0,
  xp_per_referral INT NOT NULL DEFAULT 0,
  referral_bonus_referrer BIGINT NOT NULL DEFAULT 0,
  referral_bonus_referee BIGINT NOT NULL DEFAULT 0,
  vip_token_multipliers JSONB NOT NULL DEFAULT '{}'::jsonb,
  challenge_reward_multiplier NUMERIC NOT NULL DEFAULT 1,
  spin_enabled BOOLEAN NOT NULL DEFAULT false,
  spin_min_reward BIGINT NOT NULL DEFAULT 0,
  spin_max_reward BIGINT NOT NULL DEFAULT 0,
  spin_cooldown_hours INT NOT NULL DEFAULT 24,
  gift_enabled BOOLEAN NOT NULL DEFAULT false,
  gift_daily_limit BIGINT NOT NULL DEFAULT 0,
  gift_min_amount BIGINT NOT NULL DEFAULT 0,
  gift_max_per_tx BIGINT NOT NULL DEFAULT 0,
  gift_fee_pct NUMERIC NOT NULL DEFAULT 0,
  friends_enabled BOOLEAN NOT NULL DEFAULT false,
  admin_ai_enabled BOOLEAN NOT NULL DEFAULT false,
  admin_ai_model TEXT,
  exposure_warn_pct NUMERIC NOT NULL DEFAULT 80,
  house_low_balance BIGINT NOT NULL DEFAULT 0,
  min_selections_per_ticket INT NOT NULL DEFAULT 1,
  max_selections_per_ticket INT NOT NULL DEFAULT 20,
  emblem_auto_approve BOOLEAN NOT NULL DEFAULT false,
  vip_enabled BOOLEAN NOT NULL DEFAULT true,
  min_withdrawal BIGINT NOT NULL DEFAULT 2000000,
  virtual_payout_multiplier NUMERIC NOT NULL DEFAULT 1,
  virtual_min_stake BIGINT NOT NULL DEFAULT 0,
  virtual_max_stake BIGINT NOT NULL DEFAULT 0,
  virtual_xp_per_win INT NOT NULL DEFAULT 0,
  virtual_win_bonus_tokens BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.app_settings TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
INSERT INTO public.app_settings (id) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;
CREATE INDEX idx_audit_created ON public.audit_logs(created_at DESC);

CREATE TABLE public.house_wallet (
  id INT PRIMARY KEY DEFAULT 1,
  balance BIGINT NOT NULL DEFAULT 0,
  total_in BIGINT NOT NULL DEFAULT 0,
  total_out BIGINT NOT NULL DEFAULT 0,
  payouts_paused BOOLEAN NOT NULL DEFAULT false,
  pause_reason TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.house_wallet TO authenticated;
GRANT ALL ON public.house_wallet TO service_role;
INSERT INTO public.house_wallet (id) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE public.house_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  kind TEXT NOT NULL,
  amount BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  bet_id UUID REFERENCES public.bets(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reason TEXT
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.house_transactions TO authenticated;
GRANT ALL ON public.house_transactions TO service_role;

CREATE TABLE public.user_sessions (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
  route TEXT,
  user_agent TEXT
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_sessions TO authenticated;
GRANT ALL ON public.user_sessions TO service_role;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.markets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.odds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bet_selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.token_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.house_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.house_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles select all signed-in" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "profiles update own" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "profiles insert own" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles admin all" ON public.profiles FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "user_roles read" ON public.user_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "user_roles admin all" ON public.user_roles FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "teams read" ON public.teams FOR SELECT USING (true);
CREATE POLICY "teams admin" ON public.teams FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "categories read" ON public.categories FOR SELECT USING (true);
CREATE POLICY "categories admin" ON public.categories FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "matches read" ON public.matches FOR SELECT USING (true);
CREATE POLICY "matches admin" ON public.matches FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "markets read" ON public.markets FOR SELECT USING (true);
CREATE POLICY "markets admin" ON public.markets FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "odds read" ON public.odds FOR SELECT USING (true);
CREATE POLICY "odds admin" ON public.odds FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "bets own" ON public.bets FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "bets create own" ON public.bets FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "bets admin" ON public.bets FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "bet_sel own" ON public.bet_selections FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.bets b WHERE b.id = bet_id AND b.user_id = auth.uid()));
CREATE POLICY "bet_sel create" ON public.bet_selections FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.bets b WHERE b.id = bet_id AND b.user_id = auth.uid()));
CREATE POLICY "bet_sel admin" ON public.bet_selections FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "tt own" ON public.token_transactions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "tt admin" ON public.token_transactions FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "tr own select" ON public.token_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "tr own create" ON public.token_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "tr admin" ON public.token_requests FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "wr own select" ON public.withdrawal_requests FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "wr own create" ON public.withdrawal_requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "wr admin" ON public.withdrawal_requests FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "settings read" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "settings admin" ON public.app_settings FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "audit admin" ON public.audit_logs FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "house_wallet admin" ON public.house_wallet FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "house_tx admin" ON public.house_transactions FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "us own" ON public.user_sessions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "us upsert own" ON public.user_sessions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "us update own" ON public.user_sessions FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "us admin" ON public.user_sessions FOR ALL TO authenticated USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, referral_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    'LSL-' || upper(substr(replace(NEW.id::text, '-', ''), 1, 6))
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'viewer')
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
