\set QUIET on
\pset tuples_only on
\pset format unaligned
\echo '— MINHA UJA'
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  público vê WhatsApp/telefone antes:   '||coalesce(whatsapp,'—')||' / '||coalesce(phone,'—') FROM monira_public_ujas WHERE slug='hot7-store';
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  entrega sem zonas:                    '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"delivery_enabled":true}','[]')$q$);
SELECT '  levantamento sem morada:              '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"pickup_enabled":true}','[]')$q$);
SELECT '  mostrar WhatsApp sem número:          '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"whatsapp_public":true}','[]')$q$);
SELECT '  número inválido:                      '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"whatsapp":"abc"}','[]')$q$);
SELECT '  zonas repetidas:                      '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{}','[{"name":"Kilamba","fee_kz":3000},{"name":"kilamba","fee_kz":1}]')$q$);
SELECT '  preço negativo:                       '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{}','[{"name":"Kilamba","fee_kz":-1}]')$q$);
SELECT '  Uja de outro vendedor:                '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000002','{}','[]')$q$);
SELECT '  guarda tudo:                          '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001',
  '{"is_open":false,"pickup_enabled":true,"pickup_address":"Mártires, Rua 17","pickup_reference":"Perto da escola","delivery_enabled":true,"whatsapp":"+244 934 285 368","whatsapp_public":true,"phone":"+244 934 285 368","calls_enabled":false}',
  '[{"name":"Talatona","fee_kz":2500},{"name":"Kilamba","fee_kz":3000},{"name":"Maianga","fee_kz":2000}]')$q$);
SELECT '  tenta mudar o nome da Uja:            '||t_try($q$UPDATE monira_ujas SET name='Outra' WHERE id='20000000-0000-0000-0000-000000000001'$q$);
SELECT '  retira Kilamba:                       '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001',
  '{"is_open":false,"pickup_enabled":true,"pickup_address":"Mártires, Rua 17","delivery_enabled":true,"whatsapp":"+244 934 285 368","whatsapp_public":true,"phone":"+244 934 285 368","calls_enabled":false}',
  '[{"name":"Talatona","fee_kz":2500},{"name":"Maianga","fee_kz":2000}]')$q$);
RESET ROLE;
SELECT '  → zonas: '||string_agg(name||' '||fee_kz||(CASE WHEN active THEN '' ELSE ' (inactiva)' END), ', ' ORDER BY position, name) FROM monira_uja_delivery_zones WHERE uja_id='20000000-0000-0000-0000-000000000001';
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  público: aberta='||is_open||' · WhatsApp='||coalesce(whatsapp,'—')||' · tel='||coalesce(phone,'escondido')||' · levant.='||coalesce(pickup_address,'—')||' ('||coalesce(pickup_reference,'—')||')' FROM monira_public_ujas WHERE slug='hot7-store';
SELECT '  público vê zonas activas:             '||string_agg(name, ', ' ORDER BY position) FROM monira_uja_delivery_zones;
SELECT '  produtos continuam públicos (fechada):'||count(*) FROM monira_public_products WHERE uja_id='20000000-0000-0000-0000-000000000001';
RESET ROLE;
SET ROLE service_role;
SELECT '  compra com entrega (Maianga):         '||t_try(format($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',1,'delivery',%L,'Rua Y')$q$, (SELECT id FROM monira_uja_delivery_zones WHERE name='Maianga')));
SELECT '  compra com zona inactiva (Kilamba):   '||t_try(format($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',1,'delivery',%L,'Rua Y')$q$, (SELECT id FROM monira_uja_delivery_zones WHERE name='Kilamba')));
RESET ROLE;
SET ROLE authenticated; SELECT t_as('authenticated','00000000-0000-0000-0000-00000000000a');
SELECT '  desliga entrega:                      '||t_try($q$SELECT monira_save_uja_settings('20000000-0000-0000-0000-000000000001','{"is_open":true,"pickup_enabled":false,"delivery_enabled":false}','[{"name":"Talatona","fee_kz":2500}]')$q$);
RESET ROLE;
SET ROLE anon; SELECT t_as('anon',null);
SELECT '  público vê zonas (entrega desligada): '||count(*) FROM monira_uja_delivery_zones;
SELECT '  público vê morada (levant. desligado):'||coalesce(pickup_address,'—') FROM monira_public_ujas WHERE slug='hot7-store';
RESET ROLE;
SET ROLE service_role;
SELECT '  compra com entrega desligada:         '||t_try(format($q$SELECT monira_place_order('60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',1,'delivery',%L,'Rua Y')$q$, (SELECT id FROM monira_uja_delivery_zones WHERE name='Talatona')));
SELECT '  → total da compra Maianga: '||total_kz||' (1120000 + 2000)' FROM monira_orders WHERE delivery_zone_name='Maianga';
RESET ROLE;
