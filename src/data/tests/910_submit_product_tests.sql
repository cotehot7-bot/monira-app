\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— ADICIONAR PRODUTO'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 envia foto para a sua pasta:     '||t_try($q$INSERT INTO storage.objects(bucket_id,name) VALUES ('monira-raw','20000000-0000-0000-0000-000000000001/a.jpg')$q$);
SELECT '  hot7 envia foto para pasta de outro:  '||t_try($q$INSERT INTO storage.objects(bucket_id,name) VALUES ('monira-raw','20000000-0000-0000-0000-000000000002/a.jpg')$q$);
SELECT '  hot7 envia foto sem pasta:            '||t_try($q$INSERT INTO storage.objects(bucket_id,name) VALUES ('monira-raw','a.jpg')$q$);
SELECT '  submete Galaxy Buds (opções c/ repet.):'||t_try($q$SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','galaxy buds3 pro','caixa fechada',ARRAY['20000000-0000-0000-0000-000000000001/a.jpg'],90000,ARRAY[' Preto','Branco','Preto ','',NULL])$q$);
SELECT '  foto de outra pasta:                  '||t_try($q$SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','x',null,ARRAY['20000000-0000-0000-0000-000000000002/a.jpg'],1,null)$q$);
SELECT '  sem fotos:                            '||t_try($q$SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','x',null,ARRAY[]::text[],1,null)$q$);
SELECT '  preço zero:                           '||t_try($q$SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','x',null,ARRAY['20000000-0000-0000-0000-000000000001/a.jpg'],0,null)$q$);
SELECT '  na Uja de outro vendedor:             '||t_try($q$SELECT monira_submit_product('20000000-0000-0000-0000-000000000002','x',null,ARRAY['20000000-0000-0000-0000-000000000002/a.jpg'],1,null)$q$);
RESET ROLE;
SELECT '  → '||p.raw_name||' · '||p.price_kz||' Kz · público: '||(p.admin_reviewed)||' · opções: '||string_agg(o.name, ', ' ORDER BY o.position)
  FROM monira_products p JOIN monira_product_options o ON o.product_id=p.id WHERE p.raw_name='galaxy buds3 pro' GROUP BY p.raw_name,p.price_kz,p.admin_reviewed;
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  anónimo vê o produto novo:            '||(SELECT count(*) FROM monira_public_products WHERE id IN (SELECT id FROM monira_public_products))||' (esperado 1: só o iPhone revisto)';
SELECT '  anónimo chama submit:                 '||t_try($q$SELECT monira_submit_product('20000000-0000-0000-0000-000000000001','x',null,ARRAY['20000000-0000-0000-0000-000000000001/a.jpg'],1,null)$q$);
RESET ROLE;
