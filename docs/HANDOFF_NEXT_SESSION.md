# Handoff — Feed a Giant ("Alimente um Gigante")

**Atualizado em:** 08/11/2026 (noite, missão "evolução integrada") · **Repositório:** https://github.com/FiaresAlan/FeedAGiant (branch `main`, último commit `292ce41` + o deste handoff)
**Pasta local:** `C:\Users\Administrador\Pictures\FeedAGiant PRINCIPAL`
**Idioma obrigatório:** português brasileiro em toda comunicação, documentação e relatório. O usuário é **leigo** em programação: explicar em linguagem simples.

> **Leia a Parte A inteira antes de qualquer coisa.** A Parte B é o histórico detalhado das sessões anteriores: consulte quando precisar de um detalhe.
> Depois leia `docs/GAME_BRIEF.md` (decisões aprovadas) e `docs/DIAGNOSTICO_E_PLANO.md` (as 5 fases; **não reformular**).

---

# PARTE A — ESTADO ATUAL E PRÓXIMOS PASSOS

## A000000. Sistema de Ovos (08/11/2026, madrugada): VALIDADO, NÃO IMPLEMENTADO
- **Pedido do usuário:**
  - ovos de 5 tamanhos num Ninho na praça;
  - efeito visual por raridade;
  - 3 espécies iniciais fora da loja;
  - ovo de tutorial;
  - notificação de "ovo pronto".
- **Pacote de assets:** pasta "50 Stylized Eggs – Free 3D Asset Pack" em Pictures. Licença comercial, mas sem redistribuir, então o upload tem de ser privado.
- **Validação:** `docs/VALIDACAO_OVOS_V1.md` traz a análise do pacote e **9 perguntas pendentes**.
- **Estado:** o próprio pedido proíbe codar antes das respostas. Nada foi implementado nem enviado.

## A00000. Especificação v3 (08/11/2026, fim da noite) — parte 1 entregue
O usuário mandou a "Especificação Final v2.1 → v3.0" (com esqueletos em `src/shared/Config/`) e pediu: validar e implementar.
- **Validação completa, item por item:** `docs/VALIDACAO_ESPEC_V3.md` (aprovado / adaptado / adiado / conflito, com motivos).
- Os esqueletos foram para `docs/propostas/onboarding_v2/`: uma pasta `Config` ao lado de `Config.lua` quebraria o `require`.
- **Ligado:** a janela não escurece mais o mundo (`UI.window`, `Hatch`); porção da Carne Gigante virou pernil (`DropService.dressMeatPortion`).
- **Desligado em `src/shared/Features.lua`** (no Studio: atributo `Feature_<Nome>` no ReplicatedStorage):
  - `LunchboxPity` (50 caixas pagas → Épica garantida, chance exibida = sorteada);
  - `StreakBackup` (1 proteção por ciclo de 7 dias, máx. 2);
  - `ObjectiveHints` (1 dica na linha de META);
  - `OnboardingV2` (câmera de chegada, 1ª alimentação 2x, presente guardado);
  - `StealProtection` (nível < 5 protegido, 3 roubos/dia).
- Métricas: `src/server/Analytics.lua`. Testes: `tests/V3.spec.luau`; suíte no Play **88/88**. Evidências: `docs/qa/FASE8_EVIDENCIAS.md`.
- **ATENÇÃO:** o Studio aberto é o place "Alimente um Gigante" **placeId 115578986093768** (já publicado?) com `rojo serve`. Testar só em Play; nunca salvar. Confirmar com o usuário se é o oficial.
- Comando do Studio não compartilha módulos com o jogo: para ler o estado real, crie um `Script` temporário no servidor do Play (técnica usada nas evidências).
- **Próximo:** o usuário decide quais flags ligar; depois Boss Raid ("Fase 1: alimentar enfraquece" no Dragão), missão semanal 1-de-3 no Diário, revanche do roubo, teste com 2 jogadores e com conta nova (câmera de chegada).

## A0000. Missão "evolução integrada" (08/11/2026, noite) — ESTADO EXATO

Pedido: alimentação com mais impacto + coleção + competição, tudo ligado ao gigante. Cópia de teste: `scratchpad/studio/FeedAGiant-s1.rbxl`
(código chega pela sincronização do `rojo serve` do usuário). Evidências: `docs/qa/FASE7_EVIDENCIAS.md`; fotos `docs/qa/shots/fase7/`.
Commits no `main`: `5e9f1f2`, `1757569` (selene), `207bdb1`, `a298318` (+ o deste handoff). Push feito. Nada publicado, nenhum upload, nenhum Robux.

### Separação pedida
**Implementado e testado no Studio (1 jogador):**
- **Animações procedurais (P1)** — `GiantAnim.lua` v2 + `GiantPersonality.lua`: respiração/olhar/flutuar, antecipação enquanto a comida voa,
  MORDIDA no instante da chegada (0,6 s, medido), 2 mastigadas, crítica (antecipação maior, mordida dupla, pulo), comemorar (5 estilos por
  espécie), evoluir (agacha, salta girando, aterrissa, ruge), birra de fome (atributo `Mood`), follow-through com mola, poeira. Motivo de ser
  procedural: os modelos no Roblox são 1 MeshPart com **0 ossos** (medido: goblin, troll, dragão, hidra).
- **Bug corrigido:** o gigante voltava à escala 1 e crescia de novo a CADA alimentação (`GiantService.refreshVisual`).
- **Sequência (4.1), características (4.3), crítica (4.4)** — `PlotService.doFeed`, números em `src/shared/GameRules.lua`.
- **Coleção com progresso por espécie + 30%** — `GiantService.grantSpecies/setSpecies`, migração em `DataService.sanitize`.
- **Exposição + renda offline (8 h)** — `RosterService.lua`, botões EXPOR/RECOLHER na Coleção.
- **Batalha por turnos (PvE)** — `GiantBattleService.lua` + `GiantBattle.lua` (3 golpes/estilo, AFK não ganha).
- **Carne Gigante (4.5)** — `MeatService.lua` + `DropService.giveCarried` + `Meat.lua` (selo e seta).
- **Ilha do Dragão** — `World.buildBossIsland` (MAP_VERSION **3**), `BossService` com fases, participação, bônus e pendências.
- **Diário (P5) + recordes (4.6)** — `ProgressService.lua`, `Diary.lua` (o botão DIÁRIO agora abre o painel).
- Testes: verificador **PASS (76 arquivos)**; **39 testes antigos passaram**; simulações no Studio (seções 1-8 das evidências).

**Implementado, parcialmente testado:** 4.2 estágios (já existia; ganhou animação de evolução — só visto no código/medição, não filmado);
personalidade das 12 espécies (só humano e dragão vistos em jogo); renda offline e pendências do Dragão (DataStore real não existe no
Studio: testado com o substituto em memória); tela da batalha em celular (só na janela baixa do Studio, escala 0,6).

**Documentado, não implementado:** PvP por turnos (a função `resolve` serve para 2 lados; falta convite/fila); recompensa por coleção completa;
ranking de batalhas; auras (`RETENCAO_E_FUTURO.md` §4-5).

**Testado com 2 jogadores (depois, com o controle de tela liberado pelo usuário):** disputa da Carne Gigante (soco derruba, o outro pega
e entrega na própria base; os dois cortam do mesmo pedaço) e Dragão com 2 lutadores (vida escala, Player2 sai no meio e fica com
pendência de 422 moedas + 123 XP). Evidências §9. Corrigido: aviso ao cortar carregando algo.

**Bloqueado pelo ambiente:** reentrada de verdade em outro servidor, celular físico/emulador e controle, DataStore real (place de teste não publicado), medir orçamento de triângulos da ilha com a
câmera do jogador.

### Notas de qualidade (ledger)
- Sistema: rodada 0 (3 revisores cegos) 6,3 / 6,25 / 6,3 → mediana **6,3** (15/24); rodada 2 (1 revisor cego, depois das correções) **7,5** (18/24).
- Sistema, painel final (3 revisores cegos, depois do teste com 2 jogadores): 7,5 / 7,5 / 6,25 → mediana **7,5** (18/24). 3ª rodada: parado abaixo de 8,5.
  Painel depois dos testes automáticos (3 revisores cegos): 7,9 / 7,9 / 7,9 → mediana **7,9** (19/24). S6 subiu para 2.
  Para passar de 8,5 faltavam: **S3** — FEITO no emulador de celular (evidências §11: vistas de jogo ≤ 281k/190; ilha +8k/5 draws; animação 0,1 ms com 8 gigantes; placar da batalha corrigido no celular);
  **S1** — reentrada real em outro servidor e DataStore real (place publicado; depende do dono). Corrigido neste painel: prêmio do
  Dragão não se perde se o perfil não estiver carregado (vai para a fila de pendentes).
- Animação: rodada 0 **6,0** (18/30; o revisor errou a soma dos pesos e escreveu 5,6); rodada 2 **6,3** (19/30).
  Bloqueadores: sem rig não há overlap real (P5) e faltam fotos/vídeo das 12 espécies (P1/P2).
- **Abaixo de 8,5 = rascunho.** Os critérios que travam a nota são "testado com 2 jogadores" (S1/S2), "teste automático dos sistemas
  novos" (S6) e, na animação, overlap real (precisaria separar cabeça/corpo no Blender e reenviar).

### Avisos para o próximo
- **Re-assar o mapa** no place oficial (MAP_VERSION 3) só quando o usuário pedir; sem isso o jogo gera o mapa por código (funciona).
- O Dragão **não usa mais o coliseu**: `Main.server.lua` tirou o Boss do `IsArenaBusy`.
- As faixas do TUTORIAL antigo aparecem por cima das janelas novas (foto 02) — problema anterior, não corrigido.
- O botão "GOLPE FORTE" e o remote `RequestGiantSpecial` não são mais usados (o remote ficou na lista só por compatibilidade).

### HUD do celular (08/11/2026, fim da noite)
- **Modo compacto** (`HUD.compact`, tela útil < 500 px de altura): LOJA + MENU com gaveta ao lado; nível recolhido; META no alto;
  escudo embaixo do LOJA/MENU; faixa duplicada do tutorial desligada; LUTAR acima do pulo em tela de toque; **modo luta** na batalha
  por turnos. Evidências §11–§13. Painel de UI: 5,0 (foto de batalha antiga); falta foto nova e painel novo.
- Emulador do Studio: para trocar de aparelho use a lista "Dispositivo" do viewport; os cliques automáticos nos ícones de categoria
  não funcionaram nesta sessão (ficou em Meta Quest 3).

