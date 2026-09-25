\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— NOVAS LOJAS'
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-00000000000e');
INSERT INTO monira_admins(user_id) VALUES ('00000000-0000-0000-0000-00000000000c') ON CONFLICT DO NOTHING;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000e');
SELECT '  candidata-se já aprovada (insert):    '||t_try($q$INSERT INTO monira_applications(user_id,name,phone,status) VALUES ('00000000-0000-0000-0000-00000000000e','X','923000000','aprovado')$q$);
SELECT '  nome curto:                           '||t_try($q$SELECT monira_submit_application('X','923000000','roupa',null,'Luanda')$q$);
SELECT '  telefone inválido:                    '||t_try($q$SELECT monira_submit_application('Nádia Studio','abc','roupa',null,'Luanda')$q$);
SELECT '  pede para vender:                     '||t_try(format($q$SELECT monira_submit_application('Nádia Studio','+244 923 000 000','Vestidos e fatos feitos à medida.',%L,'Talatona')$q$,(SELECT id FROM monira_avenues WHERE slug='estilo')));
SELECT '  pede outra vez (já em análise):       '||t_try($q$SELECT monira_submit_application('Nádia Studio','923000000','x',null,null)$q$);
SELECT '  vê o próprio pedido:                  '||status FROM monira_applications WHERE user_id='00000000-0000-0000-0000-00000000000e';
SELECT '  tenta aprovar-se:                     '||t_try($q$SELECT monira_admin_approve_application((SELECT id FROM monira_applications LIMIT 1),'Nádia',(SELECT id FROM monira_avenues LIMIT 1),true)$q$);
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 (já vende) pede outra loja:      '||t_try($q$SELECT monira_submit_application('Segunda loja','923000000','x',null,null)$q$);
SELECT '  hot7 vê pedidos alheios:              '||(SELECT count(*) FROM monira_applications)||' (esperado 0)';
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  Monira vê pedidos:                    '||(SELECT count(*) FROM monira_applications WHERE status='pendente');
SELECT '  Monira recusa sem nota:               '||t_try($q$SELECT monira_admin_reject_application((SELECT id FROM monira_applications WHERE status='pendente' LIMIT 1),' ')$q$);
SELECT '  Monira recusa com nota:               '||t_try($q$SELECT monira_admin_reject_application((SELECT id FROM monira_applications WHERE status='pendente' LIMIT 1),'Envia fotos dos teus produtos no WhatsApp.')$q$);
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000e');
SELECT '  quem pediu vê a nota:                 '||decision_note FROM monira_applications WHERE status='rejeitado';
SELECT '  pede de novo depois de recusado:      '||t_try(format($q$SELECT monira_submit_application('Nádia Studio','+244 923 000 000','Vestidos, fatos e acessórios.',%L,'Talatona')$q$,(SELECT id FROM monira_avenues WHERE slug='estilo')));
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  Monira aprova:                        '||monira_admin_approve_application((SELECT id FROM monira_applications WHERE status='pendente' LIMIT 1),'Nádia Studio',(SELECT id FROM monira_avenues WHERE slug='estilo'),true);
SELECT '  aprovar outra vez:                    '||t_try($q$SELECT monira_admin_approve_application((SELECT id FROM monira_applications WHERE status='aprovado' LIMIT 1),'X',(SELECT id FROM monira_avenues LIMIT 1),false)$q$);
RESET ROLE;
SELECT '  → Uja criada: '||u.name||' · /uja/'||u.slug||' · aberta='||u.is_open||' · estado='||u.status||' · verificada='||v.verified FROM monira_ujas u JOIN monira_vendors v ON v.id=u.vendor_id WHERE v.user_id='00000000-0000-0000-0000-00000000000e';
SELECT '  → slug sem repetir: '||monira_unique_slug('hot7 store','monira_ujas')||', '||monira_unique_slug('Açaí & Ção!','monira_ujas');
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000e');
SELECT '  nova loja submete produto:            '||t_try($q$SELECT monira_submit_product((SELECT id FROM monira_ujas WHERE slug='nadia-studio'),'vestido azul',null,ARRAY[(SELECT id FROM monira_ujas WHERE slug='nadia-studio')::text||'/v.jpg'],45000,null)$q$);
RESET ROLE;
