-- MONIRA — Auditoria de segurança (SÓ LEITURA: não altera nada)
-- Correr no SQL Editor. Cada linha com estado ≠ 'ok' é para rever.
WITH
sem_rls AS (
  SELECT 'Tabela sem RLS' AS verificacao, c.relname::text AS objecto, 'REVER' AS estado
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
),
escrita_visitante AS (
  SELECT 'Escrita não protegida (anon ou TRUNCATE)' AS verificacao, table_name || ' · ' || string_agg(grantee || ':' || privilege_type, ', ') AS objecto, 'REVER' AS estado
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public' AND (
          (grantee = 'anon' AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'))
       OR (grantee = 'authenticated' AND privilege_type = 'TRUNCATE'))
  GROUP BY table_name
),
definer_visitante AS (
  SELECT 'Função privilegiada aberta a visitantes' AS verificacao, p.proname::text AS objecto,
         CASE WHEN p.proname IN ('monira_is_admin', 'monira_is_uja_owner', 'monira_is_own_buyer', 'monira_uja_is_public',
                                 'monira_uja_delivers', 'monira_is_conversation_participant', 'monira_is_product_owner',
                                 'monira_product_is_public')
              THEN 'ok (só responde sim/não)'
              WHEN p.prorettype = 'trigger'::regtype THEN 'ok (só corre como trigger)'
              ELSE 'REVER' END AS estado
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prosecdef AND has_function_privilege('anon', p.oid, 'EXECUTE')
),
buckets AS (
  SELECT 'Bucket de fotografias' AS verificacao, id || CASE WHEN public THEN ' (público)' ELSE ' (privado)' END AS objecto,
         CASE WHEN id = 'monira-raw' AND public THEN 'REVER: devia ser privado'
              WHEN id = 'monira-public' AND NOT public THEN 'REVER: devia ser público'
              ELSE 'ok' END AS estado
  FROM storage.buckets
),
sem_politica AS (
  SELECT 'Tabela com RLS mas sem regras (ninguém lê)' AS verificacao, c.relname::text AS objecto, 'ok se for interna' AS estado
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
    AND NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = 'public' AND p.tablename = c.relname)
),
admins AS (
  SELECT 'Contas com acesso Monira (admin)' AS verificacao, coalesce(u.email, a.user_id::text) AS objecto, 'confirmar que és tu' AS estado
  FROM monira_admins a LEFT JOIN auth.users u ON u.id = a.user_id
)
SELECT * FROM sem_rls
UNION ALL SELECT * FROM escrita_visitante
UNION ALL SELECT * FROM definer_visitante
UNION ALL SELECT * FROM buckets
UNION ALL SELECT * FROM sem_politica
UNION ALL SELECT * FROM admins
ORDER BY 3 DESC, 1, 2;