### Painel de admin e bots (08/11/2026, madrugada)
- **Admin:** `src/server/AdminConfig.lua` (dono por UserId, só servidor) + `Services/AdminService.lua` + `client/Controllers/Admin.lua`
  (botão ADM no canto superior direito, só para admins). Testado no Studio: moedas/nível/comida ok; teto de moedas bloqueou;
  admin não se expulsa/bane; aviso filtrado; eventos e bots. Banir não foi aplicado de verdade (no Studio o BanAsync só valida).
  NÃO testado: um não-admin tentando (o caminho existe: tentativa registrada e ignorada).
- **Bots:** `Services/BotService.lua`. Testado: entram sozinhos completando 4 "pessoas", nomes conferidos como livres na Roblox,
  base do fim da lista, gigante próprio, andam com as animações oficiais da Roblox, foram à Carne Gigante e alimentaram o
  gigante (comida voando). NÃO testado: ida ao Dragão pela ponte (pathfinding longo), saída do bot quando o servidor lota.
  Avatares só com cores e proporções (sem roupas do catálogo: não há IDs verificados).

### PRÓXIMA TAREFA PRIORITÁRIA
1. ~~Teste com 2 jogadores~~ FEITO (evidências §9); painel final 7,5. Specs FEITAS: `tests/GameLogic.spec.luau` (33 testes do `src/server/GameLogic.lua`, 72/72 passando; evidências §10). Próximo: medir a ilha e a animação no emulador de celular e um novo painel de 3 revisores.
2. **Testes automáticos** dos sistemas novos em `tests/` (sequência, transferência 30%, renda offline com teto, pendências idempotentes).
3. Fotos das 12 espécies comendo/comemorando (contact sheet) para a rubrica de animação; avaliar separar cabeça/corpo do dragão e do
   humano no Blender (requer novo upload: pedir autorização).
4. Corrigir as faixas do tutorial por cima das janelas.

## A000. Pedido integrado de 08/11/2026 (21 itens): situação de CADA item

Cópia de teste usada: `scratchpad/studio/FeedAGiant-hud3.rbxl` (código sincronizado pela técnica da A7). Fotos em `docs/qa/shots/fase6/`. Todos os commits estão no `main`.

Legenda: ✅ feito e visto no Studio · 🟨 feito, teste parcial · ⬜ não feito (motivo).

| # | Item | Situação | Onde / observação |
|---|---|---|---|
| 0 | Preparação, backups, commits | ✅ | Um commit+push por etapa. Nada publicado, nenhum Robux gasto. Uploads autorizados: 25 imagens da HUD, 8 músicas, 3 modelos refeitos |
| 1 | HUD nova (grafite, botões coloridos, peças recortadas da referência) | 🟨 | `tools/crop_hud2.py` recorta ícones e logo de `feedagiant_hud_transparente.png` para `assets/ui/extra/hud2_*` (UIAssets). Coluna esquerda: `HUD.lua` (logo, moedas, nível/XP/fome, grade de 8 botões, cartão META+tutorial embaixo). LUTAR grande. Janelas em grafite com faixa laranja (`UI.window`). **Falta:** celular físico, emulador de celular e controle físico. O painel de UI deu 4,5 e 5,0 (ver ledger) e as correções da revisão não foram reavaliadas |
| 2 | Skins das 5 Lunchboxes | ✅ | `assets/ui/extra/box_*.png` (arte do usuário). Aparecem na loja, na abertura (`Hatch.lua`, campo `boxId` no `HatchResult`) e na caixa no chão (sprite). A imagem "incomum" não é usada (não existe Lunchbox Incomum) |
| 3 | 8 músicas | ✅ | `Controllers/Music.lua`. Trilha da ilha e do evento com crossfade, fanfarras com prioridade, vitória só no fim da luta, canais Musica/Efeitos/Vozes (SoundGroups). Testado: ilha tocando, fanfarra mítica abaixa a trilha para 0,07. **Não existia** música de combate nem de abertura de caixa no código: não havia nada a preservar (registrado) |
| 4 | Auditoria das chances (itens aleatórios pagos) | ✅ | Ver A000b abaixo |
| 5 | Drops com cronômetro, coleta manual, carregar até a base | 🟨 | `DropService.lua` reescrito + `Drops.lua`. Testado: cronômetro, pegar com E, entrega no pátio, caixa guardada, abrir. **Não testado com 2 jogadores:** soco derrubando a carga e outro jogador pegando |
| 5.1 | Frequência | ✅ | 45 a 80 s (antes 35 a 70), 15% de caixas, Chuva de Comida com 14 itens manuais (antes ~75 automáticos). Tudo em `Config.Drops` |
| 6 | Renda das comidas expostas | ✅ | Já existia (`PlotService.coinsPerSecond`: cps da raridade × espécie × rebirth × humor × nível × passe × grupo). Agora cada comida mostra "+N/s" (valor base) |
| 7 | Lojas separadas | ✅ | `Shop.lua`: LOJA DE LUNCHBOXES (botão LOJA e pad da praça), LOJA DE GIGANTES (estátuas e confirmação), LOJA ROBUX (botão R$ da HUD, de qualquer lugar) |
| 8 | Escudos | ✅ | `ShieldService.lua`: pedestal "RENOVAR ESCUDO" em cada base, só o dono usa, janela com tempo restante, renovar com moedas (2 cliques) ou Super Escudo (Robux, produto existente; com id 0 aparece "em breve"). Preço em `Config.Shield` |
| 9 | Giant Clash com 2 modos | 🟨 | Boxe entre jogadores preservado. Arena dos gigantes: `GiantBattleService.lua` + `Controllers/GiantBattle.lua`. O gigante do jogador (espécie que ele possui) luta contra um selvagem, com vida e força reais e animação PROCEDURAL (os modelos não têm esqueleto no Roblox). GOLPE FORTE na tecla G, no botão Y ou na tela. Moedas e XP com teto de 15 vitórias por dia. **Falta:** gigante contra gigante de outro jogador (ver RETENCAO_E_FUTURO §3) |
| 10 | Cronômetros no mundo | ✅ | Entrada da arena: "DRAGÃO FAMINTO EM 4:28" (o Dragão agora tem horário próprio a cada 15 min, `Config.Boss.Every`). Caldeirão: próximo evento ou evento atual (`EventService`) |
| 11 | Estátuas | ✅ | Pintura real, colisão por cilindro invisível, pedestal redondo em degraus com faixa colorida, placa de madeira, blip + "ENCONTRAR <espécie>" (E/X/toque), que abre a confirmação com preço e atributos. A busca de pedestal na Creator Store **não foi feita**: o pedestal foi construído com peças e materiais do Roblox (sem risco de licença) |
| 12 | Troll, Hidra e Fênix | ✅ | Causa: decimação forte (de 185 a 400 mil para 8 a 11 mil triângulos), sem solda, numa malha "sopa de triângulos" (virava cacos). Correção: `tools/blender/rebake_creature.py` (remesh por voxel + bake da cor original, 16 mil triângulos). Novos IDs em `CreatureAssets.lua`. Antes e depois nas fotos 08 a 11 |
| 13 | Comidas cinza | ✅ | Causa: a cor padrão (163,162,165) da MeshPart multiplicava a textura. `FoodModels.load` agora usa branco; `FoodView` tem mais luz ambiente |
| 14 | Mouse preso | 🟨 | O botão fechar tem `Modal = true`, o que libera o cursor em 1ª pessoa. ESC, Backspace e B do controle fecham a janela de cima; ao abrir, `MouseBehavior = Default`. **Não testado em 1ª pessoa de verdade** (o MCP não trava o mouse) |
| 15 | Indicador dos drops | ✅ | Disco pequeno (3 studs) translúcido na cor da raridade + brilho leve. O círculo Neon de 28 studs saiu |
| 16 | Mapa: sem mar, montanhas, grama | 🟨 | `WorldFx.world`: grama de terreno (superfície em y=0 com camada de ocupação 0,5, medido), ondulações fora das rotas, 72 montanhas cartoon com neve, paredes invisíveis no limite, lagos de água de terreno. **Falta medir** triângulos e draw calls (painel do mundo deu 5,0 pelo portão) |
| 17 | Auras | ⬜ (só avaliação) | `docs/RETENCAO_E_FUTURO.md` §4 |
| 18 | Loop e retenção | ✅ (análise) | `docs/RETENCAO_E_FUTURO.md` |
| 19 | Ordem de prioridade | ✅ | Seguida de P1 a P7 |
| 20 | Testes | 🟨 | Feitos no Studio com 1 jogador. **Não feitos:** 2 clientes, celular, controle, desempenho medido, saída de jogador no meio da batalha de gigantes |
| 21 | Relatório | ✅ | Esta seção + resposta ao usuário |

### A000b. Auditoria de itens aleatórios pagos (item 4)
- **Fonte única:** `LunchboxOdds.lua` calcula as chances por comida. O servidor sorteia com `LunchboxOdds.roll` e a tela mostra `LunchboxOdds.rows` (a mesma função). Cada caixa lista todas as comidas com a % individual na janela CHANCES; o resumo por raridade aparece no cartão antes da compra.
- **Arredondamento:** as porcentagens exibidas são arredondadas (aviso em `LunchboxOdds.Disclaimer`). Na tabela do servidor a soma é exatamente 100%.
- **Modificador ativo:** o evento Lucky Boxes (+50% em Raro ou melhor) muda as chances mostradas na hora (atributo `LunchboxLuckBonus`), e o cabeçalho avisa.
- **Formas de obter caixas:**
  - (a) com moedas;
  - (b) com o produto LuckyBox (Robux, `paidRandom = true`);
  - (c) com moedas compradas com Robux (`Coins10k/100k`, `fundsRandom = true`);
  - (d) ganhas jogando (drops do mapa, Dragão), que não são pagas.
- **PolicyService:** `MonetizationService.canPrompt` recusa (b) e (c) para quem tem `ArePaidRandomItemsRestricted`, e o cliente mostra "INDISPONÍVEL". Assim, para o jogador restrito toda moeda é ganha jogando, e a caixa comprada com moedas não é item aleatório pago. Nenhuma chance foi alterada. **Falta:** o dono confirmar a regra atual na página da Roblox (não foi aberta nesta sessão).


## A00. Teste do usuário em 08/11/2026 (tarde) e o que foi corrigido

O usuário jogou e apontou problemas. Todos foram tratados e testados na cópia `scratchpad/studio/FeedAGiant-boss1.rbxl` (fotos em `docs/qa/shots/fase5/`):

