# FeedAGiant — Ilha Viva: revitalização SEM aumentar o terreno
**Data:** 10/11/2026 (UTC) · **Branch:** `codex/feedagiant-ilha-viva-2026-11-10`
**Base:** PR #2 @ `a6554b35463a9121f4a7ff320a210db11b0203b9`
**Backup isolado:** `backup/2026-11-10-antes-revitalizacao-ilha`
**Status:** implementação em código no GitHub; ainda **NÃO validada no Roblox Studio** nesta rodada.

## 1. Diagnóstico a partir de dois screenshots do dono
As capturas mostram ilha em anel, oito bases, arena, caldeirão central e montanhas ao redor. Há escala e identidade; os principais problemas são áreas vazias entre os caminhos, falta de atividades visíveis na praça, títulos flutuantes interferindo na leitura e uma neblina laranja intensa que reduz contraste.

**Decisão:** NÃO aumentar o raio de 470 studs. Concentrar atividades num anel de 98 studs a 22,5° das estradas radiais (cada uma a múltiplos de 45°). Nenhuma construção invade as oito estradas, o caldeirão central ou as estátuas de espécies, posicionadas por volta de r166.

## 2. Entrega — três pontos COM UTILIDADE real

### A. Cozinha Colossal (v2 do Banquete em Dupla)
**Posição aproximada:** phi 112,5°, r98, dentro do anel da praça, sem mexer no mapa assado.
**Visual:** piso circular, anel turquesa contrastante, bandeiras, balcão de serviço, tábua de corte, legumes, panelão mexível e barris. As peças são construídas com primitivas sem scripts externos.
**Fluxo de jogo:**
1. Jogador A chega ao balcão com um alimento comum/incomum **normal** na mochila e abre a inscrição (120 s).
2. Jogador B aceita com outro alimento normal.
3. Jogador A precisa ir fisicamente à TÁBUA e SEGURAR o prompt por 1,7 s para cortar.
4. Jogador B precisa ir à PANELA e SEGURAR por 1,7 s para misturar.
5. Só então o servidor revalida presença, papel, distância, prazo, limites diários e **UID de cada comida**. Retira ambos os alimentos, concede +150 moedas a cada um e +15% XP ao alimentar durante 4 min.
6. O balcão reabre para outra dupla após 10 s; cada jogador tem limite próprio de 3 participações premiadas por dia e cooldown de 3 min.

**Nunca há débito antes da conclusão**. Se a dupla se desfizer, prazo acabar, faltar ingrediente ou o servidor cair antes do commit, cada alimento continua na mochila. Não há NPC substituindo pessoa real. Os convites globais têm cooldown de 60 s para não virar spam.

**Feature flags:** `Features.SocialFeast` e `Features.ColossalKitchenSteps`. Desligar `ColossalKitchenSteps` retorna à conclusão simples do PR #2 e permite rollback caso o preparo falhe no Studio. A cozinha física permanece.

### B. Trilha da Comida — exploração solo opcional
**Posições:** início phi202,5°, pistas phi247,5°, phi292,5° e phi337,5°, todos em r98. Marcadores turquesa de baixa geometria conectam o circuito.
**Fluxo:** ativar o Totem, percorrer três pistas EM ORDEM em até 180 s, pressionando os prompts próximos. O servidor valida posição, ordem e tempo. Conclusão dá **200 moedas** e uma comida de preferência diária, se houver espaço na mochila. Com mochila cheia, recebe as moedas normalmente.
**Retenção:** até dois prêmios por dia; progresso da sessão não persistido, mas limite e histórico de conclusão ficam no slice `ingredientTrail`. Falhar não remove alimentos nem cobra nada.
**Por quê:** garante algo divertido para 1 jogador enquanto aguarda parceria, devolvendo o prêmio ao loop de alimentar.

**Feature flag:** `Features.IngredientTrail`, desligável sem mexer em DataStore.

