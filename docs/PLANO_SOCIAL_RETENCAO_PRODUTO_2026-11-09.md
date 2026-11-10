# FeedAGiant — plano de diversão, cooperação e retenção 70/30
**Data:** 09/11/2026 · **Base de código:** PR #1 (`007c8f80`) · **Nova branch:** `codex/feedagiant-social-retencao-2026-11-09`
**Backup imutável:** `backup/2026-11-09-antes-social-retencao`
**Situação:** implementação em código; ainda **SEM teste Roblox Studio desta rodada**, nem aprovação de lançamento.

## 1. Diagnóstico de produto: qual é o motivo para jogar junto?
O loop central é alimentar seu gigante, crescer, colecionar e disputar comida. Já há Ancestral (todos alimentam seus gigantes para despertar um chefe compartilhado), bots e arena. Falta **colaboração consciente**: encontrar outro humano, decidir participar, coordenar uma ação e ver o resultado **dos dois**.

A primeira atualização é um **Banquete em Dupla** no caldeirão da praça. Dois jogadores verdadeiros precisam se reunir e se inscrever em até 120 segundos, com comidas comuns ou incomuns. Recebem +150 moedas cada e +15% XP para alimentação durante 4 minutos. A participação é opcional, três sucessos por dia por perfil, um novo por pessoa a cada 3 minutos. O pedestal reabre para outra dupla após 10 segundos. O bônus usa horário absoluto e seu tempo restante é restaurado após reconexão, sem congelar a duração offline. Não há Robux nem novo item aleatório.

**Segurança da inscrição:** a primeira comida é apenas identificada pelo UID e NÃO é retirada. Quando o segundo jogador chega, o servidor revalida o mesmo item, a localização, jogadores distintos, os dois perfis, os limites diários e a comida do segundo. Os dois itens só são removidos no sucesso. Se o tempo acabar, a pessoa sair ou o servidor cair antes de completar, **não perde sua comida**.

**Feedback real:** contador no mundo, convite discreto no servidor ao primeiro inscrito, celebração no pedestal e reação dos dois gigantes. O bônus aplica-se somente à alimentação posterior, incentivando o retorno ao loop central. Bots não contam como segundo jogador.

**Por que isso é diferente de simplesmente mostrar um indicador coletivo:** ambos precisam chegar ao mesmo local com recursos próprios, se coordenar e agir dentro do prazo. Não se premia AFK.

## 2. Retenção: 70% progresso positivo / 30% urgência justa

A proporção descreve o **esforço de design**, não uma métrica mensurável automaticamente nem uma garantia de retenção.

| Peso de design | Mecanismo | Como funciona | Proteção |
|---|---|---|---|
| 10% saudável | Sabor Favorito (feito) | Cada espécie prefere uma comida normal diferente por dia: +20% XP se alimentada com ela | nenhuma compra/raridade exigida; não desconta XP |
| 10% saudável | Banquete em Dupla (feito) | 2 humanos juntos e recompensa compartilhada | inscrição não consome item; solo mantém outros loops |
| 10% saudável | Evolução marcante (já existe) | crescer e mudar de estágio como recompensa visual | não acelerá-la por monetização |
| 10% saudável | Decisão de alimentação (feito) | botão rápido protege raras, mutações e gigantescas; seleção especial manual | nunca sacrificar comida valiosa por um clique |
| 10% saudável | Coleção com identidade (já existe) | espécie própria, níveis, exposição em base | mostrar silhuetas distintas antes de vender |
| 10% saudável | Objetivos de domínio (já existe) | diário e objetivos semanais ligados a alimentar | recompensas limitadas, sem obrigação de login |
| 10% saudável | Reconhecimento social (primeiro passo feito) | celebração da dupla e contador pessoal persistente | sem spam público de vendas/Robux |
| 10% urgência | Janela de colaboração (feito) | a inscrição termina em 120 s; perde somente **a oportunidade**, não o alimento | aviso exato do prazo e devolução implícita |
| 10% urgência | Bônus que expira (feito) | +15% de XP durante 4 min após a colaboração | bônus temporário não comprado; nenhuma perda permanente |
| 10% urgência | Disputa ao vivo (já existe) | drops limitados e roubo leve com proteção do novato/último ovo | não roubar inventário salvo enquanto está offline |

**Limite ético:** o FeedAGiant pode receber crianças. Não implementar saque de itens pagos/colecionados na ausência, punição por faltar à escola/trabalho, timers secretos, chances de compra obscuras ou compra de proteção obrigatória. A ideia é dar urgência a atividades **voluntárias e reversíveis**, não transformar o retorno numa obrigação.

## 3. Segunda atualização imediata — personalidade real no loop
**Sabor Favorito** (`src/shared/FoodPreference.lua`): a espécie e o dia UTC determinam um alimento favorito entre Maçã, Pão, Banana, Pizza, Hambúrguer e Sushi. O favorito muda a cada dia, sem re-roll pago. Alimentar com ele adiciona 20% ao XP base e mostra reação; a HUD informa o pedido.