| Pedido / bug | Solução | Onde |
|---|---|---|
| **Nenhum botão da HUD abria nada** | A janela nascia `Visible = true` com o fundo escondido; `if not win.Visible then UI.pop(win)` nunca rodava. Agora nasce escondida | `UI.window` |
| Alimentava do outro lado do mapa | Servidor exige estar perto do próprio gigante (`PlotService.nearGiant`, borda + 28 studs); o botão ALIMENTAR só aparece perto | `PlotService`, `HUD.buildFeedButton` |
| Soco no vento o tempo todo | **Modo de luta**: botão LUTAR/SAIR (canto inferior direito), Q no teclado, Y no controle. Luvas, socos e bloqueio só nele; arena e dragão ligam sozinhos | `CombatService.setFightMode`, `Combat.lua`, remote `RequestFightMode` |
| HUD do topo tampando a tela | Botão ▲/▼ encolhe o painel (fica só moedas + "Nv."). Em telas baixas (< 560 px) já começa encolhido | `HUD.buildTopBar` |
| "Sombra branca rolando" nas barras | Brilho virou reflexo parado | `UI.bar` |
| Boss sem sentido (bloco + bola) | **Dragão Faminto** na arena (malha `crystal-dragon`), barra de vida, pisão com círculo vermelho, prêmio 2x/dia e castigo (come 1 comida). Regras no GAME_BRIEF | `BossService.lua`, `Config.Boss`, `EventService` |
| Sem expectativa de evento | Chip "Próximo evento: X 3:21" no canto superior esquerdo; pisca no último minuto; vira "EVENTO AGORA" | `EventService` (remote `EventSchedule`), `Notifications.lua` |
| Lago e mar geométricos | Água de terreno (lagos + anel de mar) | `src/server/WorldFx.lua` |
| Panela com "fumaça" de peças | Fogo (10 focos), faíscas e vapor de partículas; crescem no evento e o vapor ganha a cor do evento | `WorldFx` (`setEventBoost`) |
| Fogos no servidor para item de valor | Comida Épica+ solta fogos para todos (perto de quem achou e na frente da câmera de cada um) | `ShopService`, `Effects.fireworks`, remote `Fireworks` |
| Progressão pouco clara | Estátuas das 12 espécies em volta da praça com placa de preço; chip "META: virar CRIANÇA no Nv. 10 (faltam 9)" | `WorldFx.statues`, `HUD` |
| Áudios aprovados | 27 sons enviados (`tools/upload_audio.py` → `AudioAssets.lua`) e ligados | `Config.Sounds` |
| Raridade em inglês nos drops | `Locale.rarity` | `DropService` |

**Não testado:** dragão com 2+ jogadores; castigo do dragão (nocaute → comer comida) só pelo código; celular de verdade. O pedido "baú físico" ficou como está: a abertura de caixa atual foi aprovada ("acho muito válido").


## A0. Sessão de 08/11/2026 (autônoma; o usuário dormiu e deu autorização total)

O usuário mandou seguir todas as fases até o fim sem perguntar nada. Ele autorizou o uso da API Key e do Chrome, e pediu git push e backup antes de cada mudança importante (ver A5c).

**Feito e testado nesta sessão** (cada item tem commit no GitHub):

| Item | Onde | Teste |
|---|---|---|
| Céu "dourado" (6 faces enviadas) | `tools/make_sky.py`, `upload_sky.py`, `gen_sky_assets.py`, `SkyAssets.lua`, `LightingRecipes` | Cópia no Studio; fotos em `docs/qa/shots/fase1/ceu/` |
| 16 comidas 3D CC0 (Grab3D), com variações de ouro, cristal, galáxia e cósmica, mais brilho por raridade | `tools/fetch_foods.py`, `prep_foods.py`, `gen_food_assets.py`, `FoodAssets`, `FoodVisuals`, `src/server/FoodModels.lua` (pátio, drops, chuva, comida roubada) | Pátio com 16 comidas; fotos em `docs/qa/shots/fase2/comidas/` |
| Animação procedural dos gigantes (respirar, morder, comemorar) | `src/client/Controllers/GiantAnim.lua` | Medido no cliente: a mordida inclina ~9° |
| Espécies humano (bebê e adulto), jacaré, águia e slime em 3D | Malhas da **IA do Roblox Studio** (`generate_mesh`), IDs em `assets/optimized/assets.json` (`gen-*`); o carregador aceita `mesh:<malha>|<textura>` | 5 modelos trocam sem erro |
| **Bug do gigante afundando ao crescer** (pivô no tronco) | `GiantService.buildGiantModel`: `torso.PivotOffset` nos pés | Pés = topo do pedestal na escala 5,2 |
| HUD nova (pedido "mega importante") | `HUD.lua`, `UI.lua` (`autoScale`/`deviceScale`, ícones de `UIAssets`, 9-slice com `SliceScale`), `Main.client` (área segura) | Fotos em `docs/qa/shots/fase3/` |
| 8 ícones recortados da folha e enviados (fim dos ícones vazios) | `tools/slice_icons.py`, `upload_ui.py`, `UIAssets.lua` | Aparecem na HUD |
| Arena física (coliseu da referência) | `World.buildArena` (φ 22,5°, r 235), **MAP_VERSION 2** | Assada numa cópia; fotos 03 e 04 |
| Luta de boxe **de verdade** na arena | `ArenaService` (`fight`, `duelBody`, `runDuel`), `CombatService` (`HitFilter`, `IgnoreSafeZone`, `CanPunch`, `NoRegen`, `resetFighter`, `hpFraction`) | **Não testada com 2 jogadores** (o controle de tela foi negado: o usuário estava ausente). Revisão independente feita e 11 achados corrigidos |
| Boxe do personagem: luvas (douradas com Boxer Pro) e animações R15 de jab, direto, pesado e reação | `CombatService.equipGloves`; kit make-anim; `assets/anims/*.rbxmx`; `tools/upload_anims.py`; `AnimationIds.lua`; `Combat.lua` (`playAnim`) | Luvas e soco tocando; foto 06 |
| Comida voa até a boca do gigante, com +XP | `FeedFx.lua`; `GiantFed` leva `foodId` e `from` | Voo confirmado no cliente |
| **Fase 4: tutorial do primeiro minuto** (alimentar → pátio → loja → 3 alimentações), com dicas quando o jogador trava, trilha até a loja, Pular com confirmação, progresso salvo e funil `Tutorial_v1` | `src/vendor/shared/FwjelaaTutorial.luau`, `TutorialSteps.lua`, `TutorialService.lua`, `Controllers/Tutorial.lua`; sinais em PlotService e ShopService | Os 3 primeiros passos avançam numa cópia; o último e o novo layout (faixa abaixo da HUD, Pular embaixo à esquerda) **ainda não foram vistos** |
| **Fase 4: fim do encolhimento** (o gigante só fica faminto, nunca perde nível) e produtos FreezeDecay7d/RestoreLevels aposentados (`retired = true`, recusados no servidor) | `GiantService.applyDecay`, `Config.DevProducts`, `MonetizationService.canPrompt`, textos e CSVs | Verificador PASS; **não visto em jogo** |
| **Fase 4: índice de coleção** (17 comidas em 3D, silhueta para as que faltam; espécies tem/falta; selo "!" com comida nova) | `Controllers/Collection.lua`; `profile.discovered` marcado em `PlotService.pushState`; azulejo COLEÇÃO na HUD | Fotos 01 e 02 em `docs/qa/shots/fase4/` |
| **Miniaturas 3D das comidas** (caixa aberta girando, mochila, azulejo, faixa rara) | `src/client/FoodView.lua` (usa `ReplicatedStorage.FoodTemplates`) | Fotos 04 e 07 |
| **Celular:** janelas encolhem para caber (`UI.window` com `FitScale`); a coluna de botões vira grade quando falta altura; faixa do tutorial abaixo do escudo e por baixo das janelas | `UI.lua`, `HUD.buildSideButtons`, `Tutorial.lua` | Foto 01 e 03 (viewport 1690×635, escala 0,6). **Falta celular de verdade** |
| **Juice:** moedas voando até o contador (só ganhos reais, nunca a renda de cada segundo; respeita "movimento reduzido"); faixa "comida rara" com 3D para o servidor (1 a cada 6 s, remote `RareFound`); raridades em português com acento | `HUD.flyCoins`, `Effects.lua`, `ShopService`, `Locale.rarity`/`Locale.upper` | Fotos 05 a 07 |
| **Fase 5: checklist de pré-lançamento** | `docs/PRE_LANCAMENTO.md` | — |
| **Revisão de UI (2 rodadas × 3 revisores cegos)** e 3 passes de correção. O maior achado: a "sombra" de cada botão (filho do botão, com ZIndexBehavior Sibling) cobria o texto do próprio botão, e por isso o X de fechar e os preços da loja estavam invisíveis. | `UI.button` (borda abaixo), `UI.pop/pulse/window`, Shop, Drops, Combat, Collection, Notifications | Notas brutas 5,0/7,1/6,3 → 6,3/6,3/6,3; **final 5,0 por portão** ("sem celular e controle físicos"). A rodada 3 de correções (fotos em `fase4/rodada3/`) **não foi reavaliada**. Ver `.fwjelaa/ledger.jsonl` |
| **Fase 4: luta justa na arena** (150 de vida e força 1 para os dois; compras não pesam no duelo) | `CombatService` (gancho `FairFight`), `ArenaService` | Verificador PASS; **não testada com 2 jogadores** |

**Pendências desta sessão:**
- **Teste com 2 jogadores** da luta real, do soco no ladrão com animação e do empurrão (`AssemblyLinearVelocity` em personagem do cliente pode não funcionar: confirmar).
- Re-assar o mapa no place oficial (`MapService.bake()`), porque o MAP_VERSION subiu para 2. Isso cabe ao usuário, ou ao Claude se ele pedir.
- O place oficial ainda não tem o código novo: o usuário sincroniza com `rojo serve`.
- Painéis de 3 revisores (rubricas world, model, ui, system) para dar nota às Fases 1, 2 e 3.

## A1. Papel e procedimento (obrigatório)

