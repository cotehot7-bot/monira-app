-- ═══════════════════════════════════════════════════════════
-- MONIRA — 010_comprar_offline
-- Comprar com pagamento na entrega / no levantamento.
-- Duas evidências nunca misturadas:
--   online  → monira_payment_requests.status = 'confirmed' (prestador, callback)
--   offline → monira_offline_payments (a LOJA declara que recebeu) = 'seller_reported'
-- Requer 002–009.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. A loja escolhe que pagamentos offline aceita
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_ujas
  ADD COLUMN accepts_pay_on_delivery BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN accepts_pay_on_pickup   BOOLEAN NOT NULL DEFAULT false;
GRANT UPDATE (accepts_pay_on_delivery, accepts_pay_on_pickup) ON monira_ujas TO authenticated;

CREATE OR REPLACE VIEW monira_public_ujas AS
  SELECT u.id, u.name, u.slug, u.avenue_id, u.description,
         u.image_url, u.logo_url, u.is_open,
         u.pickup_enabled,
         CASE WHEN u.pickup_enabled THEN u.pickup_address END AS pickup_address,
         CASE WHEN u.whatsapp_public THEN u.whatsapp END      AS whatsapp,
         CASE WHEN u.calls_enabled THEN u.phone END           AS phone,
         v.verified, v.response_time_minutes,
         u.delivery_enabled,
         CASE WHEN u.pickup_enabled THEN u.pickup_reference END AS pickup_reference,
         (u.delivery_enabled AND u.accepts_pay_on_delivery) AS pay_on_delivery,
         (u.pickup_enabled AND u.accepts_pay_on_pickup)     AS pay_on_pickup
  FROM monira_ujas u
  JOIN monira_vendors v ON v.id = u.vendor_id
  WHERE u.status = 'active' AND v.active;

-- Guardar funcionamento: igual à 007, mais os dois interruptores de pagamento.
CREATE OR REPLACE FUNCTION monira_save_uja_settings(p_uja_id UUID, p_settings JSONB, p_zones JSONB) RETURNS VOID
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  v_pickup     BOOLEAN := coalesce((p_settings->>'pickup_enabled')::boolean, false);
  v_delivery   BOOLEAN := coalesce((p_settings->>'delivery_enabled')::boolean, false);
  v_address    TEXT    := nullif(btrim(coalesce(p_settings->>'pickup_address', '')), '');
  v_reference  TEXT    := nullif(btrim(coalesce(p_settings->>'pickup_reference', '')), '');
  v_whatsapp   TEXT    := nullif(btrim(coalesce(p_settings->>'whatsapp', '')), '');
  v_phone      TEXT    := nullif(btrim(coalesce(p_settings->>'phone', '')), '');
  v_wa_public  BOOLEAN := coalesce((p_settings->>'whatsapp_public')::boolean, false);
  v_calls      BOOLEAN := coalesce((p_settings->>'calls_enabled')::boolean, false);
  v_pay_deliv  BOOLEAN := coalesce((p_settings->>'accepts_pay_on_delivery')::boolean, false);
  v_pay_pickup BOOLEAN := coalesce((p_settings->>'accepts_pay_on_pickup')::boolean, false);
  v_zone       JSONB;
  v_name       TEXT;
  v_fee        NUMERIC;
  v_names      TEXT[] := '{}';
  v_pos        INT := 0;
