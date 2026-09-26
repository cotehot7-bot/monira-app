\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— COMPRAR (pagamento offline)'
-- hot7 (a) prepara a Uja: aberta, entrega com uma zona, aceita pagar na entrega e no levantamento
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 guarda funcionamento:            '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001',
 '{"is_open":true,"pickup_enabled":true,"pickup_address":"Benfica","delivery_enabled":true,"accepts_pay_on_delivery":true,"accepts_pay_on_pickup":true}',
 '[{"name":"Luanda e arredores","fee_kz":3000}]')$q$);
SELECT '  hot7 compra na própria Uja:           '||t_try($q$SELECT monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','pickup',null,null,'923000000','on_pickup')$q$);
RESET ROLE;
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  público vê pay_on_delivery/pickup:    '||pay_on_delivery||'/'||pay_on_pickup FROM monira_public_ujas WHERE slug='hot7-store';
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT '  sem telefone:                         '||t_try($q$SELECT monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','pickup',null,null,'','on_pickup')$q$);
SELECT '  pagamento online (ainda não):         '||t_try($q$SELECT monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','pickup',null,null,'923000000','online')$q$);
SELECT '  pagar na entrega mas levantar:        '||t_try($q$SELECT monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','pickup',null,null,'923000000','on_delivery')$q$);
SELECT (monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','delivery',
   (SELECT id FROM monira_uja_delivery_zones WHERE name='Luanda e arredores'),'Talatona, rua X','+244 923 000 000','on_delivery')).id AS d \gset
SELECT '  pedido com entrega:                   '||order_number||' · '||price_kz||' + '||delivery_fee_kz||' = '||total_kz||' · '||payment_method||' · '||status FROM monira_orders WHERE id=:'d';
SELECT '  aviso à loja (1ª vez):                '||coalesce((SELECT email||' · '||order_number||' · '||payment_method FROM monira_order_notification(:'d')),'sem aviso');
SELECT '  aviso à loja (2ª vez):                '||coalesce((SELECT email FROM monira_order_notification(:'d')),'sem aviso (já enviado)');
SELECT '  estado de pagamento (cliente vê):     '||payment_state FROM monira_order_payment_state WHERE order_id=:'d';
SELECT (monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','pickup',null,null,'923000000','on_pickup')).id AS p \gset
SELECT '  pedido com levantamento:              '||total_kz||' · '||payment_method FROM monira_orders WHERE id=:'p';
SELECT '  cliente tenta concluir o próprio:     '||t_try(format($q$SELECT monira_complete_offline_order(%L,'cash')$q$, :'d'));
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 vê o telefone do cliente:        '||customer_phone FROM monira_orders WHERE id=:'d';
SELECT '  entregue e pago sem sair (entrega):   '||t_try(format($q$SELECT monira_complete_offline_order(%L,'cash')$q$, :'d'));
SELECT '  começar entrega (sem pagamento):      '||(monira_advance_order(:'d')).status;
SELECT '  "avançar" em vez de entregue e pago:  '||t_try(format($q$SELECT monira_advance_order(%L)$q$, :'d'));
SELECT '  meio inválido:                        '||t_try(format($q$SELECT monira_complete_offline_order(%L,'cheque')$q$, :'d'));
SELECT '  entregue e pago (TPA):                '||(monira_complete_offline_order(:'d','tpa')).status;
SELECT '  levantado e pago (dinheiro):          '||(monira_complete_offline_order(:'p','cash')).status;
SELECT '  cancelar um concluído:                '||t_try(format($q$SELECT monira_cancel_order(%L,'x')$q$, :'p'));
RESET ROLE;
SELECT '  → estados: '||string_agg(o.order_number||'='||s.payment_state, ', ' ORDER BY o.order_number) FROM monira_orders o JOIN monira_order_payment_state s ON s.order_id=o.id WHERE o.payment_method IS NOT NULL;
SELECT '  → pagamentos declarados: '||string_agg(method||' '||amount_kz, ', ') FROM monira_offline_payments;
-- cancelar pedido de cliente que não aparece
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT (monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','pickup',null,null,'923000000','on_pickup')).id AS c \gset
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  cancelar sem motivo:                  '||t_try(format($q$SELECT monira_cancel_order(%L,'')$q$, :'c'));
SELECT '  cancelar (não apareceu):              '||(monira_cancel_order(:'c','O cliente não apareceu.')).status;
SELECT '  fecha a Uja:                          '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"is_open":false,"pickup_enabled":true,"pickup_address":"Benfica","accepts_pay_on_pickup":true}','[]')$q$);
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT '  comprar com a Uja fechada:            '||t_try($q$SELECT monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','pickup',null,null,'923000000','on_pickup')$q$);
RESET ROLE;