- Você é o **diretor técnico**. Carregue a skill `roblox-director` antes de qualquer trabalho Roblox. Se ela não estiver listada, leia `C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\skill\SKILL.md`.
- Loop de toda tarefa:
  1. pesquisar no vault do Fwjelaa antes (`python "<vault>\_tools\vault.py" "<tarefa>"`);
  2. nunca inventar APIs, IDs ou números; conferir nomes com `studio-kit\tools\api_lookup.py`;
  3. citar as notas usadas;
  4. pré-voo de 3 a 6 linhas;
  5. testar de verdade;
  6. **revisão independente:**
     - 1 revisor cego nas rodadas de correção;
     - 3 revisores cegos para aprovar (agente `rubric-reviewer`), com a mediana por critério;
     - **refaça a soma dos pesos você mesmo**: um revisor já errou a soma, usando 13 em vez de 12;
  7. nota mínima **8,5**; no máximo 3 rodadas de correção;
  8. registrar em `.fwjelaa/ledger.jsonl`.
- **Não use o scaffold de projetos novos.** O projeto já existe.

## A2. Regras e autorizações do usuário

Aprovadas em 07/11/2026 e ampliadas depois:

1. **Commit antes** de toda alteração importante. Testar sempre numa **cópia** do place, nunca no place oficial.
2. Autonomia técnica total, sem consultar o usuário em decisões técnicas rotineiras. Decida e documente.
3. Para mudanças de **economia, monetização, identidade visual ou experiência**: justifique antes. O usuário já aprovou estas:
   - estilo **cartoon pintado** (stylised PBR);
   - clima **fim de tarde**;
   - **5 espécies novas** com preços (tabela de decisões do GAME_BRIEF);
   - seguir a Fase 2.
4. **Nada de publicar o jogo nem gastar Robux.**
5. **Uploads:**
   - o usuário autorizou o envio dos modelos da Fase 2 ("pode seguir, tem total aprovação"; "pode fazer, você tem a key");
   - ele também disse que você pode baixar arquivos CC0 e enviar imagens e modelos para o visual (itens A–C da §A6).
   - O **classificador do modo automático do Claude Code** bloqueou o primeiro upload ("Public Data-Sharing Upload") e só liberou depois da autorização explícita do usuário no chat. **Não contorne bloqueios.** Se bloquear, peça ao usuário.
6. Celular primeiro: orçamento por vista de **500 mil triângulos / 500 draw calls**.
7. Relatórios honestos: o que não foi testado é dito como não testado.

## A3. Situação das fases

| Fase | Situação | Nota |
|---|---|---|
| Diagnóstico e plano | ✅ | — |
| **0 — Fundação segura** | ✅ **Concluída** | **8,75** (system, 3 revisores) |
| **1 — Mundo bonito** | 🟨 Céu de entardecer feito (08/11); falta o novo painel | **7,9** antes do céu |
| **2 — Criaturas de verdade** | 🟩 Modelos de todas as espécies + comidas 3D + animação procedural; falta o painel `model` | não avaliada ainda |
| 3 — Efeitos e juice | 🟧 HUD nova, arena e luta real, boxe, voo da comida (08/11); faltam música, abertura de caixa 3D e o teste com 2 jogadores | não avaliada ainda |
| 4 — Primeiro minuto e retenção | 🟩 Tutorial, fim do encolhimento, luta justa, índice de coleção, telas que cabem no celular (08/11); falta celular de verdade | UI: ver ledger |
| 5 — Pré-lançamento | 🟨 Checklist em `docs/PRE_LANCAMENTO.md`; o resto depende do dono da conta (IDs, questionário, publicação) | — |

## A4. O que existe hoje (resumo técnico)

**Fase 0 (segurança):**
- `DataService` usa o `PlayerData` do fwjelaa: trava de sessão, carga falha nunca salva, `BindToClose`.
- `MonetizationService` usa `Receipts` (idempotente, salva antes de `PurchaseGranted`) e `Policy` (itens aleatórios pagos falham fechado).
- `LunchboxOdds` é a tabela única de chances.
- `Guard.lua`: limite de frequência (token bucket) em **todos** os `OnServerEvent`, índices inteiros e checagem de distância.
- Depósito do roubo conferido no servidor (dentro da própria base + tempo mínimo de viagem).
- Testes: 39 specs (`tests/`, rodar com `require(ServerScriptService.FwjelaaTests.Runner)()`) e teste ao vivo com 2 jogadores.
- Detalhes em `docs/qa/FASE0_EVIDENCIAS.md`.

**Fase 1 (mundo):**
- O mundo é **gerado por código a cada início de servidor**, com semente fixa:
  - `src/server/World.lua`, com o MapKit do fwjelaa vendorizado em `src/vendor/server/MapKit` (Build, Geo, Props, Scatter; licença com crédito ao fwjelaa);
  - `MapService` monta as bases e chama o `World`.
- **Contrato** (não quebrar): `Workspace.Map` precisa ter `ShopPad`, `EventPad` e `Leaderboard1..3` (com `SurfaceGui > List`).
  - Os drops caem entre r 50 e 82 do centro (círculo de raio 14). A chuva de comida cai entre r 40 e 90.
  - O caldeirão ocupa até r ≈ 32, e os mastros das bandeiras ficam em r 34.
- Conteúdo:
  - ilha (raio 470) com praia, água rasa e mar de peça;
  - praça (r 138/120) com faixas-guia;
  - **marco: Caldeirão do Banquete** sobre pedestal de pedra, com fogo Neon e PointLight, sopa, comidas gigantes, vapor e 4 bandeiras;
  - 4 mesas de banquete, loja (norte), evento (sul), 3 placares de madeira;
  - postes com lâmpada Neon;
  - 8 caminhos de pedra até 8 bases com cor-tema (cerca branca, placa nos fundos com contorno no texto);
  - 3 lagos; árvores, arbustos, flores, pedras e colinas espalhados.
- **Luz:** `src/shared/LightingRecipes.lua`, receita **`GoldenAfternoon`**, aplicada pelo `Main.server.lua`. Base: vault "Stylized Lighting Recipes" §3.3, com ClockTime 16,8.
- **Texturas** (08/11, pedido do usuário): materiais do Roblox. Ilha Grass, praia Sand, estrada Cobblestone, borda Slate, praça Pavement, bases WoodPlanks.
- **Orçamento medido:** no máximo ~466 mil triângulos e ~43 draw calls por vista. A água de terreno custava ~290k triângulos e ~300 draws; foi removida.
- Detalhes e fotos: `docs/qa/FASE1_MUNDO_EVIDENCIAS.md` e `docs/qa/shots/fase1/`.

**Fase 2 (criaturas):** detalhes na Parte B §2-F2.
- Pipeline: `tools/blender/prep_creature.py`, com `tools/blender/front_view.py` para prévias de frente.
- **11 modelos enviados e no jogo.** IDs em `assets/optimized/assets.json` e `src/shared/CreatureAssets.lua`, este **gerado** por `tools/gen_creature_assets.py`:

  | Modelo | ID | Triângulos | Usado por |
  |---|---|---|---|
  | dragon | rbxassetid://114192879428967 | 8.000 | espécie dragon (estágio ≥ 2) |
  | baby-dragon | rbxassetid://101061619934373 | 8.000 | dragon no estágio Bebê |
  | phoenix | rbxassetid://88390329506943 | 10.333 | phoenix |
  | stone-golem | rbxassetid://117386809116187 | 8.000 | golem |
  | goblin | rbxassetid://121162892456103 | 7.999 (rig + andar/correr) | goblin |
  | zombie | rbxassetid://72703131003646 | 7.999 | zombie |
  | troll | rbxassetid://107171111505874 | 8.000 (rig + andar/correr) | troll |
  | wyvern | rbxassetid://103967817492078 | 8.000 | wyvern |
  | hydra | rbxassetid://120607062685991 | 11.315 | hydra |
  | crystal-dragon | rbxassetid://123375042698261 | 14.060 | **não usado ainda** (reserva/evento) |
  | cauldron (do usuário) | rbxassetid://74001747238408 | 15.000 | marco da praça (`World.buildCauldron`) |

- `src/shared/CreatureModels.lua` faz o mapa espécie → arquivo (`babyFile`, `yaw`).
- O `GiantService` carrega o Model com `InsertService:LoadAsset` (cache em `ServerStorage.CreatureTemplates`), **esconde o corpo de blocos** (que continua dando a placa, a aura e as partículas) e coloca a malha sobre o pedestal. A escala por nível usa `ScaleTo`. **Sem ID, nada muda.**
- Testado nas 8 espécies: troca em ~0,5 s, nenhum bloco visível, sem erros. A hidra no nível 40 fica com 90 studs.
- Espécies sem modelo, que seguem de blocos: human, gator, eagle, slime.
- **Espécies novas no `Config.Species`:**

  | Espécie | Preço (moedas) | Raridade |
  |---|---|---|
  | goblin | 8.000 | Incomum |
  | zombie | 25.000 | Raro |
  | troll | 75.000 | Épico |
  | wyvern | 220.000 | Lendário |
  | hydra | 600.000 | Mítico |

  Atributos no GAME_BRIEF. A loja lista as espécies automaticamente.

## A4b. Mapa "assado" — o mundo aparece no modo edição (08/11/2026)

**Pedido do usuário:** ver e editar o mundo no Studio **sem dar Play**, no place oficial.

**Como funciona:**
- `MapService.bake()` gera o mundo inteiro no **modo edição**, como pasta `Workspace.Map` com os atributos `Baked = true`, `MapVersion` e `BakedAt`. Também guarda o `Baseplate` antigo em `ServerStorage.LegacyMap` e aplica a luz `GoldenAfternoon`.
- Para assar ou re-assar, na barra de comandos do Studio ou pelo MCP (`execute_luau`, modo Edit):
  `require(game.ServerScriptService.Server.Services.MapService).bake()`
- **Ao rodar** (`MapService.init`):
  - se existir `Workspace.Map` assado com `MapVersion == MAP_VERSION` e completo (ShopPad + Base1..8 com Floor, Zone, GiantAnchor, Sign, Slot1..16), o jogo **reaproveita** esse mapa e não gera outro. O console mostra "[MapService] usando o mapa assado do place (versão N)";
  - se a versão for diferente ou faltar algo, o mapa é descartado **só na execução** e o jogo gera de novo pelo código. O place salvo não muda.
