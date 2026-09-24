-- ═══════════════════════════════════════════════════════════
-- MONIRA — hot7 como primeira Uja de teste
-- Correr no SQL Editor do Supabase DEPOIS de:
--   1. aplicar 002_v0.1.sql e 003_submit_product.sql
--   2. entrar uma vez em /entrar com o email abaixo (cria o utilizador)
-- ═══════════════════════════════════════════════════════════

WITH u AS (
  SELECT id FROM auth.users WHERE email = 'O_TEU_EMAIL@exemplo.com'   -- ← trocar
), v AS (
  INSERT INTO monira_vendors (user_id, name, slug, phone, whatsapp, verified)
  SELECT id, 'hot7 store', 'hot7-store', '+244 000 000 000', '+244 000 000 000', true FROM u   -- ← trocar números
  RETURNING id
)
INSERT INTO monira_ujas (vendor_id, name, slug, avenue_id, status, is_open)
SELECT v.id, 'hot7 store', 'hot7-store', (SELECT id FROM monira_avenues WHERE slug = 'tech'), 'active', true
FROM v;
