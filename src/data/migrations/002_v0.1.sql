-- ═══════════════════════════════════════════════════════════
-- MONIRA — 002_v0.1
-- Alinha o schema da Fase 0 com o freeze v0.1.
--
-- Autoridade por domínio:
--   raw_* do produto ............ quem vende
--   apresentação do produto ..... Monira
--   preço e total do pedido ..... servidor
--   custo de entrega ............ servidor (a partir das zonas da Uja)
--   estado do pedido ............ quem vende + regras do servidor
--   estado do pagamento ......... servidor / prestador, apenas
--   mensagem .................... autor autenticado
--   funcionamento da Uja ........ quem vende
--   curadoria / distribuição .... Monira
--
-- Regras:
--   · Compra directa: 1 pedido = 1 produto. Sem carrinho.
--   · Nenhum nome de prestador de pagamento no domínio.
--   · Uma só cadeia de verdade: produto → Uja → vendor.
-- ═══════════════════════════════════════════════════════════

BEGIN;

-- ───────────────────────────────────────────────────────────
-- 0. Funções auxiliares de autorização
--    SECURITY DEFINER para poderem ser usadas dentro de políticas
--    sem depender do que o utilizador consegue ler directamente.
-- ───────────────────────────────────────────────────────────

CREATE FUNCTION monira_is_uja_owner(p_uja_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM monira_ujas u
    JOIN monira_vendors v ON v.id = u.vendor_id
    WHERE u.id = p_uja_id AND v.user_id = auth.uid()
  );
$$;

CREATE FUNCTION monira_is_own_buyer(p_buyer_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM monira_buyers b WHERE b.id = p_buyer_id AND b.user_id = auth.uid()
  );
$$;

CREATE FUNCTION monira_uja_is_public(p_uja_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM monira_ujas u
    JOIN monira_vendors v ON v.id = u.vendor_id
    WHERE u.id = p_uja_id AND u.status = 'active' AND v.active
  );
$$;

-- ───────────────────────────────────────────────────────────
-- 1. SEGURANÇA — remover políticas perigosas da Fase 0
-- ───────────────────────────────────────────────────────────

-- Deixava quem vende alterar qualquer coluna do pedido, incluindo o pagamento.
DROP POLICY "Morador actualiza pedido" ON monira_orders;
-- Deixava o cliente inserir o pedido com o preço e o total que quisesse.
DROP POLICY "Visitante cria pedido" ON monira_orders;
-- Mostrava produtos não revistos e os campos raw_* a toda a gente.
DROP POLICY "Produtos públicos" ON monira_products;
-- Expunham a linha inteira (user_id, plano, candidatura…). Substituídas por vistas públicas.
DROP POLICY "Ujas públicas" ON monira_ujas;
DROP POLICY "Vendedor público" ON monira_vendors;
-- Deixava qualquer utilizador avaliar qualquer pedido.
DROP POLICY "Visitante cria review" ON monira_reviews;
-- Dependem de vendor_id, que sai (ver secção 2). Recriadas abaixo.
DROP POLICY "Morador vê seus produtos" ON monira_products;
DROP POLICY "Morador insere produto" ON monira_products;
DROP POLICY "Morador vê seus pedidos" ON monira_orders;

-- Quem vende só pode editar o seu perfil, não verified / plan / rating / total_sales.
REVOKE UPDATE ON monira_vendors FROM anon, authenticated;
GRANT UPDATE (name, photo_url, province, city) ON monira_vendors TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 2. Uma só cadeia de verdade: produto → Uja → vendor
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_products DROP COLUMN vendor_id;
ALTER TABLE monira_orders   DROP COLUMN vendor_id;
ALTER TABLE monira_ujas     ALTER COLUMN vendor_id SET NOT NULL;
ALTER TABLE monira_products ALTER COLUMN uja_id    SET NOT NULL;

