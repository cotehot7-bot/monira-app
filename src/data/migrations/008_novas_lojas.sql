-- ═══════════════════════════════════════════════════════════
-- MONIRA — 008_novas_lojas
-- Entrada de novas lojas sem SQL:
--   quem quer vender pede → a Monira aprova (cria conta de quem vende + Uja) ou recusa com nota.
-- Uma conta pode comprar, conversar e também ter uma Uja.
-- Requer 002–007.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. Segurança: a regra da Fase 0 deixava quem se candidata escrever o próprio estado.
-- ───────────────────────────────────────────────────────────

DROP POLICY "Candidatura insere" ON monira_applications;
REVOKE INSERT, UPDATE, DELETE ON monira_applications FROM anon, authenticated;
REVOKE SELECT ON monira_applications FROM anon;

-- Nota da Monira para quem pediu (admin_notes continua interna).
ALTER TABLE monira_applications ADD COLUMN decision_note TEXT;

-- Estados conhecidos; no máximo um pedido em análise por conta.
UPDATE monira_applications SET status = 'pendente' WHERE status IS NULL;
ALTER TABLE monira_applications
  ALTER COLUMN status SET NOT NULL,
  ALTER COLUMN user_id SET NOT NULL,
  ADD CONSTRAINT monira_applications_status_chk CHECK (status IN ('pendente', 'aprovado', 'rejeitado'));
CREATE UNIQUE INDEX monira_applications_one_pending ON monira_applications (user_id) WHERE status = 'pendente';

CREATE POLICY "Monira lê candidaturas" ON monira_applications FOR SELECT USING (monira_is_admin());

-- ───────────────────────────────────────────────────────────
-- 2. Pedir para vender
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_submit_application(
  p_name        TEXT,
  p_phone       TEXT,
  p_description TEXT,
  p_avenue_id   UUID,
  p_city        TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid  UUID := auth.uid();
  v_name TEXT := btrim(coalesce(p_name, ''));
  v_phone TEXT := btrim(coalesce(p_phone, ''));
  v_desc TEXT := nullif(btrim(coalesce(p_description, '')), '');
  v_city TEXT := nullif(btrim(coalesce(p_city, '')), '');
  v_id   UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_signed_in'; END IF;
  IF EXISTS (SELECT 1 FROM monira_vendors WHERE user_id = v_uid) THEN RAISE EXCEPTION 'already_seller'; END IF;
  IF EXISTS (SELECT 1 FROM monira_applications WHERE user_id = v_uid AND status = 'pendente') THEN RAISE EXCEPTION 'already_pending'; END IF;

  IF char_length(v_name) NOT BETWEEN 2 AND 80 THEN RAISE EXCEPTION 'invalid_name'; END IF;
  IF v_phone !~ '^\+?[0-9 ]{9,20}$' THEN RAISE EXCEPTION 'invalid_phone'; END IF;
  IF v_desc IS NULL OR char_length(v_desc) > 1000 THEN RAISE EXCEPTION 'invalid_description'; END IF;
  IF char_length(coalesce(v_city, '')) > 80 THEN RAISE EXCEPTION 'invalid_city'; END IF;
  IF p_avenue_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM monira_avenues WHERE id = p_avenue_id AND active) THEN
    RAISE EXCEPTION 'invalid_avenue';
  END IF;

  INSERT INTO monira_applications (user_id, name, phone, whatsapp, description, avenue_id, city, status)
  VALUES (v_uid, v_name, v_phone, v_phone, v_desc, p_avenue_id, v_city, 'pendente')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 3. Endereços da Uja a partir do nome ("hot7 store" → "hot7-store", sem repetir)
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_unique_slug(p_text TEXT, p_table TEXT) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_base TEXT;
  v_slug TEXT;
  v_n    INT := 1;
  v_taken BOOLEAN;
