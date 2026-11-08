# Briefing do jogo — Feed a Giant

> Fonte da verdade do projeto. Preenchido em 07/11/2026 a partir de `GAME_DESIGN.md`, `README.md`, do código (Config v4.0.0) e das decisões aprovadas pelo usuário. Campo marcado **[PENDENTE]** = decisão do usuário ainda não tomada; não construir nada que dependa dele.

## 1. Identidade
- **Nome:** Feed a Giant (FEED A GIANT).
- **Pitch:** você adota um Gigante bebê que come tudo. Quanto mais ele come, mais cresce, até ficar maior que o mapa. Outros jogadores podem invadir sua base e roubar a comida do seu Gigante.
- **Gênero:** simulador / tycoon de coleção e crescimento, com PvP leve (roubo, socos, duelos).
- **Referências** (só a lógica, nunca nome, arte ou personagens):
  - jogos de "roubar da base" → roubo com contra-jogo;
  - jogos de "fazer crescer" → progresso visível no próprio objeto;
  - simuladores com ovos → caixas com raridades.

## 2. Público e plataforma
- **Faixa etária:** público geral de simuladores Roblox (crianças e adolescentes). Conteúdo sem violência gráfica: os socos derrubam ("tonto"), não matam.
- **Dispositivos:** **celular primeiro** (condição do usuário), depois PC. Console não é prioridade.
- **Sessão típica:** 10 a 30 min, com retorno diário.
- **Idiomas:** PT-BR (padrão), EN, ES.

## 3. Jogabilidade
- **Verbos:** comprar caixa, colocar comida no pátio, alimentar, roubar, defender (soco e bloqueio), disputar drop, duelar.
- **Loop de 30 s:** ganhar moedas → comprar lunchbox → comida → pátio (renda) ou alimentar (XP).
- **Loop de 5 min:** subir de nível, o gigante cresce e muda de estágio, eventos e drops.
- **Loop da sessão:** rebirth (nível 50+), espécies, campeonato a cada 15 min, placares.
- **Progressão:** nível até 250, 7 estágios (Bebê → DEUS), rebirths com multiplicador, 7 espécies.
- **Social:** até 8 jogadores por servidor, 1 base cada.

## 4. Escopo
- **Plano aprovado:** `docs/DIAGNOSTICO_E_PLANO.md`, com as fases 0 a 5 mantidas sem reformulação.
- **Escala:** hub central + 8 bases em anel (raio 320 studs). Vai ser redesenhado na Fase 1.
- **Fora do escopo até a Fase 5:** trocas entre jogadores, pets, guerra entre servidores.

## 5. Direção de arte
- **Estilo:** **cartoon pintado (stylised PBR)**, escolhido pelo usuário em 07/11/2026. Formas estilizadas com texturas pintadas simples (cor, mais normal opcional, rugosidade alta, metalness 0) e iluminação trabalhada. Superfícies grandes e repetidas usam a camada barata "cartoon liso" (cor + SmoothPlastic). Criaturas: reduzidas para no máximo 20 mil triângulos e repintadas em toon, mantendo a silhueta.
- **Paleta e clima:** **fim de tarde** (sol baixo e quente, horizonte alaranjado, grama menos saturada), escolhido pelo usuário em 07/11/2026 depois do painel da Fase 1. Antes era diurno e saturado; a paleta fica em `World.Palette` (`src/server/World.lua`) e precisa passar no teste em tons de cinza. Neon só com orçamento (destaques de raridade e de interação).
- **Assets existentes:**
  - `assets/ui` (logo, ícones, painel, já enviados ao Roblox);
  - `assets/Personagens (goblin, dragao)`, só local: 185k a 800k triângulos, precisam ser otimizados para no máximo 20 mil.
- **Fontes permitidas:** Blender (próprio), Asset Pack do Fwjelaa, Creator Store, modelos CC0 da internet (Poly Pizza, Poly Haven), IA do Studio.

## 6. UI, áudio e sensação
- **UI:** HUD existente (`src/client/UI.lua` e Controllers). Corrigir o layout no celular na Fase 4.
- **Áudio:** SFX e narrações próprios em `assets/audio` (pendente de upload autorizado). Hoje usa a biblioteca Roblox.
- **VFX importantes:** alimentar, subir de nível, evoluir, abrir caixa, roubo, socos (Fase 3).

## 7. Dados e economia
- **O que salva:** moedas, nível, XP, rebirths, inventário, pátio, espécies, passes, estatísticas, códigos, diário.
- **Moeda:** Moedas (soft). Sem troca entre jogadores.
- **Monetização:**
  - 8 Game Passes e 9 Dev Products desenhados em `Config.lua`, todos com ID 0;
  - preços sugeridos em `Config.GamePassInfo` e `Config.DevProductInfo`;
  - itens aleatórios pagos devem cumprir as regras de 2026: chances por item e `PolicyService`.
- **Limites éticos** (a revisar, Fase 4): reduzir o pay-to-win na arena e suavizar o encolhimento por ausência. Mudanças de economia exigem justificativa antes (condição 4).