-- ───────────────────────────────────────────────────────────
-- 3. Uja — funcionamento (autoridade de quem vende)
--    Imagem e logo: quem vende envia o original (*_raw_url);
--    a Monira publica a versão tratada (*_url). Sem banners livres.
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_ujas
  ADD COLUMN is_open        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN image_raw_url  TEXT,
  ADD COLUMN image_url      TEXT,
  ADD COLUMN logo_raw_url   TEXT,
  ADD COLUMN logo_url       TEXT,
  ADD COLUMN pickup_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN pickup_address TEXT,
  ADD COLUMN whatsapp       TEXT,
  ADD COLUMN phone          TEXT,
  ADD CONSTRAINT monira_ujas_pickup_address_chk
    CHECK (NOT pickup_enabled OR pickup_address IS NOT NULL);

-- A Uja é criada pela Monira; quem vende só mexe no funcionamento.
REVOKE INSERT, UPDATE, DELETE ON monira_ujas FROM anon, authenticated;
GRANT UPDATE (is_open, image_raw_url, logo_raw_url, pickup_enabled, pickup_address, whatsapp, phone, updated_at)
  ON monira_ujas TO authenticated;

CREATE POLICY "Morador actualiza funcionamento da Uja" ON monira_ujas FOR UPDATE
  USING (monira_is_uja_owner(id)) WITH CHECK (monira_is_uja_owner(id));

CREATE TABLE monira_uja_hours (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  uja_id    UUID NOT NULL REFERENCES monira_ujas(id) ON DELETE CASCADE,
  weekday   SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),  -- 0 = domingo
  opens_at  TIME NOT NULL,
  closes_at TIME NOT NULL CHECK (closes_at > opens_at),
  UNIQUE (uja_id, weekday, opens_at)
);

