# FeedAGiant V3 — auditoria remota preliminar (NÃO substitui Tarefa 00 local)

**Data:** 11/11/2026 (America/Sao_Paulo)  
**Tipo de evidência:** leitura estática via GitHub. **NENHUM teste executado no Roblox Studio**, inspeção do Windows, Rojo/Blender, vídeo, FPS, backup local ou verificação de assets do proprietário.  
**Escopo vigente:** `docs/FEEDAGIANT_V3_00_COMECE_AQUI.md` a `05_EXECUCAO_CLAUDE.md`. A V3 substitui os prompts mestres V1/V2 para esta rodada.  
**Estado da Tarefa 00:** **BLOQUEADA / PARCIAL**. Não autoriza Tarefa 01 nem ativação/publicação da feature flag.

## 1. Refs inspecionadas

| Ref | Commit base observado | Resultado |
|---|---|---|
| `main` | `374c95436109d1023a43b4914dd8c11ac86ad6e3` (09/11) | Legado preservado, **não presumir ser o place local atual**. |
| `docs/feedagiant-v3-montaria-disputa-2026-11-11` | `f03390fc47896235be96eb74a29e573e03b2f13f` | Nove commits só de documentos/snippets sobre main. |
| `feat/feedagiant-v2-rebuild-2026-11-11` | `31514effe58548bb40db2a1c342582fc197412bd` | 44 commits sobre main, **contém também os documentos V3** e protótipos de implementação. `docs/V2_EXECUCAO_E_STATUS.md` declara que o produto segue o GDD V3. |
| `codex/feedagiant-toybrick-2026-11-10` | `09475b212f7cf776fa1d981dc5bdd65ad61e6f8c` | Divergiu da branch feat; NÃO presumir as melhorias visuais integradas. |

PRs draft ainda abertos observados: #1 Pré-lançamento, #2 Social/Retenção, #3 Ilha Viva, #4 ToyBrick; são cadeias de base/heads distintas. **Não fazer merge automático**. Branches e commits podem mudar depois deste snapshot.

## 2. Componentes remotos verificados

| Sistema | Arquivo(s) | Verificação estática |
|---|---|---|
| Entrada server/client | `src/server/Main.server.lua`, `src/client/Main.client.lua` | Inicializam serviços V2 e selecionam HUD novo via `Features.on("RebuildV2")`. |
| Flag de compatibilidade | `src/shared/Features.lua` | `RebuildV2 = false` por padrão; override Studio via atributo `Feature_RebuildV2`. |
| Persistência anterior | `src/server/Services/DataService.lua`, `PlotService.lua`, `EggService.lua` | Interface de perfil/inventário ainda presente; **regressão não testada**. |
| Cozinha V3 (arquivos intitulados V2) | `V2CookingService.lua`, `src/shared/RebuildV2/RecipeCatalog.lua` | Slice `v2Cook`, dois slots, UTC, seis receitas, claim comparando `jobId`; requer testes reais de reentrada e repetição. |
| Pista e cargos | `V2WorldService.lua`, `V2LaneService.lua` | Spawn, pickup, carregamento, drop, entrega por zona e disputa server-side; sem validação simultânea em 2 clientes. |
| Montaria | `V2MountService.lua`, `src/client/Controllers/V2Mount.lua` | Clona rig `ServerStorage/V2RigTemplates`, prende avatar por weld e usa comando de movimento / câmera local; **não validado em Studio**. |
| Clips | `V2AnimationService.lua` | Serviço `bind` para tracks, mas não identificada chamada `AnimationService.bind` no `V2MountService.lua` ou `Main.server.lua` lidos. O commit mais recente criou o módulo, sem comprovar integração ou clips importados. |
| UX | `V2Hub.lua`, `V2Lane.lua`, `V2Cookbook.lua` | HUD e controles criados por scripts; legibilidade mobile e ausência de sobreposições precisam de imagem/Studio. |
| Teste puro | `tests/V2Core.spec.luau` | Há assertions para receitas e velocidades; **não foram executadas nesta auditoria**. |

## 3. Riscos e lacunas a resolver por prioridade

**P0-A — Fonte local desconhecida.** A versão real do projeto no Windows/Studio pode conter alterações de outro agente, meshes, animações, IDs e saves não presentes no GitHub. Antes de qualquer rebase/merge/novo código, tirar snapshot e comparar `git status`, commits e place. Sem essa verificação, não escolher a branch de implementação definitiva.