**Alimentação segura** (`src/shared/FoodChoice.lua`): o botão ALIMENTAR prioriza item favorito normal da mochila, depois comida comum/incomum normal. Itens raros, mutados, gigantescos ou do pátio de alto valor não são selecionados automaticamente. Seleção manual na janela ITENS permanece. Evita frustração e fortalece a decisão comer vs expor.

## 4. Três ideias extraordinárias — conceitos para protótipos PÓS-beta

### A. Cozinha Colossal: partidas 2v2 de preparo + interceptação
Em uma cozinha da praça, duas equipes precisam juntar ingredientes, cortar/misturar em minijogos de habilidade de 20–40 s e levar um PRATO GIGANTE ao próprio gigante. Rival pode interceptar ingrediente **de evento**, nunca item persistente do inventário. Cada prato permite reação e transformação cômica única, além de pontos no placar da rodada.
- **Hook:** mistura cooperação de Overcooked com perseguição de Sea of Thieves, mas usa a fantasia principal do FeedAGiant.
- **MVP:** 1 cozinha reutilizando o caldeirão, 3 receitas legíveis, 1 partida de 3 minutos, bots para preencher vagas sem premiar competição fingida.
- **Diferencial comercial:** clipes de cozinheiros correndo com um hambúrguer gigante e o gigante esperando.
- **Risco:** não transformar o jogo inteiro em minigames. Deve devolver comida/XP ao gigante. Nenhuma vantagem competitiva paga.

### B. Expedição dentro do Gigante: mapa episódico cooperativo
O gigante engole um artefato misterioso. O jogador e dois amigos encolhem e entram numa pequena instância do estômago, navegando por comidas flutuantes, vapores e objetos engolidos. Precisam recuperar a receita antes que a digestão termine (5–6 min). A criatura reage do lado de fora.
- **MVP:** uma arena/instância curta com 3 salas e duas escolhas de rota, sem criar mundo aberto nem inventário extra.
- **Por que é forte:** oferece uma história compartilhável que não existe no loop principal de roubo; envolve o próprio gigante, não pets genéricos.
- **Punição:** só perder bônus da expedição, nunca o gigante ou ovos colecionados.

### C. Desfile dos Colossos: o mundo reage ao progresso dos jogadores
Ao atingir um marco de crescimento, o jogador pode convidar o gigante para **andar uma rota curta** pela cidade com até 3 amigos. Outros jogadores alimentam ou ajudam a guiar a criatura; o grupo precisa passar por obstáculos/tarefas que mudam segundo a espécie. Terminando, uma foto panorâmica vira cartão de recorde.
- **MVP:** caminho curto fora das zonas PvP, uma espécie com animação/proxy leve, captura de tela iniciada pelo próprio jogador e nenhum streaming pesado.
- **Valor social:** o gigante se torna protagonista no mundo, atrai visitantes e produz mídia orgânica.
- **Risco:** rigs e física custosos; só implementar após perfil de desempenho no celular.

**Ordem recomendada após o beta:** testar Cozinha Colossal antes das outras duas; validar hipótese com 10 pessoas e medir participação/retorno.

## 5. Concorrentes — práticas valiosas e queixas documentadas

| Jogo | Mecânica útil para entender | Crítica pública que precisamos evitar |
|---|---|---|
| My Hungry Giant! [ASMR] | cortar/cozinhar, empilhar comida, ASMR, ajudar amigos na base | não prometer uma mastigação detalhada sem rig e áudio real; nosso diferencial deve ser cooperação + mundo vivo |
| Feed a Giant (Big Mouth!) | roubar comida, treinar força, lançar comida na boca | evitar confusão de marca/nome e clone visual; focar seu próprio gigante |
| Steal an Egg | biomas, velocidade, ninhos, mutações, roubo | relatos de hackers, velocidade desproporcional, perseguição e frustração por perda de raros |
| Steal a Brainrot | histórias sociais de roubo/defesa e proteção da base | críticas a pay-to-win, stunlocks e perda de toda a progressão |
| Grow a Garden | crescimento offline, mutações, eventos e cooperação por caldeirão | queixas de espera longa, atualizações sem recompensa proporcional, economia inflada e saques irreversíveis |
| Pet Simulator 99 | metas, relicários, coleção, áreas desbloqueáveis | críticas a AFK obrigatório, loop repetitivo, compras como atalho obrigatório |

Fontes para revisão:
- Roblox discovery (junho de 2026): https://create.roblox.com/docs/discovery
- https://about.roblox.com/pt-br/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- https://www.roblox.com/games/112345685575988/My-Hungry-Giant
- https://www.roblox.com/pt/games/107778070777162/Steal-An-Egg
- https://www.reddit.com/r/StealAnEggRoblox/comments/1xeqjli/hackers_are_ruining_the_game/
- https://www.reddit.com/r/StealAnEggRoblox/comments/1whrh1n/why_are_the_players_here_so_greedy/
- https://www.reddit.com/r/roblox/comments/1rc4vgt/steal_a_brainrot_is_not_fun/
- https://www.reddit.com/r/growagarden/comments/1oztv89/is_anyone_else_really_struggling_with_this_game/
- https://www.reddit.com/r/growagarden/comments/1vkcyq3/anyone_else_a_little_bored/
- https://www.reddit.com/r/roblox/comments/18aq2aw