-- Zonas de entrega: dado operacional consultado no checkout.
CREATE TABLE monira_uja_delivery_zones (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  uja_id     UUID NOT NULL REFERENCES monira_ujas(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,                                   -- "Talatona"
  fee_kz     NUMERIC(12,2) NOT NULL CHECK (fee_kz >= 0),       -- definido por quem vende
  active     BOOLEAN NOT NULL DEFAULT true,
  position   INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (uja_id, name)
);

ALTER TABLE monira_uja_hours          ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_uja_delivery_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Horário público"        ON monira_uja_hours FOR SELECT USING (monira_uja_is_public(uja_id));
CREATE POLICY "Morador gere horário"   ON monira_uja_hours FOR ALL
  USING (monira_is_uja_owner(uja_id)) WITH CHECK (monira_is_uja_owner(uja_id));
CREATE POLICY "Zonas públicas"         ON monira_uja_delivery_zones FOR SELECT USING (active AND monira_uja_is_public(uja_id));
CREATE POLICY "Morador gere zonas"     ON monira_uja_delivery_zones FOR ALL
  USING (monira_is_uja_owner(uja_id)) WITH CHECK (monira_is_uja_owner(uja_id));

REVOKE INSERT, UPDATE, DELETE ON monira_uja_hours, monira_uja_delivery_zones FROM anon;

-- ───────────────────────────────────────────────────────────
-- 4. Produto — duas camadas
--    Quem vende escreve raw_*, preço e stock.
--    A Monira escreve name, description, photos, category, tags, featured, admin_reviewed.
-- ───────────────────────────────────────────────────────────

-- Quando quem vende muda o conteúdo bruto de um produto já publicado,
-- a apresentação actual continua visível, mas fica marcada para revisão.
ALTER TABLE monira_products ADD COLUMN needs_review BOOLEAN NOT NULL DEFAULT true;

CREATE FUNCTION monira_products_flag_review() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.raw_name        IS DISTINCT FROM OLD.raw_name
  OR NEW.raw_description IS DISTINCT FROM OLD.raw_description
  OR NEW.raw_photos      IS DISTINCT FROM OLD.raw_photos THEN
    NEW.needs_review := true;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER monira_products_flag_review BEFORE UPDATE ON monira_products
  FOR EACH ROW EXECUTE FUNCTION monira_products_flag_review();

REVOKE INSERT, UPDATE, DELETE ON monira_products FROM anon, authenticated;
REVOKE SELECT ON monira_products FROM anon;          -- o público lê pela vista monira_public_products
GRANT INSERT (uja_id, raw_name, raw_description, raw_photos, price_kz, stock) ON monira_products TO authenticated;
GRANT UPDATE (raw_name, raw_description, raw_photos, price_kz, stock)          ON monira_products TO authenticated;

CREATE POLICY "Morador vê seus produtos"   ON monira_products FOR SELECT USING (monira_is_uja_owner(uja_id));
CREATE POLICY "Morador insere produto"     ON monira_products FOR INSERT WITH CHECK (monira_is_uja_owner(uja_id));
CREATE POLICY "Morador edita produto"      ON monira_products FOR UPDATE
  USING (monira_is_uja_owner(uja_id)) WITH CHECK (monira_is_uja_owner(uja_id));

CREATE FUNCTION monira_product_is_public(p_product_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM monira_products p
    WHERE p.id = p_product_id AND p.active AND p.admin_reviewed AND monira_uja_is_public(p.uja_id)
  );
$$;

CREATE FUNCTION monira_is_product_owner(p_product_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM monira_products p WHERE p.id = p_product_id AND monira_is_uja_owner(p.uja_id));
$$;

-- Opções (ex.: cores). O cliente escolhe uma no pedido.
CREATE TABLE monira_product_options (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES monira_products(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,                  -- "Azul"
  position   INT NOT NULL DEFAULT 0,
  active     BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (product_id, name)
);
ALTER TABLE monira_product_options ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON monira_product_options FROM anon;
CREATE POLICY "Opções públicas"      ON monira_product_options FOR SELECT USING (active AND monira_product_is_public(product_id));
CREATE POLICY "Morador gere opções"  ON monira_product_options FOR ALL
  USING (monira_is_product_owner(product_id)) WITH CHECK (monira_is_product_owner(product_id));

-- ───────────────────────────────────────────────────────────
-- 5. Vistas públicas — o que a Monira mostra
--    (sem security_invoker: filtram por dentro e expõem só colunas de apresentação)
-- ───────────────────────────────────────────────────────────

CREATE VIEW monira_public_ujas AS
  SELECT u.id, u.name, u.slug, u.avenue_id, u.description,
         u.image_url, u.logo_url, u.is_open,
         u.pickup_enabled, u.pickup_address, u.whatsapp, u.phone,
         v.verified, v.response_time_minutes
  FROM monira_ujas u
  JOIN monira_vendors v ON v.id = u.vendor_id
  WHERE u.status = 'active' AND v.active;

CREATE VIEW monira_public_products AS
  SELECT p.id, p.uja_id, p.name, p.description, p.photos, p.price_kz,
         p.category, p.tags, p.featured, (p.stock > 0) AS available, p.created_at
  FROM monira_products p
  WHERE p.active AND p.admin_reviewed AND monira_uja_is_public(p.uja_id);

REVOKE ALL ON monira_public_ujas, monira_public_products FROM anon, authenticated;
GRANT SELECT ON monira_public_ujas, monira_public_products TO anon, authenticated;

-- ───────────────────────────────────────────────────────────
-- 6. Pedido — compra directa, 1 produto
--    Estados: new → delivering → completed (| cancelled)
--    Preço, custo de entrega e total são snapshot calculado pelo servidor.
-- ───────────────────────────────────────────────────────────

ALTER TABLE monira_orders
  DROP COLUMN payment_method,
  DROP COLUMN payment_ref,
  DROP COLUMN payment_status,
  DROP COLUMN paid_at,
  DROP COLUMN confirmed_by_vendor_at;

UPDATE monira_orders SET status = CASE status
  WHEN 'entregue'  THEN 'completed'
  WHEN 'cancelado' THEN 'cancelled'
  WHEN 'disputado' THEN 'cancelled'
  ELSE 'new' END;
UPDATE monira_orders SET delivery_mode = CASE delivery_mode
  WHEN 'entrega_propria' THEN 'delivery'
  WHEN 'levantamento'    THEN 'pickup'
  ELSE delivery_mode END;

ALTER TABLE monira_orders RENAME COLUMN delivered_at TO completed_at;

ALTER TABLE monira_orders
  ALTER COLUMN status SET DEFAULT 'new',
  ALTER COLUMN status SET NOT NULL,
  ADD COLUMN option_id          UUID REFERENCES monira_product_options(id) ON DELETE SET NULL,
  ADD COLUMN option_name        TEXT,                -- snapshot
  ADD COLUMN delivery_fee_kz    NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN delivery_zone_id   UUID REFERENCES monira_uja_delivery_zones(id) ON DELETE SET NULL,
  ADD COLUMN delivery_zone_name TEXT,                -- snapshot
  ADD COLUMN delivery_address   TEXT,
  ADD COLUMN delivering_at      TIMESTAMPTZ,
  ADD COLUMN cancelled_at       TIMESTAMPTZ,
  ADD CONSTRAINT monira_orders_status_chk        CHECK (status IN ('new', 'delivering', 'completed', 'cancelled')),
  ADD CONSTRAINT monira_orders_delivery_mode_chk CHECK (delivery_mode IN ('delivery', 'pickup')) NOT VALID,
  ADD CONSTRAINT monira_orders_quantity_chk      CHECK (quantity > 0) NOT VALID,
  ADD CONSTRAINT monira_orders_total_chk         CHECK (total_kz = price_kz * quantity + delivery_fee_kz) NOT VALID;

-- Ninguém escreve pedidos directamente a partir do browser.
REVOKE INSERT, UPDATE, DELETE ON monira_orders FROM anon, authenticated;
CREATE POLICY "Morador vê seus pedidos" ON monira_orders FOR SELECT USING (monira_is_uja_owner(uja_id));
-- "Visitante vê seus pedidos" (buyer_id) mantém-se.

CREATE SEQUENCE monira_order_number_seq;
CREATE FUNCTION monira_next_order_number() RETURNS TEXT
LANGUAGE sql AS $$
  SELECT 'MON-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('monira_order_number_seq')::text, 5, '0');
$$;

-- ───────────────────────────────────────────────────────────
-- 7. Pagamento — abstracto, sem prestador no domínio
--    PaymentProvider → coluna `provider` (texto de configuração)
--    MerchantAccount, PaymentRequest, PaymentConfirmation → tabelas
--    Estados do pedido de pagamento: requested → confirmed | failed | expired
-- ───────────────────────────────────────────────────────────

CREATE TABLE monira_merchant_accounts (
  id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vendor_id            UUID NOT NULL REFERENCES monira_vendors(id) ON DELETE CASCADE,
  provider             TEXT NOT NULL,              -- identificador do prestador (configuração)
  external_account_ref TEXT,                       -- referência da conta no prestador
  status               TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'disabled')),
  created_at           TIMESTAMPTZ DEFAULT now(),
  UNIQUE (vendor_id, provider)
);

