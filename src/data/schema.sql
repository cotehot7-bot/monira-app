-- ═══════════════════════════════════════════════════════════
-- MONIRA — Database Schema
-- Supabase (PostgreSQL)
-- 3 sistemas: Visitante, Morador, Administração
-- ═══════════════════════════════════════════════════════════

-- Avenidas (categorias macro — administradas)
CREATE TABLE monira_avenues (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,              -- "Estilo", "Lar", "Sabor"
  slug TEXT NOT NULL UNIQUE,       -- "estilo", "lar", "sabor"
  description TEXT,
  color TEXT,                      -- hex accent da Avenida
  icon TEXT,                       -- emoji ou código ícone
  position INT DEFAULT 0,         -- ordem de exibição
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Candidaturas de Moradores (antes de ter Uja)
CREATE TABLE monira_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,              -- nome do Morador/negócio
  phone TEXT NOT NULL,             -- WhatsApp
  whatsapp TEXT,                   -- se diferente do phone
  description TEXT,                -- o que vende, breve
  avenue_id UUID REFERENCES monira_avenues(id),
  province TEXT,                   -- localização
  city TEXT,
  delivery_modes TEXT[] DEFAULT '{}', -- ["entrega_propria", "levantamento"]
  sample_photos TEXT[],            -- URLs de fotos exemplo
  status TEXT DEFAULT 'pendente',  -- pendente / aprovado / rejeitado
  admin_notes TEXT,                -- notas internas da Admin
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Moradores (vendedores aprovados)
CREATE TABLE monira_vendors (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) UNIQUE,
  application_id UUID REFERENCES monira_applications(id),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,       -- monira.ao/v/slug
  phone TEXT NOT NULL,
  whatsapp TEXT NOT NULL,
  photo_url TEXT,                  -- foto do Morador
  province TEXT,
  city TEXT,
  delivery_modes TEXT[] DEFAULT '{}',
  verified BOOLEAN DEFAULT false,
  plan TEXT DEFAULT 'free',        -- free / residente / premium
  rating NUMERIC(3,2) DEFAULT 0,
  total_sales INT DEFAULT 0,
  response_time_minutes INT,      -- "Responde em ~X min"
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Ujas (espaços comerciais — montadas pela Admin, aprovadas pelo Morador)
CREATE TABLE monira_ujas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vendor_id UUID REFERENCES monira_vendors(id),
  name TEXT NOT NULL,              -- nome da Uja
  slug TEXT NOT NULL UNIQUE,       -- monira.ao/u/slug
  avenue_id UUID REFERENCES monira_avenues(id),
  description TEXT,                -- gerada pelo Abi, aprovada pelo Morador
  status TEXT DEFAULT 'draft',     -- draft / pendente_aprovacao / active / paused
  approved_by_vendor_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Produtos (enviados pelo Morador, curados pela Admin)
CREATE TABLE monira_products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  uja_id UUID REFERENCES monira_ujas(id),
  vendor_id UUID REFERENCES monira_vendors(id),
  -- Dados brutos do Morador
  raw_name TEXT,                   -- nome dado pelo Morador
  raw_description TEXT,            -- descrição bruta
  raw_photos TEXT[],               -- fotos originais
  price_kz NUMERIC(12,2) NOT NULL,
  -- Dados curados pela Admin/Abi
  name TEXT,                       -- título curado
  description TEXT,                -- descrição gerada pelo Abi
  photos TEXT[],                   -- fotos processadas (resize, optimized)
  category TEXT,                   -- subcategoria dentro da Avenida
  tags TEXT[] DEFAULT '{}',        -- atributos: ["feminino", "preto", "midi"]
  -- Estado
  stock INT DEFAULT 1,            -- 0 = esgotado
  active BOOLEAN DEFAULT true,
  featured BOOLEAN DEFAULT false,  -- destaque na Uja ou Avenida
  -- Auto-geração
  auto_generated BOOLEAN DEFAULT false,  -- true se Abi gerou desc/tags
  admin_reviewed BOOLEAN DEFAULT false,  -- true se Admin reviu
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Burs (curadorias editoriais — criadas pela Admin)
CREATE TABLE monira_burs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,              -- "Novidades", "Feito Cá", "Fim de Semana"
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  avenue_id UUID REFERENCES monira_avenues(id),  -- NULL = cross-avenue
  type TEXT DEFAULT 'editorial',   -- editorial / sazonal / promo
  cover_image TEXT,
  active BOOLEAN DEFAULT true,
  starts_at TIMESTAMPTZ,           -- para Burs sazonais
  ends_at TIMESTAMPTZ,
  position INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Relação Bur ↔ Produto (N:N — produto pode estar em vários Burs)
CREATE TABLE monira_bur_products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bur_id UUID REFERENCES monira_burs(id) ON DELETE CASCADE,
  product_id UUID REFERENCES monira_products(id) ON DELETE CASCADE,
  position INT DEFAULT 0,
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(bur_id, product_id)
);