- **REGRA:** sempre que mudar a geometria em `World.lua` ou `MapService` (posições, peças, natureza), **aumente `MAP_VERSION`** (em `MapService.lua`) e re-asse no place oficial. Sem isso, o mapa antigo continua aparecendo.
- **Mudanças feitas à mão** pelo usuário dentro de `Workspace.Map` ficam no place, mas **somem se alguém re-assar**. Para mudanças permanentes, altere `World.lua`. Avise o usuário antes de re-assar se ele tiver editado o mapa.
- Testado numa cópia: assou em 0,4 s com 4.851 peças. Ao rodar, 1 mapa só, o jogador pega a base, o gigante nasce, a placa mostra o nome e a comida vai para o pátio.
- **Assado no place oficial** em 08/11/2026 pelo MCP, a pedido explícito do usuário ("quero isso no oficial"). Foi feito dentro de uma gravação de desfazer ("Assar mapa Feed a Giant"), então dá para usar Ctrl+Z.
  - O place não foi salvo pelo Claude. **O usuário salvou o place oficial** em seguida (08/11/2026), então o mapa assado (versão 1) está no place oficial.
  - Foto: `docs/qa/shots/fase1/07_oficial_modo_edicao.jpg`.
- O código chegou ao place oficial pelo `rojo serve` do usuário. Conferido só por leitura: as fontes de MapService, World e CreatureAssets estavam atualizadas.

## A5. Fatos importantes do ambiente

- **Place oficial:** "Alimente um Gigante", **placeId 115578986093768** (publicado). O usuário o mantém aberto no Studio e sincroniza com **`rojo serve`**: apareceu o aviso "Project 'FeedAGiant' is serving at localhost". **Nunca escreva nesse place pelo MCP.** Inspeção só de leitura, quando o usuário pedir.
  - Ele ainda guarda o `Baseplate` antigo (1200 × 4, topo em y = 2), que enterrava o mundo novo. **Corrigido em código** (`MapService.init` move o `Workspace.Baseplate` para `ServerStorage.LegacyMap`). O usuário ainda precisa confirmar que, depois da sincronização do Rojo, ficou certo no place oficial.
  - Atualize "Fatos do projeto" no `CLAUDE.md` (hoje diz "Place ID: não publicado").
- **Chave da Open Cloud:** `ROBLOX_API_KEY` (variável de usuário). **Nunca imprima nem grave a chave.** Ela tem escopos muito amplos (places, DataStores, Game Passes, `manage-and-spend-robux`...). **Recomende ao usuário criar uma chave só com `asset read/write`.**
- **Modelos brutos:** `assets/Personagens (goblin, dragao)/`, com golem, zumbi e wyvern extraídos em `_extraido/`. São 550 MB, ficam fora do Git e **só existem nesta máquina**.
  - Fonte do caldeirão: `assets/Caldeirão FeedAGiant sem cor.glb` (769k triângulos, ignorado). A versão leve (`.obj` de 20k + `Geometry01_diff.png`) está no Git.
  - Golem, zumbi e wyvern são CC0 da Grab3D, feitos com ajuda de IA.
- Ferramentas:
  - Blender: `C:\Users\Administrador\Desktop\blender-5.4.0-alpha+main.50d477803fa8-windows.amd64-release\blender.exe` (sempre `-b --factory-startup`).
  - Rojo 7.7.1.
  - Verificador: `python "C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\tools\luau_check.py" --project .`. Meta: **overall PASS**; hoje está PASS com 47 arquivos.
- Ruído conhecido no console: `rbxassetid://203785492` e `81504106` vêm do plugin "Ecos Tools", não do jogo. O aviso "Tecnologia de migração de iluminação" ao dar Play é do Studio (o projeto não usa mais `Technology`).

## A5b. Item A — céu de fim de tarde (08/11/2026, em andamento)

- **Pronto no código, falta o upload.**
  - Ferramenta: `tools/make_sky.py`. Ela reaproveita só as funções de geometria do `sky.py` do kit make-map e grava em `assets/sky/<nome>/`; o pack do fwjelaa fica intocado.
  - Céu **`dourado`**: HDRI CC0 `qwantani_sunset_puresky` (Poly Haven), recolorido com um degradê pintado por altura (horizonte dourado → coral → lilás → azul-lavanda no topo). O sol e os realces mantêm a cor original.
  - Faces de 512² com o sol girado para o azimute do sol da receita: **−96,83°** (oeste), medido no Studio com `GetSunDirection`, ClockTime 16,8 e latitude 30.
  - Prévia: `assets/sky/dourado_preview.jpg`.
  - Para refazer: o campo `remake` em `assets/sky/dourado/sky.json`.
- **Envio:** `python -I tools/upload_sky.py dourado` (6 imagens) e depois `python -I tools/gen_sky_assets.py`, que gera `src/shared/SkyAssets.lua`.
  - **Na 1ª tentativa (08/11) o envio foi BLOQUEADO pelo classificador do modo automático ("External System Writes")**, como aconteceu com os modelos. Não contornar: o usuário roda os comandos no terminal ou libera a permissão.
- **Código:** `LightingRecipes.GoldenAfternoon.skybox = "dourado"`.
  - Com as 6 faces em `SkyAssets`, `apply()` põe as faces no `RecipeSky`, desliga o disco do sol do Roblox (ficaria a 18° de altura, longe do sol pintado a 2,7°; seriam dois sóis) e afina as nuvens 3D (Cover 0,32).
  - **Sem IDs, nada muda** (céu padrão). O atributo `RecipeSky.Skybox` diz qual céu está ativo.
- Depois do upload: testar numa cópia, tirar as fotos do painel world (as mesmas vistas de `docs/qa/shots/fase1/`), conferir que o sol pintado bate com a direção das sombras, e chamar um painel de 3 revisores.

## A5c. Autorizações e pedidos do usuário (08/11/2026, noite)

**Autorização ampliada** (palavras do usuário):
- "sobre as imagens de agora e as próximas pode enviar eu permito";
- "siga todas as fases até o final, sem perguntar-me nada. Você tem autorização total de usar API Key do creator hub roblox e usar chrome; caso vá fazer alguma mudança importante, faça git push e backup";
- "não quero mais que você me chame, nem peço opinião alguma".

Continua proibido **publicar o jogo e gastar Robux**, porque isso não foi pedido.

**Pedidos novos, encaixados nas fases:**
1. **HUD bonita, "mega importante".** As imagens de referência estão em `assets/` (ui/logo, icons_sheet, panel_9slice e outras do usuário). Vai para o **início da Fase 3**, antes dos efeitos. Use as skills `fwjelaa-ui-builder` e `quality-score` (rubrica `ui`).
2. **Mecânica de boxe do personagem + luta de verdade nas arenas.** Hoje o duelo da arena é **encenado**: o servidor calcula o vencedor e manda os ticks. O pedido é luta real com os socos do CombatService dentro de uma arena física. Vai para a **Fase 3**, junto com os VFX de golpe (skills `fwjelaa-system-builder`, `fwjelaa-vfx`, `make-anim`).
3. **Arena física, a partir da referência que o usuário mandou** (imagem no chat em 08/11; descrição aqui porque o arquivo não ficou salvo):
   - coliseu redondo de **pedra lilás-acinzentada** em blocos, muro externo com painéis;
   - **arquibancadas de madeira** em 3 a 4 degraus por setor, com escadas entre os setores;
   - **8 braseiros de bronze com fogo** sobre pilares de pedra;
   - **bandeiras altas** alternando vermelho e azul, com coroa dourada, também penduradas no muro externo;
   - **camarote real** no fundo (painel azul com coroa dourada grande);
   - **portão principal** com arco de madeira e coroa dourada, e rampa de pedra na frente;
   - **chão de areia/terracota** com anéis concêntricos e uma **coroa grande pintada** no centro.

   A versão cinza (sem textura) mostra a forma: anel externo baixo, 8 pilares, 2 portões em arco opostos, arquibancadas em leque e chão com 2 anéis.

## A6. PRÓXIMOS PASSOS (em ordem)

O usuário pediu (08/11): "te permito seguir a fase". Antes disso ele quis o conserto do chão (feito) e perguntou o que mais você planeja para o visual, que "ainda está bem fraco". A lista abaixo foi apresentada a ele. **A última pergunta, "visual primeiro (A–C) ou seguir a Fase 2", ficou sem resposta.** Pergunte no início da sessão, ou siga a ordem abaixo se ele disser para seguir.

**Visual (Fase 1, para sair de 7,9). Os revisores pedem principalmente W4 (clima), W3 (coesão) e W5 (densidade):**
- **A. Céu de entardecer** (o bloqueador do W4 nos 3 revisores: "o céu de cima continua azul de meio-dia"):
  - kit make-map: `cd "<pack make-map>" && python kit/tools/run.py sky <nome> --from polyhaven:<hdri>_puresky --azimuth <graus>`;
  - gera 6 faces de **512²** (1024² não renderiza, medido pelo kit);
  - precisa de upload de 6 imagens; o usuário autorizou;
  - depois, adicionar `Sky` com os IDs em `LightingRecipes.GoldenAfternoon.sky`.
- **B. Texturas pintadas próprias** (MaterialVariant) para grama, estrada e praça:
  - `run.py material <nome> --from ambientcg:<ID> --tint "#hex"`;
  - aplicar via `MaterialService`;
  - hoje são os materiais padrão do Roblox, meio realistas.
- **C. Árvores, arbustos e pedras low-poly CC0** (Poly Pizza / Quaternius / Kenney) no lugar das primitivas de bolas:
  - passar pelo `prep_creature.py`, com altura e triângulos adequados;
  - subir como Model;
  - trocar no `World.buildNature`.
  - Manter o orçamento de 500k triângulos por vista.
- **D. Relevo:** colinas e vales com terreno. Cuidado com custo e com o contrato de alturas.
- **E. Grama 3D do terreno (`Terrain.Decoration`):** não é scriptável e custa 180 a 310k triângulos por vista. Só com cautela e se o usuário quiser; ele liga no Studio.
- Depois de cada passo: fotos com avatar e UI escondida, orçamento por vista, gates (rotas, props flutuando) e novo painel de 3 revisores.

**Fase 2 (continuação):**
1. **Painel de qualidade dos modelos** (rubrica `model`, 3 revisores cegos) com as prévias em `assets/optimized/previews/` e capturas no jogo.
2. **Animações** (skill `fwjelaa:make-anim`): idle, comer, comemorar e ficar bravo.
   - Troll e goblin já têm rig com andar e correr.
   - Os outros são estáticos: avaliar rig simples (Blender) ou "animação" procedural (bob, escala e rotação por código), que é mais barato.
   - Fazer o gigante tocar uma animação ao ser alimentado.
