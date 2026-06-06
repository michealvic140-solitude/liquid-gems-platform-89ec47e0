ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS leaderboard_banner_url text,
  ADD COLUMN IF NOT EXISTS leaderboard_banner_description text;