# Monira — Backlog

Problemas observados a usar o produto real. Só entram aqui descobertas de uso, não ideias.

## Aberto

- **Revisão: rejeitar / esconder envios repetidos.** Hoje só por SQL
  (`update monira_products set active = false where …`). Observado a 24 Set 2026:
  quatro envios do mesmo iPhone durante o primeiro teste.
- **Adicionar produto: sem saída depois de "Recebido."** Quem vende não tem para onde ir a seguir.
  Resolve-se com o Painel.
- **Revisão: corrigir a apresentação de um produto já publicado** (nome, descrição, fotos).
  Observado a 24 Set 2026: nome publicado como "IPhone" e descrição com aspas a mais; corrigido por SQL.

## Próximas fatias

1. Início ✓ → Produto público ✓ (mínimo, sem Comprar/Conversar) → Uja pública ✓ (sem Conversar/contactos/métricas)
2. Depois: enriquecer o Painel.
