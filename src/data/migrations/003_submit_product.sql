-- ═══════════════════════════════════════════════════════════
-- MONIRA — 003_submit_product
-- Adicionar produto (quem vende): fotografias brutas + submissão atómica.
-- Requer 002_v0.1.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. Submissão de produto
--    SECURITY INVOKER: corre com a sessão de quem vende, por isso
--    as políticas RLS da 002 continuam a decidir o que é permitido.
--    Produto e opções entram na mesma transacção: ou tudo, ou nada.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_submit_product(
  p_uja_id          UUID,
  p_raw_name        TEXT,
  p_raw_description TEXT,
  p_raw_photos      TEXT[],
  p_price_kz        NUMERIC,
  p_options         TEXT[]
) RETURNS UUID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  v_name    TEXT := btrim(coalesce(p_raw_name, ''));
  v_desc    TEXT := nullif(btrim(coalesce(p_raw_description, '')), '');
  v_options TEXT[];
  v_photo   TEXT;
  v_id      UUID;
BEGIN
  IF char_length(v_name) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'invalid_name'; END IF;
  IF v_desc IS NOT NULL AND char_length(v_desc) > 2000 THEN RAISE EXCEPTION 'invalid_description'; END IF;
  IF p_price_kz IS NULL OR p_price_kz <= 0 OR p_price_kz > 100000000000 THEN RAISE EXCEPTION 'invalid_price'; END IF;
  IF coalesce(array_length(p_raw_photos, 1), 0) NOT BETWEEN 1 AND 8 THEN RAISE EXCEPTION 'invalid_photos'; END IF;

  -- Cada fotografia tem de estar na pasta da própria Uja.
  FOREACH v_photo IN ARRAY p_raw_photos LOOP
    IF v_photo IS NULL OR v_photo NOT LIKE p_uja_id::text || '/%' OR v_photo LIKE '%..%' THEN
      RAISE EXCEPTION 'invalid_photos';
    END IF;
  END LOOP;

  -- Opções: sem espaços a mais, sem vazias, sem repetidas, pela ordem dada.
  SELECT coalesce(array_agg(o ORDER BY first_pos), '{}') INTO v_options
  FROM (
    SELECT btrim(o) AS o, min(pos) AS first_pos
    FROM unnest(coalesce(p_options, '{}')) WITH ORDINALITY AS t(o, pos)
    WHERE btrim(coalesce(o, '')) <> ''
    GROUP BY btrim(o)
  ) s;
  IF array_length(v_options, 1) > 12 THEN RAISE EXCEPTION 'invalid_options'; END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_options) o WHERE char_length(o) > 40) THEN RAISE EXCEPTION 'invalid_options'; END IF;

  INSERT INTO monira_products (uja_id, raw_name, raw_description, raw_photos, price_kz)
  VALUES (p_uja_id, v_name, v_desc, p_raw_photos, round(p_price_kz, 2))
  RETURNING id INTO v_id;

  INSERT INTO monira_product_options (product_id, name, position)
  SELECT v_id, o, pos - 1 FROM unnest(v_options) WITH ORDINALITY AS t(o, pos);

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION monira_submit_product(UUID, TEXT, TEXT, TEXT[], NUMERIC, TEXT[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION monira_submit_product(UUID, TEXT, TEXT, TEXT[], NUMERIC, TEXT[]) TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 2. Fotografias brutas
--    Bucket privado. Quem vende envia para <uja_id>/<ficheiro>.
--    A Monira lê com service_role, trata e publica noutro sítio.
--    O público nunca vê fotografias brutas.
-- ───────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('monira-raw', 'monira-raw', false, 15728640,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Morador envia fotografias brutas" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'monira-raw'
    AND (storage.foldername(name))[1] IN (SELECT id::text FROM monira_ujas WHERE monira_is_uja_owner(id))
  );

CREATE POLICY "Morador vê as suas fotografias brutas" ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'monira-raw'
    AND (storage.foldername(name))[1] IN (SELECT id::text FROM monira_ujas WHERE monira_is_uja_owner(id))
  );

COMMIT;