BEGIN
  IF NOT monira_is_uja_owner(p_uja_id) THEN RAISE EXCEPTION 'not_allowed'; END IF;

  IF v_pickup AND v_address IS NULL THEN RAISE EXCEPTION 'pickup_address_required'; END IF;
  IF char_length(coalesce(v_address, '')) > 200 OR char_length(coalesce(v_reference, '')) > 200 THEN RAISE EXCEPTION 'invalid_address'; END IF;
  IF v_whatsapp IS NOT NULL AND v_whatsapp !~ '^\+?[0-9 ]{9,20}$' THEN RAISE EXCEPTION 'invalid_whatsapp'; END IF;
  IF v_phone    IS NOT NULL AND v_phone    !~ '^\+?[0-9 ]{9,20}$' THEN RAISE EXCEPTION 'invalid_phone'; END IF;
  IF v_wa_public AND v_whatsapp IS NULL THEN RAISE EXCEPTION 'whatsapp_required'; END IF;
  IF v_calls AND v_phone IS NULL THEN RAISE EXCEPTION 'phone_required'; END IF;
  IF jsonb_typeof(coalesce(p_zones, '[]'::jsonb)) <> 'array' OR jsonb_array_length(coalesce(p_zones, '[]'::jsonb)) > 30 THEN
    RAISE EXCEPTION 'invalid_zones';
  END IF;

  FOR v_zone IN SELECT * FROM jsonb_array_elements(coalesce(p_zones, '[]'::jsonb)) LOOP
    v_name := btrim(coalesce(v_zone->>'name', ''));
    BEGIN
      v_fee := (v_zone->>'fee_kz')::numeric;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'invalid_zones';
    END;
    IF char_length(v_name) NOT BETWEEN 1 AND 60 OR v_fee IS NULL OR v_fee < 0 OR v_fee > 1000000000 THEN
      RAISE EXCEPTION 'invalid_zones';
    END IF;
    IF lower(v_name) = ANY (SELECT lower(n) FROM unnest(v_names) n) THEN RAISE EXCEPTION 'duplicate_zone'; END IF;
    v_names := v_names || v_name;

    UPDATE monira_uja_delivery_zones
       SET name = v_name, fee_kz = round(v_fee, 2), active = true, position = v_pos
     WHERE uja_id = p_uja_id AND lower(name) = lower(v_name);
    IF NOT FOUND THEN
      INSERT INTO monira_uja_delivery_zones (uja_id, name, fee_kz, active, position)
      VALUES (p_uja_id, v_name, round(v_fee, 2), true, v_pos);
    END IF;
    v_pos := v_pos + 1;
  END LOOP;

  UPDATE monira_uja_delivery_zones SET active = false
   WHERE uja_id = p_uja_id AND active AND NOT (lower(name) = ANY (SELECT lower(n) FROM unnest(v_names) n));

  IF v_delivery AND array_length(v_names, 1) IS NULL THEN RAISE EXCEPTION 'zone_required'; END IF;

  UPDATE monira_ujas
     SET is_open                 = coalesce((p_settings->>'is_open')::boolean, is_open),
         pickup_enabled          = v_pickup,
         pickup_address          = v_address,
         pickup_reference        = v_reference,
         delivery_enabled        = v_delivery,
         whatsapp                = v_whatsapp,
         whatsapp_public         = v_wa_public,
         phone                   = v_phone,
         calls_enabled           = v_calls,
         accepts_pay_on_delivery = v_pay_deliv,
         accepts_pay_on_pickup   = v_pay_pickup,
         updated_at              = now()
   WHERE id = p_uja_id;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 2. O pedido guarda o método de pagamento e o contacto do cliente
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_orders
  ADD COLUMN payment_method TEXT CHECK (payment_method IN ('on_delivery', 'on_pickup', 'online')),
  ADD COLUMN customer_phone TEXT,
  ADD COLUMN cancel_reason  TEXT;

-- ───────────────────────────────────────────────────────────
-- 3. Pagamento offline declarado pela loja (≠ confirmação do prestador)
-- ───────────────────────────────────────────────────────────

