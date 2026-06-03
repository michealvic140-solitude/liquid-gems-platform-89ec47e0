
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='public read new asset buckets') THEN
    CREATE POLICY "public read new asset buckets" ON storage.objects FOR SELECT TO anon, authenticated
      USING (bucket_id = ANY (ARRAY['gang-emblems','event-banners','season-banners','popup-ads']));
  END IF;
END $$;
