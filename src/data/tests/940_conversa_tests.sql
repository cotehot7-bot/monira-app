\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— CONVERSA'
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 conversa com a própria Uja:      '||t_try($q$SELECT monira_start_conversation('30000000-0000-0000-0000-000000000001')$q$);
RESET ROLE;
-- novo cliente, sem linha em monira_buyers
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-00000000000d');
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000d');
SELECT '  cliente novo, produto não publicado:  '||t_try($q$SELECT monira_start_conversation('30000000-0000-0000-0000-000000000002')$q$);
SELECT monira_start_conversation('30000000-0000-0000-0000-000000000001') AS conv \gset
SELECT '  cliente novo abre conversa:           ok ('||(:'conv' IS NOT NULL)||')';
SELECT '  abre outra vez (mesma conversa):      '||(monira_start_conversation('30000000-0000-0000-0000-000000000001') = :'conv');
SELECT '  cliente pergunta:                     '||t_try(format($q$INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES (%L,'00000000-0000-0000-0000-00000000000d','Conseguem entregar no Talatona?')$q$, :'conv'));
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  hot7 vê a conversa:                   '||count(*) FROM monira_conversations WHERE id = :'conv';
SELECT '  hot7 responde:                        '||t_try(format($q$INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES (%L,'00000000-0000-0000-0000-00000000000a','Sim. Fazemos entrega no Talatona.')$q$, :'conv'));
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000c');
SELECT '  admin (não participante) lê:          '||(SELECT count(*) FROM monira_messages WHERE conversation_id = :'conv')||' mensagens (esperado 0)';
SELECT '  admin escreve na conversa:            '||t_try(format($q$INSERT INTO monira_messages(conversation_id,sender_user_id,body) VALUES (%L,'00000000-0000-0000-0000-00000000000c','x')$q$, :'conv'));
RESET ROLE;
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  anónimo abre conversa:                '||t_try($q$SELECT monira_start_conversation('30000000-0000-0000-0000-000000000001')$q$);
RESET ROLE;
SELECT '  → conversa: '||string_agg(body, ' / ' ORDER BY created_at) FROM monira_messages WHERE conversation_id = :'conv';
SELECT '  → last_message_at preenchido:         '||(last_message_at IS NOT NULL) FROM monira_conversations WHERE id = :'conv';
