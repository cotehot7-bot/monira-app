# Monira v0.1 — primeira fatia: Adicionar produto

## O que existe
- `/entrar` — entrar com link enviado por email (volta por `/auth/callback`).
- `/painel/produtos/novo` — Adicionar produto (quem vende). Fotografias vão directamente
  para o Storage (bucket privado `monira-raw`); a Server Action só recebe os caminhos.
  Produto e opções são gravados de forma atómica por `monira_submit_product`.
- O produto fica **por rever** (`admin_reviewed = false`) e não aparece ao público
  até a Monira preparar a apresentação.

## Aplicar no Supabase (por esta ordem)
1. SQL Editor → `select version();` — tem de ser PostgreSQL 15 ou mais.
2. Correr `src/data/migrations/002_v0.1.sql`.
3. Correr `src/data/migrations/003_submit_product.sql`.
4. Authentication → **URL Configuration**:
   - Site URL: `https://monira-app.vercel.app`
   - Redirect URLs: acrescentar `https://monira-app.vercel.app/**`
   (O email de entrada traz um link que volta a `/auth/callback`.)
5. Entrar uma vez em `/entrar` com o teu email.
6. Correr `src/data/seed_hot7_test.sql` (trocar email e números antes).

**Não correr** nada de `src/data/tests/` no Supabase — são testes locais.

## Variáveis de ambiente (Vercel e .env.local)
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## Testes locais da base de dados
Com um Postgres 15+ vazio:
`000_supabase_stub_LOCAL_ONLY.sql` → `schema.sql` → `seed.sql` → `002` → `003` → `900_*` → `910_*`.

## Revisão (004)
1. Correr `src/data/migrations/004_review.sql`.
2. Tornar-te admin (és o único utilizador; se houver mais, trocar pelo teu email):
   `insert into monira_admins (user_id) select id from auth.users order by created_at limit 1;`
3. Abrir `/revisao`. Quem não é admin vê "página não encontrada".

Fotografias: o original fica em `monira-raw` (privado). Ao publicar, a Monira gera
uma versão JPEG até 1600 px, sem metadados (incluindo GPS), em `monira-public`.
Fotos HEIC não são lidas pelo servidor; o formulário pede `image/*` para o iPhone
converter para JPEG ao escolher.

## Poder editorial (005)
Correr `src/data/migrations/005_editorial.sql`. Sem mais configuração.

## Conversa (006)
1. Correr `src/data/migrations/006_conversa.sql`.
2. (Opcional) Contactos da Uja para "Continuar no WhatsApp · Ligar" dentro da conversa:
   `update monira_ujas set whatsapp = '+244 934 285 368', phone = '+244 934 285 368' where slug = 'hot7-store';`
3. Para testar o lado de quem compra é precisa **outra conta** (quem vende não conversa consigo próprio).
   O email gratuito do Supabase só entrega a membros da organização: convidar o segundo email em
   Organization → Team → Invite, ou configurar SMTP próprio.

Privacidade: nem a Monira (admin) lê conversas entre clientes e Ujas.

## Minha Uja (007)
Correr `src/data/migrations/007_minha_uja.sql`. Quem vende passa a gerir em `/painel/uja`:
aberta/fechada, levantamento (morada + referência), entrega (zonas com preço) e contactos
(com "Mostrar WhatsApp" e "Permitir chamadas" separados). A apresentação continua da Monira.
