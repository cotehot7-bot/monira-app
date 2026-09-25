-- ═══════════════════════════════════════════════════════════
-- MONIRA — 009_avisos
-- Avisos por email. A base de dados decide QUEM recebe e SE recebe;
-- o servidor só envia. O email de quem vende nunca passa pelo cliente.
-- Requer 002–008.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. Diário de avisos (anti-cascata e, mais tarde, agrupamento)
-- ───────────────────────────────────────────────────────────

CREATE TABLE monira_notification_log (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  kind              TEXT NOT NULL,        -- message | product_published | product_changes | application_approved | application_rejected
  subject_key       TEXT NOT NULL,        -- conversa, produto ou pedido
  recipient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sent_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX monira_notification_log_recent ON monira_notification_log (kind, subject_key, recipient_user_id, sent_at DESC);
ALTER TABLE monira_notification_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON monira_notification_log FROM anon, authenticated;   -- só as funções abaixo escrevem

-- Email do dono de uma Uja.
CREATE FUNCTION monira_uja_owner_email(p_uja_id UUID) RETURNS TABLE (user_id UUID, email TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT v.user_id, u.email::text
  FROM monira_ujas j
  JOIN monira_vendors v ON v.id = j.vendor_id
  JOIN auth.users u ON u.id = v.user_id
  WHERE j.id = p_uja_id;
$$;
REVOKE EXECUTE ON FUNCTION monira_uja_owner_email(UUID) FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────
-- 2. Nova mensagem → avisar a loja
--    Só quem escreveu a mensagem pode pedir o aviso. Mensagens da própria loja: nada.
--    Um aviso por conversa a cada 10 minutos.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_message_notification(p_message_id UUID)
RETURNS TABLE (email TEXT, conversation_id UUID, product_name TEXT, body TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_msg   monira_messages;
  v_conv  monira_conversations;
  v_owner RECORD;
BEGIN
  SELECT * INTO v_msg FROM monira_messages WHERE id = p_message_id;
  IF NOT FOUND OR v_msg.sender_user_id IS DISTINCT FROM auth.uid() THEN RETURN; END IF;

  SELECT * INTO v_conv FROM monira_conversations WHERE id = v_msg.conversation_id;
  SELECT * INTO v_owner FROM monira_uja_owner_email(v_conv.uja_id);
  IF v_owner.user_id IS NULL OR v_owner.email IS NULL THEN RETURN; END IF;
  IF v_owner.user_id = v_msg.sender_user_id THEN RETURN; END IF;   -- a loja escreveu: sem aviso

  IF EXISTS (
    SELECT 1 FROM monira_notification_log
    WHERE kind = 'message' AND subject_key = v_conv.id::text AND recipient_user_id = v_owner.user_id
      AND sent_at > now() - interval '10 minutes'
  ) THEN RETURN; END IF;

  INSERT INTO monira_notification_log (kind, subject_key, recipient_user_id)
  VALUES ('message', v_conv.id::text, v_owner.user_id);

  RETURN QUERY
    SELECT v_owner.email, v_conv.id,
           (SELECT coalesce(p.name, p.raw_name) FROM monira_products p WHERE p.id = v_conv.product_id),
           left(v_msg.body, 280);
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 3. Decisão editorial → avisar a loja (só a Monira pede)
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_product_notification(p_product_id UUID, p_kind TEXT)
RETURNS TABLE (email TEXT, product_id UUID, product_name TEXT, note TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_prod  monira_products;
  v_owner RECORD;
BEGIN
  IF NOT monira_is_admin() OR p_kind NOT IN ('product_published', 'product_changes') THEN RETURN; END IF;
  SELECT * INTO v_prod FROM monira_products WHERE id = p_product_id;
  IF NOT FOUND THEN RETURN; END IF;
  SELECT * INTO v_owner FROM monira_uja_owner_email(v_prod.uja_id);
  IF v_owner.email IS NULL THEN RETURN; END IF;

  INSERT INTO monira_notification_log (kind, subject_key, recipient_user_id)
  VALUES (p_kind, v_prod.id::text, v_owner.user_id);

  RETURN QUERY SELECT v_owner.email, v_prod.id,
    CASE WHEN p_kind = 'product_published' THEN v_prod.name ELSE coalesce(v_prod.raw_name, v_prod.name) END,
    v_prod.attention_note;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 4. Decisão sobre pedido para vender → avisar quem pediu (só a Monira pede)
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_application_notification(p_application_id UUID)
RETURNS TABLE (email TEXT, status TEXT, note TEXT, uja_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_app   monira_applications;
  v_email TEXT;
  v_kind  TEXT;
BEGIN
  IF NOT monira_is_admin() THEN RETURN; END IF;
  SELECT * INTO v_app FROM monira_applications WHERE id = p_application_id;
  IF NOT FOUND OR v_app.status = 'pendente' THEN RETURN; END IF;
  SELECT u.email::text INTO v_email FROM auth.users u WHERE u.id = v_app.user_id;
  IF v_email IS NULL THEN RETURN; END IF;

  v_kind := CASE WHEN v_app.status = 'aprovado' THEN 'application_approved' ELSE 'application_rejected' END;
  INSERT INTO monira_notification_log (kind, subject_key, recipient_user_id)
  VALUES (v_kind, v_app.id::text, v_app.user_id);

  RETURN QUERY SELECT v_email, v_app.status, v_app.decision_note,
    (SELECT j.name FROM monira_ujas j JOIN monira_vendors v ON v.id = j.vendor_id
      WHERE v.user_id = v_app.user_id ORDER BY j.created_at LIMIT 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION
  monira_message_notification(UUID),
  monira_product_notification(UUID, TEXT),
  monira_application_notification(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  monira_message_notification(UUID),
  monira_product_notification(UUID, TEXT),
  monira_application_notification(UUID)
TO authenticated;

COMMIT;
