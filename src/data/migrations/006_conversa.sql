-- ═══════════════════════════════════════════════════════════
-- MONIRA — 006_conversa
-- Conversa: o primeiro contacto acontece dentro da Monira.
-- As tabelas monira_conversations / monira_messages e as suas regras
-- já existem (002). Aqui: identidade mínima do cliente e abertura segura.
-- Requer 002–005.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- O telefone só é necessário na compra (pagamento). Para conversar basta a sessão.
ALTER TABLE monira_buyers ALTER COLUMN phone DROP NOT NULL;

-- Abre (ou reabre) a conversa sobre um produto publicado.
-- Cria a identidade de cliente se ainda não existir.
-- Quem vende não conversa consigo próprio.
CREATE FUNCTION monira_start_conversation(p_product_id UUID) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_uja   UUID;
  v_buyer UUID;
  v_id    UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_signed_in'; END IF;

  SELECT uja_id INTO v_uja FROM monira_products WHERE id = p_product_id;
  IF v_uja IS NULL OR NOT monira_product_is_public(p_product_id) THEN RAISE EXCEPTION 'product_unavailable'; END IF;
  IF monira_is_uja_owner(v_uja) THEN RAISE EXCEPTION 'own_uja'; END IF;

  INSERT INTO monira_buyers (user_id) VALUES (v_uid) ON CONFLICT (user_id) DO NOTHING;
  SELECT id INTO v_buyer FROM monira_buyers WHERE user_id = v_uid;

  INSERT INTO monira_conversations (uja_id, customer_id, product_id)
  VALUES (v_uja, v_buyer, p_product_id)
  ON CONFLICT (uja_id, customer_id, product_id) DO NOTHING;

  SELECT id INTO v_id FROM monira_conversations
   WHERE uja_id = v_uja AND customer_id = v_buyer AND product_id = p_product_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION monira_start_conversation(UUID) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION monira_start_conversation(UUID) TO authenticated;

COMMIT;
