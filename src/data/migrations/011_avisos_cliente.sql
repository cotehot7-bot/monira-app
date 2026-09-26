-- ═══════════════════════════════════════════════════════════
-- MONIRA — 011_avisos_cliente
-- Fecha o circuito: a loja responde → o cliente é avisado;
-- o pedido sai para entrega ou é cancelado → o cliente é avisado.
-- Mesmas regras dos avisos à loja: a base de dados decide quem e se.
-- Requer 002–010.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- Email de quem compra (a partir do comprador do pedido ou da conversa).
CREATE FUNCTION monira_buyer_email(p_buyer_id UUID) RETURNS TABLE (user_id UUID, email TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT b.user_id, u.email::text
  FROM monira_buyers b JOIN auth.users u ON u.id = b.user_id
  WHERE b.id = p_buyer_id;
$$;
REVOKE EXECUTE ON FUNCTION monira_buyer_email(UUID) FROM PUBLIC, anon, authenticated;

-- ───────────────────────────────────────────────────────────
-- 1. A loja respondeu → avisar o cliente
--    Só a loja que escreveu pode pedir o aviso. Mensagens do próprio cliente: nada.
--    Um aviso por conversa a cada 10 minutos.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_reply_notification(p_message_id UUID)
RETURNS TABLE (email TEXT, conversation_id UUID, uja_name TEXT, product_name TEXT, body TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_msg   monira_messages;
  v_conv  monira_conversations;
  v_buyer RECORD;
BEGIN
  SELECT * INTO v_msg FROM monira_messages WHERE id = p_message_id;
  IF NOT FOUND OR v_msg.sender_user_id IS DISTINCT FROM auth.uid() THEN RETURN; END IF;

  SELECT * INTO v_conv FROM monira_conversations WHERE id = v_msg.conversation_id;
  IF NOT monira_is_uja_owner(v_conv.uja_id) THEN RETURN; END IF;       -- só respostas da loja

  SELECT * INTO v_buyer FROM monira_buyer_email(v_conv.customer_id);
  IF v_buyer.email IS NULL OR v_buyer.user_id = v_msg.sender_user_id THEN RETURN; END IF;

  IF EXISTS (
    SELECT 1 FROM monira_notification_log
    WHERE kind = 'reply' AND subject_key = v_conv.id::text AND recipient_user_id = v_buyer.user_id
      AND sent_at > now() - interval '10 minutes'
  ) THEN RETURN; END IF;

  INSERT INTO monira_notification_log (kind, subject_key, recipient_user_id)
  VALUES ('reply', v_conv.id::text, v_buyer.user_id);

  RETURN QUERY SELECT v_buyer.email, v_conv.id,
    (SELECT name FROM monira_ujas WHERE id = v_conv.uja_id),
    (SELECT coalesce(p.name, p.raw_name) FROM monira_products p WHERE p.id = v_conv.product_id),
    left(v_msg.body, 280);
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 2. Pedido a caminho / cancelado → avisar o cliente
--    Só a loja dona do pedido pede o aviso; só depois da transição real
--    (o estado actual tem de corresponder); no máximo uma vez por pedido e tipo.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_order_status_notification(p_order_id UUID, p_kind TEXT)
RETURNS TABLE (email TEXT, order_id UUID, order_number TEXT, product_name TEXT, uja_name TEXT, reason TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order monira_orders;
  v_buyer RECORD;
BEGIN
  IF p_kind NOT IN ('order_delivering', 'order_cancelled') THEN RETURN; END IF;
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id;
  IF NOT FOUND OR NOT monira_is_uja_owner(v_order.uja_id) THEN RETURN; END IF;
  IF (p_kind = 'order_delivering' AND v_order.status <> 'delivering')
  OR (p_kind = 'order_cancelled'  AND v_order.status <> 'cancelled') THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM monira_notification_log WHERE kind = p_kind AND subject_key = v_order.id::text) THEN RETURN; END IF;

  SELECT * INTO v_buyer FROM monira_buyer_email(v_order.buyer_id);
  IF v_buyer.email IS NULL THEN RETURN; END IF;

  INSERT INTO monira_notification_log (kind, subject_key, recipient_user_id)
  VALUES (p_kind, v_order.id::text, v_buyer.user_id);

  RETURN QUERY SELECT v_buyer.email, v_order.id, v_order.order_number,
    (SELECT coalesce(p.name, p.raw_name) FROM monira_products p WHERE p.id = v_order.product_id),
    (SELECT name FROM monira_ujas WHERE id = v_order.uja_id),
    CASE WHEN p_kind = 'order_cancelled' THEN v_order.cancel_reason END;
END;
$$;

REVOKE EXECUTE ON FUNCTION monira_reply_notification(UUID), monira_order_status_notification(UUID, TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION monira_reply_notification(UUID), monira_order_status_notification(UUID, TEXT) TO authenticated;

COMMIT;