CREATE TABLE monira_payment_requests (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id            UUID NOT NULL REFERENCES monira_orders(id) ON DELETE CASCADE,
  merchant_account_id UUID NOT NULL REFERENCES monira_merchant_accounts(id),
  provider            TEXT NOT NULL,
  amount_kz           NUMERIC(12,2) NOT NULL CHECK (amount_kz > 0),
  payer_phone         TEXT NOT NULL,
  external_ref        TEXT,                        -- devolvida pelo prestador
  status              TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'confirmed', 'failed', 'expired')),
  requested_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at          TIMESTAMPTZ NOT NULL,
  resolved_at         TIMESTAMPTZ
);
-- No máximo um pedido de pagamento em aberto e um confirmado por pedido.
CREATE UNIQUE INDEX monira_payment_requests_one_open      ON monira_payment_requests (order_id) WHERE status = 'requested';
CREATE UNIQUE INDEX monira_payment_requests_one_confirmed ON monira_payment_requests (order_id) WHERE status = 'confirmed';
CREATE UNIQUE INDEX monira_payment_requests_external      ON monira_payment_requests (provider, external_ref) WHERE external_ref IS NOT NULL;

CREATE TABLE monira_payment_confirmations (
  id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  payment_request_id UUID NOT NULL REFERENCES monira_payment_requests(id),
  provider           TEXT NOT NULL,
  external_ref       TEXT NOT NULL,
  amount_kz          NUMERIC(12,2) NOT NULL,
  accepted           BOOLEAN NOT NULL,             -- false se o valor não bater certo
  raw_payload        JSONB,
  received_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, external_ref)                  -- idempotência: o mesmo callback conta uma vez
);

