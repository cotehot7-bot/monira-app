# Monira — Visão

> O que a Monira poderá tornar-se. **Não são tarefas de desenvolvimento.** O trabalho em curso está em
> `BACKLOG.md`; o que aconteceu com utilizadores reais está em `VALIDACAO-v0.1.md`.

Isto começa a revelar uma possibilidade maior para a Monira: deixar de ser apenas um lugar onde se encontram
produtos e tornar-se uma infraestrutura que permite a pequenos comerciantes operar como empresas maiores.

E as duas ideias que trouxeste — motoboys e fornecedores internacionais — têm uma ligação direta com aquilo que
já construímos.

Mas eu não as juntaria criando uma aplicação de transportes e outra de importação dentro da Monira. Isso seria
perder o foco.

Criaria um princípio:

**A Monira liga quem vende aos recursos necessários para vender. O comerciante não precisa de construir essas
relações sozinho.**

Há três dimensões distintas:

- **Comércio:** a Uja apresenta produtos, recebe conversas e pedidos.
- **Operação:** parceiros ajudam a entregar as encomendas.
- **Abastecimento:** fornecedores ajudam a encontrar e adquirir mercadoria.

O marketing, o design e a apresentação continuam sob responsabilidade da Monira.

Assim, tudo pertence ao mesmo sistema, mas não precisamos de construir tudo ao mesmo tempo.

## 1. Motoboys: a Monira não precisa de ser uma Yango

A tua intuição de trabalhar com parceiros faz sentido.

Imagina que a hot7 recebe um pedido. Hoje tem de organizar a entrega por conta própria. Numa fase seguinte,
poderia aparecer no detalhe do pedido:

```
Pedido #MON-0024
Pagamento confirmado
Marshall Acton III
Entrega · Talatona

Como queres entregar?
  Entrega própria
  Solicitar parceiro Monira
```

O parceiro recebe a solicitação, aceita, recolhe o produto e realiza a entrega.

A Monira acompanha os estados do pedido, mas não precisa de possuir motorizadas, contratar uma frota ou
desenvolver um sistema completo de mobilidade.

O modelo inicial pode ser ainda mais simples: parceiros de entrega aprovados pela Administração, com
distribuição manual ou semiautomática das solicitações.

Só depois de haver volume faria sentido construir um painel próprio para estafetas.

Há também uma responsabilidade operacional a definir: quem responde por extravio, danos, atrasos, prova de
entrega e reclamações. A experiência deve ser simples para o comerciante, mas estas regras não podem ficar
implícitas.

## 2. Fornecedores internacionais: uma segunda oportunidade

Aqui vejo uma ideia comercial diferente, mas complementar.

Imagina uma pequena marca de moda que já vende na Monira. Tem procura, clientes e uma Uja, mas não sabe como
encontrar fornecedores, negociar compras ou organizar importações.

A Monira poderia criar uma área reservada:

```
Abastecimento                               Conceito futuro
Encontra produtos para a tua Uja.
Pesquisa fornecedores e solicita uma cotação antes de comprar.
  Moda e acessórios · Tecnologia

Como funciona
Produto pretendido → Solicitação → Cotação → Aprovação → Aquisição → Entrega.
```

Mas atenção à diferença entre três modelos:

| Modelo | Papel da Monira |
|---|---|
| Catálogo externo | Mostra ofertas de fornecedores autorizados |
| Intermediação | Recebe solicitações e coordena compras |
| Importação própria | Compra, importa e revende mercadorias |

São negócios com obrigações, capital e riscos diferentes.

Eu começaria pelo segundo, de forma assistida, com parceiros verificados e cotações individuais.

Não assumiria que SHEIN ou eBay permitem automaticamente integração, revenda, importação ou acesso aos seus
catálogos para qualquer finalidade. Isso teria de ser validado contratual e tecnicamente. Também precisamos de
considerar alfândega, impostos, garantias e responsabilidade pela mercadoria.

E existe uma possibilidade especialmente interessante: o abastecimento pode nascer dos dados comerciais da
própria Monira.

Se várias Ujas recebem perguntas sobre determinado produto, a Administração pode identificar procura que os
comerciantes ainda não conseguem satisfazer.

Ou seja:

**Monira descobre procura → identifica oportunidades de abastecimento → aproxima fornecedores e comerciantes.**

A plataforma deixa de apenas distribuir oferta existente e começa a ajudar a criar nova oferta.

## 3. Como ligar tudo sem perder Monira

Eu organizaria a visão em quatro sistemas, todos associados à Uja.

**MONIRA — Infraestrutura comercial gerida**

| Sistema | Âmbito | Estado |
|---|---|---|
| Comércio | Ujas, produtos, descoberta, conversas e pedidos. | Em desenvolvimento |
| Confiança | Verificação, pagamentos, avaliações e reputação. | Expansão gradual |
| Entrega | Parceiros logísticos associados aos pedidos. | Futuro |
| Abastecimento | Fornecedores, cotações e intermediação. | Futuro |

**Administração Monira:** Marketing invisível · Conteúdo · Design · Curadoria · Operação · Qualidade

Repara que a Uja continua a ser o centro económico. Não estamos a construir quatro aplicações independentes.

Estamos a permitir que um pequeno comerciante tenha acesso a uma infraestrutura que, sozinho, teria dificuldade
em organizar.

## 4. A ordem em que eu desenvolveria

Aqui precisamos de disciplina. Não interromperia os sete dias de validação que acabámos de definir.

| Etapa | Desenvolvimento | O que precisamos provar |
|---|---|---|
| 1 | Comércio atual | Pessoas descobrem, conversam e compram |
| 2 | Confiança e relações | Compradores regressam e seguem Ujas |
| 3 | Entregas parceiras | Existe volume e procura por entregas integradas |
| 4 | Abastecimento assistido | Comerciantes solicitam e concluem compras |
| 5 | Integrações internacionais | Existem parceiros e operações recorrentes |

Antes de construir a integração de motoboys, podemos realizar dez entregas com um parceiro e observar custos,
atrasos e problemas.

Antes de construir um catálogo internacional, podemos receber cinco pedidos de abastecimento, procurar
fornecedores e acompanhar as operações manualmente.

Primeiro validamos o serviço. Depois transformamos o processo repetitivo em software.

## A decisão registada

A Monira não será apresentada como uma empresa de motoboys, importadora, rede social ou agência de marketing.

A sua proposta permanece:

**Abre a tua Uja. A Monira ajuda-te a vender.**

Por trás dessa frase, podemos construir gradualmente distribuição, comunidade, confiança, logística e
abastecimento.

O comerciante não precisa conhecer a complexidade de tudo isso.

Ele precisa sentir que, ao entrar na Monira, deixou de estar sozinho a tentar vender.