### C. Mirante dos Colossos — captura real e compartilhável
**Posição:** phi67,5°, r98, plataforma de foto com bandeiras e enquadramento próprio.
**Fluxo:** prompt inicia câmera scriptable por no máximo 12 s; cliente cria cópia **temporária, local e sanitizada** do gigante verdadeiro do jogador ao lado do avatar, dimensionada para caber no palco. Não move o gigante real da base, não muda XP/renda, não replica efeitos ou Scripts e não pesa no servidor.
**Captura:** botão `SALVAR FOTO` usa `CaptureService:TakeScreenshotCaptureAsync` com `UICaptureMode.None`, seguido de **confirmação nativa** para salvar. Nunca faz upload remoto automático, nunca compra nada; botão SAIR e retorno automático restauram a câmera.
**Fallbacks:** se gigante não estiver replicado, modelo excessivo ou câmera indisponível, a câmera ainda enquadra o jogador. A função de captura depende do suporte do dispositivo/Studio e requer QA prático.

### D. Atmosfera/legibilidade
- Preservado o pôr do sol `GoldenAfternoon`, mas reduzidos Density/Haze/Glare e tint laranja para recuperar contraste sem trocar o estilo do usuário.
- Identificação de gigantes passa a ter alcance de 95 studs (era 155); texto do Ancestral reduzido para alcance de 320 studs (era 2.000).
- O roteiro de 3 pistas utiliza marcadores pequenos para o jogador percorrer o mapa ao invés de depender de setas e janelas.
- Nenhuma criatura 3D ou malha original foi substituída e nenhuma base foi alterada.

## 3. Estratégia 70% saudável / 30% pressão controlada
É uma proporção de **esforço de design**, não uma medição real de métricas nem promessa de retenção.

**70%**: alimento favorito; escolher alimentação sem sacrificar raras; colaboração consciente na cozinha; descobrir a rota; foto com o gigante; evolução e coleção; progressão diária e semanal já existente.

**30%**: janela voluntária do banquete por 120s; trilha por 180s; buff temporário de 4min; drops de comida que exigem participação. Cada risco se limita ao bônus/oportunidade, sem roubar itens offline, níveis, ovos pagos, progresso de assinatura ou o gigante do jogador. O jogador pode interromper sem penalidade permanente.

## 4. Próximas duas expansões — NÃO prometidas como já prontas
O conceito original “Expedição Dentro do Gigante” não deve nascer como portal decorativo vazio. A **Trilha da Comida** é o MVP de explorar e resolver micro-objetivos, usando o mapa existente. Se ela for bem avaliada em playtest, a fase seguinte pode ser uma arena de 3 salas dentro do gigante: 1 jogador ou pequena equipe, 4–6 min, bônus ao alimentar, sem perda de inventário.

O “Desfile dos Colossos” depende de um rig de gigante leve, que ainda não está disponível para vários modelos. O **Mirante com o gigante verdadeiro** é o primeiro produto social que não requer arrastar malhas enormes ao redor da ilha. Próxima fase: um percurso de 20–30 s com **um** proxy visual leve por vez, teste de desempenho em Android intermediário e permissão opcional. Nunca mover diretamente o gigante real da base.

**Cozinha Colossal** fica como MVP completo de evento social curto, já com duas tarefas que exigem agir e não apenas pressionar o balcão duas vezes.

## 5. Pesquisa de assets GRÁTIS: fontes, procedência e uso futuro
**Nenhum download/asset de terceiro foi importado automaticamente nesta branch.** O navegador Chrome autenticado e o MCP do Studio não estão acessíveis nesta sessão de chat; não alegar que um item foi inserido. Os cenários acima são construídos em código com primitivas Roblox, sem depender de upload.

Candidatos verificados em páginas oficiais:

| Uso | Origem verificável | Licença/custo informado | Cuidado antes de importar |
|---|---|---|---|
| Tenda medieval opcional | https://create.roblox.com/store/asset/16263631766/Medieval-Market-Stalls | `Get Model` na Creator Store, cerca de 12.900 triângulos e 48 MeshParts | Testar em cópia do place; verificar todo `Script`, `ModuleScript`, `LocalScript` e dependências externas, e avaliar draw calls |
| Barraca da feira | https://grab3d.com/models/buildings/farm-stand/ | CC0, $0, versão Light de ~16.784 triângulos, 1K | Uma malha para perto da cozinha, não dezenas de cópias; converter/importar FBX pelo Studio |
| Pão detalhado | https://grab3d.com/models/food/bread-loaf/ | CC0, $0, ~9.906 triângulos | Usar só para objeto de close-up; reduzir textura 2K para 512/1K |
| Props de madeira | https://grab3d.com/models/props/old-barrel/ | CC0, $0, ~19.856 triângulos | Muito pesado para encher o mapa; preferir os barris procedurais já criados |
| Modelos pesquisáveis por API | https://3dassets.dev/ | maioria dos envios novos CC0; modelos em GLB | Conferir licença do item, origem, conversão e custo de triangulação por asset |
| Materiais para acabamento | https://polyhaven.com/license | Todos os assets CC0, comercial | Texturas PBR geralmente pesadas; otimizar para mobile e manter estilo cartoon-pintado |

