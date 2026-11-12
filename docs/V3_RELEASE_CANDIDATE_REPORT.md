# FeedAGiant V3 — V3_RELEASE_CANDIDATE_REPORT

**Data:** 11/11/2026.  
**Status:** **PRÉ-CANDIDATA / NO-GO PARA PUBLICAÇÃO**. A especificação V3 00–05 foi seguida como escopo, mas todos os gates que exigem Studio/playtest continuam pendentes. Não confundir commits de código com funcionalidades aprovadas em uma experiência Roblox.
**Branch:** `feat/feedagiant-v3-integracao-segura-2026-11-11`.  
**PR:** https://github.com/FiaresAlan/FeedAGiant/pull/5 (DRAFT, não mergeado).  
**Base inicial:** `feat/feedagiant-v2-rebuild-2026-11-11` / `31514effe58548bb40db2a1c342582fc197412bd`.  
**Main antiga observada:** `374c95436109d1023a43b4914dd8c11ac86ad6e3`.  
**Place de teste ID/arquivo local:** não disponível nesta sessão. Não houve ação sobre Studio ou conta Roblox.

## 1. Matriz de fases 00–08

| Fase | Código/progresso | Evidência comprovada | Gate |
|---|---|---|---|
| 00 — Auditoria, proteção | Comparação remota de V3, branch e PRs; auditoria local só descrita | GitHub + `V3_AUDITORIA_GITHUB_PRELIMINAR.md` | **PENDENTE** backup e estado real do PC/Studio |
| 01 — Golem de Pedra hero | Rig procedural de Pedra com articulações, mandíbula, mãos e attachments. Fogo/Gelo variantes de QA | Código e testes estruturais escritos | **PENDENTE** clips reais, vídeo, rig/asset/visual aprovado |
| 02 — Montaria robusta | Servidor valida dono, rider preso ao torso, controles PC/touch/gamepad, camera e boost + cleanup, estados de rede | Código, sem demonstração Studio | **PENDENTE** 20 montagens, dois clientes, câmera e colisões |
| 03 — Pista/entrega | Pista anexa do código anterior, cargas leve/média/pesada, reserva/posse única, drop, intercept, 2 entregas iniciais protegidas, volta à base | Código e specs; sem test runtime | **PENDENTE** mapa real, simultaneidade e 100 RemoteEvents |
| 04 — Panelas/receitas | Seis receitas, par determinístico, jobs UTC em dois slots, claim idempotente, mundo com bolhas/luz/som, livro compacto | Código, specs, logger; sem persistência real | **PENDENTE** duas contas, offline, mochila cheia, receipts |
| 05 — Elementos/evolução | Três variantes rigadas de laboratório, boost de Pedra/Fogo/Gelo no servidor; Bebê/Jovem/Colosso só na base, sem perdas offline | Regras/scripts escritos | **PENDENTE** rigs finais, comparação física, mobile |
| 06 — UX e base premium | Contorno modular em cada base, 2 panelas, livro e nicho de ovos, cartão de 7 passos, kit inicial garante par de receita, HUD de peso/retorno/cooldown, XP pós-mastigação | Código e arte procedural da base | **PENDENTE** vídeo de primeiros 3 min e QA sem ajuda |
| 07 — Analytics/QA | Hooks no servidor, eventos V3 e funil com ordem real, testes de regras, matriz de QA e script de auditoria | Hooks, spec e checklist escritos; analytics não ingerido | **PENDENTE** testes e relatório de desempenho |
| 08 — Revisão de produto | Riscos e critérios de GO/NO-GO abaixo, SEM novos sistemas adicionais | Revisão baseada no design/código, **não em usuários** | **PENDENTE** playtest cego / top 5 observado |

## 2. Integrações e segurança

- Feature flag original `RebuildV2 = false` preservada, com override **só no Studio**. V3 é nome do produto; nome da flag segue V2 para evitar duplicação e migração desnecessária.
- Legado mantido nos arquivos; os `init()` de arena, boss, boxe, roubo legado, viagens, eventos secundários e bots são omitidos somente quando V3 está ativa.
- `EggSteal`, `Ancestral` e `Mutations` avaliados como OFF na V3; os ovos e dados anteriores continuam no perfil.
- `GiantService.applyDecay` não é chamado no login V3: nenhuma perda de nível por ausência nessa rodada.
- `PlotService.giveFood`/alimentação continuam autoridade econômica; cenas de comida são apenas visuais.
- `CargoRules` faz reserva/commit/rollback, sem conceder item na coleta. Apenas entrega dentro da própria zona chama o adaptador de prêmio.
- `CookRules` exige duas instâncias distintas, ID de receita conhecido na seleção direta, relógio UTC, jobId válido e espaço na mochila; mutações no profile não têm yield intermediário. Pergaminho repetido não produz farm infinito.
- `v3Journey` é uma slice aditiva com metas; não altera campos existentes de níveis, ovos, recibos, passes nem inventário.
- `V2MetricsService` gera custom events no servidor; `Analytics.recent` dá fallback em Studio. Funil não força etapas realizadas fora de ordem.
- Recebíveis e produtos antigos continuam sob `MonetizationService`; ausência de regressão **não foi comprovada**.

## 3. Inventário de assets

