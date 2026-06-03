
-- 1) Reload-broadcast column
ALTER TABLE public.app_settings ADD COLUMN IF NOT EXISTS force_reload_at timestamptz;

-- 2) Add FKs from user-scoped tables to public.profiles(id) so PostgREST can embed `profiles!user_id(...)`
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='bets_user_profile_fkey') THEN
    ALTER TABLE public.bets ADD CONSTRAINT bets_user_profile_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.bets VALIDATE CONSTRAINT bets_user_profile_fkey;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='user_tasks_user_profile_fkey') THEN
    ALTER TABLE public.user_tasks ADD CONSTRAINT user_tasks_user_profile_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.user_tasks VALIDATE CONSTRAINT user_tasks_user_profile_fkey;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='user_achievements_user_profile_fkey') THEN
    ALTER TABLE public.user_achievements ADD CONSTRAINT user_achievements_user_profile_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.user_achievements VALIDATE CONSTRAINT user_achievements_user_profile_fkey;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='support_tickets_user_profile_fkey') THEN
    ALTER TABLE public.support_tickets ADD CONSTRAINT support_tickets_user_profile_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.support_tickets VALIDATE CONSTRAINT support_tickets_user_profile_fkey;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='ticket_messages_user_profile_fkey') THEN
    ALTER TABLE public.ticket_messages ADD CONSTRAINT ticket_messages_user_profile_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL NOT VALID;
    ALTER TABLE public.ticket_messages VALIDATE CONSTRAINT ticket_messages_user_profile_fkey;
  END IF;
END $$;

-- 3) Add tables to realtime publication so admin live-refresh works
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['bets','bet_selections','app_settings','broadcasts','matches','virtual_payout_requests','withdrawal_requests','token_requests','support_tickets','ticket_messages'] LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN NULL; END;
  END LOOP;
END $$;

-- 4) Ensure REPLICA IDENTITY FULL so updates emit full rows
ALTER TABLE public.bets REPLICA IDENTITY FULL;
ALTER TABLE public.bet_selections REPLICA IDENTITY FULL;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;