## 8. Restrições
- **Técnicas:**
  - desempenho no celular primeiro;
  - StreamingEnabled ao redesenhar o mapa;
  - 20 mil triângulos por malha;
  - partículas no máximo a 100/s por emissor no celular.
- **Políticas:** regras de itens aleatórios pagos de 2026, nada de conteúdo impróprio.
- **Não fazer:**
  - publicar, gastar Robux ou fazer upload comercial sem autorização;
  - mexer no place original (testar em cópia);
  - reformular as fases.

## 9. Recursos disponíveis
- **Arquivos:** `FeedAGiant.rbxl`, `.rbxlx`, `src/` (Rojo), `assets/`, `tools/Rojo_plugin`.
- **Place ID / Universe ID:** ainda não publicado (PlaceId 0).
- **Dono dos assets:** conta do usuário (logo, ícones e painel já enviados).
- **Repositório:** https://github.com/FiaresAlan/FeedAGiant (`main`).

## 10. Autorizações
- **Upload de assets ao Roblox:** [ ] sim [ ] não [x] **perguntar a cada lote** (condição 7: nada comercial sem autorização).
- **Publicar no place (sem tornar público):** [ ] sim [x] **não**.
- **Tornar público / lançar:** sempre perguntar.
- **Gastar Robux:** nunca sem pedido explícito.

## 11. Critérios de sucesso
- **Fase 0:**
  - verificador Luau com overall PASS;
  - teste com vários jogadores no Studio sem perda nem duplicação;
  - revisão independente nota ≥ 8,5 (rubrica `system`).
- **Lançamento** (sinais do algoritmo de 2026): pouca saída antes de 60 s, retorno nos dias 1, 2 a 7 e 8 a 28. Ainda não há métricas reais.

---
## Decisões do diretor técnico

