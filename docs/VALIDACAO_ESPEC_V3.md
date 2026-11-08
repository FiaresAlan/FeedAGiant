# Validação da "Especificação Final v2.1 → v3.0" (08/11/2026)

Feita pelo diretor técnico contra `docs/GAME_BRIEF.md`, `docs/DIAGNOSTICO_E_PLANO.md`, o código real e o vault do Fwjelaa.
Os esqueletos que vieram junto (pasta `src/shared/Config/`) foram movidos para `docs/propostas/onboarding_v2/` e servem só de referência.

## Por que a pasta saiu de `src/shared/Config/`
O jogo já tem o módulo `src/shared/Config.lua`, que quase todo o código carrega pelo nome "Config". Uma pasta com o
mesmo nome ao lado dele cria dois "Config" no ReplicatedStorage, e o `require` pode pegar a pasta e quebrar o jogo.
Por isso os interruptores ficaram em `src/shared/Features.lua`. Além disso, os esqueletos chamavam módulos que não
existem (`Features`, `Analytics`, `RaidService`, `ClashService`, `EggService`) e partiam de premissas que não valem
para este jogo: 7 espécies (são 12), ovos (o jogo usa Lunchboxes, que abrem na hora) e `_G.Profiles` (o jogo usa PlayerData).

## Regras gerais adotadas
- Tudo novo entra **desligado** em `Features.lua`. Com tudo desligado, o jogo é exatamente o de antes (testado).
- No Studio dá para ligar uma função sem editar o arquivo: `game.ReplicatedStorage:SetAttribute("Feature_<Nome>", true)`.
- Métricas: um módulo só, no servidor (`src/server/Analytics.lua`), em `pcall`, com campos curtos (vault: *Analytics and Funnels*).
- Nenhum remote novo de cliente para servidor: os 2 remotes novos só vão do servidor ao cliente, então não há o que spammar.

## Item por item

