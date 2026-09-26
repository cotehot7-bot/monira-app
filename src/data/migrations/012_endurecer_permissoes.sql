-- ═══════════════════════════════════════════════════════════
-- MONIRA — 012_endurecer_permissoes
-- Segurança (permitido durante o congelamento). Não muda nada do que os utilizadores fazem.
-- • Visitantes sem sessão (anon) não escrevem em nada: só lêem, e só o que as regras (RLS) deixam.
-- • TRUNCATE (esvaziar uma tabela) não passa pelas regras RLS: retirado a anon e authenticated.
-- • Tabelas criadas no futuro nascem já sem estas permissões.
-- Requer 002–011.
-- ═══════════════════════════════════════════════════════════

BEGIN;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE ON TABLES FROM authenticated;

COMMIT;