ALTER TABLE monira_merchant_accounts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_payment_requests      ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_payment_confirmations ENABLE ROW LEVEL SECURITY;

-- Só o servidor escreve. Clientes lêem o estritamente necessário.
REVOKE ALL ON monira_merchant_accounts, monira_payment_requests, monira_payment_confirmations FROM anon, authenticated;
GRANT SELECT (id, vendor_id, provider, status, created_at) ON monira_merchant_accounts TO authenticated;
GRANT SELECT (id, order_id, provider, amount_kz, status, requested_at, expires_at, resolved_at) ON monira_payment_requests TO authenticated;

CREATE POLICY "Morador vê a sua conta de comerciante" ON monira_merchant_accounts FOR SELECT
  USING (vendor_id IN (SELECT id FROM monira_vendors WHERE user_id = auth.uid()));
CREATE POLICY "Partes vêem pedidos de pagamento" ON monira_payment_requests FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM monira_orders o
    WHERE o.id = order_id AND (monira_is_uja_owner(o.uja_id) OR monira_is_own_buyer(o.buyer_id))
  ));

-- Estado de pagamento por pedido, para o UI ("Pago ✓", "A aguardar pagamento", …).
CREATE VIEW monira_order_payment_state WITH (security_invoker = true) AS
  SELECT o.id AS order_id,
         COALESCE(
           (SELECT 'confirmed' FROM monira_payment_requests r WHERE r.order_id = o.id AND r.status = 'confirmed' LIMIT 1),
           (SELECT r.status FROM monira_payment_requests r WHERE r.order_id = o.id ORDER BY r.requested_at DESC LIMIT 1),
           'none'
         ) AS payment_state
  FROM monira_orders o;
GRANT SELECT ON monira_order_payment_state TO authenticated;

-- ───────────────────────────────────────────────────────────
-- 8. Conversas — intenção em formação, separada do pedido
-- ───────────────────────────────────────────────────────────

CREATE TABLE monira_conversations (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  uja_id          UUID NOT NULL REFERENCES monira_ujas(id),
  customer_id     UUID NOT NULL REFERENCES monira_buyers(id),
  product_id      UUID REFERENCES monira_products(id) ON DELETE SET NULL,   -- contexto de origem
  order_id        UUID REFERENCES monira_orders(id)   ON DELETE SET NULL,   -- se resultou em compra
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_message_at TIMESTAMPTZ,
  UNIQUE NULLS NOT DISTINCT (uja_id, customer_id, product_id)
);

CREATE TABLE monira_messages (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES monira_conversations(id) ON DELETE CASCADE,
  sender_user_id  UUID NOT NULL REFERENCES auth.users(id),
  body            TEXT NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 4000),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX monira_messages_conversation ON monira_messages (conversation_id, created_at);

CREATE FUNCTION monira_is_conversation_participant(p_conversation_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM monira_conversations c
    WHERE c.id = p_conversation_id
      AND (monira_is_own_buyer(c.customer_id) OR monira_is_uja_owner(c.uja_id))
  );
$$;

ALTER TABLE monira_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_messages      ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON monira_conversations, monira_messages FROM anon;
REVOKE INSERT, UPDATE, DELETE ON monira_conversations, monira_messages FROM authenticated;
GRANT INSERT (uja_id, customer_id, product_id)        ON monira_conversations TO authenticated;
GRANT INSERT (conversation_id, sender_user_id, body)  ON monira_messages      TO authenticated;

CREATE POLICY "Participantes vêem conversa" ON monira_conversations FOR SELECT
  USING (monira_is_own_buyer(customer_id) OR monira_is_uja_owner(uja_id));