3. **Comidas 3D** (maçã, pizza, sushi...) no lugar das bolas e cubos: um lote de props (skill `fwjelaa-blender-modeling`, ou CC0), enviado como Model e trocado em `PlotService` / `DropService` / `Hatch`.
4. **Troll:** pequenas falhas na superfície por causa da decimação forte de malha "sopa de triângulos". O vault recomenda retopologia para malhas que deformam.
5. **Modelos para human, gator, eagle e slime**, que hoje são de blocos.
6. **Conferir o `yaw`** de cada espécie no jogo. O dragão com 0° ficou bom; confira hidra, wyvern e golem.

**Outras pendências do usuário:**
- Lucky Box comprada por conta com restrição a itens aleatórios pagos (`PromptProductPurchase` direto pelo cliente): o recibo não pode ser recusado. Proposta: entregar uma comida Rare fixa. **Falta a decisão do usuário.**
- ~~Fase 4: suavizar o encolhimento e o pay-to-win da arena~~ → feito em 08/11 com a autorização total do usuário; justificativas no `GAME_BRIEF.md`.

## A7. Armadilhas medidas (economizam horas)

**Studio:**
- Tem **limite de ~10 janelas**, e a RAM acaba com muitas cópias de teste (chegou a 2,9 GB livres de 32).
  - **Feche cada cópia ao terminar:** Arquivo → Fechar local → **Não salvar**.
  - `Stop-Process` em processos do Studio é **bloqueado** pelo classificador. `CloseMainWindow` funciona, mas abre o diálogo "Salvar alterações?".
- Abrir um `.rbxl` (`Invoke-Item`) pode carregar dentro de uma janela vazia existente.
- **Atualizar o código de uma cópia JÁ ABERTA sem abrir janela nova (08/11, funciona):**
  1. `rojo build <projeto com uma Folder raiz: Shared=src/shared, Server=src/server, Client=src/client, fwjelaaShared=src/vendor/shared, fwjelaaServer=src/vendor/server> -o "C:/Program Files/Roblox/Versions/<versão do Studio>/content/fagsync/fagsync.rbxmx"` (a pasta `content` do Studio é gravável nesta máquina);
  2. no `execute_luau` (Edit): `game:GetObjects("rbxasset://fagsync/fagsync.rbxmx")[1]` e copiar o `Source` de cada script para o lugar certo (criar os que faltam);
  3. Play. O `HttpService` do assistente **não** acessa o GitHub (lista de domínios), por isso este caminho.
- Para fotografar algo que dura poucos segundos (abertura de caixa, faixa): disparar o remote no `execute_luau` do Server com `task.wait(≈2)` no fim e chamar `screen_capture` logo depois.
- **Teste com 2 jogadores:** seletor de modo no topo à esquerda → "Servidor e clientes", contador de jogadores → 2, Play. O MCP lista servidor e clientes como instâncias separadas (o id do servidor descobre-se testando `datamodel_type: Server`). Os jogadores de teste têm **UserId negativo**.
- `require` pelo `execute_luau` usa um **cache de módulos separado** do jogo. Para ler ou mudar o estado real, **injete um `Script`** no `ServerScriptService` da cópia e devolva o resultado por atributo.
- Chamadas MCP demoram segundos. Testes que dependem de tempo (anti-teletransporte, por exemplo) devem rodar **dentro de um único script** no servidor.
- **Fotos:**
  - trave a câmera do cliente com `RunService:BindToRenderStep` (o Assistente do Studio reseta o `CameraType`);
  - esconda `ScreenGui` e `BillboardGui` só no cliente;
  - traga a janela para a frente com PowerShell user32 `ShowWindow` + `SetForegroundWindow`;
  - capture com `computer-use` (zoom na região do viewport).
- O aviso "Tecnologia de migração de iluminação" aparece a cada Play: botão "Continuar".
- Sob pouca memória, a qualidade automática encurta a distância de desenho e some coisa de longe. Para medir orçamento, fixe a qualidade (`settings().Rendering.QualityLevel = Enum.QualityLevel.Level05` / `Level10`) e devolva para `Automatic` no fim.

**Código:**
- Python `write_text` no Windows grava CRLF: rode `luau_check.py --fix-format`.
- Heredocs grandes no Bash com Luau dentro às vezes não parseiam: escreva o `.py` com a ferramenta Write.
- Hook do fwjelaa: os avisos `findfirstchild-chain` em `GiantService` (piscar dos olhos) são falsos positivos antigos, de nível "info".

**Blender:**
- Malha "sopa de triângulos" (troll: 15.831 ilhas) só reduz **sem solda** (`--merge 0`).
- Com o modificador de **armadura** antes do Decimate, a redução trava em ~32k: o pipeline remove a armadura, decima e recoloca.
- Exportar com mais de 4 influências por vértice gera aviso: o pipeline limita a 4 e normaliza.
- Penas e escamas soltas (fênix, hidra, dragão de cristal) não descem de 10 a 14k: é o piso possível.

**Visual:**
- Os revisores penalizam "dia padrão", campos vazios, primitivas sem textura e letreiros flutuantes nas fotos.
- Fotos com o avatar no quadro ajudam o critério de escala (W6).

## A8. Como verificar rápido que está tudo bem (comandos)

```
cd "C:\Users\Administrador\Pictures\FeedAGiant PRINCIPAL"
python "C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\tools\luau_check.py" --project .
rojo build test.project.json -o <scratchpad>\FeedAGiant-testN.rbxl   (abrir a cópia no Studio; nunca o place oficial)
python -I tools/gen_creature_assets.py      (regenera CreatureAssets.lua a partir de assets/optimized/assets.json)
python -I tools/upload_models.py [nome]      (envia .glb novos de assets/optimized; pula os que já têm ID)
blender -b --factory-startup -P tools/blender/prep_creature.py -- <entrada> <saida.glb> <preview.png> --tris 8000 --height 6 [--merge 0] [--yaw 0] [--tex 1024]
```

---

# PARTE B — HISTÓRICO DETALHADO (sessões de 07–08/11/2026)

> As seções abaixo foram escritas durante as sessões, em ordem não cronológica. Em caso de conflito, **vale a Parte A**.
> As seções numeradas antigas 4 a 10 descrevem o estado **do recebimento do projeto** e estão obsoletas, mantidas só como registro.

## 2a. Atualização de 07/11/2026 (madrugada): fim de tarde aplicado; Fase 2 iniciada

**O que o usuário decidiu:** clima de **fim de tarde** e, ao terminar, seguir **direto para a Fase 2**.

**O que foi feito:**
- Receita `GoldenAfternoon` em `src/shared/LightingRecipes.lua`. Base: vault §3.3 Golden hour, com ClockTime 16,8 e ambiente ~20% mais alto para não escurecer.
- O `Main.server.lua` aplica essa receita.
- Grama #7FA34E, menos saturada; postes de madeira com lâmpada Neon.
- Decisão registrada no GAME_BRIEF (§5 e tabela de decisões).

**Resultado medido:**
- Painel world: **7,9** de novo, mediana [2,2,1,1,1,2].
- Orçamento: 176k a 466k triângulos e 23 a 38 draw calls por vista.
- Gates OK: 24/24 rotas, 0/285 props flutuando.
- Fotos em `docs/qa/shots/fase1/`; as versões anteriores estão em `rodada1..3/`.

**Bloqueador consensual (W4):** o **céu de cima continua azul**, porque o céu padrão do Roblox não muda de cor. A solução é uma caixa de céu de entardecer (`make-map` `run.py sky` com HDRI CC0, 6 faces de 512²). Isso precisa de **upload de 6 imagens**, que depende de autorização do usuário. O W3 (sem texturas pintadas) se resolve com os assets da Fase 2.

**Fato novo:** existe um place publicado **"Alimente um Gigante" (placeId 115578986093768)**. Ele esteve aberto no Studio em 07/11/2026 (aberto pelo usuário) e fechou em seguida. Nenhuma ferramenta escreveu nele. Atualize "Fatos do projeto" no CLAUDE.md quando o usuário confirmar que é este jogo.

**Novos assets do usuário em `assets/` (fora do Git até decidir):**
- `Caldeirão FeedAGiant sem cor.glb`: 769 mil triângulos, versão-fonte sem material.
- `Caldeirão com textura basica + fogo.obj` + `.mtl` + `Geometry01_diff.png` (1024²): **20.000 triângulos exatos**, cerca de 21 × 19 × 13 de tamanho.
- `Caldeirão FeedAGiant referencia textura e cor.png`: cobre com rachaduras e alças de argola.
- Esses arquivos são o candidato para substituir o caldeirão de primitivas. Usá-los **exige upload do modelo**, que precisa de autorização.

**Fase 2 (em andamento):** veja §2-F2 logo abaixo.

### §2-F1b. Correção no place oficial + texturas (08/11/2026)
- **Bug relatado pelo usuário no place oficial "Alimente um Gigante":** árvores e estrada "enterradas", estrada se fundindo com a grama.
  - **Causa (inspeção só leitura no place oficial):** o place guarda o `Baseplate` antigo, 1200 × 4 centrado em y = 0, com topo em **y = 2**. O mundo novo tem o chão em y = 0, então tudo ficava 2 studs abaixo.
  - O place de teste não mostrava isso porque o Baseplate saiu do `*.project.json`.
  - **Correção em código** (`MapService.init`): ao iniciar, um `Workspace.Baseplate` existente vai para `ServerStorage.LegacyMap`; nada é apagado. Testado reproduzindo o Baseplate oficial numa cópia: saiu, e o chão volta a ser a ilha.
  - **O place oficial não foi alterado pelo Claude.** O usuário sincroniza com `rojo serve`.
- **Texturas** (pedido do usuário: "grama natural, não liso"), com materiais do próprio Roblox, sem upload:
  - ilha `Grass`, praia `Sand`;
  - estrada `Cobblestone` com borda de `Slate`;
  - praça `Pavement`;
  - piso das bases `WoodPlanks` (sem studs);
  - pedestal e fogueira do caldeirão `Slate`;
  - manchas de grama `Grass`, borda dos lagos `Sand`.

  Foto: `docs/qa/shots/fase1/06_texturas_grama_pedra.jpg`.

### §2-F2. Fase 2 — criaturas (07/11/2026, madrugada)

**Aprovação do usuário:** "pode seguir, tem total aprovação". Vale para as espécies novas e os preços.

**Feito:**
- **Pipeline Blender sem interface:** `tools/blender/prep_creature.py`.
  - Junta as malhas e decima até o alvo (busca binária).
  - Deixa só a textura de cor, com 1024 px, rugosidade 1 e metal 0.
  - Ajusta a altura em studs, com os pés em Z = 0, e exporta GLB com prévia.
  - Com esqueleto: tira a armadura durante a decimação e recoloca depois; limita os pesos a 4 e normaliza.
  - `--merge 0` pula a solda. O troll é uma "sopa de triângulos" (15.831 pedaços) e só reduz sem solda.
  - `tools/blender/front_view.py` faz a vista de frente para conferir a orientação.