**Regra de segurança inegociável:** o antigo `Workspace.MainModule` malicioso já motivou remoção e auditoria do place. Não instalar free models com script, `require(assetId)`, `loadstring`, `LinkedSource`, `InsertService:LoadAsset` ou código obfuscado. Importar primeiro em place de quarentena, remover scripts, revisar o conteúdo e só então migrar geometria/meshes. A Creator Store não assegura ausência completa de backdoors. Fontes:
- https://create.roblox.com/docs/production/creator-store
- https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities
- https://create.roblox.com/docs/performance-optimization/improve

## 6. Verificações antes de publicar
1. **Luau/Selene/StyLua/Rojo** de toda a branch. Não assumir que 167 testes antigos incluem o código novo.
2. **Play Solo:** Trilha começa, exige etapas 1→2→3, respeita 180 s, permite 2 prêmios/dia, não duplica recompensa ao apertar várias vezes.
3. **Play 2 clientes:** Banquete exige duas pessoas; B não consegue cortar como A; A não consegue mexer como B; a recompensa só chega depois das duas tarefas.
4. **Reversões:** primeiro sai, segundo sai, um usa a comida reservada em outra função, 120 s vencem, o servidor fecha; nenhum item sofre perda parcial.
5. **DataStore:** `ingredientTrail` e `communityFeast` persistem; o buff do banquete continua correndo mesmo offline, sem ser estendido por reconexões.
6. **Fotos:** câmera não bloqueia movimento de longo prazo; botão sair, timeout, respawn, retorno normal; cópia 3D não altera gigante real; galeria salva com consentimento do usuário no dispositivo suportado.
7. **Baked Map:** executar no place com mapa assado atual e no mapa gerado — `LivingPlazaDistrict` aparece uma vez, sem destruir estruturas.
8. **Visual + celular físico:** verificar que marcadores, placas, botões e efeitos não dominam a tela; comparar screenshot da iluminação antiga e nova, olhar da rua e da câmera aérea.
9. **Segurança:** place oficial limpo, assets de terceiros inspecionados, DataStore e recibos de compras reais, 2–3 jogadores e roubo de ovos com desconexão.
10. **Retenção:** sessão cega com 10 pessoas: entendem onde cozinhar, completar a Trilha e fotografar sem instrução? Medir `ingredient_trail_started/finished`, `social_feast_started/paired/prepared/completed` e primeiros feeds.

**Bloqueadores para lançamento permanecem:** validação real no Studio, celular físico, place oficial, DataStore, compras/recibos e concorrência de ovos/boss. Não fazer merge/publicar/anunciar/gastar Robux antes dos gates. Nenhuma execução remota em conta Roblox foi feita aqui.

## 7. Arquivos e reversão
- `src/server/PlazaDistrict.lua` — geometria das atrações, idempotente em Workspace.Map.
- `src/server/Services/SocialFeastService.lua` e `src/shared/SocialFeastRules.lua` — cozinha em duas etapas com cooldowns do PR #2.
- `src/server/Services/IngredientTrailService.lua` e `src/shared/IngredientTrailRules.lua` — exploração com regras de servidor e limite persistente.
- `src/client/Controllers/PhotoStage.lua` — câmera temporária, cópia local do gigante e captura via API oficial.
- `src/server/Main.server.lua`, `src/client/Main.client.lua`, `src/server/Guard.lua`, `src/shared/Features.lua` — integração.
- `src/shared/LightingRecipes.lua`, `src/server/Services/GiantService.lua`, `src/server/Services/AncestralService.lua` — iluminação/nomeplates.
- `tests/IngredientTrail.spec.luau`, `tests/PlazaDistrict.spec.luau`, `tests/SocialFeast.spec.luau` — testes novos/estendidos. Dependem de Roblox Studio para executar.

Rollback sem perder dados: fazer checkout do backup `backup/2026-11-10-antes-revitalizacao-ilha`. O novo slice `ingredientTrail` é aditivo e compatível com perfis antigos. Não apagar dados persistentes ao fazer rollback.
