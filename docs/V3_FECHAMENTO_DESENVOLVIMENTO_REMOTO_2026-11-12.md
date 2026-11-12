# FeedAGiant V3 — Fechamento de desenvolvimento remoto

**Data:** 12/11/2026 (Brasil).  
**Branch:** `feat/feedagiant-v3-integracao-segura-2026-11-11`  
**PR:** https://github.com/FiaresAlan/FeedAGiant/pull/5 — **DRAFT, NÃO MESCLADO**.  
**Entregável:** código de integração, regras e testes automatizados, dois places compilados para **QA**, não uma experiência publicada ou validada em Roblox Studio.

## 1. Estado dos gates

| Área | Entrega no repositório | Evidência | Gate |
|---|---|---|---|
| Fundação e compatibilidade | Flag V3 usa nome técnico `RebuildV2` e fica OFF por padrão, serviços e perfis antigos preservados | Análise CI/compilação | **Código OK**, teste legado no Studio pendente |
| Criaturas | Golem articulado de Pedra + variantes Fire/Ice procedurais de QA, joints e controles | Syntax CI + testes estruturais escritos | **Rig definitivo e animações reais pendentes** |
| Montaria e câmera | Movimentação server-authoritative, stamina, boost, desmontagem/respawn, restauração de zoom e FOV, movimento animado a até 15Hz | Syntax CI/compile, não jogo real | **Studio/multicliente/móvel pendentes** |
| Pista/disputa | Reserva/posse única, peso, drop, intercept, entrega na própria base; créditos com estado `depositing`, `deposited`, `quarantined` | 250 ciclos simulados de carga no Lune | **Remotes reais e DataStore pendentes** |
| Cozinha | Seis receitas determinísticas, duas panelas UTC, slots persistidos, validação de ingredientes, UID e claim único | Regras puras executadas no CI; job inválido preservado | **Reconexão/claim real no Studio pendentes** |
| Alimentação/níveis | Solicitação de feed por UID, alimento visual mão→boca, feedback XP após a ação, crescimento em três marcos na base | Regra de UID/estágios no CI | **Física/visual e XP em runtime pendentes** |
| UX e onboarding | Guia de sete passos, responsive layout, HUD sem overlay, painel de receitas sem botão redundante; chegada e starter modal legados não são disparados na V3 | Regras de layout/testes puros | **Android, gamepad e playtest pendentes** |
| Analytics | Eventos gameplay server-side, funil ordenado e mecanismo de log em Studio | Contratos + compilação | **Ingestão AnalyticsService e funil real pendentes** |
| Publicação e monetização | Nenhuma chamada de publicação, alteração de main ou novo gasto | PR draft / fontes | **NO-GO** até autorizações separadas |

## 2. Correções da rodada final

1. Layout responsivo via `src/shared/RebuildV2/GuideLayoutRules.lua`, aplicado por `V3Journey.lua` a partir do tamanho da câmera e da visibilidade de escolha inicial; acompanha mudanças de viewport.
2. Remoção do segundo botão flutuante do Livro de Receitas em `V2Cookbook.lua`. Os acessos por **RECEITAS** no HUD, tecla **B** e prompts físicos permanecem.
3. `OnboardingService.onJoin` mantém elegibilidade e concessão de espécie do servidor, mas não inicia Arrival/câmera e modal antigos sob V3.
4. Guia inicial descreve a escolha de gigante de forma válida para todos os elementos.
5. `CookRules.remainingSeconds` recusa timestamp não numérico/NaN/infinito; `isReady` não concede um prato a partir de `-math.huge`.
6. `V2CookingService.visibleSlot`, `V2WorldService.updatePot` e `V2Cookbook.draw` apresentam **VERIFICAR JOB** e preservam dados se o estado ou tempo salvo for inválido, sem resetar a panela.
7. Testes de comportamento Lune incluem layout 360/520/1280px, 250 ciclos com dois donos e replay, e recuperação de jobs corrompidos.
8. Histórico anterior no mesmo PR inclui proteção de depósito, rollback/quarentena, alimentação pelo UID da instância e animações com limite de frequência.

**Regra de recuperação:** estado de prêmio incerto é terminal para aquela carga, não faz retry automático. Isso prioriza impedir duplicação; casos de erro precisam de reconciliação manual via logs em ambiente QA. O código não garante persistência exatamente-uma-vez através de quedas abruptas de servidor — essa propriedade depende do DataStore/PlayerData testado em contexto real.

## 3. Evidência CI mais recente

[GitHub Actions — run 43190558762](https://github.com/FiaresAlan/FeedAGiant/actions/runs/43190558762): todos os três jobs **concluídos com sucesso**.

- **parse-luau:** 152 arquivos Luau analisados, 0 erros; manifests `default.project.json` e `test.project.json` válidos.
- **behavior-luau:** 12 cenários determinísticos executados no Lune 0.11.1, incluindo disputa de 250 cargas, transações com falha, UID, panelas UTC corrompidas, jornadas, estágio e layout. Não equivale a testes de Roblox.
- **rojo-build:** Rojo 7.7.1 compilou `FeedAGiant-V3-QA.rbxlx` (1.360.659 bytes) e `FeedAGiant-V3-Tests.rbxlx` (1.457.183 bytes). O teste do build confirmou módulos importantes da V3 presentes.

**Artefato:** https://github.com/FiaresAlan/FeedAGiant/actions/runs/43190558762/artifacts/13930202324 — dois places compilados, expiração prevista para 19/11/2026 (UTC). Esse ZIP é fornecido pelo GitHub Actions, não foi publicado no Roblox.

## 4. Handoff para o Studio

**Antes de tocar no place real**, fazer backup e comparar alterações locais: a compilação Rojo não contém assets criados apenas no Studio ou não commitados.

1. Abrir `FeedAGiant-V3-Tests.rbxlx` como **cópia de QA**.
2. Em modo edição, habilitar no `ReplicatedStorage` o atributo booleano `Feature_RebuildV2 = true`; iniciar Play depois da mudança.
3. No servidor, executar `require(game.ServerScriptService.FwjelaaTests.Runner)()` e guardar Output (nem todas as specs existentes já foram executadas pelo CI).
4. Executar o roteiro de **20 cenários** em `docs/V3_QA_PLAYTEST_MATRIX.md`, especialmente 20 montagens/desmontagens, 2 clientes, 100 pedidos via Remote, comida correta pelo UID, save/offline, mobile e gamepad.
5. Substituir os rigs QA por meshes/anim IDs licenciados e confirmar câmera/colisões antes de aprovar a arte.
6. Se algum cenário falhar: anexar Output, vídeo, arquivo/place de QA, usuário de teste não sensível, repro passo a passo; corrigir o PR antes de merge/publicação.
7. Validar rollback com `RebuildV2=false` sem apagar `v2Race`, `v2Cook` ou `v3Journey`, nem alterar recibos de compra.

## 5. Não realizado nesta sessão

- Acesso ao Windows, arquivos de Studio locais ou backup do place do proprietário.
- Execução do projeto Roblox em Play Solo, 2-clientes, Android, gamepad ou experimento real de 3 minutos.
- Validação de malhas/anim IDs/fontes/licenças do rig hero ou clipes finais.
- Testes de DataStore, recibos Robux, desempenho FPS/memória, telemetria no AnalyticsService.
- Merge do PR, atualização da `main`, publicação de place/assets, anúncios ou gastos.

**Decisão:** a implementação remota e seu pipeline de compilação/testes são entregáveis para QA, mas a V3 é **NO-GO para produção** até a validação do Studio e aprovação do proprietário.