- **11 modelos em `assets/optimized/`** (prévias em `previews/`):

  | Modelo | Triângulos |
  |---|---|
  | dragon | 8.000 |
  | baby-dragon | 8.000 |
  | crystal-dragon | 14.060 |
  | hydra | 11.315 |
  | phoenix | 10.333 |
  | goblin | 7.999 (rig + andar/correr) |
  | troll | 8.000 (rig + andar/correr) |
  | stone-golem | 8.000 |
  | zombie | 7.999 |
  | wyvern | 8.000 |
  | cauldron (caldeirão do usuário) | 15.000; 64,7 × 57 × 38 studs, no lugar do marco de primitivas |

  Os que passam de 8 mil têm muitas penas ou escamas soltas; o mínimo possível é esse. Todos ficam abaixo de 20 mil.
  Golem, zumbi e wyvern são **CC0**, da Grab3D, feitos com ajuda de IA (a licença está no zip original).
- **Espécies novas em `Config.Species`:** goblin, zombie, troll, wyvern e hydra, com os preços e atributos do GAME_BRIEF. Testado: compra e equipa sem erro.
- **Código:**
  - `src/shared/CreatureModels.lua` liga cada espécie a um arquivo, com o bebê-dragão no estágio Bebê e um `yaw` por espécie.
  - `src/shared/CreatureAssets.lua` é **gerado** por `tools/gen_creature_assets.py` e hoje está vazio.
  - O `GiantService` carrega o Model com `InsertService:LoadAsset` (com cache em `ServerStorage.CreatureTemplates`), esconde o corpo de blocos e coloca a malha sobre o pedestal.
  - **Sem ID, nada muda** (testado).

**Atualização (madrugada de 08/11/2026): upload FEITO e testado no Studio.**
- O usuário disse "pode fazer, você tem a key", e o upload rodou com a autorização explícita dele. Os 11 IDs estão em `assets/optimized/assets.json` e `src/shared/CreatureAssets.lua`.
- **Testado (place de teste 14 e 15):** as 8 espécies com modelo trocam para a malha 3D em ~0,5 s, sem nenhum bloco visível.
  - O dragão usa o bebê-dragão no nível 1 e o dragão adulto a partir do estágio seguinte.
  - A escala por nível funciona: a hidra no nível 40 fica com 90 studs.
  - O console não mostra erros.
- **Bug corrigido:** o "piscar" dos olhos (loop no fim do GiantService) re-mostrava os olhos de bloco por cima do modelo 3D. Agora ele não pisca quando há `CreatureMesh`, nem no meio de uma piscada.
- **O caldeirão do usuário virou o marco:** `World.buildCauldron` carrega `cauldron` (InsertService) e substitui pernas, corpo, faixas, borda e alças. A largura é a mesma (38 × 1,7) e a base apoia na fogueira. Sopa, comidas, concha e vapor acompanham a borda nova. Sem ID, o caldeirão volta a ser de primitivas.
- O `yaw` 0 dos dragões ficou bom no jogo: o dragão olha para quem chega pela praça.
- Fotos em `docs/qa/shots/fase2/`.
- **Fato:** apareceu no Studio um aviso de que um projeto Rojo "FeedAGiant" está sendo servido em localhost (provavelmente o usuário sincronizando um place). Nada foi conectado.

**Histórico — o bloqueio do upload:** `python -I tools/upload_models.py` foi **negado pelo classificador do modo automático** do Claude Code ("Public Data-Sharing Upload"). Para seguir, há dois caminhos:
- o usuário roda os dois comandos no terminal: `python -I tools/upload_models.py` e depois `python -I tools/gen_creature_assets.py`;
- ou o usuário adiciona uma regra de permissão para esse comando.

Depois disso: compilar o place de teste, conferir cada criatura no Studio (escala, frente, `yaw` dos dragões, que ficaram ~45° na vista de frente) e trocar o caldeirão de primitivas pelo modelo.

**Alerta de segurança:** a chave em `ROBLOX_API_KEY` tem escopos muito amplos: places, DataStores, Game Passes, `legacy-universe.badge manage-and-spend-robux`, `universe-places write`, entre outros. O ideal é criar uma chave só com `asset read/write` para uploads.

**Ainda falta na Fase 2:**
- testar no Studio, depois do upload;
- animações idle, comer, comemorar e bravo (skill `make-anim`; troll e goblin já têm andar e correr);
- comidas 3D;
- revisar o troll, que tem pequenas falhas na superfície por causa da redução forte; o vault recomenda retopologia para malhas que deformam;
- modelos para humano, jacaré, águia e slime, que hoje continuam de blocos.

## 2b. Atualização de 07/11/2026 (noite): FASE 1, MUNDO NOVO (7,9; abaixo de 8,5)

- **Estilo de arte decidido pelo usuário:** cartoon pintado (stylised PBR). Está registrado no GAME_BRIEF §5 e no CLAUDE.md.
- **Luz:** `src/shared/LightingRecipes.lua` (receita Bright cartoon do vault, ajustada para sol de tarde e tom quente).
- **Mundo novo gerado por código:** `src/server/World.lua`, com o MapKit do fwjelaa em `src/vendor/server/MapKit`.
  - Ilha com praia e mar só de peça (a água de terreno custava cerca de 300 draw calls por vista).
  - Praça com o Caldeirão do Banquete: pedestal, fogo brilhando e 4 bandeiras.
  - Mesas de banquete, postes de luz, 3 lagos e bases com cor-tema e placa nos fundos.
  - O Baseplate saiu dos project.json.
  - Os drops agora caem a partir de r 50, e a chuva de comida a partir de r 40.
- **Gates:** 24/24 rotas de caminhada, 0 props flutuando, faixa de drops livre, 4.860 peças, no máximo 467k triângulos e 43 draw calls por vista (alvo de celular: 500k e 500).
- **Painel world:** 5,0 → 7,9 → 7,9. As 3 rodadas de correção foram usadas. Ledger e fotos em `docs/qa/FASE1_MUNDO_EVIDENCIAS.md` e `docs/qa/shots/fase1/`.
- **Bloqueadores, com mediana W3 = 1 e W4 = 1:**
  - **W3:** tudo são primitivas sem textura pintada. Isso se resolve com os modelos e MaterialVariants pintados da Fase 2.
  - **W4:** os 3 revisores dizem que a luz ainda parece "dia padrão". Ajustes sutis não movem a nota. A sugestão deles é uma luz de fim de tarde mais forte (ClockTime 16,5 a 17, névoa e horizonte alaranjados, grama menos saturada). **Isso muda o clima e a identidade visual, então é decisão do usuário.**
- **Próxima tarefa:** perguntar ao usuário se quer (a) aceitar 7,9 por enquanto e seguir para a Fase 2, que deve subir o W3, ou (b) testar o clima de fim de tarde mais forte no mundo atual.
- **Ambiente:** o Studio tem limite de janelas abertas e fica sem memória com muitas cópias de teste. Feche cada cópia ao terminar: Arquivo → Fechar local → Não salvar.

## 3. Atualização final de 07/11/2026: FASE 0 CONCLUÍDA (8,75)

- Teste com 2 jogadores feito ao vivo (Studio → Servidor e clientes, com controle de tela autorizado pelo usuário). Roubo, soco no ladrão, depósito anti-teletransporte, duelo completo e saída no meio do duelo funcionam. Detalhes em `docs/qa/FASE0_EVIDENCIAS.md`.
- 2 bugs achados e corrigidos: o aviso "Ninguém no círculo" se acumulava no painel de disputa (vinha da v4); o duelo recusava os ids negativos dos jogadores de teste.
- Painel 3: [2,2,1,2,1,2] = **8,75**. Ledger atualizado.
- **Como testar 2 jogadores:** seletor do Studio → "Servidor e clientes", contador de jogadores → 2, Play. O MCP lista servidor e clientes como instâncias separadas; os `require` de um script injetado no servidor compartilham o estado do jogo.
- **Pendências:** (1) decisão do usuário sobre a LuckyBox comprada por conta restrita (abaixo); (2) medir o desempenho no celular ou no emulador; (3) checagem de velocidade no servidor (drop/soco), da auditoria.
- **Próxima tarefa:** Fase 1 (mundo bonito). Ela está bloqueada pela decisão de estilo de arte (§6, pendente 1): apresentar as opções ao usuário antes de construir.

## 3a. Atualização de 07/11/2026, 2ª sessão: Fase 0 testada, nota 7,5 (abaixo de 8,5)

**Estado:** itens 0.2 a 0.7 implementados **e testados** em play solo. Detalhes e números em `docs/qa/FASE0_EVIDENCIAS.md`.
- Verificador Luau **overall PASS** (39 arquivos); 39 specs passam; falhas de carga e de armazenamento simuladas se comportam certo; fuzz com 1.971 chamadas sem erro no servidor; 60 fps no PC.
- Rodada de correção 1 feita (limite de frequência em todos os remotes, índices inteiros, depósito do roubo conferido no servidor, mochila sem apagar itens, caixa paga sem bônus de evento, arena/combate/roubo mais robustos). 3 sons quebrados da caixa (IDs da v4) trocados por `Config.Sounds`.
- Painel de 3 revisores cegos: 6,25 → **7,5**. Ledger em `.fwjelaa/ledger.jsonl`.
- **Bloqueador (S1):** teste com 2 jogadores (roubo, depósito, soco no ladrão, duelo, sair no meio). O MCP só faz play solo e o controle de tela do Studio foi negado nesta sessão. Precisa do usuário rodar (Studio → Testar → Clientes e servidores, 2 jogadores) ou autorizar o controle de tela.
- Restam 2 rodadas de correção (máx. 3).

**Pendências que dependem do usuário (condição 4, economia/monetização):**
1. LuckyBox comprada direto pelo cliente (`PromptProductPurchase`) por conta com restrição de itens aleatórios pagos: o recibo não pode ser recusado. Proposta: entregar um item fixo equivalente (ex.: uma comida Rare escolhida) em vez do sorteio. Precisa de aprovação.
2. Itens do 0.8 ainda não tratados (médios da auditoria): checagem de velocidade/teleporte no servidor para quem disputa drop e no alcance do soco; roubo/duelo mexem em dois perfis sem transação (inerente, só registrado).

