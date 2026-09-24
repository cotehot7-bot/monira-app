\set QUIET on
\pset tuples_only on
\pset format unaligned
CREATE FUNCTION t_try(q text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE n int; BEGIN EXECUTE q; GET DIAGNOSTICS n = ROW_COUNT; RETURN 'ok ('||n||' rows)';
EXCEPTION WHEN others THEN RETURN 'BLOQUEADO: '||sqlerrm; END $$;
GRANT EXECUTE ON FUNCTION t_try(text) TO anon, authenticated, service_role;
CREATE FUNCTION t_as(r text, uid text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN PERFORM set_config('request.jwt.claim.sub', coalesce(uid,''), false); END $$;
GRANT EXECUTE ON FUNCTION t_as(text,text) TO anon, authenticated, service_role;

-- Dados: hot7 (quem vende), cliente, outro vendedor
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-00000000000a'),('00000000-0000-0000-0000-00000000000b'),('00000000-0000-0000-0000-00000000000c');
INSERT INTO monira_vendors(id,user_id,name,slug,phone,whatsapp,verified) VALUES
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a','hot7','hot7','9','9',true),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-00000000000c','outro','outro','9','9',false);
INSERT INTO monira_ujas(id,vendor_id,name,slug,avenue_id,status,pickup_enabled,pickup_address) VALUES
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','hot7 store','hot7-store',(SELECT id FROM monira_avenues WHERE slug='tech'),'active',true,'Loja hot7'),
 ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Outra','outra',(SELECT id FROM monira_avenues WHERE slug='tech'),'active',false,null);
INSERT INTO monira_products(id,uja_id,raw_name,price_kz,stock,name,admin_reviewed,needs_review) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','iphone 17 pro max caixa fechada',1120000,3,'iPhone 17 Pro Max',true,false),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','buds',90000,5,null,false,true);
INSERT INTO monira_product_options(id,product_id,name) VALUES ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Azul'),('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','Laranja');
INSERT INTO monira_uja_delivery_zones(id,uja_id,name,fee_kz) VALUES ('50000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Talatona',5000);
INSERT INTO monira_buyers(id,user_id,phone) VALUES ('60000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000b','923000000');
INSERT INTO monira_merchant_accounts(id,vendor_id,provider,status) VALUES ('70000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','provider_x','active');

\echo '— ANÓNIMO'
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  lê tabela de produtos (raw_*):        '||t_try('SELECT * FROM monira_products');
SELECT '  vê produtos publicados na vista:      '||(SELECT count(*) FROM monira_public_products)||' (esperado 1: só o revisto)';
SELECT '  vê Ujas públicas:                     '||(SELECT count(*) FROM monira_public_ujas);
SELECT '  vê zona Talatona:                     '||(SELECT count(*) FROM monira_uja_delivery_zones);
RESET ROLE;

