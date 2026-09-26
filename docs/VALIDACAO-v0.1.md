# Monira — Validação v0.1

> O que aconteceu efectivamente com os primeiros utilizadores. A visão está em `VISAO.md`; problemas e
> funcionalidades identificados em `BACKLOG.md`.

**Estado:** construção congelada durante o período de observação.

**Pergunta central:** a Monira consegue produzir uma experiência comercial sem intervenção nossa?

**Período:** 7 dias sem novas funcionalidades, salvo correcções de segurança, pagamentos ou problemas que
impeçam a utilização.

**Participantes:** Glamour da Paula e hot7 partilham as suas Ujas com um grupo pequeno de pessoas conhecidas.
Não partilhar com desconhecidos enquanto email, permissões de acesso e fluxo de pagamentos não estiverem
suficientemente validados.

**Regras:**
- Partilhamos apenas o link. Não explicar a Monira, Uja, Avenida, Bur ou a história da cidade.
- Não apresentar a ambição do produto (OLX, Facebook, WhatsApp, Airbnb) — influenciaria a interpretação.
- Queremos saber o que as pessoas pensam que a Monira é, o que fazem naturalmente e se voltam a utilizá-la.
- Única pergunta permitida: "O que achas que esta página é?"

**Antes de convidar:** aviso de privacidade publicado (`/privacidade`), com contacto para eliminação de dados e
informação sobre quem recebe os dados dos pedidos. Versão jurídica completa antes da abertura pública.

## Medir com dados (sem perguntar a ninguém)

Correr `src/data/ops/observacao.sql` no SQL Editor (mudar a data "desde" para o dia do primeiro convite).
Mostra: contas novas, conversas iniciadas, conversas com resposta, tempo mediano de resposta, pedidos por estado,
pedidos concluídos, avisos enviados, clientes que voltaram noutro dia, pedidos para vender. Contas da equipa e das
lojas ficam fora das contagens de clientes.

## O que queremos descobrir

| Observação | Pergunta | Evidência |
|---|---|---|
| Primeira visita | A pessoa entende o que pode fazer? | |
| Produto → Uja | Percebe quem está a vender? | |
| Conversa | Consegue iniciar e retomar o contacto? | |
| Notificações | Os emails fazem as pessoas regressar? | |
| Comprar | Consegue concluir sem assistência? | |
| Entrega | Compreende preço, condições e estado? | |
| Painel | Paula e hot7 conseguem operar autonomamente? | |

## Progresso — 0/8

- [ ] Alguém descobriu um produto sem ajuda nossa.
- [ ] Alguém iniciou uma conversa.
- [ ] A loja recebeu e respondeu ao aviso.
- [ ] O cliente regressou através do email.
- [ ] Alguém fez um pedido.
- [ ] A loja conseguiu concluir o pedido.
- [ ] O cliente compreendeu o estado da encomenda.
- [ ] Alguém utilizou a Uja sem precisar de explicações.

## Perguntas espontâneas sobre a linguagem (sem explicar antes)

| Data | Quem | Palavra | O que perguntou ou disse |
|---|---|---|---|
|  |  | Uja |  |
|  |  | Avenida |  |
|  |  | Bur |  |

## Registo livre

| Data | Quem | O que aconteceu | Onde parou / o que perguntou | Voltou? |
|---|---|---|---|---|
|  |  |  |  |  |

## Antes dos convites

- [ ] Privacidade: `/privacidade` acessível, com contacto funcional (temporário: monira.entrar@gmail.com,
      consultado regularmente).
- [ ] MON-2026-00001 (teste interno): cancelado com o motivo "Teste" — o registo fica no histórico.
- [ ] Convites: só os links das Ujas e do Início, sem explicar o conceito da Monira.

**Início do período de observação:** ____ (7 dias a contar do primeiro convite)
