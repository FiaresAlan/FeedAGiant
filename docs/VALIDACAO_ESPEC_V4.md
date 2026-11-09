# Validação — Prompt Final v4 (delta) e respostas do usuário (09/11/2026)

Feita contra `docs/GAME_BRIEF.md`, o código atual e o vault do Fwjelaa. Nada do que estava pronto foi refeito.

## 1. O que foi liberado e FEITO nesta rodada
Pelas confirmações do usuário: "pode começar pelas Seções 4.2 (missão semanal 1-de-3) e 5 (flags/schema)"; notificação só
com estrutura, sem chamar a API; tabela de drops pela regra da resposta 2.

| Item | Situação | Onde |
|---|---|---|
| §5 Flags | ✅ `TutorialEgg`, `Revange`, `WeeklyQuest`, `DragonRaidPhase1` (todas `false`; `StarterSpecies` já existia) | `src/shared/Features.lua` |
| §5 Campos do perfil | ✅ `mysteryChest {unlockAt}`, `revangeTarget` (0 = nenhum), `weeklyQuest {week, chosenId, chosenAt, swappedThisWeek, progress, claimed}`. `starterSpecies` já existia (`""` = não escolheu: a "slice" não aceita `nil` como padrão) | `DataService.lua` |
| §4.2 Missão semanal 1-de-3 | ✅ Implementada e testada (`WeeklyQuest`) | `GameRules.WeeklyQuests`, `GameLogic.weekly*`, `ProgressService`, `Diary.lua` |
| Resposta 2: faixas de drop | ✅ Com ressalva (P2 abaixo) | `src/shared/EggDropTables.lua` |
| §2.3 Notificação "ovo pronto" | ✅ Só a estrutura (decide quando e para quem avisar); **não chama a API** | `EggNotificationService.lua`, `docs/PENDENCIAS_POS_PUBLICACAO.md` |
| §6 Métricas | ✅ `weekly_quest_chosen` e `weekly_quest_claimed`. As outras pertencem a itens bloqueados | `Analytics.event` |

### Missão semanal: como ficou
- Toda semana (segunda 00:00 UTC) aparecem **3 opções iguais para todos**, sorteadas de 6: alimentar 120x, entregar 20
  comidas do mapa, vencer 15 batalhas de gigantes, ajudar no Dragão 4x, levar 6 porções de Carne, subir 20 níveis.
- O jogador **escolhe 1**. Pode **trocar 1 vez por semana** pelas outras 2 (o progresso recomeça, senão a troca viraria
  "pular para a mais fácil"). As 3 tarefas **diárias continuam iguais**.
- Recompensa **maior que as diárias**: 9.000 a 12.000 moedas + 0 a 3.500 XP + **1 Lunchbox Épica grátis** (a diária
  máxima paga 1.500).
- Resgate **só por clique**. O selo "!" do Diário acende com a missão completa. Completa e não resgatada **continua
  resgatável depois da virada da semana**; a incompleta é descartada (sem prêmio).
- Servidor: escolha/troca/resgate validados (opção da semana, 1 troca, "marcar antes de pagar"), limite de pedidos.

### Testes
- `tests/Weekly.spec.luau` (13) e `tests/Eggs.spec.luau` atualizado → no Play: **`[FwjelaaTests] 121 passed, 0 failed,
  11 spec modules`**.
- Fluxo real no Play (função ligada só na sessão): escolher, trocar (bloqueia a 2ª troca), resgate incompleto recusado,
  20 entregas completam a missão, resgate pagou +10.000 moedas e a Lunchbox Épica, 2º resgate não paga.
  Foto `docs/qa/shots/v4/01_diario_missao_semanal_resgatada.jpg`.
- Verificador Luau: overall PASS (91 arquivos).

## 2. Respostas do usuário registradas
| # | Resposta | Situação |
|---|---|---|
| 1 | Espécies iniciais `fire_starter`, `ice_starter`, `stone_starter` | Registrado; espera a cópia de teste |
| 2 | Faixas de drop por tamanho | Implementado com ressalva (P2) |
| 3 | Ninho ao lado da LOJA; afastar 5-10 studs se colado | Nas fotos o ninho fica a ~26 studs do centro da loja, com espaço livre: **mantido** (fotos `docs/qa/shots/ovos/02` e `06`) |
| 4 | Lugares 1/25/50; ajustar para 20 se 25 parecer longe | Mantido 1/25/50 até o teste com jogadores |
| 5 | Níveis 1/5/10/20/30; "se o teto do jogo for >50, me avise" | **AVISO: o teto do jogo é 250** (`Config.Giant.MaxLevel = 250`; DEUS no 200). Nada mudado: decisão do usuário (Colossal 30 ou 40) |
| 6 | NPC "Treinador" reusando modelo existente | Registrado; espera a cópia de teste |
| 7 | Baú de 24 h = 1 Ovo Médio (com 3 ovos guardados: Lunchbox Rara) | Registrado; espera a cópia de teste |
| 8 | Revanche: recusa = 24 h sem roubar; ladrão offline → 25% automático em 24 h | Registrado; espera a cópia de teste (ver P8) |

## 3. Ressalvas técnicas (registradas; nada foi substituído por conta própria)
- **P2: "3 criaturas de exemplo por raridade" não é seguro.** Um ovo entregaria uma espécie que não existe (sem modelo nem
  atributos) e quebraria a coleção. Usei as **espécies reais** de cada raridade (marcado TODO para você completar a tabela):
  Comum = Humano · Raro = Jacaré, Zumbi · Épico = Águia, Troll · Lendário = Golem, Wyvern · Mítico = Slime, Hidra. Os pesos
  são provisórios (faixa de baixo 70%, de cima 30%).
  - **Consequência que você precisa ver:** o Pequeno agora **só dá o Humano**, o gigante grátis que todo mundo já tem. Na
    prática, ele vira sempre "repetido = XP". O Médio dá o Humano em 70% das vezes.
  - **Ninguém mais dá o Goblin (Incomum)**, que não está em nenhuma faixa.
  - **Sugestão (não aplicada):** Pequeno = Comum + Incomum e Médio = Incomum + Raro.
- **Seção 1, "variação de cor/proporção do rig existente":** os gigantes no Roblox são **uma malha só, sem esqueleto** (medido
  antes). Dá para fazer as 3 espécies iniciais como **variações de cor de um gigante existente** no Blender, sem gerar nada
  pelo Studio. Assim **não é preciso a cópia de teste** para os modelos; só o upload privado. Fica para você decidir se libera
  antes da cópia.
- **P8 Revanche, "recuperar 50% / 25%":** o roubo leva **comida** (um item), não moedas. Ainda falta definir se "50%"
  significa devolver a comida (se o ladrão ainda tiver) ou o valor em moedas, e o que acontece se ele já a comeu.

## 4. Continua bloqueado (o que destrava)
| Item | Destrava com |
|---|---|
| §1 Espécies iniciais + Ovo de Tutorial | Cópia de teste do place **ou** liberar a variação de cor no Blender (P2/Seção 1 acima) |
| §3.1 Soco guiado (Treinador) · §3.2 Baú 24 h · §4.1 Revanche · §4.3 Dragão fase 1 | Cópia de teste (conforme pedido) |
| §2.1 2 jogadores · §2.2 celular | Cópia de teste + contas/aparelho |
| §2.3 Notificação (envio) | Publicar + 100 visitas (`docs/PENDENCIAS_POS_PUBLICACAO.md`) |