CREATE TABLE monira_offline_payments (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id    UUID NOT NULL UNIQUE REFERENCES monira_orders(id) ON DELETE CASCADE,
  method      TEXT NOT NULL CHECK (method IN ('cash', 'tpa', 'transfer')),
  amount_kz   NUMERIC(12,2) NOT NULL,
  recorded_by UUID NOT NULL REFERENCES auth.users(id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE monira_offline_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON monira_offline_payments FROM anon;
REVOKE INSERT, UPDATE, DELETE ON monira_offline_payments FROM authenticated;
CREATE POLICY "Partes vêem pagamento declarado" ON monira_offline_payments FOR SELECT
  USING (EXISTS (SELECT 1 FROM monira_orders o WHERE o.id = order_id
                 AND (monira_is_uja_owner(o.uja_id) OR monira_is_own_buyer(o.buyer_id))));

-- Estado de pagamento por pedido (para o UI). As duas evidências continuam distintas.
CREATE OR REPLACE VIEW monira_order_payment_state WITH (security_invoker = true) AS
  SELECT o.id AS order_id,
         CASE
           WHEN EXISTS (SELECT 1 FROM monira_payment_requests r WHERE r.order_id = o.id AND r.status = 'confirmed') THEN 'confirmed'
           WHEN EXISTS (SELECT 1 FROM monira_offline_payments p WHERE p.order_id = o.id) THEN 'seller_reported'
           WHEN o.payment_method IN ('on_delivery', 'on_pickup') THEN 'offline_pending'
           ELSE coalesce((SELECT r.status FROM monira_payment_requests r WHERE r.order_id = o.id ORDER BY r.requested_at DESC LIMIT 1), 'none')
         END AS payment_state
  FROM monira_orders o;

-- ───────────────────────────────────────────────────────────
-- 4. Cliente faz o pedido (intenção → servidor calcula tudo)
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_create_order(
  p_product_id     UUID,
  p_option_id      UUID,
  p_delivery_mode  TEXT,
  p_zone_id        UUID,
  p_address        TEXT,
  p_phone          TEXT,
  p_payment_method TEXT
) RETURNS monira_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_buyer UUID;
  v_uja   monira_ujas;
  v_phone TEXT := btrim(coalesce(p_phone, ''));
  v_order monira_orders;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_signed_in'; END IF;
  IF v_phone !~ '^\+?[0-9 ]{9,20}$' THEN RAISE EXCEPTION 'invalid_phone'; END IF;

  SELECT u.* INTO v_uja FROM monira_ujas u JOIN monira_products p ON p.uja_id = u.id WHERE p.id = p_product_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'product_unavailable'; END IF;
  IF monira_is_uja_owner(v_uja.id) THEN RAISE EXCEPTION 'own_uja'; END IF;
  IF NOT v_uja.is_open THEN RAISE EXCEPTION 'uja_closed'; END IF;

  -- Só pagamento offline por agora; e só o que a loja aceita para aquela forma de receber.
  IF p_payment_method = 'on_delivery' THEN
    IF p_delivery_mode <> 'delivery' OR NOT v_uja.accepts_pay_on_delivery THEN RAISE EXCEPTION 'payment_unavailable'; END IF;
  ELSIF p_payment_method = 'on_pickup' THEN
    IF p_delivery_mode <> 'pickup' OR NOT v_uja.accepts_pay_on_pickup THEN RAISE EXCEPTION 'payment_unavailable'; END IF;
  ELSE
    RAISE EXCEPTION 'payment_unavailable';
  END IF;

  INSERT INTO monira_buyers (user_id, phone) VALUES (v_uid, v_phone)
  ON CONFLICT (user_id) DO UPDATE SET phone = EXCLUDED.phone;
  SELECT id INTO v_buyer FROM monira_buyers WHERE user_id = v_uid;

  IF (SELECT count(*) FROM monira_orders WHERE buyer_id = v_buyer AND status IN ('new', 'delivering')) >= 5 THEN
    RAISE EXCEPTION 'too_many_open_orders';
  END IF;

  -- Preço, disponibilidade, opção, zona e total: calculados pela função da 002/007.
  v_order := monira_place_order(v_buyer, p_product_id, p_option_id, 1, p_delivery_mode, p_zone_id, p_address);

  UPDATE monira_orders SET payment_method = p_payment_method, customer_phone = v_phone
   WHERE id = v_order.id RETURNING * INTO v_order;
  RETURN v_order;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 5. A loja avança o pedido
-- ───────────────────────────────────────────────────────────

-- Online: igual à 002 (só sai para entrega com pagamento confirmado).
-- Offline: pode sair para entrega sem pagamento; conclui-se com "Entregue e pago" (função abaixo).
CREATE OR REPLACE FUNCTION monira_advance_order(p_order_id UUID) RETURNS monira_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order monira_orders;
BEGIN
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR NOT monira_is_uja_owner(v_order.uja_id) THEN RAISE EXCEPTION 'not_allowed'; END IF;

  IF v_order.status = 'new' THEN
    IF v_order.payment_method IS DISTINCT FROM 'on_delivery'
       AND NOT EXISTS (SELECT 1 FROM monira_payment_requests WHERE order_id = p_order_id AND status = 'confirmed') THEN
      RAISE EXCEPTION 'payment_not_confirmed';
    END IF;
    UPDATE monira_orders SET status = 'delivering', delivering_at = now(), updated_at = now()
     WHERE id = p_order_id RETURNING * INTO v_order;
  ELSIF v_order.status = 'delivering' THEN
    IF v_order.payment_method IN ('on_delivery', 'on_pickup') THEN RAISE EXCEPTION 'use_complete_offline'; END IF;
    UPDATE monira_orders SET status = 'completed', completed_at = now(), updated_at = now()
     WHERE id = p_order_id RETURNING * INTO v_order;
  ELSE
    RAISE EXCEPTION 'invalid_transition';
  END IF;
  RETURN v_order;
END;
$$;

-- "Entregue e pago" / "Levantado e pago": regista o pagamento declarado pela loja e conclui.
CREATE FUNCTION monira_complete_offline_order(p_order_id UUID, p_method TEXT) RETURNS monira_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order monira_orders;
BEGIN
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR NOT monira_is_uja_owner(v_order.uja_id) THEN RAISE EXCEPTION 'not_allowed'; END IF;
  IF v_order.payment_method NOT IN ('on_delivery', 'on_pickup') THEN RAISE EXCEPTION 'not_offline'; END IF;
  IF p_method NOT IN ('cash', 'tpa', 'transfer') THEN RAISE EXCEPTION 'invalid_method'; END IF;
  -- Entrega: tem de ter saído para entrega. Levantamento: conclui-se directamente do "novo".
  IF NOT (v_order.status = 'delivering' OR (v_order.status = 'new' AND v_order.payment_method = 'on_pickup')) THEN
    RAISE EXCEPTION 'invalid_transition';
  END IF;

  INSERT INTO monira_offline_payments (order_id, method, amount_kz, recorded_by)
  VALUES (v_order.id, p_method, v_order.total_kz, auth.uid());

  UPDATE monira_orders SET status = 'completed', completed_at = now(), updated_at = now()
   WHERE id = p_order_id RETURNING * INTO v_order;

  -- Stock sai com a venda concluída.
  UPDATE monira_products SET stock = greatest(stock - v_order.quantity, 0) WHERE id = v_order.product_id;
  RETURN v_order;
END;
$$;

-- Cancelar (ex.: o cliente não apareceu). Só antes de concluído; guarda o motivo.
CREATE FUNCTION monira_cancel_order(p_order_id UUID, p_reason TEXT) RETURNS monira_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order  monira_orders;
  v_reason TEXT := btrim(coalesce(p_reason, ''));
BEGIN
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR NOT monira_is_uja_owner(v_order.uja_id) THEN RAISE EXCEPTION 'not_allowed'; END IF;
  IF v_order.status NOT IN ('new', 'delivering') THEN RAISE EXCEPTION 'invalid_transition'; END IF;
  IF char_length(v_reason) NOT BETWEEN 1 AND 300 THEN RAISE EXCEPTION 'invalid_reason'; END IF;
  UPDATE monira_orders SET status = 'cancelled', cancelled_at = now(), cancel_reason = v_reason, updated_at = now()
   WHERE id = p_order_id RETURNING * INTO v_order;
  RETURN v_order;
END;
$$;

-- ───────────────────────────────────────────────────────────
-- 6. Aviso à loja: pedido novo (só quem fez o pedido o pode disparar, uma vez)
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_order_notification(p_order_id UUID)
RETURNS TABLE (email TEXT, order_id UUID, order_number TEXT, product_name TEXT, total_kz NUMERIC, payment_method TEXT, delivery_mode TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order monira_orders;
  v_owner RECORD;
BEGIN
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id;
  IF NOT FOUND OR NOT monira_is_own_buyer(v_order.buyer_id) THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM monira_notification_log WHERE kind = 'order_new' AND subject_key = v_order.id::text) THEN RETURN; END IF;
  SELECT * INTO v_owner FROM monira_uja_owner_email(v_order.uja_id);
  IF v_owner.email IS NULL THEN RETURN; END IF;

  INSERT INTO monira_notification_log (kind, subject_key, recipient_user_id)
  VALUES ('order_new', v_order.id::text, v_owner.user_id);

  RETURN QUERY SELECT v_owner.email, v_order.id, v_order.order_number,
    (SELECT coalesce(p.name, p.raw_name) FROM monira_products p WHERE p.id = v_order.product_id),
    v_order.total_kz, v_order.payment_method, v_order.delivery_mode;
END;
$$;

REVOKE EXECUTE ON FUNCTION
  monira_create_order(UUID, UUID, TEXT, UUID, TEXT, TEXT, TEXT),
  monira_complete_offline_order(UUID, TEXT),
  monira_cancel_order(UUID, TEXT),
  monira_order_notification(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  monira_create_order(UUID, UUID, TEXT, UUID, TEXT, TEXT, TEXT),
  monira_complete_offline_order(UUID, TEXT),
  monira_cancel_order(UUID, TEXT),
  monira_order_notification(UUID)
TO authenticated;

COMMIT;
