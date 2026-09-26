# Monira — Backlog

Problemas observados a usar o produto real. Só entram aqui descobertas de uso, não ideias.

## Aberto

- **Testes:** 900_v0.1_cycle_tests pede entrega a uma Uja sem entregas ligadas (escrito antes da 007) —
  actualizar para ligar entrega antes do pedido. Não afecta produção.
- **Privacidade:** texto publicado em /privacidade. Contacto TEMPORÁRIO monira.entrar@gmail.com → trocar por
  privacidade@monira.ao quando o domínio e a caixa estiverem operacionais (constante CONTACT em
  src/app/privacidade/page.tsx). Antes da abertura pública: revisão jurídica (lei angolana de protecção de dados;
  frase "legislação europeia" — dados em Londres/Reino Unido, emails via Google) e termos de utilização.
- **Pedidos — a observar:** risco de pedidos falsos no pagamento offline é da loja (hoje: telefone obrigatório e máx. 5
  pedidos abertos por cliente).
- **Avisos — a observar:** o anti-cascata envia o
  primeiro aviso e silencia 10 min — agrupar ("3 mensagens novas") quando houver volume. Diário de avisos
  (monira_notification_log) já preparado para isso.
- **Desktop:** a Monira é uma coluna de telemóvel; no ecrã grande a foto do produto ocupa quase toda a
  primeira vista. Sem urgência (público é telemóvel).
- **Descoberta (24 Set 2026):** a hot7 definiu uma só zona, "Luanda e arredores — 3.000 Kz". Regra para o
  Comprar: com uma só opção activa, mostrar "Entrega — 3.000 Kz · Luanda e arredores" e pedir a morada, sem
  seleccionar zona; com várias, perguntar "Onde queres receber?".
- **Email de entrada:** SMTP Gmail (monira.entrar) serve para testes. Antes de abrir a clientes reais:
  domínio da Monira + serviço de envio transaccional.
- **Comprar:** primeiro cliente real escreveu "Preciso adquirir hoje" (24 Set 2026). Depende da validação
  técnica do prestador (confirmação por callback, liquidação directa na conta de quem vende).

## Resolvido

- ~~Uja pública sem morada~~ → "Levantamento" na Uja e no produto. Observado a 24 Set 2026: primeira
  pergunta de um cliente na Conversa foi "Onde estão localizados?".

- ~~Revisão: rejeitar / esconder envios repetidos~~ → **Pedir alterações** (editorial, com histórico;
  quem vende vê "Precisa de atenção" e responde em **Corrigir**) e **Apagar** (só nunca publicados, sem pedidos).
- ~~Revisão: corrigir a apresentação de um produto já publicado~~ → secção **Publicados** na revisão.

- ~~Adicionar produto: sem saída depois de "Recebido."~~ → Painel com estados "Em revisão" / "Publicado"
  e "Ver os meus produtos" depois de enviar.

## Próximas fatias

1. Início ✓ → Produto público ✓ (mínimo, sem Comprar/Conversar) → Uja pública ✓ (sem Conversar/contactos/métricas)
2. Painel ✓ (mínimo: Uja aberta/fechada, Adicionar produto, Produtos com estado).
3. Revisão — poder editorial ✓ (005).
4. Conversa ✓ (006): produto → Conversar → conversa dos dois lados; actualização a cada 8 s (sem tempo real ainda).
5. Minha Uja ✓ (007): funcionamento gerido por quem vende; zonas com preço prontas para o Comprar.
6. Tipos de letra ✓: Fraunces (identidade/editorial) + Instrument Sans (interface), locais, pré-carregados, CLS 0.
7. Novas lojas ✓ (008): pedir em /vender → aprovar/recusar em /revisao/lojas.
8. Avisos por email ✓ (009): mensagem → loja; decisões editoriais → loja; pedido para vender → quem pediu.
9. Comprar com pagamento na entrega/levantamento ✓ (010).
10. Avisos ao cliente ✓ (011). → **Modo validação: ver docs/VALIDACAO-v0.1.md**
11. Comprar online (MCX) — depende da validação técnica do prestador de pagamento.
12. Email com domínio da Monira — antes de clientes reais.
