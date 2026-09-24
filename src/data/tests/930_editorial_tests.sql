\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— PODER EDITORIAL'
-- admin = utilizador c; hot7 = a
INSERT INTO monira_admins(user_id) VALUES ('00000000-0000-0000-0000-00000000000c') ON CONFLICT DO NOTHING;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','buds foto escura',null,ARRAY['20000000-0000-0000-0000-000000000001/b.jpg'],250000,ARRAY['Preto']) AS buds \gset
SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','duplicado',null,ARRAY['20000000-0000-0000-0000-000000000001/d.jpg'],1,null) AS dup \gset
SELECT '  hot7 tenta corrigir sem pedido:       '||t_try(format($q$SELECT monira_resubmit_product(%L,'x',null,ARRAY['20000000-0000-0000-0000-000000000001/b.jpg'],1,null)$q$, :'buds'));
SELECT '  hot7 tenta pedir alterações:          '||t_try(format($q$SELECT monira_admin_request_changes(%L,'x')$q$, :'buds'));
SELECT '  hot7 tenta apagar:                    '||t_try(format($q$SELECT monira_admin_delete_product(%L)$q$, :'dup'));
RESET ROLE;

SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  Monira pede alterações sem nota:      '||t_try(format($q$SELECT monira_admin_request_changes(%L,'  ')$q$, :'buds'));
SELECT '  Monira pede alterações:               '||t_try(format($q$SELECT monira_admin_request_changes(%L,'A fotografia está escura. Envia outra com luz natural.')$q$, :'buds'));
SELECT '  Monira apaga o duplicado:             '||t_try(format($q$SELECT monira_admin_delete_product(%L)$q$, :'dup'));
SELECT '  Monira apaga um publicado:            '||t_try($q$SELECT monira_admin_delete_product('30000000-0000-0000-0000-000000000001')$q$);
SELECT '  → histórico dos Buds:                 '||string_agg(decision||coalesce(' ('||note||')',''), ' | ' ORDER BY created_at) FROM monira_product_decisions WHERE product_id = :'buds';
RESET ROLE;
SELECT '  → duplicado existe?                   '||count(*) FROM monira_products WHERE id = :'dup';

SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 vê o pedido:                     '||attention_note FROM monira_products WHERE id = :'buds';
SELECT '  hot7 lê o histórico:                  '||(SELECT count(*) FROM monira_product_decisions)||' linhas (esperado 0)';
SELECT '  hot7 corrige com foto de outra Uja:   '||t_try(format($q$SELECT monira_resubmit_product(%L,'Galaxy Buds3 Pro',null,ARRAY['20000000-0000-0000-0000-000000000002/x.jpg'],250000,null)$q$, :'buds'));
SELECT '  hot7 corrige e envia de novo:         '||t_try(format($q$SELECT monira_resubmit_product(%L,'Galaxy Buds3 Pro','caixa fechada',ARRAY['20000000-0000-0000-0000-000000000001/b2.jpg'],240000,ARRAY['Preto','Branco'])$q$, :'buds'));
SELECT '  → estado: pedido='||coalesce(attention_note,'nenhum')||' · needs_review='||needs_review||' · preço='||price_kz FROM monira_products WHERE id = :'buds';
SELECT '  → opções: '||string_agg(name, ', ' ORDER BY position) FROM monira_product_options WHERE product_id = :'buds';
SELECT '  corrigir outra vez (já respondido):   '||t_try(format($q$SELECT monira_resubmit_product(%L,'x',null,ARRAY['20000000-0000-0000-0000-000000000001/b.jpg'],1,null)$q$, :'buds'));
SELECT '  outro vendedor corrige os Buds:       '||'ver abaixo';
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
-- c é admin mas NÃO é dono: não pode usar a função de quem vende
SELECT '  admin usa resubmit em Uja alheia:     '||t_try(format($q$SELECT monira_resubmit_product(%L,'x',null,ARRAY['20000000-0000-0000-0000-000000000001/b.jpg'],1,null)$q$, :'buds'));
SELECT '  → histórico dos Buds:                 '||string_agg(decision, ' → ' ORDER BY created_at) FROM monira_product_decisions WHERE product_id = :'buds';
SELECT '  Monira publica:                       '||t_try(format($q$SELECT monira_admin_publish_product(%L,'Galaxy Buds3 Pro','Caixa fechada.',ARRAY[%L])$q$, :'buds', 'products/'||:'buds'||'/1.jpg'));
SELECT '  → histórico final:                    '||string_agg(decision, ' → ' ORDER BY created_at) FROM monira_product_decisions WHERE product_id = :'buds';
RESET ROLE;