-- Visitantes (compradores — conta criada na primeira compra)
CREATE TABLE monira_buyers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) UNIQUE,
  name TEXT,
  phone TEXT NOT NULL,
  province TEXT,
  rating NUMERIC(3,2) DEFAULT 0,
  total_purchases INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Pedidos
CREATE TABLE monira_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_number TEXT NOT NULL UNIQUE,  -- MON-2026-0001
  product_id UUID REFERENCES monira_products(id),
  uja_id UUID REFERENCES monira_ujas(id),
  vendor_id UUID REFERENCES monira_vendors(id),
  buyer_id UUID REFERENCES monira_buyers(id),
  -- Valores
  price_kz NUMERIC(12,2) NOT NULL,
  quantity INT DEFAULT 1,
  total_kz NUMERIC(12,2) NOT NULL,
  -- Pagamento
  payment_method TEXT DEFAULT 'mcx_express',
  payment_ref TEXT,                -- referência AppyPay
  payment_status TEXT DEFAULT 'pendente', -- pendente / pago / falhado / reembolsado
  paid_at TIMESTAMPTZ,
  -- Entrega
  delivery_mode TEXT,              -- entrega_propria / levantamento
  delivery_notes TEXT,             -- instruções do Visitante
  -- Status
  status TEXT DEFAULT 'criado',    -- criado / pago / confirmado / entregue / cancelado / disputado
  confirmed_by_vendor_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  -- WhatsApp
  whatsapp_notified BOOLEAN DEFAULT false,
  whatsapp_notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Avaliações bidirecionais
CREATE TABLE monira_reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID REFERENCES monira_orders(id),
  from_user_id UUID REFERENCES auth.users(id),
  to_user_id UUID REFERENCES auth.users(id),
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  type TEXT NOT NULL,              -- 'visitante_avalia_morador' / 'morador_avalia_visitante'
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(order_id, type)           -- uma avaliação por tipo por pedido
);

-- ═══════════════════════════════════════════════════════════
-- RLS (Row Level Security)
-- ═══════════════════════════════════════════════════════════

ALTER TABLE monira_avenues ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_ujas ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_burs ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_bur_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_buyers ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE monira_applications ENABLE ROW LEVEL SECURITY;

-- Público: Avenidas, Ujas activas, Produtos activos, Burs activos
CREATE POLICY "Avenidas públicas" ON monira_avenues FOR SELECT USING (active = true);
CREATE POLICY "Ujas públicas" ON monira_ujas FOR SELECT USING (status = 'active');
CREATE POLICY "Produtos públicos" ON monira_products FOR SELECT USING (active = true);
CREATE POLICY "Burs públicos" ON monira_burs FOR SELECT USING (active = true);
CREATE POLICY "Bur produtos públicos" ON monira_bur_products FOR SELECT USING (true);
CREATE POLICY "Reviews públicos" ON monira_reviews FOR SELECT USING (true);

-- Morador: gere a sua Uja, produtos e pedidos
CREATE POLICY "Morador vê próprio" ON monira_vendors FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Morador edita próprio" ON monira_vendors FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Morador vê sua Uja" ON monira_ujas FOR SELECT USING (vendor_id IN (SELECT id FROM monira_vendors WHERE user_id = auth.uid()));
CREATE POLICY "Morador vê seus produtos" ON monira_products FOR SELECT USING (vendor_id IN (SELECT id FROM monira_vendors WHERE user_id = auth.uid()));
CREATE POLICY "Morador insere produto" ON monira_products FOR INSERT WITH CHECK (vendor_id IN (SELECT id FROM monira_vendors WHERE user_id = auth.uid()));
CREATE POLICY "Morador vê seus pedidos" ON monira_orders FOR SELECT USING (vendor_id IN (SELECT id FROM monira_vendors WHERE user_id = auth.uid()));
CREATE POLICY "Morador actualiza pedido" ON monira_orders FOR UPDATE USING (vendor_id IN (SELECT id FROM monira_vendors WHERE user_id = auth.uid()));

-- Visitante: vê tudo público, gere seus pedidos
CREATE POLICY "Visitante vê próprio" ON monira_buyers FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Visitante vê seus pedidos" ON monira_orders FOR SELECT USING (buyer_id IN (SELECT id FROM monira_buyers WHERE user_id = auth.uid()));
CREATE POLICY "Visitante cria pedido" ON monira_orders FOR INSERT WITH CHECK (buyer_id IN (SELECT id FROM monira_buyers WHERE user_id = auth.uid()));
CREATE POLICY "Visitante cria review" ON monira_reviews FOR INSERT WITH CHECK (auth.uid() = from_user_id);

-- Candidaturas: utilizador vê a sua
CREATE POLICY "Candidatura própria" ON monira_applications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Candidatura insere" ON monira_applications FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Vendedores públicos (para perfil da Uja)
CREATE POLICY "Vendedor público" ON monira_vendors FOR SELECT USING (active = true);
