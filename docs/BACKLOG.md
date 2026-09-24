# Monira — Backlog

Problemas observados a usar o produto real. Só entram aqui descobertas de uso, não ideias.

## Aberto

- **Revisão: rejeitar / esconder envios repetidos.** Hoje só por SQL
  (`update monira_products set active = false where …`). Observado a 24 Set 2026:
  quatro envios do mesmo iPhone durante o primeiro teste.
- **Revisão: corrigir a apresentação de um produto já publicado** (nome, descrição, fotos).
  Observado a 24 Set 2026: nome publicado como "IPhone" e descrição com aspas a mais; corrigido por SQL.

## Resolvido

- ~~Adicionar produto: sem saída depois de "Recebido."~~ → Painel com estados "Em revisão" / "Publicado"
  e "Ver os meus produtos" depois de enviar.

## Próximas fatias

1. Início ✓ → Produto público ✓ (mínimo, sem Comprar/Conversar) → Uja pública ✓ (sem Conversar/contactos/métricas)
2. Painel ✓ (mínimo: Uja aberta/fechada, Adicionar produto, Produtos com estado).
3. Revisão — poder editorial da Monira: Rejeitar (decisão editorial, guarda histórico, aparece a quem
   vende como "Precisa de atenção") ≠ Apagar (destrutivo, só para duplicado/erro). Editar publicação.