| Tipo | Origem | ID/licença | Estado |
|---|---|---|---|
| Rig Pedra/Fogo/Gelo de QA | `V3StoneGolemPrototype.lua`, Parts+Motor6D criados em código | Original nesta branch, nenhum `MeshId` externo | **Criado no código**, sem inspeção visual |
| Animador procedural de QA | `V3ProceduralAnimation.lua` | Original, sem clipes externos | **Criado**, sem teste de fluidez |
| Golem hero e rigs finais importados | PC/Studio proprietário | Não obtidos, não conferidos | **PENDENTE**, não declarar aprovado |
| Comida em mão e boca | `V3FeedPresentation.lua`, Part temporária | Original | **Criado**, sem validação de clipping |
| Base, pista, duas panelas | Parts Roblox via `V2WorldService` | Original no código | **Criado**, falta sobreposição com mapa local |
| SFX panela | `src/shared/AudioAssets.lua` já existente, `sfx_bell` | ID previamente listado no próprio repositório; permissão de uso atual a verificar | **Referenciado**, reprodução real não confirmada |
| GLBs, kits Kenney/Quaternius | Materiais referidos nos documentos V3 | Arquivos/URLs/licenças não auditados nesta sessão | **NÃO IMPORTADOS** |
| Vídeos/imagens de QA | Captura Studio | — | **INEXISTENTES** |

## 4. Evidências e testes

**Executado:** leitura estática no GitHub, comparação de branches e conferência textual de contratos críticos. O CI da branch executou análise de sintaxe de **148 arquivos Luau** e validação dos **2 manifests Rojo**; também executou **7 cenários determinísticos de regras** com Lune 0.11.1 (carga, cozinha, guia, estágios e velocidade), ambos aprovados em https://github.com/FiaresAlan/FeedAGiant/actions/runs/43175799589 . Isso não valida a integração com Roblox Studio.  
**Escrito, NÃO executado:** `V3CargoRules.spec.luau`, `V3CookRules.spec.luau`, `V3StageRules.spec.luau`, `V3GolemPrototype.spec.luau`, `V3GuideRules.spec.luau`, `V3SourceContract.spec.luau`, adições a `V2Core.spec.luau`.  
**Ainda NÃO executado:** Roblox Studio Play Solo, dois clientes, Android real, emulador Studio, gamepad, 8 players, teste de 100 replays na Remote, DataStore de QA, receipt/regressão, vídeo de rig e animações, FPS/memória e Analytics real.

Checklist executável detalhado: `docs/V3_QA_PLAYTEST_MATRIX.md`.

## 5. Revisão de produto — top 5 riscos A VERIFICAR, não observados

1. **Montaria/rig:** falta de rig hero e animações definitivas pode deixar o gigante com aspecto de peça de laboratório e deslizando. Critério: dois vídeos, um de perto e outro a 30 studs, mais 20 montagens com câmera.
2. **Mapa e rota:** pista em coordenadas fixas pode ficar desconectada da ilha local mais recente e das outras branches visuais. Critério: mapa do Workspace com oito bases e linha de chegada alcançável.
3. **Feeding:** apesar de morsel mão → boca e número pós-mastigação, a cena final do gigante parado na base ainda pode não cumprir expressividade. Critério: comida visível na mão, mandíbula, som e 2 alimentações sem ajuda.
4. **Tela pequena:** HUD, Livro e controles ContextActionService podem competir entre si em Android landscape e gamepad. Critério: teste real/simulado devidamente identificado, sem overlay e sem toque sobreposto.
5. **Retorno de jogadores e produto:** é desconhecido se a pessoa quer repetir coleta, receita e alimentação depois de 3 minutos. Critério: playtest cego com contagens absolutas; não confundir sessão longa com diversão.

Esses pontos **não** são feedback de jogadores, nem estatísticas coletadas. São hipóteses derivadas do design e da leitura de código.

## 6. Plano de rollback

1. Não mesclar PR #5 enquanto gates P0 forem vermelhos. A `main` permanece não alterada.
2. Para retornar ao HUD e loop anterior: manter `Features.RebuildV2 = false`, como já está no repositório. No Studio, remover override `Feature_RebuildV2` e reiniciar Play.
3. Preservar campos `v2Cook`, `v2Race`, `v3Journey` para reativação futura; não apagá-los na reversão. Não tentar remover perfis ou recriar DataStores.
4. Se um place local tiver mudanças não commitadas ou assets próprios, manter backup externo antes de sincronizar branch.
5. Se testes revelarem duplicação ou perda, parar e restaurar a cópia de teste; **não usar saves de jogadores reais para reproduzir**.

## 7. Decisão GO/NO-GO

**NO-GO para publicação, monetização nova e anúncios.** Falta o backup e a auditoria local, rig/clips finais, evidência de Studio, testes de dois clientes, persistência e mobile. Nenhuma mudança no ambiente publicado, anúncio ou gasto Robux foi autorizada/realizada.

**Próximas tarefas concretas:** executar a matriz de QA no place de teste; corrigir defeitos demonstrados, importar rigs licenciados e realizar revisão visual/produto. Somente após critérios P0 aprovados o proprietário decide se publica **cópia de teste** e, em autorização separada, se investe em ads.