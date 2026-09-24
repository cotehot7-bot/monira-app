# Monira v0.1 — primeira fatia: Adicionar produto

## O que existe
- `/entrar` — entrar com código por email.
- `/painel/produtos/novo` — Adicionar produto (quem vende). Fotografias vão directamente
  para o Storage (bucket privado `monira-raw`); a Server Action só recebe os caminhos.
  Produto e opções são gravados de forma atómica por `monira_submit_product`.
- O produto fica **por rever** (`admin_reviewed = false`) e não aparece ao público
  até a Monira preparar a apresentação.

## Aplicar no Supabase (por esta ordem)
1. SQL Editor → `select version();` — tem de ser PostgreSQL 15 ou mais.
2. Correr `src/data/migrations/002_v0.1.sql`.
3. Correr `src/data/migrations/003_submit_product.sql`.
4. Authentication → Email Templates → **Magic Link**: incluir `{{ .Token }}` no corpo,
   para o email trazer o código de 6 dígitos que o `/entrar` pede.
5. Entrar uma vez em `/entrar` com o teu email.
6. Correr `src/data/seed_hot7_test.sql` (trocar email e números antes).

**Não correr** nada de `src/data/tests/` no Supabase — são testes locais.

## Variáveis de ambiente (Vercel e .env.local)
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## Testes locais da base de dados
Com um Postgres 15+ vazio:
`000_supabase_stub_LOCAL_ONLY.sql` → `schema.sql` → `seed.sql` → `002` → `003` → `900_*` → `910_*`.
