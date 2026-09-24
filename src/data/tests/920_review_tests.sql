\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— REVISÃO'
-- a hot7 submete um produto; o cliente (b) passa a ser admin para o teste
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','iphone teste','texto bruto',ARRAY['20000000-0000-0000-0000-000000000001/x.jpg'],1750000,ARRAY['Azul']) \gset
RESET ROLE;
INSERT INTO monira_admins(user_id) VALUES ('00000000-0000-0000-0000-00000000000c');
INSERT INTO storage.objects(bucket_id,name) VALUES ('monira-raw','20000000-0000-0000-0000-000000000001/x.jpg');

SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT '  não-admin: é admin?                   '||monira_is_admin();
SELECT '  não-admin vê produtos por rever:      '||(SELECT count(*) FROM monira_products WHERE NOT admin_reviewed);
SELECT '  não-admin publica:                    '||t_try($q$SELECT monira_admin_publish_product((SELECT id FROM monira_products WHERE raw_name='iphone teste'),'X',null,ARRAY['products/x/1.jpg'])$q$);
SELECT '  não-admin lê foto bruta:              '||(SELECT count(*) FROM storage.objects WHERE bucket_id='monira-raw');
SELECT '  não-admin escreve em monira-public:   '||t_try($q$INSERT INTO storage.objects(bucket_id,name) VALUES ('monira-public','products/x/1.jpg')$q$);
SELECT '  não-admin lê a tabela de admins:      '||t_try($q$SELECT * FROM monira_admins$q$);
RESET ROLE;

SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  admin: é admin?                       '||monira_is_admin();
SELECT '  admin vê produtos por rever:          '||(SELECT count(*) FROM monira_products WHERE NOT admin_reviewed);
SELECT '  admin lê foto bruta:                  '||(SELECT count(*) FROM storage.objects WHERE bucket_id='monira-raw');
SELECT '  admin escreve em monira-public:       '||t_try($q$INSERT INTO storage.objects(bucket_id,name) VALUES ('monira-public','products/p/1.jpg')$q$);
SELECT '  admin publica com foto fora da pasta: '||t_try($q$SELECT monira_admin_publish_product((SELECT id FROM monira_products WHERE raw_name='iphone teste'),'iPhone',null,ARRAY['products/outro/1.jpg'])$q$);
SELECT '  admin publica:                        '||t_try(format($q$SELECT monira_admin_publish_product(%L,'iPhone 17 Pro Max','Caixa fechada.',ARRAY[%L])$q$, (SELECT id FROM monira_products WHERE raw_name='iphone teste'), 'products/'||(SELECT id FROM monira_products WHERE raw_name='iphone teste')||'/1.jpg'));
RESET ROLE;

SET ROLE anon; SELECT t_as('anon',null);
SELECT '  anónimo vê agora:                     '||string_agg(name||' ('||price_kz||' Kz)', ', ') FROM monira_public_products;
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 muda o texto bruto depois:       '||t_try($q$UPDATE monira_products SET raw_description='outro texto' WHERE raw_name='iphone teste'$q$);
RESET ROLE;
SELECT '  → continua público, marcado p/ rever: '||admin_reviewed||' / needs_review '||needs_review FROM monira_products WHERE raw_name='iphone teste';
