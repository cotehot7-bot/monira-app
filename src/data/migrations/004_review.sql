-- ═══════════════════════════════════════════════════════════
-- MONIRA — 004_review
-- Revisão interna: a Monira lê o que quem vende enviou,
-- prepara a apresentação e publica.
-- Requer 002_v0.1 e 003_submit_product.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. Quem é a Monira
-- ───────────────────────────────────────────────────────────

CREATE TABLE monira_admins (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE monira_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON monira_admins FROM anon, authenticated;   -- geridos só no SQL Editor

CREATE FUNCTION monira_is_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM monira_admins WHERE user_id = auth.uid());
$$;
REVOKE EXECUTE ON FUNCTION monira_is_admin() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION monira_is_admin() TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 2. A Monira lê tudo o que precisa para rever
-- ───────────────────────────────────────────────────────────

CREATE POLICY "Monira lê produtos"  ON monira_products        FOR SELECT USING (monira_is_admin());
CREATE POLICY "Monira lê opções"    ON monira_product_options FOR SELECT USING (monira_is_admin());
CREATE POLICY "Monira lê Ujas"      ON monira_ujas            FOR SELECT USING (monira_is_admin());

-- ───────────────────────────────────────────────────────────
-- 3. Publicar: a apresentação é escrita pela Monira, nunca por quem vende.
--    `photos` guarda caminhos no bucket público `monira-public`.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_admin_publish_product(
  p_product_id  UUID,
  p_name        TEXT,
  p_description TEXT,
  p_photos      TEXT[]
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_name  TEXT := btrim(coalesce(p_name, ''));
  v_desc  TEXT := nullif(btrim(coalesce(p_description, '')), '');
  v_photo TEXT;
BEGIN
  IF NOT monira_is_admin() THEN RAISE EXCEPTION 'not_allowed'; END IF;
  IF char_length(v_name) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'invalid_name'; END IF;
  IF v_desc IS NOT NULL AND char_length(v_desc) > 1000 THEN RAISE EXCEPTION 'invalid_description'; END IF;
  IF coalesce(array_length(p_photos, 1), 0) NOT BETWEEN 1 AND 8 THEN RAISE EXCEPTION 'invalid_photos'; END IF;

  FOREACH v_photo IN ARRAY p_photos LOOP
    IF v_photo IS NULL OR v_photo NOT LIKE 'products/' || p_product_id::text || '/%' OR v_photo LIKE '%..%' THEN
      RAISE EXCEPTION 'invalid_photos';
    END IF;
  END LOOP;

  UPDATE monira_products
     SET name = v_name,
         description = v_desc,
         photos = p_photos,
         admin_reviewed = true,
         needs_review = false,
         updated_at = now()
   WHERE id = p_product_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'product_not_found'; END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION monira_admin_publish_product(UUID, TEXT, TEXT, TEXT[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION monira_admin_publish_product(UUID, TEXT, TEXT, TEXT[]) TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 4. Fotografias
--    monira-raw: a Monira pode ler os originais.
--    monira-public: versões tratadas, legíveis por qualquer pessoa,
--    escritas só pela Monira.
-- ───────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('monira-public', 'monira-public', true, 5242880, ARRAY['image/jpeg', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Monira lê fotografias brutas" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'monira-raw' AND monira_is_admin());

CREATE POLICY "Monira publica fotografias" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'monira-public' AND monira_is_admin());
CREATE POLICY "Monira substitui fotografias" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'monira-public' AND monira_is_admin())
  WITH CHECK (bucket_id = 'monira-public' AND monira_is_admin());
CREATE POLICY "Monira vê fotografias publicadas" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'monira-public' AND monira_is_admin());

COMMIT;
