\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— AVISOS'
UPDATE auth.users SET email = 'hot7@exemplo.com' WHERE id = '00000000-0000-0000-0000-00000000000a';
UPDATE auth.users SET email = 'cliente@exemplo.com' WHERE id = '00000000-0000-0000-0000-00000000000b';
INSERT INTO monira_admins(user_id) VALUES ('00000000-0000-0000-0000-00000000000c') ON CONFLICT DO NOTHING;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
INSERT INTO monira_conversations(uja_id,customer_id,product_id) VALUES ('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001') ON CONFLICT DO NOTHING;
INSERT INTO monira_messages(conversation_id,sender_user_id,body) SELECT id,'00000000-0000-0000-0000-00000000000b','Olá' FROM monira_conversations LIMIT 1 RETURNING id AS m1 \gset
SELECT '  cliente escreve "Olá":                '||coalesce((SELECT email||' · '||product_name||' · '||body FROM monira_message_notification(:'m1')),'sem aviso');
INSERT INTO monira_messages(conversation_id,sender_user_id,body) SELECT id,'00000000-0000-0000-0000-00000000000b','Tem disponível?' FROM monira_conversations LIMIT 1 RETURNING id AS m2 \gset
SELECT '  segundos depois "Tem disponível?":    '||coalesce((SELECT email FROM monira_message_notification(:'m2')),'sem aviso (anti-cascata)');
SELECT '  pede aviso de mensagem alheia:        '||coalesce((SELECT email FROM monira_message_notification(:'m1')),'sem aviso');
SELECT '  cliente pede aviso de publicação:     '||coalesce((SELECT email FROM monira_product_notification('30000000-0000-0000-0000-000000000001','product_published')),'sem aviso');
SELECT '  cliente lê o diário:                  '||t_try($q$SELECT * FROM monira_notification_log$q$);
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
INSERT INTO monira_messages(conversation_id,sender_user_id,body) SELECT id,'00000000-0000-0000-0000-00000000000a','Sim, temos.' FROM monira_conversations LIMIT 1 RETURNING id AS m3 \gset
SELECT '  a loja responde (aviso à loja?):      '||coalesce((SELECT email FROM monira_message_notification(:'m3')),'sem aviso (mensagem da própria loja)');
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  Monira publica → aviso:               '||(SELECT email||' · '||product_name FROM monira_product_notification('30000000-0000-0000-0000-000000000001','product_published'));
SELECT monira_admin_request_changes('30000000-0000-0000-0000-000000000001','Envia uma foto com fundo claro.');
SELECT '  Monira pede alterações → aviso:       '||(SELECT email||' · '||note FROM monira_product_notification('30000000-0000-0000-0000-000000000001','product_changes'));
RESET ROLE;
-- "mais tarde" para testar o fim da janela de 10 min
UPDATE monira_notification_log SET sent_at = now() - interval '11 minutes' WHERE kind='message';
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000b');
INSERT INTO monira_messages(conversation_id,sender_user_id,body) SELECT id,'00000000-0000-0000-0000-00000000000b','Preciso hoje' FROM monira_conversations LIMIT 1 RETURNING id AS m4 \gset
SELECT '  11 min depois "Preciso hoje":         '||coalesce((SELECT email||' · '||body FROM monira_message_notification(:'m4')),'sem aviso');
RESET ROLE;
SELECT '  → diário: '||string_agg(kind, ', ' ORDER BY sent_at) FROM monira_notification_log;