BEGIN
  v_base := lower(translate(coalesce(p_text, ''),
    'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ',
    'aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn'));
  v_base := trim(both '-' from regexp_replace(v_base, '[^a-z0-9]+', '-', 'g'));
  IF v_base = '' THEN v_base := 'loja'; END IF;
  v_base := left(v_base, 60);
  v_slug := v_base;
  LOOP
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE slug = $1)', p_table) INTO v_taken USING v_slug;
    EXIT WHEN NOT v_taken;
    v_n := v_n + 1;
    v_slug := v_base || '-' || v_n;
  END LOOP;
  RETURN v_slug;
END;
$$;
REVOKE EXECUTE ON FUNCTION monira_unique_slug(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────
-- 4. A Monira aprova: cria a conta de quem vende e a Uja (fechada até quem vende a abrir).
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_admin_approve_application(
  p_application_id UUID,
  p_uja_name       TEXT,
  p_avenue_id      UUID,
  p_verified       BOOLEAN
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_app    monira_applications;
  v_name   TEXT := btrim(coalesce(p_uja_name, ''));
  v_vendor UUID;
  v_slug   TEXT;
BEGIN
  IF NOT monira_is_admin() THEN RAISE EXCEPTION 'not_allowed'; END IF;
  SELECT * INTO v_app FROM monira_applications WHERE id = p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'application_not_found'; END IF;
  IF v_app.status <> 'pendente' THEN RAISE EXCEPTION 'not_pending'; END IF;
  IF EXISTS (SELECT 1 FROM monira_vendors WHERE user_id = v_app.user_id) THEN RAISE EXCEPTION 'already_seller'; END IF;
  IF char_length(v_name) NOT BETWEEN 2 AND 80 THEN RAISE EXCEPTION 'invalid_name'; END IF;
  IF p_avenue_id IS NULL OR NOT EXISTS (SELECT 1 FROM monira_avenues WHERE id = p_avenue_id AND active) THEN
    RAISE EXCEPTION 'invalid_avenue';
  END IF;

  INSERT INTO monira_vendors (user_id, application_id, name, slug, phone, whatsapp, city, verified)
  VALUES (v_app.user_id, v_app.id, v_app.name, monira_unique_slug(v_app.name, 'monira_vendors'),
          v_app.phone, coalesce(v_app.whatsapp, v_app.phone), v_app.city, coalesce(p_verified, false))
  RETURNING id INTO v_vendor;

  v_slug := monira_unique_slug(v_name, 'monira_ujas');
  INSERT INTO monira_ujas (vendor_id, name, slug, avenue_id, status, is_open, whatsapp, whatsapp_public)
  VALUES (v_vendor, v_name, v_slug, p_avenue_id, 'active', false, coalesce(v_app.whatsapp, v_app.phone), false);

  UPDATE monira_applications
     SET status = 'aprovado', reviewed_at = now(), decision_note = NULL
   WHERE id = v_app.id;

  RETURN v_slug;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 5. A Monira recusa, com uma nota para quem pediu (pode pedir outra vez).
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_admin_reject_application(p_application_id UUID, p_note TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_note TEXT := btrim(coalesce(p_note, ''));
BEGIN
  IF NOT monira_is_admin() THEN RAISE EXCEPTION 'not_allowed'; END IF;
  IF char_length(v_note) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'invalid_note'; END IF;
  UPDATE monira_applications
     SET status = 'rejeitado', reviewed_at = now(), decision_note = v_note
   WHERE id = p_application_id AND status = 'pendente';
  IF NOT FOUND THEN RAISE EXCEPTION 'not_pending'; END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  monira_submit_application(TEXT, TEXT, TEXT, UUID, TEXT),
  monira_admin_approve_application(UUID, TEXT, UUID, BOOLEAN),
  monira_admin_reject_application(UUID, TEXT)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  monira_submit_application(TEXT, TEXT, TEXT, UUID, TEXT),
  monira_admin_approve_application(UUID, TEXT, UUID, BOOLEAN),
  monira_admin_reject_application(UUID, TEXT)
TO authenticated;

COMMIT;
