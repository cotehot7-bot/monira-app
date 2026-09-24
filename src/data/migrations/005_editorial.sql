-- ═══════════════════════════════════════════════════════════
-- MONIRA — 005_editorial
-- Poder editorial da Monira depois de receber um produto:
--   Pedir alterações (≠ apagar) · Apagar (só envios nunca publicados) · Editar publicação
-- E a resposta de quem vende: corrigir e enviar de novo.
-- Requer 002, 003, 004.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. "Precisa de atenção": o pedido da Monira a quem vende
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_products
  ADD COLUMN attention_note TEXT,          -- o que a Monira pediu; NULL = nada pendente
  ADD COLUMN attention_at   TIMESTAMPTZ;

-- ───────────────────────────────────────────────────────────
-- 2. Histórico editorial — decisões não se apagam
-- ───────────────────────────────────────────────────────────

CREATE TABLE monira_product_decisions (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id    UUID NOT NULL REFERENCES monira_products(id) ON DELETE CASCADE,
  decision      TEXT NOT NULL CHECK (decision IN ('published', 'changes_requested', 'resubmitted')),
  note          TEXT,
  actor_user_id UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX monira_product_decisions_product ON monira_product_decisions (product_id, created_at DESC);
ALTER TABLE monira_product_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON monira_product_decisions FROM anon;
REVOKE INSERT, UPDATE, DELETE ON monira_product_decisions FROM authenticated;
CREATE POLICY "Monira lê histórico" ON monira_product_decisions FOR SELECT USING (monira_is_admin());

-- ───────────────────────────────────────────────────────────
-- 3. Quando quem vende muda o conteúdo bruto:
--    fica marcado para revisão e o pedido pendente dá-se por respondido.
-- ───────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION monira_products_flag_review() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.raw_name        IS DISTINCT FROM OLD.raw_name
  OR NEW.raw_description IS DISTINCT FROM OLD.raw_description
  OR NEW.raw_photos      IS DISTINCT FROM OLD.raw_photos THEN
    NEW.needs_review   := true;
    NEW.attention_note := NULL;
    NEW.attention_at   := NULL;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 4. Monira: publicar (substitui a da 004 — agora limpa pedidos e regista a decisão)
-- ───────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION monira_admin_publish_product(
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
     SET name = v_name, description = v_desc, photos = p_photos,
         admin_reviewed = true, needs_review = false,
         attention_note = NULL, attention_at = NULL,
         updated_at = now()
   WHERE id = p_product_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'product_not_found'; END IF;

  INSERT INTO monira_product_decisions (product_id, decision, actor_user_id)
  VALUES (p_product_id, 'published', auth.uid());
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 5. Monira: pedir alterações (decisão editorial, guarda histórico)
--    Um produto já publicado continua visível com a apresentação actual.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_admin_request_changes(p_product_id UUID, p_note TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_note TEXT := btrim(coalesce(p_note, ''));
BEGIN
  IF NOT monira_is_admin() THEN RAISE EXCEPTION 'not_allowed'; END IF;
  IF char_length(v_note) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'invalid_note'; END IF;

  UPDATE monira_products
     SET attention_note = v_note, attention_at = now(), needs_review = false, updated_at = now()
   WHERE id = p_product_id AND active;
  IF NOT FOUND THEN RAISE EXCEPTION 'product_not_found'; END IF;

  INSERT INTO monira_product_decisions (product_id, decision, note, actor_user_id)
  VALUES (p_product_id, 'changes_requested', v_note, auth.uid());
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 6. Monira: apagar (destrutivo)
--    Só envios que nunca foram publicados e sem pedidos. Devolve as fotografias
--    originais para o servidor as remover do Storage.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_admin_delete_product(p_product_id UUID) RETURNS TEXT[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_prod monira_products;
BEGIN
  IF NOT monira_is_admin() THEN RAISE EXCEPTION 'not_allowed'; END IF;

  SELECT * INTO v_prod FROM monira_products WHERE id = p_product_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'product_not_found'; END IF;
  IF v_prod.admin_reviewed THEN RAISE EXCEPTION 'already_published'; END IF;
  IF EXISTS (SELECT 1 FROM monira_orders WHERE product_id = p_product_id) THEN RAISE EXCEPTION 'has_orders'; END IF;

  DELETE FROM monira_products WHERE id = p_product_id;
  RETURN coalesce(v_prod.raw_photos, '{}');
END;
$$;

CREATE POLICY "Monira apaga fotografias brutas" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'monira-raw' AND monira_is_admin());

-- ───────────────────────────────────────────────────────────
-- 7. Quem vende: corrigir e enviar de novo
--    SECURITY INVOKER: as regras da 002/003 continuam a decidir.
--    Só enquanto houver um pedido da Monira por responder.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_resubmit_product(
  p_product_id      UUID,
  p_raw_name        TEXT,
  p_raw_description TEXT,
  p_raw_photos      TEXT[],
  p_price_kz        NUMERIC,
  p_options         TEXT[]
) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  v_uja     UUID;
  v_pending BOOLEAN;
  v_name    TEXT := btrim(coalesce(p_raw_name, ''));
  v_desc    TEXT := nullif(btrim(coalesce(p_raw_description, '')), '');
  v_options TEXT[];
  v_photo   TEXT;
BEGIN
  SELECT uja_id, attention_note IS NOT NULL INTO v_uja, v_pending
    FROM monira_products WHERE id = p_product_id AND monira_is_uja_owner(uja_id);
  IF NOT FOUND THEN RAISE EXCEPTION 'product_not_found'; END IF;
  IF NOT v_pending THEN RAISE EXCEPTION 'not_editable'; END IF;

  IF char_length(v_name) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'invalid_name'; END IF;
  IF v_desc IS NOT NULL AND char_length(v_desc) > 2000 THEN RAISE EXCEPTION 'invalid_description'; END IF;
  IF p_price_kz IS NULL OR p_price_kz <= 0 OR p_price_kz > 100000000000 THEN RAISE EXCEPTION 'invalid_price'; END IF;
  IF coalesce(array_length(p_raw_photos, 1), 0) NOT BETWEEN 1 AND 8 THEN RAISE EXCEPTION 'invalid_photos'; END IF;
  FOREACH v_photo IN ARRAY p_raw_photos LOOP
    IF v_photo IS NULL OR v_photo NOT LIKE v_uja::text || '/%' OR v_photo LIKE '%..%' THEN
      RAISE EXCEPTION 'invalid_photos';
    END IF;
  END LOOP;

  SELECT coalesce(array_agg(o ORDER BY first_pos), '{}') INTO v_options
  FROM (
    SELECT btrim(o) AS o, min(pos) AS first_pos
    FROM unnest(coalesce(p_options, '{}')) WITH ORDINALITY AS t(o, pos)
    WHERE btrim(coalesce(o, '')) <> ''
    GROUP BY btrim(o)
  ) s;
  IF array_length(v_options, 1) > 12 THEN RAISE EXCEPTION 'invalid_options'; END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_options) o WHERE char_length(o) > 40) THEN RAISE EXCEPTION 'invalid_options'; END IF;

  -- Mudar o conteúdo bruto faz o trigger marcar para revisão e dar o pedido por respondido.
  UPDATE monira_products
     SET raw_name = v_name, raw_description = v_desc, raw_photos = p_raw_photos, price_kz = round(p_price_kz, 2)
   WHERE id = p_product_id;

  DELETE FROM monira_product_options WHERE product_id = p_product_id;
  INSERT INTO monira_product_options (product_id, name, position)
  SELECT p_product_id, o, pos - 1 FROM unnest(v_options) WITH ORDINALITY AS t(o, pos);

  PERFORM monira_log_resubmission(p_product_id);
END;
$$;

-- O registo no histórico é escrito com privilégios da Monira (quem vende não escreve no histórico).
CREATE FUNCTION monira_log_resubmission(p_product_id UUID) RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO monira_product_decisions (product_id, decision, actor_user_id)
  SELECT p_product_id, 'resubmitted', auth.uid()
  WHERE monira_is_uja_owner((SELECT uja_id FROM monira_products WHERE id = p_product_id));
$$;

REVOKE EXECUTE ON FUNCTION
  monira_admin_request_changes(UUID, TEXT),
  monira_admin_delete_product(UUID),
  monira_resubmit_product(UUID, TEXT, TEXT, TEXT[], NUMERIC, TEXT[]),
  monira_log_resubmission(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  monira_admin_request_changes(UUID, TEXT),
  monira_admin_delete_product(UUID),
  monira_resubmit_product(UUID, TEXT, TEXT, TEXT[], NUMERIC, TEXT[]),
  monira_log_resubmission(UUID)
TO authenticated;

COMMIT;