CREATE POLICY "Cliente inicia conversa" ON monira_conversations FOR INSERT
  WITH CHECK (
    monira_is_own_buyer(customer_id)
    AND monira_uja_is_public(uja_id)
    AND (product_id IS NULL OR EXISTS (
      SELECT 1 FROM monira_public_products p WHERE p.id = product_id AND p.uja_id = monira_conversations.uja_id
    ))
  );
CREATE POLICY "Participantes vêem mensagens" ON monira_messages FOR SELECT
  USING (monira_is_conversation_participant(conversation_id));
CREATE POLICY "Autor envia mensagem" ON monira_messages FOR INSERT
  WITH CHECK (sender_user_id = auth.uid() AND monira_is_conversation_participant(conversation_id));

CREATE FUNCTION monira_messages_touch_conversation() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE monira_conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;
CREATE TRIGGER monira_messages_touch_conversation AFTER INSERT ON monira_messages
  FOR EACH ROW EXECUTE FUNCTION monira_messages_touch_conversation();

-- ───────────────────────────────────────────────────────────
-- 9. Avaliações — só as partes de um pedido concluído
-- ───────────────────────────────────────────────────────────

CREATE POLICY "Partes avaliam pedido concluído" ON monira_reviews FOR INSERT
  WITH CHECK (
    from_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM monira_orders o
      WHERE o.id = order_id AND o.status = 'completed'
        AND (
          (type = 'visitante_avalia_morador' AND monira_is_own_buyer(o.buyer_id))
          OR (type = 'morador_avalia_visitante' AND monira_is_uja_owner(o.uja_id))
        )
    )
  );

-- ───────────────────────────────────────────────────────────
-- 10. Operações de servidor
--     Executadas apenas pelo backend (service_role), excepto
--     monira_advance_order, que quem vende chama com a sua sessão.
-- ───────────────────────────────────────────────────────────

