
-- Public read for display buckets, authenticated write
DO $$
DECLARE
  b TEXT;
  pub_buckets TEXT[] := ARRAY['announcements','highlights','ads','team-logos','chat-images','avatars','player-avatars','gang-emblems','event-banners','season-banners','popup-ads'];
BEGIN
  FOREACH b IN ARRAY pub_buckets LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', b||'_public_read');
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', b||'_auth_write');
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', b||'_auth_update');
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', b||'_auth_delete');
    EXECUTE format($p$CREATE POLICY %I ON storage.objects FOR SELECT USING (bucket_id = %L)$p$, b||'_public_read', b);
    EXECUTE format($p$CREATE POLICY %I ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = %L)$p$, b||'_auth_write', b);
    EXECUTE format($p$CREATE POLICY %I ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = %L)$p$, b||'_auth_update', b);
    EXECUTE format($p$CREATE POLICY %I ON storage.objects FOR DELETE TO authenticated USING (bucket_id = %L)$p$, b||'_auth_delete', b);
  END LOOP;
END $$;

-- Private buckets: owner-only + admin
DROP POLICY IF EXISTS ticket_uploads_owner_select ON storage.objects;
DROP POLICY IF EXISTS ticket_uploads_owner_insert ON storage.objects;
DROP POLICY IF EXISTS ticket_uploads_admin_all ON storage.objects;
CREATE POLICY ticket_uploads_owner_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'ticket-uploads' AND (owner = auth.uid() OR public.has_role(auth.uid(),'admin')));
CREATE POLICY ticket_uploads_owner_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'ticket-uploads' AND owner = auth.uid());

DROP POLICY IF EXISTS token_proofs_owner_select ON storage.objects;
DROP POLICY IF EXISTS token_proofs_owner_insert ON storage.objects;
CREATE POLICY token_proofs_owner_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'token-proofs' AND (owner = auth.uid() OR public.has_role(auth.uid(),'admin')));
CREATE POLICY token_proofs_owner_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'token-proofs' AND owner = auth.uid());
