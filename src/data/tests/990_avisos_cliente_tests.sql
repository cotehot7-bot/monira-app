\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— AVISOS AO CLIENTE'
UPDATE auth.users SET email='hot7@exemplo.com' WHERE id='00000000-0000-0000-0000-00000000000a';
UPDATE auth.users SET email='cliente@exemplo.com' WHERE id='00000000-0000-0000-0000-00000000000b';
-- conversa cliente (b) ↔ hot7 (a)
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT monira_start_conversation('30000000-0000-0000-0000-000000000001') AS conv \gset
INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES (:'conv','00000000-0000-0000-0000-00000000000b','Tem disponível?') RETURNING id AS mc \gset
SELECT '  cliente pede aviso de resposta (sua): '||coalesce((SELECT email FROM monira_reply_notification(:'mc')),'sem aviso (mensagem do próprio cliente)');
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES (:'conv','00000000-0000-0000-0000-00000000000a','Sim, temos disponível para entrega.') RETURNING id AS ms \gset
SELECT '  a loja responde:                      '||coalesce((SELECT email||' · '||uja_name||' · '||product_name||' · '||body FROM monira_reply_notification(:'ms')),'sem aviso');
INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES (:'conv','00000000-0000-0000-0000-00000000000a','Entregamos amanhã.') RETURNING id AS ms2 \gset
SELECT '  segunda resposta logo a seguir:       '||coalesce((SELECT email FROM monira_reply_notification(:'ms2')),'sem aviso (anti-cascata)');
SELECT '  aviso à loja pela própria resposta:   '||coalesce((SELECT email FROM monira_message_notification(:'ms')),'sem aviso');
-- pedido
SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"is_open":true,"pickup_enabled":true,"pickup_address":"Benfica","delivery_enabled":true,"accepts_pay_on_delivery":true,"accepts_pay_on_pickup":true}','[{"name":"Luanda","fee_kz":3000}]');
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
SELECT (monira_create_order('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','delivery',(SELECT id FROM monira_uja_delivery_zones WHERE name='Luanda'),'Rua X','923000000','on_delivery')).id AS o \gset
SELECT '  cliente pede aviso "a caminho":       '||coalesce((SELECT email FROM monira_order_status_notification(:'o','order_delivering')),'sem aviso');
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  "a caminho" antes da transição:       '||coalesce((SELECT email FROM monira_order_status_notification(:'o','order_delivering')),'sem aviso (ainda não saiu)');
SELECT (monira_advance_order(:'o')).status AS st \gset
SELECT '  depois de Começar entrega:            '||coalesce((SELECT email||' · '||order_number||' · '||product_name||' · '||uja_name FROM monira_order_status_notification(:'o','order_delivering')),'sem aviso');
SELECT '  a mesma transição outra vez:          '||coalesce((SELECT email FROM monira_order_status_notification(:'o','order_delivering')),'sem aviso (já enviado)');
SELECT (monira_cancel_order(:'o','Sem stock do tamanho pedido.')).status AS st2 \gset
SELECT '  cancelado:                            '||coalesce((SELECT email||' · '||reason FROM monira_order_status_notification(:'o','order_cancelled')),'sem aviso');
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  outra conta abre o pedido do cliente: '||(SELECT count(*) FROM monira_orders WHERE id=:'o')||' linhas (esperado 0)';
SELECT '  outra conta abre a conversa:          '||(SELECT count(*) FROM monira_messages WHERE conversation_id=:'conv')||' mensagens (esperado 0)';
RESET ROLE;