| Item da especificação | Decisão | O que foi feito / motivo |
|---|---|---|
| 2.1 Fundo escuro da loja (P0) | ✅ **Feito, ligado** | `UI.window` não escurece mais a tela (era 45% de preto); sombra só atrás do painel. A abertura de caixa passou de 45% para um véu de 15%. Foto `docs/qa/shots/fase8/01` |
| 2.2 Carne Gigante "azul" (P0) | ✅ **Feito, ligado** | O pedaço grande já era modelo; o problema era a **porção carregada** (cubo na cor azul da raridade Rara). Agora é um pernil de peças (carne, gordura, osso) com luz quente. Fotos 02 (antes do ajuste de luz) e 03 |
| 2.3 Atalhos / menos deslocamento | ⏸️ Adiado | Mexe no mapa e na Fase 1 (layout). Sugestão: teleporte Base ↔ Praça no menu. Pede decisão de design do mapa |
| §1 regra 6: rate limit nos remotes novos | ✅ | Não há remote novo de cliente para servidor |
| §8 ProfileTemplate v2 + migração | ✅ **Adaptado** | O projeto usa PlayerData com "slices" que completam campos faltando sozinhas. Foram somados 6 campos (`pityCount`, `streakBackups`, `stealDay`, `stealsToday`, `onboardingAt`, `welcomeGiven`). Teste: um perfil antigo mantém moedas, nível, inventário, caixas e espécies, e ganha os campos novos |
| 6.2 Gacha com pity visível | ✅ **Adaptado** (`LunchboxPity`) | Não foi criado um segundo gacha: o pity entra nas **Lunchboxes que já existem**. Na 50ª caixa paga seguida sem Épica, sai **Épica ou melhor, garantida**. Só caixas compradas (moedas ou Robux) contam; as grátis não contam nem zeram. A loja mostra "Épico garantido em N caixas", e a tela de CHANCES mostra a chance REAL da próxima caixa (a mesma função do servidor). Não há "soft pity": cada caixa mostraria uma chance diferente, e o vault aponta isso como erro comum de transparência |
| 6.1 Streak com backup | ✅ **Adaptado** (`StreakBackup`) | A recompensa diária de 7 dias já existia (janela de 48 h). Completar os 7 dias dá **1 proteção** (máximo 2). Se o jogador perder a janela e tiver proteção, ela é gasta sozinha e a sequência continua. O Diário mostra quantas proteções há. **Backup comprável com Robux NÃO foi criado:** é monetização nova e precisa da sua autorização |
| 6.6 Objetivo visível (1 dica por vez) | ✅ **Adaptado** (`ObjectiveHints`) | Não foi criado um cartão novo (no celular não sobra espaço): a dica ocupa a linha de META por 12 s, com cor por tipo. Ordem: caixa guardada → prêmio do Diário → comida no chão perto → Dragão ou Carne chegando → gigante com fome → espécies que faltam. Nada aparece durante o tutorial. Métricas `objective_shown` e `objective_acted_on`, esta medida no servidor |
| §3 Onboarding de 7 fases | 🟨 **Parcial, adaptado** (`OnboardingV2`) | **Não substitui** o tutorial atual de 4 passos, que já ensina o loop (alimentar → pátio → caixa → crescer) e tem funil próprio. Entraram: câmera de chegada diante do próprio gigante, primeira alimentação com efeito dobrado e **presente de boas-vindas** (1 Lunchbox Comum guardada, aberta só com clique, uma vez por conta, nunca para quem pulou o tutorial). **Ficou de fora:** "ovo garantido" (não há ovos); "escolher 1 de 3 espécies" de graça (espécies são vendidas por moedas e Robux: dar uma de presente muda a economia); "soco guiado contra NPC" (exigiria NPC de treino; o modo LUTAR já existe); "baú de 24 h" (sem prêmio definido no briefing) |
| 5.4 Roubo ético | ✅ **Parcial** (`StealProtection`) | Proteção de novato (base de quem tem **nível < 5** não pode ser roubada) e no máximo **3 roubos por dia** por ladrão, com mensagem clara. A especificação pedia "conta < 3 dias **ou** nível < 5": ficou só o nível, porque o jogo não guarda a data da 1ª entrada de forma confiável. **Revanche (recuperar 50%) adiada:** exige um duelo específico entre os dois |
| §7 Bots | ✅ Já cumprido | Conferido no código: não estão na lista de jogadores (são modelos, não contas), não roubam, só pegam comida comum ou incomum sem jogador real perto, não usam chat, saem quando um humano precisa da base. "Desligar quando houver jogadores suficientes" já é o modo automático (completam até 4) |
| §11 Métricas | ✅ Base pronta | `gacha_roll`, `streak_lost`, `streak_preserved_by_backup`, `objective_shown`, `objective_acted_on`, `onboarding_phase_started`, `onboarding_finished`. No Studio a Roblox não registra nada (esperado); o módulo guarda as últimas 50 chamadas para teste |
| 4 Boss Raid co-op de 4 chefes | ⏸️ Adiado | Precisa de 3 chefes novos (Gelo, Pedra, Vazio) com modelo, animação e arena: é a maior peça da lista. O jogo já tem o Dragão Faminto cooperativo na ilha. Próximo passo sugerido: a "Fase 1: enfraquecer alimentando" no próprio Dragão |
| 6.3 Missão semanal 1-de-3 | ⏸️ Adiado | O Diário já tem 3 tarefas por dia com resgate manual. A missão semanal é a próxima candidata (barata, usa o mesmo painel) |
| 6.7 Arena com NPC de reserva | ⏸️ Adiado | A Arena dos Gigantes (PvE) já evita a arena vazia; o boxe entre jogadores é por convite |
| 5.1 Codex com variantes | ⏸️ Adiado | Não há clima nem variantes de arte. A Coleção atual já mostra o que falta |
| 5.2 Maestria com bônus de dano | ⚠️ Conflito | A decisão "luta justa na arena" proíbe bônus dentro da luta. A coleção já guarda nível por espécie. Comidas favoritas (+15% XP, descobertas jogando) podem entrar depois |
| 5.3 Duplas, 6.4 Temporada | ⏸️ Adiado | A temporada precisa do place publicado (placares globais) e de recompensas (skins) que não existem |
| 6.5 Drops anunciados, no máximo 4 por dia | ❌ Não aplicado | Contradiz a decisão aprovada dos drops (um a cada 45-80 s, com cronômetro). A Carne Gigante já avisa 20 s antes |
| Anúncio global de descoberta rara | ✅ Já existe | Faixa global só para Lendária ou melhor, no máximo 1 a cada 6 s |

## Precisa da sua decisão
1. **Ligar as funções** (uma por vez) no `src/shared/Features.lua`. Ordem sugerida: `ObjectiveHints` → `StreakBackup` → `LunchboxPity` → `StealProtection` → `OnboardingV2`.
2. **Pity mexe com itens aleatórios pagos:** as chances mostradas acompanham o contador (testado). Confira na página de políticas da Roblox antes de publicar.
3. **Backup da sequência à venda por Robux:** não foi criado (monetização nova).
4. O Studio aberto hoje é o place **"Alimente um Gigante" (placeId 115578986093768)**, que já está publicado. Os testes foram feitos só no modo Play e nada foi salvo nele. O briefing ainda diz "não publicado": confirme se esse é o place oficial para eu atualizar o `CLAUDE.md`.