**P0-B — Rig físico/articulado não comprovado.** `V2MountService.mount` exige `ServerStorage/V2RigTemplates/{StoneGolem,FireGiant,IceGiant}`, `HumanoidRootPart`, `Humanoid` e `ShoulderSeatAnchor`. `default.project.json` não mapeia `ServerStorage`. Isso **não prova ausência no Studio**, mas os templates/AnimationIds/licenças não foram verificados. Sem template válido a montaria avisa e não começa.

**P0-C — Nenhum gate de Studio aprovado.** Sem evidência de controle do humano antes/depois, 20 montagens, física/colisões, câmera, duas contas, Android/emulador, alimentação visual ou integridade de 100 replays do deposit. Não habilitar a flag em produção.

**P1-A — Animações não conectadas na montaria examinada.** `V2AnimationService.lua` define controlador de clips, mas `V2MountService.lua` não importa nem chama esse serviço. Verificar se há integração local fora do repositório; caso não exista, conectar ações locomotoras e eventos somente **depois** do Golem real cumprir o Gate 01.

**P1-B — Posição da pista é hardcoded.** `V2WorldService.init` usa coordenadas aproximadamente X=480..730, Z=±35 sem mapa de colisões visual da ilha atual. Inspecionar ocupação do Workspace em Studio antes de validar a posição.

**P1-C — Validação de descoberta na rota `start` da cozinha.** `V2CookRequest("start", index, recipeId)` seleciona `Catalog.ById[arg]` sem verificar `data.discoveredRecipeIds`. Embora ingredientes sejam validados, a ação direta pode contornar o bloqueio de receitas não descobertas exibido no Livro. Definir a regra de produto e incluir caso de teste no servidor antes de corrigir.

**P1-D — QA de retenção de dados.** Avaliar de ponta a ponta as mutações de `v2Cook` e `v2Race` e interações com `PlotService.giveFood`, ovos, passes/receipts, legados e sanitização de perfis antigos. O código está atrás de flag, mas isso não substitui testes de regressão.

**P1-E — Trabalho de branches divergentes.** As alterações de PRs #1–#4 não podem ser consideradas presentes na feat V2 por serem refs separadas. Catalogar quais changes do Studio/local vêm dessas branches antes de incorporar mapa/HUD.

## 4. Checklist obrigatório no PC / Roblox Studio para concluir Tarefa 00

- [ ] Identificar diretório local efetivo, `git remote -v`, `git status --short --branch`, `git log -8 --oneline --decorate`, `git diff` e arquivos ignorados/não comitados relevantes. **Não fazer reset/clean**.
- [ ] Comparar local com refs acima, PRs draft, e confirmar qual versão do `.rbxl/`.rbxlx` representa o place de teste mais atual.
- [ ] Fazer backup **local** do projeto, place e materiais; registrar nome, data, caminho e SHA-256. Não colocar saves, credenciais ou IDs privados num repo público.
- [ ] Em Studio, inventariar `ServerStorage/V2RigTemplates`, templates, articulações, Motor6D/Bones, clipes, marcações, sons e fontes/licenças.
- [ ] Conferir os 7 CC0 Kenney/Quaternius de cozinha e os GLBs anteriores pelo arquivo **real**; não inferir licença do nome.
- [ ] Usar comando/script **somente de leitura** para mapear Workspace (oito bases, posição do centro, pista, interferências), PlayerGui e perfis de teste.
- [ ] Confirmar Rojo e ferramentas disponíveis; executar testes em ambiente de QA **sem tocar produção**; anotar logs e resultados, distinguindo Play Solo de teste com 2 clientes.
- [ ] Escrever `docs/V3_AUDITORIA_LOCAL_REAL.md` baseado nos dados locais, anexar evidências, rollback e identificação do backup.
- [ ] Só então criar branch de **execução local** a partir do estado efetivo do proprietário. Esta branch `audit/` **não é branch de execução**.

## 5. Critério de avanço

**Gate 00: NÃO APROVADO.** A auditoria remota não valida place, arquivos locais, meshes nem salvamento real. Próxima etapa: finalizar a auditoria local, confirmar o Golem e seu direito de uso; depois avançar estritamente por 01 (arte/rig), 02 (montaria), 03 (pista) e assim por diante, com vídeos, QA e commits pequenos.

**Garantias desta entrega remota:** nenhum código funcional alterado, `main` intocada, nenhuma feature flag ligada, nenhuma alteração no place, nenhuma publicação, nenhum asset importado e nenhum Robux gasto.