| Data | Decisão | Alternativas consideradas | Motivo | Notas do vault citadas |
|---|---|---|---|---|
| 07/11/2026 | Fase 0 (segurança) antes do visual | Começar pelo visual | Perda de save e cobrança sem entrega geram avaliações ruins e reembolsos; aprovado pelo usuário | Session Locking and Profile Libraries; Developer Products and ProcessReceipt |
| 07/11/2026 | Modelos 3D brutos fora do Git | Git LFS; versionar tudo | 550 MB em formatos duplicados, inutilizáveis sem otimização; os otimizados entram na Fase 2 | AI Pitfalls - Assets and Import |
| 07/11/2026 | Manter a extensão `.lua` (não renomear para `.luau`) | Renomear tudo | Rojo e luau-lsp tratam os dois iguais; renomear só gera ruído no histórico | — |
| 07/11/2026 | Formatação StyLua aplicada num commit separado, sem mudar lógica | Formatar junto com as correções | Deixa os diffs das correções legíveis | — |
| 07/11/2026 | Checagem de distância no servidor para ClickDetector | Confiar em MaxActivationDistance | O vault (Roblox docs) diz que não é validado no servidor; o revisor discordou; a checagem é barata | Clickable and Interactive Parts |
| 07/11/2026 | Estilo de arte: cartoon pintado (stylised PBR); confirmado pelo usuário | Cartoon liso (só cor); semi-realista | Realismo não é o atrativo; maioria no celular (realismo fica chapado e pesa na memória); simuladores têm convenção estilizada (thumbnail e descoberta); combina com avatares | Stylised vs Realistic Material Pipelines; Stylized Lighting Recipes; Art Budgets - Triangles Draw Calls Memory; Mesh Optimization for Mobile |
| 07/11/2026 | Clima: fim de tarde (receita GoldenAfternoon), confirmado pelo usuário | Manter o "Bright cartoon" de meio-dia | Os 3 revisores da Fase 1 (nota 7,9) apontaram W4 "dia padrão"; ajustes sutis não mudaram a nota; o usuário escolheu um clima mais marcante | Stylized Lighting Recipes §3.3 Golden hour; Lighting Mood and Time of Day |
| 07/11/2026 | Espécies novas da Fase 2 (aprovadas pelo usuário: "tem total aprovação"): Goblin 8.000 moedas (Incomum; +20% moedas, fome 1,3×, força 9, HP 80) · Zumbi 25.000 (Raro; fome 0,6×, −15% XP, força 11, HP 120) · Troll 75.000 (Épico; −20% XP, força 16, HP 160) · Wyvern 220.000 (Lendário; +35% XP e moedas, fome 1,4×, força 15, HP 110) · Hidra 600.000 (Mítico; +50% XP e moedas, fome 1,6×, força 18, HP 150). Dragão e Fênix seguem por Game Pass. Bebê-dragão = visual do estágio Bebê do Dragão | Só reaproveitar modelos nas espécies atuais | Usa os 9 modelos existentes (CC0/AI-assisted, Grab3D); preços encaixam entre os degraus da curva atual (0, 15k, 40k, 120k, 350k) sem passar o topo pago; cada espécie troca um bônus por uma desvantagem, como as atuais | Art Budgets; Modeling Fundamentals for Games |
| 08/11/2026 | **Fim do encolhimento por ausência** (Fase 4). A ausência só deixa o gigante faminto (renda x0,8 até comer); bônus de volta mantido; produtos "Congelar" e "Restaurar níveis" aposentados (recibos atrasados ainda entregues); Guardião, Dragão e Fênix passam a "nunca passar fome" | Manter o encolhimento; suavizar só o ritmo | Punir quem volta derruba a retenção D8-28 (sinal do algoritmo de 2026) e "pague para desfazer o castigo" gera avaliações ruins. O usuário deu autonomia total em 08/11 | Retention and Return Hooks; Discovery and the Algorithm |
| 08/11/2026 | **Luta justa na arena** (Fase 4): dentro da luta real, os dois lutadores têm 150 de vida e força 1 (sem bônus de espécie, nível, rebirth ou Boxer Pro) | Matchmaking por nível; manter os bônus | A luta tira moedas e comida do perdedor: com bônus pagos (Dragão = 2,5x a vida) virava pague-para-vencer. Fora da arena os bônus continuam | Monetization ethics (vault); revisão independente da Fase 3 |
| 08/11/2026 | **Malhas geradas pela IA do Roblox Studio** para humano (bebê e adulto), jacaré, águia e slime | Modelos CC0 (só versões realistas e pesadas no Grab3D); continuar de blocos | Estilo cartoon coerente, < 8k triângulos, sem custo; o usuário autorizou usar o assistente do Studio | AI Pitfalls - Assets and Import |
| 08/11/2026 | **Dragão Faminto** substitui o "Boss Faminto" (pedido do usuário): evento na arena com contagem; quem ajuda a derrubar ganha caixa Épica grátis (comida Épica ou melhor) **até 2 vezes por dia**; quem é nocauteado pelo dragão perde **1** comida aleatória da mochila (no máximo 1 por evento). Vida 900 + 600 por lutador extra; pisão a cada 3,2 s com círculo vermelho de 1,4 s | Manter o boss clicável; recompensa sem limite | O usuário pediu boss de verdade, na arena, com prêmio e castigo. O limite diário evita farm da caixa épica (4.000 moedas); o castigo pequeno dá tensão sem destruir progresso | Retention and Return Hooks; Boss design (vault 10) |
| 08/11/2026 | **Modo de luta** (botão LUTAR, tecla Q, controle Y): fora dele o clique não soca e as luvas somem; arena e dragão ligam sozinhos | Soco sempre ligado | Pedido do usuário ("não ficar dando soco no vento") | — |
| 08/11/2026 | **Alimentar só perto do próprio gigante** (borda + 28 studs, validado no servidor); botão ALIMENTAR só aparece perto | Alimentar de qualquer lugar | Bug apontado pelo usuário; o botão escondido também libera a tela | Server Authority |
| 08/11/2026 | **Fogos de artifício** para todo o servidor quando sai comida Épica ou melhor (1 a cada 4 s) | Só a faixa de Lendária+ | Regra pedida pelo usuário | — |
| 08/11/2026 | **Água de terreno** nos lagos e num anel de mar de ~260 studs (o resto do mar segue peça) | Mar inteiro de terreno | Pedido do usuário (água "de verdade"); o anel limita o custo medido na Fase 1 (~290 mil triângulos com o mar inteiro) | Water and Terrain; Mobile budgets |
| 08/11/2026 | **Sons aprovados pelo usuário** (`assets/audio`, 27 arquivos) enviados e ligados no `Config.Sounds` (narrador nos 3 idiomas) | Sons da biblioteca | "todos esses áudios estão aprovados" | — |
| 08/11/2026 | **Drops reformados**: cronômetro por raridade, coleta manual, carga na cabeça com peso (comum sem penalidade; mítico anda a 65% da velocidade), soco ou nocaute derrubam a carga, entrega na própria base. 15% dos drops são Lunchboxes, guardadas para abrir depois. Chuva de Comida com 14 itens manuais | Manter o círculo de disputa; só reduzir a chuva | Pedido do usuário: a coleta "de graça" (20 a 50 comidas) tirava o valor das caixas. Números em `Config.Drops` | Padrões de combate e disputa de drops (vault 10) |
| 08/11/2026 | **Escudo com moedas** no pedestal da base: 5 min pelo valor de 2 min da renda atual (mínimo 500) | Só Robux | Pedido do usuário (renovar dentro da base). O preço acompanha o progresso | — |
| 08/11/2026 | **Arena dos gigantes**: vitória rende 60 + 12×nível moedas e 40 + 6×nível XP, até 15 vitórias premiadas por dia, descanso de 25 s. Derrota não tira nada | Moeda nova; recompensa sem teto | Usa moedas e XP que já existem. O teto evita fazenda. Equivale a ~4 moedas/s no nível 10 | Retention and Return Hooks |
| 08/11/2026 | **Dragão com horário próprio** (a cada 15 min, por 3 min), fora do sorteio de eventos | Continuar no sorteio | Permite um cronômetro real na entrada da arena (item 10) | — |
| 08/11/2026 | **Mapa fechado por montanhas, sem mar** | Manter o mar | Pedido do usuário (custo e limite da área de jogo) | Worldbuilding (vault) |

