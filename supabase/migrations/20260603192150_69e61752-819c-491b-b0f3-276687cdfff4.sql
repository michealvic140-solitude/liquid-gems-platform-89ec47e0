
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='promo_code_requests_user_profile_fkey') THEN
    ALTER TABLE public.promo_code_requests ADD CONSTRAINT promo_code_requests_user_profile_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE NOT VALID;
    ALTER TABLE public.promo_code_requests VALIDATE CONSTRAINT promo_code_requests_user_profile_fkey;
  END IF;
END $$;