-- Cliente envia intenção; o servidor resolve preço, disponibilidade, entrega e total.
CREATE FUNCTION monira_place_order(
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

  -- interesse → conversa → pedido
  UPDATE monira_conversations SET order_id = v_order.id
   WHERE uja_id = v_uja.id AND customer_id = p_buyer_id AND product_id = v_prod.id AND order_id IS NULL;

  RETURN v_order;
END;
$$;

-- Abre um pedido de pagamento em nome da Uja. O valor vem sempre do pedido.
CREATE FUNCTION monira_create_payment_request(
  p_order_id    UUID,
  p_provider    TEXT,
  p_payer_phone TEXT,
  p_ttl         INTERVAL DEFAULT interval '15 minutes'
) RETURNS monira_payment_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order monira_orders;
  v_acc   monira_merchant_accounts;
  v_req   monira_payment_requests;
BEGIN
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR v_order.status <> 'new' THEN RAISE EXCEPTION 'order_not_payable'; END IF;
  IF EXISTS (SELECT 1 FROM monira_payment_requests WHERE order_id = p_order_id AND status = 'confirmed') THEN
    RAISE EXCEPTION 'already_confirmed';
  END IF;

  -- Pedidos em aberto que já expiraram passam a 'expired' antes de abrir um novo.
  UPDATE monira_payment_requests SET status = 'expired', resolved_at = now()
   WHERE order_id = p_order_id AND status = 'requested' AND expires_at <= now();

  SELECT a.* INTO v_acc FROM monira_merchant_accounts a
   JOIN monira_ujas u ON u.vendor_id = a.vendor_id
   WHERE u.id = v_order.uja_id AND a.provider = p_provider AND a.status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'merchant_account_unavailable'; END IF;

  INSERT INTO monira_payment_requests (order_id, merchant_account_id, provider, amount_kz, payer_phone, expires_at)
  VALUES (p_order_id, v_acc.id, p_provider, v_order.total_kz, p_payer_phone, now() + p_ttl)
  RETURNING * INTO v_req;
  RETURN v_req;
END;
$$;

-- Callback do prestador. Idempotente. Só confirma se o valor bater certo.
CREATE FUNCTION monira_record_payment_confirmation(
  p_provider     TEXT,
  p_external_ref TEXT,
  p_amount_kz    NUMERIC,
  p_payload      JSONB
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_req      monira_payment_requests;
  v_accepted BOOLEAN;
  v_qty      INT;
BEGIN
  IF EXISTS (SELECT 1 FROM monira_payment_confirmations WHERE provider = p_provider AND external_ref = p_external_ref) THEN
    RETURN 'duplicate';
  END IF;

  SELECT * INTO v_req FROM monira_payment_requests
   WHERE provider = p_provider AND external_ref = p_external_ref FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'unknown_payment_request'; END IF;

  v_accepted := (p_amount_kz = v_req.amount_kz AND v_req.status = 'requested');

  INSERT INTO monira_payment_confirmations (payment_request_id, provider, external_ref, amount_kz, accepted, raw_payload)
  VALUES (v_req.id, p_provider, p_external_ref, p_amount_kz, v_accepted, p_payload);

  IF NOT v_accepted THEN RETURN 'rejected'; END IF;

  UPDATE monira_payment_requests SET status = 'confirmed', resolved_at = now() WHERE id = v_req.id;

  -- Stock sai só com pagamento confirmado.
  SELECT quantity INTO v_qty FROM monira_orders WHERE id = v_req.order_id;
  UPDATE monira_products p SET stock = greatest(p.stock - v_qty, 0)
    FROM monira_orders o WHERE o.id = v_req.order_id AND p.id = o.product_id;

  RETURN 'confirmed';
END;
$$;

CREATE FUNCTION monira_resolve_payment_request(p_request_id UUID, p_status TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_status NOT IN ('failed', 'expired') THEN RAISE EXCEPTION 'invalid_status'; END IF;
  UPDATE monira_payment_requests SET status = p_status, resolved_at = now()
   WHERE id = p_request_id AND status = 'requested';
END;
$$;

-- Quem vende avança o pedido. Só sai para entrega com pagamento confirmado.
CREATE FUNCTION monira_advance_order(p_order_id UUID) RETURNS monira_orders
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order monira_orders;
BEGIN
  SELECT * INTO v_order FROM monira_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND OR NOT monira_is_uja_owner(v_order.uja_id) THEN RAISE EXCEPTION 'not_allowed'; END IF;

  IF v_order.status = 'new' THEN
    IF NOT EXISTS (SELECT 1 FROM monira_payment_requests WHERE order_id = p_order_id AND status = 'confirmed') THEN
      RAISE EXCEPTION 'payment_not_confirmed';
    END IF;
    UPDATE monira_orders SET status = 'delivering', delivering_at = now(), updated_at = now()
     WHERE id = p_order_id RETURNING * INTO v_order;
  ELSIF v_order.status = 'delivering' THEN
    UPDATE monira_orders SET status = 'completed', completed_at = now(), updated_at = now()
     WHERE id = p_order_id RETURNING * INTO v_order;
  ELSE
    RAISE EXCEPTION 'invalid_transition';
  END IF;
  RETURN v_order;
END;
$$;

-- Em Supabase, as funções em public são executáveis por anon/authenticated por omissão.
REVOKE EXECUTE ON FUNCTION
  monira_place_order(UUID, UUID, UUID, INT, TEXT, UUID, TEXT),
  monira_create_payment_request(UUID, TEXT, TEXT, INTERVAL),
  monira_record_payment_confirmation(TEXT, TEXT, NUMERIC, JSONB),
  monira_resolve_payment_request(UUID, TEXT),
  monira_advance_order(UUID),
  monira_next_order_number()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  monira_place_order(UUID, UUID, UUID, INT, TEXT, UUID, TEXT),
  monira_create_payment_request(UUID, TEXT, TEXT, INTERVAL),
  monira_record_payment_confirmation(TEXT, TEXT, NUMERIC, JSONB),
  monira_resolve_payment_request(UUID, TEXT),
  monira_next_order_number()
TO service_role;

GRANT EXECUTE ON FUNCTION monira_advance_order(UUID) TO authenticated, service_role;

COMMIT;