\echo '— CLIENTE'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT '  insere pedido com preço à escolha:    '||t_try($q$INSERT INTO monira_orders(order_number,product_id,uja_id,buyer_id,price_kz,total_kz) VALUES ('X','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001',1,1)$q$);
SELECT '  chama place_order directamente:       '||t_try($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',null,1,'pickup',null,null)$q$);
SELECT '  inicia conversa c/ id escolhido:      '||t_try($q$INSERT INTO monira_conversations(id,uja_id,customer_id) VALUES (gen_random_uuid(),'20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001')$q$);
SELECT '  inicia conversa sobre o iPhone:       '||t_try($q$INSERT INTO monira_conversations(uja_id,customer_id,product_id) VALUES ('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001')$q$);
SELECT '  envia "Conseguem entregar no Talatona?": '||t_try($q$INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES ((SELECT id FROM monira_conversations LIMIT 1),'00000000-0000-0000-0000-00000000000b','Conseguem entregar no Talatona?')$q$);
SELECT '  envia mensagem em nome da hot7:       '||t_try($q$INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES ((SELECT id FROM monira_conversations LIMIT 1),'00000000-0000-0000-0000-00000000000a','Sim')$q$);
SELECT '  conversa sobre produto não publicado: '||t_try($q$INSERT INTO monira_conversations(uja_id,customer_id,product_id) VALUES ('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002')$q$);
RESET ROLE;

\echo '— HOT7 (quem vende)'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  responde "Sim. Fazemos entrega…":     '||t_try($q$INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES ((SELECT id FROM monira_conversations LIMIT 1),'00000000-0000-0000-0000-00000000000a','Sim. Fazemos entrega no Talatona.')$q$);
SELECT '  vê as mensagens da conversa:          '||(SELECT count(*) FROM monira_messages)||' (esperado 2)';
SELECT '  abre a Uja (is_open):                 '||t_try($q$UPDATE monira_ujas SET is_open=true WHERE id='20000000-0000-0000-0000-000000000001'$q$);
SELECT '  muda o estado da Uja (curadoria):     '||t_try($q$UPDATE monira_ujas SET status='draft' WHERE id='20000000-0000-0000-0000-000000000001'$q$);
SELECT '  marca-se como verificado:             '||t_try($q$UPDATE monira_vendors SET verified=true, plan='premium'$q$);
SELECT '  edita o título apresentado:           '||t_try($q$UPDATE monira_products SET name='SUPER PROMO' WHERE id='30000000-0000-0000-0000-000000000001'$q$);
SELECT '  edita o texto bruto:                  '||t_try($q$UPDATE monira_products SET raw_name='iphone 17 pro max novo' WHERE id='30000000-0000-0000-0000-000000000001'$q$);
SELECT '  cria zona Kilamba 7.000 Kz:           '||t_try($q$INSERT INTO monira_uja_delivery_zones(uja_id,name,fee_kz) VALUES ('20000000-0000-0000-0000-000000000001','Kilamba',7000)$q$);
SELECT '  cria zona na Uja de outro:            '||t_try($q$INSERT INTO monira_uja_delivery_zones(uja_id,name,fee_kz) VALUES ('20000000-0000-0000-0000-000000000002','Talatona',1)$q$);
RESET ROLE;
SELECT '  → needs_review depois do texto bruto: '||needs_review||' · título continua: '||name FROM monira_products WHERE id='30000000-0000-0000-0000-000000000001';

\echo '— SERVIDOR: compra'
SET ROLE service_role;
SELECT '  sem escolher cor:                     '||t_try($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',null,1,'delivery','50000000-0000-0000-0000-000000000001','Rua X')$q$);
SELECT '  zona de outra Uja / inexistente:      '||t_try($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',1,'delivery','50000000-0000-0000-0000-000000000009','Rua X')$q$);
SELECT '  produto não revisto:                  '||t_try($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002',null,1,'pickup',null,null)$q$);
SELECT '  pedido válido (Azul, Talatona):       '||t_try($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',1,'delivery','50000000-0000-0000-0000-000000000001','Talatona, rua X')$q$);
SELECT '  → '||order_number||' · '||option_name||' · preço '||price_kz||' + entrega '||delivery_fee_kz||' = total '||total_kz||' · estado '||status FROM monira_orders;
SELECT '  → conversa ligada ao pedido:          '||(order_id IS NOT NULL) FROM monira_conversations;
RESET ROLE;

\echo '— HOT7 tenta sair para entrega antes do pagamento'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  advance_order:                        '||t_try($q$SELECT monira_advance_order((SELECT id FROM monira_orders LIMIT 1))$q$);
SELECT '  estado de pagamento visto:            '||payment_state FROM monira_order_payment_state;
RESET ROLE;

\echo '— SERVIDOR: pagamento'
SET ROLE service_role;
SELECT '  pedido de pagamento:                  '||t_try($q$SELECT monira_create_payment_request((SELECT id FROM monira_orders LIMIT 1),'provider_x','923000000')$q$);
SELECT '  segundo pedido em aberto:             '||t_try($q$SELECT monira_create_payment_request((SELECT id FROM monira_orders LIMIT 1),'provider_x','923000000')$q$);
UPDATE monira_payment_requests SET external_ref='EXT-1';
SELECT '  → valor pedido ao cliente:            '||amount_kz FROM monira_payment_requests;
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 vê estado:                       '||payment_state||' (disparado ≠ pago)' FROM monira_order_payment_state;
SELECT '  hot7 tenta confirmar o pagamento:     '||t_try($q$UPDATE monira_payment_requests SET status='confirmed'$q$);
SELECT '  hot7 chama o callback:                '||t_try($q$SELECT monira_record_payment_confirmation('provider_x','EXT-1',1125000,'{}')$q$);
RESET ROLE;
SET ROLE service_role;
SELECT '  callback com valor errado (1.000 Kz): '||monira_record_payment_confirmation('provider_x','EXT-1',1000,'{}');
RESET ROLE;
-- limpar para testar o caminho válido com nova referência
DELETE FROM monira_payment_confirmations; UPDATE monira_payment_requests SET external_ref='EXT-2';
SET ROLE service_role;
SELECT '  callback com valor certo:             '||monira_record_payment_confirmation('provider_x','EXT-2',1125000,'{"ok":true}');
SELECT '  mesmo callback repetido:              '||monira_record_payment_confirmation('provider_x','EXT-2',1125000,'{"ok":true}');
SELECT '  → stock do iPhone: 3 → '||stock FROM monira_products WHERE id='30000000-0000-0000-0000-000000000001';
RESET ROLE;

\echo '— OUTRO VENDEDOR'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  vê pedidos da hot7:                   '||(SELECT count(*) FROM monira_orders)||' (esperado 0)';
SELECT '  vê a conversa da hot7:                '||(SELECT count(*) FROM monira_messages)||' (esperado 0)';
SELECT '  avança pedido da hot7:                '||t_try($q$SELECT monira_advance_order((SELECT id FROM monira_orders LIMIT 1))$q$);
RESET ROLE;

\echo '— HOT7: entrega'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  estado de pagamento:                  '||payment_state FROM monira_order_payment_state;
SELECT '  Começar entrega:                      '||(monira_advance_order((SELECT id FROM monira_orders LIMIT 1))).status;
SELECT '  Marcar como entregue:                 '||(monira_advance_order((SELECT id FROM monira_orders LIMIT 1))).status;
SELECT '  avançar outra vez:                    '||t_try($q$SELECT monira_advance_order((SELECT id FROM monira_orders LIMIT 1))$q$);
RESET ROLE;

\echo '— AVALIAÇÕES'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  outro avalia pedido alheio:           '||t_try($q$INSERT INTO monira_reviews(order_id,from_user_id,to_user_id,rating,type) VALUES ((SELECT o.id FROM monira_orders o LIMIT 1),'00000000-0000-0000-0000-00000000000c','00000000-0000-0000-0000-00000000000a',1,'visitante_avalia_morador')$q$);
SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT '  cliente avalia pedido concluído:      '||t_try($q$INSERT INTO monira_reviews(order_id,from_user_id,to_user_id,rating,type) VALUES ((SELECT o.id FROM monira_orders o LIMIT 1),'00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000a',5,'visitante_avalia_morador')$q$);
RESET ROLE;
