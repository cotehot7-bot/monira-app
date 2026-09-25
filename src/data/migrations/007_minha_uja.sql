-- ═══════════════════════════════════════════════════════════
-- MONIRA — 007_minha_uja
-- Quem vende controla o FUNCIONAMENTO da Uja:
--   aberta/fechada · levantamento · entrega e zonas · contactos
-- Não controla a APRESENTAÇÃO (nome, selo, Avenida, imagem, logo, descrição).
-- Estado operacional ≠ estado editorial: fechar não despublica produtos.
-- Requer 002–006.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 1. Novos campos de funcionamento
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_ujas
  ADD COLUMN delivery_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN pickup_reference TEXT,
  ADD COLUMN whatsapp_public  BOOLEAN NOT NULL DEFAULT false,   -- ter contacto ≠ mostrá-lo
  ADD COLUMN calls_enabled    BOOLEAN NOT NULL DEFAULT false;

-- Nada muda para quem já tinha contactos visíveis.
UPDATE monira_ujas SET whatsapp_public = (whatsapp IS NOT NULL), calls_enabled = (phone IS NOT NULL);

GRANT UPDATE (delivery_enabled, pickup_reference, whatsapp_public, calls_enabled) ON monira_ujas TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 2. Vista pública: só o que quem vende escolheu mostrar.
--    (Colunas novas no fim, para a vista poder ser substituída.)
-- ───────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW monira_public_ujas AS
  SELECT u.id, u.name, u.slug, u.avenue_id, u.description,
         u.image_url, u.logo_url, u.is_open,
         u.pickup_enabled,
         CASE WHEN u.pickup_enabled THEN u.pickup_address END AS pickup_address,
         CASE WHEN u.whatsapp_public THEN u.whatsapp END      AS whatsapp,
         CASE WHEN u.calls_enabled THEN u.phone END           AS phone,
         v.verified, v.response_time_minutes,
         u.delivery_enabled,
         CASE WHEN u.pickup_enabled THEN u.pickup_reference END AS pickup_reference
  FROM monira_ujas u
  JOIN monira_vendors v ON v.id = u.vendor_id
  WHERE u.status = 'active' AND v.active;

-- Zonas públicas só quando a Uja faz entregas.
-- (O público não lê monira_ujas, por isso a verificação passa por uma função com privilégios.)
DROP POLICY "Zonas públicas" ON monira_uja_delivery_zones;
CREATE FUNCTION monira_uja_delivers(p_uja_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM monira_ujas WHERE id = p_uja_id AND delivery_enabled);
$$;
CREATE POLICY "Zonas públicas" ON monira_uja_delivery_zones FOR SELECT
  USING (active AND monira_uja_is_public(uja_id) AND monira_uja_delivers(uja_id));

-- ───────────────────────────────────────────────────────────
-- 3. Guardar o funcionamento numa só transacção
--    SECURITY INVOKER: as regras de acesso da 002 continuam a decidir.
--    Zonas identificadas pelo nome; as que saem da lista ficam inactivas (não se apagam).
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_save_uja_settings(p_uja_id UUID, p_settings JSONB, p_zones JSONB) RETURNS VOID
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

  -- Zonas: validar, depois gravar (activar/actualizar) e desactivar as que saíram.
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
     SET is_open          = coalesce((p_settings->>'is_open')::boolean, is_open),
         pickup_enabled   = v_pickup,
         pickup_address   = v_address,
         pickup_reference = v_reference,
         delivery_enabled = v_delivery,
         whatsapp         = v_whatsapp,
         whatsapp_public  = v_wa_public,
         phone            = v_phone,
         calls_enabled    = v_calls,
         updated_at       = now()
   WHERE id = p_uja_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION monira_save_uja_settings(UUID, JSONB, JSONB) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION monira_save_uja_settings(UUID, JSONB, JSONB) TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 4. O cálculo da compra respeita o funcionamento da Uja
--    (substitui a da 002 — a única diferença: entrega exige delivery_enabled).
-- ───────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION monira_place_order(
  p_buyer_id      UUID,
  p_product_id    UUID,
  p_option_id     UUID,
  p_quantity      INT,
  p_delivery_mode TEXT,
  p_zone_id       UUID,
  p_address       TEXT
) RETURNS monira_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_prod  monira_products;
  v_uja   monira_ujas;
  v_opt   monira_product_options;
  v_zone  monira_uja_delivery_zones;
  v_fee   NUMERIC(12,2) := 0;
  v_order monira_orders;
BEGIN
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION 'invalid_quantity'; END IF;

  SELECT * INTO v_prod FROM monira_products
   WHERE id = p_product_id AND active AND admin_reviewed;
  IF NOT FOUND THEN RAISE EXCEPTION 'product_unavailable'; END IF;
  IF v_prod.stock < p_quantity THEN RAISE EXCEPTION 'out_of_stock'; END IF;

  SELECT * INTO v_uja FROM monira_ujas WHERE id = v_prod.uja_id;
  IF NOT monira_uja_is_public(v_uja.id) THEN RAISE EXCEPTION 'uja_unavailable'; END IF;

  IF p_option_id IS NOT NULL THEN
    SELECT * INTO v_opt FROM monira_product_options
     WHERE id = p_option_id AND product_id = v_prod.id AND active;
    IF NOT FOUND THEN RAISE EXCEPTION 'invalid_option'; END IF;
  ELSIF EXISTS (SELECT 1 FROM monira_product_options WHERE product_id = v_prod.id AND active) THEN
    RAISE EXCEPTION 'option_required';
  END IF;

  IF p_delivery_mode = 'delivery' THEN
    IF NOT v_uja.delivery_enabled THEN RAISE EXCEPTION 'delivery_unavailable'; END IF;
    SELECT * INTO v_zone FROM monira_uja_delivery_zones
     WHERE id = p_zone_id AND uja_id = v_uja.id AND active;
    IF NOT FOUND THEN RAISE EXCEPTION 'invalid_zone'; END IF;
    IF coalesce(btrim(p_address), '') = '' THEN RAISE EXCEPTION 'address_required'; END IF;
    v_fee := v_zone.fee_kz;
  ELSIF p_delivery_mode = 'pickup' THEN
    IF NOT v_uja.pickup_enabled THEN RAISE EXCEPTION 'pickup_unavailable'; END IF;
  ELSE
    RAISE EXCEPTION 'invalid_delivery_mode';
  END IF;

  INSERT INTO monira_orders (
    order_number, product_id, uja_id, buyer_id,
    option_id, option_name, price_kz, quantity, delivery_fee_kz, total_kz,
    delivery_mode, delivery_zone_id, delivery_zone_name, delivery_address, status
  ) VALUES (
    monira_next_order_number(), v_prod.id, v_uja.id, p_buyer_id,
    v_opt.id, v_opt.name, v_prod.price_kz, p_quantity, v_fee, v_prod.price_kz * p_quantity + v_fee,
    p_delivery_mode, v_zone.id, v_zone.name, nullif(btrim(p_address), ''), 'new'
  ) RETURNING * INTO v_order;

  UPDATE monira_conversations SET order_id = v_order.id
   WHERE uja_id = v_uja.id AND customer_id = p_buyer_id AND product_id = v_prod.id AND order_id IS NULL;

  RETURN v_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION monira_place_order(UUID, UUID, UUID, INT, TEXT, UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION monira_place_order(UUID, UUID, UUID, INT, TEXT, UUID, TEXT) TO service_role;

COMMIT;