Relatos do Reddit são exemplos individuais/autoselecionados, não amostras representativas. Não confundir descrição promocional dos jogos com fato observado em playtest.

## 6. Plano de execução e gates

### Gate A — novo sistema em QA
1. Verificar Luau, Selene, StyLua, Rojo e TestEZ; executar `tests/SocialFeast.spec.luau` e `tests/FoodPreference.spec.luau` além dos testes existentes.
2. Testar a praça com **2 clientes** reais: primeiro oferece, segundo completa; somente a segunda confirmação consome os 2 alimentos (com UID). Verificar que o prazo restante do bônus sobrevive a uma reconexão real, mas continua correndo enquanto o jogador está offline.
3. Testar timeout, desconexão do primeiro, troca do item prometido, inventário cheio e reinício abrupto em cópia; nenhuma comida perdida antes de completar.
4. Confirmar limite de 3/dia por perfil e cooldown de 3 min por pessoa, sem bloquear outras duplas.
5. Validar bonus de XP de 4 min (não altera compras/arena/XP sem comida), 20% do sabor favorito e proteção da alimentação rápida.
6. Celular físico: prompt do pedestal, painel de META e HUD; não tapar botões.
7. Validar DataStore real, recibos, place oficial, proteção `Workspace.MainModule`, roubo de ovos e prêmio do Dragão. Pendências antigas **continuam bloqueadoras**.

### Gate B — primeira sessão / vontade de voltar
- Teste cego com >=10 jogadores novos: quantos conseguem alimentar o gigante, entender crescimento e achar outra pessoa para o banquete sem instruções?
- Instrumentar e comparar `ftue_first_feed`, `ftue_second_feed`, `social_feast_started`, `social_feast_completed`, `giant_favorite_fed`, e dias de co-play.
- Acompanhar abandono antes de 60 s e de 61–180 s, retorno dia 1, dias 2–7 e dias 8–28 (sinais Roblox atuais).
- Não usar só duração de sessão ou quantas funcionalidades existem como prova de diversão.

### Gate C — produção
Nenhum merge na `main`, publicação, anúncio ou Robux até que Play em dois clientes, mobile, dados e segurança passem. PR mantido em rascunho. Ao fazer rollout, poder desligar `Features.SocialFeast` sem perder perfil.

## 6.1. Ajuste de conforto: fome menos agressiva
Na build de beta desta branch, `Config.Giant.HungerDecayPerSec` foi reduzido de **0,5 para 0,25 por segundo**. A alimentação padrão repõe 12 pontos: isso representa aproximadamente **48 s** de desgaste basal por alimento, em vez de 24 s (antes de multiplicadores de espécie). O objetivo é que a fome provoque decisões, não uma obrigação a cada poucos segundos. É reversível e precisa ser avaliado em playtest de 15–30 minutos. A taxa não foi validada em dados reais.

O Banquete em Dupla tem convite geral limitado a uma mensagem por minuto e é indisponível quando há só um humano no servidor; nesse caso, recomenda convidar outro jogador sem consumir comida. O pedestal fica livre para outras duplas 10 s após uma conclusão, enquanto cada participante mantém cooldown próprio de 3 min.


## 7. Alterações concretas nesta branch
- `src/server/Services/SocialFeastService.lua` — pedestal, pairing real, validações, moedas, limite diário, anti-loss.
- `src/shared/SocialFeastRules.lua` — regras puras e testes.
- `src/shared/FoodPreference.lua` — favorito diário determinístico, sem sorteios.
- `src/shared/FoodChoice.lua` — seleção segura no botão principal.
- `src/server/Main.server.lua` — inicia serviço/slice antes de carregar perfis.
- `src/server/Services/GiantService.lua` — bônus temporário para os dois participantes e evento de favorito.
- `src/server/Services/PlotService.lua` — bônus do favorito, estado do cliente, preserva contadores existentes.
- `src/client/Controllers/HUD.lua` e `FeedFx.lua` — informação e feedback sem novas janelas.
- `src/client/State.lua`, `src/shared/Locale.lua`, `src/shared/Features.lua` — estado, idioma e flag.
- `tests/SocialFeast.spec.luau`, `tests/FoodPreference.spec.luau` — **13 testes novos escritos**, ainda não executados no Studio nesta sessão.

**Testes automatizados anteriores:** o Work relatou 167/167 antes dessas alterações. Não incluir os novos testes nesse número nem afirmar que compilam sem executar. A próxima etapa é validar a branch em Studio/Work.
