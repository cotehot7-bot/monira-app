-- MONIRA — Painel de observação da Validação v0.1 (SÓ LEITURA)
-- Muda a data na linha "desde" para o dia do primeiro convite.
WITH desde AS (SELECT timestamptz '2026-09-27 00:00+01' AS t),
equipa AS (  -- contas internas (Monira e lojas) ficam fora das contagens de clientes
  SELECT user_id FROM monira_admins UNION SELECT user_id FROM monira_vendors
),
clientes_ativos AS (
  SELECT m.sender_user_id AS uid, (m.created_at AT TIME ZONE 'Africa/Luanda')::date AS dia
  FROM monira_messages m, desde WHERE m.created_at >= desde.t AND m.sender_user_id NOT IN (SELECT user_id FROM equipa)
  UNION
  SELECT b.user_id, (o.created_at AT TIME ZONE 'Africa/Luanda')::date
  FROM monira_orders o JOIN monira_buyers b ON b.id = o.buyer_id, desde WHERE o.created_at >= desde.t
)
SELECT 1 AS n, 'Contas novas (entraram na Monira)' AS indicador,
       (SELECT count(*) FROM auth.users u, desde WHERE u.created_at >= desde.t AND u.id NOT IN (SELECT user_id FROM equipa))::text AS valor
UNION ALL SELECT 2, 'Conversas iniciadas por clientes',
       (SELECT count(*) FROM monira_conversations c JOIN monira_buyers b ON b.id = c.customer_id, desde
        WHERE c.created_at >= desde.t AND b.user_id NOT IN (SELECT user_id FROM equipa))::text
UNION ALL SELECT 3, 'Conversas em que a loja respondeu',
       (SELECT count(DISTINCT c.id) FROM monira_conversations c JOIN monira_messages m ON m.conversation_id = c.id
        JOIN monira_ujas j ON j.id = c.uja_id JOIN monira_vendors v ON v.id = j.vendor_id, desde
        WHERE c.created_at >= desde.t AND m.sender_user_id = v.user_id)::text
UNION ALL SELECT 4, 'Tempo mediano até a loja responder (min)',
       (SELECT coalesce(round(percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM r.primeira_resposta - r.primeira_msg) / 60))::text, '—')
        FROM (SELECT c.id,
                     min(m.created_at) FILTER (WHERE m.sender_user_id <> v.user_id) AS primeira_msg,
                     min(m.created_at) FILTER (WHERE m.sender_user_id = v.user_id) AS primeira_resposta
              FROM monira_conversations c JOIN monira_messages m ON m.conversation_id = c.id
              JOIN monira_ujas j ON j.id = c.uja_id JOIN monira_vendors v ON v.id = j.vendor_id, desde
              WHERE c.created_at >= desde.t GROUP BY c.id) r
        WHERE r.primeira_resposta > r.primeira_msg)
UNION ALL SELECT 5, 'Pedidos feitos',
       (SELECT count(*) FROM monira_orders o, desde WHERE o.created_at >= desde.t)::text
UNION ALL SELECT 6, 'Pedidos por estado',
       (SELECT coalesce(string_agg(status || ' ' || n, ' · '), '—') FROM
          (SELECT status, count(*) n FROM monira_orders o, desde WHERE o.created_at >= desde.t GROUP BY status) s)
UNION ALL SELECT 7, 'Pedidos concluídos com pagamento declarado',
       (SELECT count(*) FROM monira_offline_payments p JOIN monira_orders o ON o.id = p.order_id, desde WHERE o.created_at >= desde.t)::text
UNION ALL SELECT 8, 'Avisos enviados por tipo',
       (SELECT coalesce(string_agg(kind || ' ' || n, ' · '), '—') FROM
          (SELECT kind, count(*) n FROM monira_notification_log l, desde WHERE l.sent_at >= desde.t GROUP BY kind) s)
UNION ALL SELECT 9, 'Clientes que voltaram noutro dia',
       (SELECT count(*) FROM (SELECT uid FROM clientes_ativos GROUP BY uid HAVING count(DISTINCT dia) > 1) v)::text
UNION ALL SELECT 10, 'Pedidos para vender recebidos',
       (SELECT count(*) FROM monira_applications a, desde WHERE a.created_at >= desde.t)::text
ORDER BY 1;
