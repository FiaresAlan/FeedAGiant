# FeedAGiant V3 — implementação incremental na branch isolada

**Data:** 11/11/2026.  
**Branch:** \`feat/feedagiant-v3-integracao-segura-2026-11-11\`  
**Base:** \`feat/feedagiant-v2-rebuild-2026-11-11\` no commit \`31514effe58548bb40db2a1c342582fc197412bd\`, com a auditoria remota \`05e03ba81ef8f1f12e91ba11fcd2e1d60a631fb3\`.  
**Situação:** código acrescentado / modificado no GitHub; **NÃO testado no Roblox Studio, no Windows local ou em dispositivos físicos**. Não é release candidate nem conclusão dos gates artísticos de V3.

## Entregas de código

1. \`src/shared/RebuildV2/RecipeCatalog.lua\`: adicionada \`canStartById\` para distinguir receita já conhecida de descoberta pela combinação.
2. \`src/server/Services/V2CookingService.lua\`: comando \`start\` rejeita ID ainda não descoberto; \`combine\` pode descobrir pela primeira vez com os ingredientes válidos; pergaminho repetido é aceito na entrega mas NÃO cria comida extra. Sem migração destrutiva do inventário, do perfil e dos ovos.
3. \`tests/V2Core.spec.luau\`: casos de autorização de início direto por receita.
4. \`src/server/Services/V2MountService.lua\`: conecta o serviço de animação à sessão, atualiza gait com locomoção/carga, executa o estado \`Eat\` apenas após o hook de alimentação, limpa clips na desmontagem e reforça posse de rede do servidor após soldar o rider. Cria o Golem de laboratório em Studio se não houver template próprio.
5. \`src/server/Services/V2LaneService.lua\`: dispara animações de pegar, soltar e comemorar somente depois das verificações do servidor e da entrega válida.
6. \`src/server/Services/V2AnimationService.lua\`: usa clipes reais de rigs importados; só para \`V3ProceduralRig\` usa movimento procedural; \`CarryWalk\` sem clip volta a \`Walk\` em vez de congelar em \`Idle\`.
7. \`src/server/Services/V3StoneGolemPrototype.lua\`: rig de Pedra autoria em partes Roblox, com articulações via \`Motor6D\`, duas pernas divididas, cotovelos, mãos, mandíbula, olhos, núcleo e attachments de montaria/carga. **Exclusivamente para teste no Studio**; nenhuma malha externa ou licença de terceiro.
8. \`src/server/Services/V3ProceduralAnimation.lua\`: idle, walk, run, carry, pickup, drop, eat, celebrate e ability procedurais para o Golem Studio. Atualizações C0 limitadas a 15 Hz, não qualificadas como acabamento de produção.
9. \`src/client/Controllers/V2Mount.lua\`: salvar e restaurar o zoom e FOV anteriores do usuário na desmontagem.
10. \`tests/V3GolemPrototype.spec.luau\`: verificações estruturais de RootPart, Humanoid, joints, attachments e limpeza do controlador (exigem runner Studio).

## O que continua protegido

- \`main\` **não foi modificada** e o PR não deve ser mesclado automaticamente.
- \`RebuildV2\` permanece **false** por padrão no código. O nome da flag vem da implementação anterior, mas o GDD vigente é V3.
- Nenhum asset, animação, experiência ou place foi publicado. Nenhum Robux gasto.
- Não houve criação de DataStore separado, remoção de saves, mudança de recibos ou importação de rigs de procedência incerta.
- O fallback não é ativado em servidor público. Se \`ServerStorage/V2RigTemplates/StoneGolem\` existir, o modelo importado tem prioridade.

## Integração de QA no Roblox Studio (manual / comando de trabalho)

1. Compare primeiro o estado local do seu projeto com esta branch: o place local pode ser mais novo que o GitHub. Preserve um backup do \`.rbxl\` e dos recursos não commitados **antes** do Rojo.
2. Sincronize o código desta branch em **cópia de teste** do place e deixe \`main\` intacta.
3. Em **modo edição** do Roblox Studio, antes de iniciar Play, execute no Command Bar:
   ~~~luau
   game:GetService("ReplicatedStorage"):SetAttribute("Feature_RebuildV2", true)
   ~~~
   Reinicie o Play se alterar a flag; \`V2WorldService.init\` constrói a pista apenas na inicialização. Fora do Studio, essa sobreposição de atributo não habilita a feature.
4. Se não existir \`ServerStorage/V2RigTemplates/StoneGolem\`, a montaria do \`stone_starter\` usará o Golem de laboratório gerado durante Play. As outras espécies precisam de rigs reais. Escolha Pedra no HUD, fique perto da base e pressione **F** para montar, **Shift** para sprint, **Q** para habilidade, **E** para pegar/entregar carga.
5. Teste uma entrega individual, depois duas contas disputando a mesma carga. Teste duas primeiras entregas protegidas; ao sair e reconectar, inventário, ovos e cozinha não podem perder item.
6. Para cozinha, faça a combinação **pão + queijo** e verifique que iniciar pelo ID antes de descobrir falha sem consumir os ingredientes. Cozinhe dois pratos nas duas panelas, feche e retorne depois dos timers; confirme claim único mesmo repetindo request.
7. No place **de testes**, rode pelo Command Bar:
   ~~~luau
   require(game.ServerScriptService.FwjelaaTests.Runner)()
   ~~~
   Registre resultados, logs e diferenças entre testes puros e gameplay real. Não relatar testes como aprovados antes de executá-los.
8. Testar 20 montagens/desmontagens, morte/respawn, 2 clientes com câmera replicada, latência elevada, touch/mobile e gamepad. Registrar vídeo, FPS e memória.

## A substituir ou ajustar após a prova local

- **Arte:** Golem Studio é uma base de engenharia, não o Golem hero final. Importar rig licenciado de qualidade, \`HumanoidRootPart\`, \`Humanoid\`, \`ShoulderSeatAnchor\`, \`CargoCarryAnchor\` e pasta \`Animations\` com clips publicados e acessíveis. Usar \`AnimationConstraint\`/Animator quando for melhor para pipeline final. Não depender do C0 procedural em produção.
- **Física:** root invisível alto do protótipo pode colidir com cenário. Medir inclinação, degraus, deslizamento e aterrissagem. Ajustar \`HipHeight\`, peças colidíveis e geometria com vídeo do Studio.
- **Câmera e controles:** a restauração de FOV/zoom ainda requer testes em PC, Android e console.
- **Dados e competição:** testar repetição de delivery/claim, desligar servidor em estados de cozinha e item carregado, duas contas, sessões antigas e recibos pagos.
- **Mapa:** coordenadas fixas da pista ainda dependem da medição real da ilha e dos PRs visuais divergentes (#1–#4).
- **Balanceamento/telemetria:** métricas ainda são hipóteses até publicação de ambiente de QA autorizada.
- **Problemas de integração:** a branch de implementação não incorpora automaticamente as mudanças não commitadas da instalação do proprietário; resolver divergências manualmente.

## Gates

- **Gate 00 (local)**: pendente (backup local, git status, place Studio, assets reais e licenças).
- **Gate 01 (Golem hero)**: protótipo criado, **não aprovado visualmente**.
- **Gate 02 (montaria)**: implementação estendida, **não validada em Studio**.
- **Gate 03 (pista/entrega)**: integração de animações do código existente; **sem validação multi-cliente**.
- **Gate 04 (cozinha)**: controle de descoberta corrigido; **persistência/claim ainda precisam de testes de servidor**.
- **Publicação**: expressamente bloqueada até autorização independente do proprietário.