**Próxima tarefa exata:** com o teste de 2 jogadores feito (pelo usuário ou com acesso à tela), registrar o resultado em `FASE0_EVIDENCIAS.md`, corrigir o que falhar e chamar novo painel de 3 revisores. Com ≥ 8,5, marcar a Fase 0 como concluída.

## 3b. Atualização de 07/11/2026 (sessão interrompida por limite de uso)

**Itens 0.2 a 0.7 implementados no código, mas AINDA NÃO TESTADOS no Studio.** Último commit: "WIP Fase 0.3–0.7".

**O que foi feito:**
- **0.2:** concluído. Criados `GAME_BRIEF.md`, `CLAUDE.md`, `selene.toml` e `stylua.toml`, mais um commit separado só com a formatação.
- **Módulos do Fwjelaa vendorizados:**
  - `src/vendor/shared` (vira `ReplicatedStorage.fwjelaa`): Signal, Odds e RateLimit;
  - `src/vendor/server` (vira `ServerScriptService.fwjelaa`): PlayerData, Receipts, Policy e StudioMemoryStore;
  - ajustes locais documentados no cabeçalho de cada arquivo;
  - `test.project.json` mapeia `tests/` para `ServerScriptService.FwjelaaTests`.
- **0.3:** `DataService` virou uma fachada sobre o PlayerData, mantendo a mesma interface. Também:
  - `DataService.start()` é chamado no fim do `Main`;
  - `Config.MaxInventory = 300`;
  - `PlotService.giveFood(player, id, force)` retorna boolean.
- **0.4:** `MonetizationService` reescrita sobre Receipts e Policy. Os passes são reconferidos na entrada. "Trocar Espécie" virou **Ficha de Espécie** (`profile.speciesTokens`), em que o jogador escolhe a espécie.
- **0.5:** `src/shared/LunchboxOdds.lua` é a tabela única de chances, com a mesma distribuição da v4 (verificada no teste `tests/LunchboxOdds.spec.luau`). A loja ganhou o botão CHANCES. Os produtos `paidRandom`/`fundsRandom` ficam bloqueados para quem tem restrição.
- **0.6:**
  - bastão removido (agora ladrão socado derruba a comida);
  - `src/server/Guard.lua` confere distância nos cliques e toques;
  - o roubo reconfere escudo e uid no fim e bloqueia depósito por teleporte;
  - o drop confere a altura;
  - os códigos foram para `src/server/Secrets.lua`;
  - argumentos validados na Arena e no Combat.
- **0.7:** `leaderArena` criado. O tick manda só `{coins, cps, hunger}`, e o estado completo vai quando algo muda e a cada 15 s. `IsInGroup` é guardado em cache.

**Próxima tarefa exata:**
1. Rodar o verificador. Faltavam:
   - um `fwjelaa-ignore` justificado em `EventService.lua:68` (o Touched é ligado por peça, que é destruída depois);
   - os avisos `UDim2.fromScale`/`fromOffset` do selene;
   - as variáveis sem uso `stBg`, `hBg` e o `i` de `MapService`;
   - o `elseif` vazio em `Arena.lua:258`;
   - talvez `Remotes.GetFullState.OnServerInvoke` em `PlotService` precise de cast.
2. Montar o place de teste: `rojo build test.project.json -o <scratchpad>/x.rbxl`, abrir e rodar `require(game.ServerScriptService.FwjelaaTests.Runner)()`.
3. Play test: entrar, comprar caixa, alimentar, depois testar `MemoryStoreFailNext` e `SimulateLoadFailure`, e por fim 2 jogadores (roubo, soco no ladrão).
4. Revisão independente (rubrica `system`) e registro no ledger.

## 4. Próxima tarefa exata (original — OBSOLETA)

**Fase 0, item 0.2.** Criar `docs/GAME_BRIEF.md`, `selene.toml` e `stylua.toml`, rodar o verificador e confirmar que restam só erros reais de código, não de configuração. Comando:

```
python "C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\tools\luau_check.py" --project "C:\Users\Administrador\Pictures\FeedAGiant PRINCIPAL"
```

Depois, seguir para **0.3 (DataService)**, que é o problema mais grave do jogo. Antes de mexer em dados, rodar o loop de alto risco: ler `## Common mistakes` e `## Checklist` de *Session Locking and Profile Libraries* e *DataStore Fundamentals* no vault, e usar a skill `fwjelaa-datastore-safety`. Fazer um commit antes de cada item.

## 5. Arquivos modificados ou criados até agora (no recebimento — OBSOLETO)

| Arquivo | O quê |
|---|---|
| `docs/DIAGNOSTICO_E_PLANO.md` | Novo. Diagnóstico completo e plano das 5 fases |
| `docs/HANDOFF_NEXT_SESSION.md` | Novo. Este arquivo |
| `.gitignore` | Novo. Ignora as travas do Studio e os modelos 3D brutos (§7) |

**Nenhum arquivo de código (`src/`), place (`.rbxl`/`.rbxlx`) ou asset foi alterado.** Todo o código está como foi recebido (Config v4.0.0).

## 6. Decisões

**Tomadas:**
- Ordem: Fase 0 primeiro (aprovado pelo usuário).
- Os modelos 3D brutos ficam fora do Git: são 550 MB e ninguém trabalha neles nesse formato. Na Fase 2, os modelos **otimizados** (≤ 20 mil triângulos) entram no repositório.
- Conflito de fontes: o revisor disse que `ClickDetector.MaxActivationDistance` é validado pelo servidor, mas o vault (*Clickable and Interactive Parts*, rótulo Roblox docs) diz que **não**. Vale o vault: fazer a checagem de distância no servidor, que é barata.

**Pendentes** (não bloqueiam a Fase 0):
1. **Estilo de arte** (bloqueia a Fase 1): (A) cartoon estilizado, que recomendei por ser legível no celular e próprio do público de simuladores, ou (B) semi-realista, como os modelos atuais. É mudança de identidade visual, então segue a condição 4: apresentar a justificativa e confirmar antes.
2. **Suavizar o encolhimento e o pay-to-win da arena** (Fase 4): é mudança de economia e experiência, então também segue a condição 4.
3. **Uploads** (sons, modelos, imagens): só com autorização explícita (condição 7).

## 7. Problemas encontrados

Detalhes completos com arquivo e linha estão em `docs/DIAGNOSTICO_E_PLANO.md` §3.

- **Críticos:**
  - C1: carregamento que falha salva o perfil padrão por cima do save real (`DataService.lua:125-151`).
  - C2: sem trava de sessão.
  - C3: `ProcessReceipt` não é idempotente nem durável.
- **Altos:**
  - Lucky Box paga pode não entregar nada.
  - Regras de itens aleatórios pagos de 2026 não são cumpridas.
  - `BindToClose` com espera fixa de 3 s.
  - O bastão do v1 pode ser explorado.
  - ClickDetector sem checagem de distância.
- **Modelos 3D** (`assets/Personagens (goblin, dragao)/`, **só na máquina local, fora do Git**):
  - têm de 185 mil a 800 mil triângulos, contra o limite do Roblox de 20 mil por peça;
  - só o troll e o goblin têm esqueleto (24 ossos, animações walk e run);
  - os de dragão, hidra, fênix e crystal-dragon não têm esqueleto;
  - stone-golem, stylized-zombie e wyvern existem só em `.obj` zipado.

  **Se a próxima sessão rodar em outra máquina, essa pasta precisa ser copiada manualmente.**
- **Visual:** mapa plano e vazio, sem Sky, Atmosphere ou pós-processamento, placa da base espelhada, ícones ITENS e CÓDIGOS vazios, botão de alimentar vazio.
- **Mensagens** `rbxassetid://203785492` e `81504106` com erro no console vêm de fora do `src/`, provavelmente do plugin "Ecos Tools" instalado no Studio. Fica para confirmar.

## 8. Testes realizados

| Teste | Como | Resultado |
|---|---|---|
| Verificador Luau | `luau_check.py --project ...` | **FAIL** nas 4 etapas. selene falha por configuração (falta `selene.toml`); StyLua só formatação; luau-lsp com cerca de 10 erros de tipo reais (`Remotes.lua:70`, `State.lua:80-81`, `UI.lua:439-440`, `Combat.lua:43-45`, `Drops.lua:24-27`); fwjelaa-check com remotes sem validação, `:Connect` dentro de loop em `EventService:61` e `FindFirstChild` encadeado |
| Teste de jogo no Studio | **Cópia** do place em pasta temporária, Play solo | Servidor e cliente sobem sem erro de script, 8 bases, cerca de 250 peças no mapa. DataStore em memória, porque o place não está publicado |
| Assets no Studio | `ContentProvider:PreloadAsync` | Logo, ícones, painel e os sons da biblioteca carregam (Success) |
| Modelos 3D | Blender 5.4 sem interface, script de medição | Contagem de triângulos, ossos e animações na tabela de §7 |
| Revisão de segurança | Revisor independente, somente leitura (skills anti-exploit, datastore-safety, monetization-compliance) | 3 críticos, 5 altos, 8 médios, 7 baixos |

Nenhuma nota de qualidade (0–10) foi dada ainda: as notas são por entrega, a partir da Fase 0.

## 9. Ambiente e ferramentas

Verificado em 07/11/2026 nesta máquina.

- **Kit:** `C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\`
- **Vault Fwjelaa:** `C:\Users\Administrador\Desktop\Roblox Claude Work\fwjelaa-vault-0.1.0\fwjelaa\fwjelaa vault\` (`_tools\vault.py`)
- **Blender:** `C:\Users\Administrador\Desktop\blender-5.4.0-alpha+main.50d477803fa8-windows.amd64-release\blender.exe` (fora do PATH)
- **Studio MCP:** sempre rodar `list_roblox_studios` e conferir o place antes de escrever. **Testar sempre numa cópia do `.rbxl`, nunca no original.**
- **Rojo:** `default.project.json` mapeia `src/` para o DataModel. `FeedAGiant.rbxl` é o place compilado.
- **Git:** usuário `Alan Fiares`, remoto `origin` = `https://github.com/FiaresAlan/FeedAGiant.git`.

## 10. Estado do Git no momento do primeiro handoff (OBSOLETO)

- O repositório foi iniciado neste handoff, com branch `main` e primeiro commit contendo o projeto como recebido mais os documentos.
- Enviado para `origin/main`.
- Árvore de trabalho limpa depois do commit, exceto os modelos 3D ignorados de propósito.
