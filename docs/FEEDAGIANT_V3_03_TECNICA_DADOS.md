# FEED A GIANT V3 — ARQUITETURA TÉCNICA, DADOS E CONTRATOS
11/11/2026 | Documento para Claude | Código aqui é referência de comportamento; integrar no repositório real antes de compilar

## 0. Auditoria obrigatória: não presumir versão atual do projeto

GitHub consultado: main em 374c95436109d1023a43b4914dd8c11ac86ad6e3. Branch e PRs de Ilha Viva contêm trabalho ainda em draft. ZIPs locais podem conter código e place mais recentes. O Claude DEVE iniciar com backup de tudo que existe: fonte Rojo, arquivo place .rbxl/.rbxlx, pasta de models/meshes, commits não publicados, DataStore keys/schemas e links de assets. Rodar git status, diff e logs antes de fazer checkout/reset.
No branch consultado:
- src/server/Services/GiantService.lua: espécies, nível, modelo, stage, XP, spawns.
- src/server/Services/PlotService.lua: inventário, giveFood, alimentação, plot.
- src/server/Services/EggService.lua: ovos, incubação, aquisição e roubo antigo de ovos.
- src/server/Services/ArenaService.lua: duelos e bots antigos (NÃO expandir para V3).
- src/server/Services/DataService.lua: profile default/sanitize/registerSlice/saveNow, persistência.
- src/server/Services/SocialFeastService.lua: cozinha social antiga para dois jogadores; manter isolada.
- src/server/Services/MutationService.lua: mutações ALIMENTARES antigas; não usar para cruzamento ou mutação de gigantes.
- src/shared/Config.lua: parâmetros centralizados de gameplay (a versão consultada indicava MaxPlayers 8, MaxInventory 300 etc.).
- default.project.json: mapeamento Rojo; respeitar a estrutura.
Estas observações vêm da inspeção do branch em 11/11; NÃO são prova do estado atual em Roblox Studio.

Gerar um arquivo docs/V3_AUDITORIA_LOCAL_REAL.md com a lista real de arquivos e recursos antes de integrar. Não sobrescrever saves, IDs de Foods, visual por script ou UI sem reportar efeitos colaterais.

## 1. Arquitetura recomendada — módulos novos adaptadores

Objetivo: criar serviços novos e plugar os antigos em poucos pontos. NÃO reescrever arquitetura persistente.

Shared/config:
- ElementRunRules: efeito de elemento, stamina, limites de velocidade e peso, estados.
- RecipeCatalogV3: tabela de ingredientes e seis receitas determinísticas; validação de combinações sem perda.
- V3Flags: FeatureFlags, leitura segura cliente/servidor; disabled por padrão até QA.

Servidor:
- MountService: propriedade de gigante ativo, mount/unmount, lifecycle, attachment, reset.
- RunLaneService: spawns e pickup de objetos, carga ativa, reserva, drop, delivery, cooldown e zona segura.
- PotServiceV3: duas panelas offline, debitar input, ready e claim idempotente.
- CookbookServiceV3: descobertas de receita/pergaminho, atualização de HUD, sem novos currencies.
- V3MetricsService: wrapper server-only para AnalyticsService, com gating em ambiente publicado.
- GiantService e PlotService existentes: adaptadores; feed e XP continuam em seus próprios serviços.

Cliente:
- MountController: input local, câmera, botões PC/mobile/console e visual montaria.
- LaneHudController: carga/peso/boost/direção de casa, sem paredes de UI.
- CookbookController: livro, combinar ingredientes, estado das duas panelas.
- CreaturePresentationController: animations, VFX/SFX cosméticos sem confiança no client para economia.

## 2. Remotes e segurança

Criar RemoteEvents/RemoteFunctions via um RemoteContract revisado; nomes exatos definidos após inspeção dos remotes existentes.
Exemplos lógicos:
MountRequest(action, requestedCreatureUid?)
MountStateChanged(snapshot)
RunInput(seq, moveX, moveZ, sprintHeld, boostPressed) — SOMENTE se arquitetura escolhida requer transporte de direção; validar frequência e vetor.
RunGrabRequest(cargoUid)
RunDropRequest(cargoUid)
RunInterceptRequest(targetCargoUid)
RunDepositRequest(cargoUid)
PotStartRequest(potIndex, recipeId)
PotClaimRequest(potIndex, jobId)
PotStateChanged(snapshot)
CookbookRequestSnapshot()
ServerDeliveryResult(result)

**Não criar um Remote "AwardFood", "AddXP", "SetLevel", "SetSpeed", "SetCookDone" ou "ForceOwnership" que aceite parâmetros econômicos do cliente.**
Todos os direitos verificados no servidor: ID dono, personagem vivo, distância, etapa, carga não depositada, slots, receitas realmente existentes, limites de peso, cooldown, tipo de item, tempo UTC.
Cada chamada pode ter rate limiting, seq anti-replay e idempotency key quando faz transação. Não usar nomes de objetos enviados pelo client como caminho absoluto de Instances sem validação.

## 3. Montaria: arquitetura segura para um Humanoid montável

Objetivo: humano normal no player, gigante como NPC humanoide montável de tamanho compatível com animação.

### Estrutura visual sugerida

Giant Model
  HumanoidRootPart (raiz física controlada)
  Humanoid
  Animator
  CreatureVisualRig (peças/mesh, bones ou joints)
  ShoulderSeatAnchor (Attachment rígido à parte superior do torso)
  CargoCarryAnchor (Attachment nas mãos/braço)
  AnimationTracks (IDs ou templates validados)

### Etapas

1. Player interage perto da própria base. MountService valida que o gigante é seu ativo, não está ocupado em troca/combate, e tem model com RootPart, Humanoid e Animator.
2. Salva estado humano anterior necessário (câmera no cliente, colisões, auto-rotate, tools, estado de assento).
3. Posiciona avatar sobre apoio invisível soldado ao torso (Seat padrão OU weld/rig de montaria validado); desliga colisão entre rider e criatura para evitar impulso e flutuação. Não ancorar o RootPart do avatar de um jeito que congele a montagem inteira.
4. Habilita estado MOUNTED por servidor e notifica cliente. Cliente ativa terceira pessoa sobre o gigante, captura movimentos e sprint/boost com ContextActionService/InputActionManager quando disponível. Testar um caminho técnico com prototype antes de padronizar.
5. Movimentação não usa VehicleSeat como máquina veicular. Giant Humanoid:Move() ou controlador Humanoid compatível movimenta o gigante; animações reproduzem idle/walk/run e carry de acordo com velocidade real. Se cliente controlar física local, servidor confere posição, velocidade e teleportes com tolerância para latência; se servidor aplicar comandos, limitar frequência (por ex. 10-15 Hz de input, teste em rede de 120 ms) e interpolar visual, sem enviar 60 RemoteEvents/s por client.
6. Enquanto mounted, o avatar permanece visível no ombro, tem animação de postura, não pode usar ferramentas que explorem hitbox ou cair por bug; toda distância de interação é avaliada do gigante, não do avatar humano escondido.
7. Unmount: soltar carga em posição segura ou bloquear saída com mensagem curta quando carregando; reposicionar humano em piso válido; restaurar controles/câmera/collision/autorotate/sit; limpar weld, estado e conexões.
8. Se CharacterAdded, morte, streaming, desconexão, reset, teleport ou troca de gigante acontecerem, usar cleanup idempotente, sem duplicação.
9. Teste com 2 clientes, dos quais um enxerga o outro montado. E com teclado/gamepad/touch. Não depender de Play Solo.

### Alternativas de implementação

A — Rider humano soldado a giant Humanoid que recebe input via controller customizado.
B — Player.Character temporariamente representado por rig de gigante; um avatar humano é apenas visual preso aos ombros.
Preferir A como hipótese inicial por preservar avatar/skin, mas **não declarar A definitiva sem validar câmera, replicação, reset e input**. Se não ficar fluida, testar B em branch de laboratório. Cada abordagem exige evidência no Studio antes de continuar.
O giant não pode se mover independentemente enquanto o dono está controlando, nem permitir controle por outro player.

Referências: https://create.roblox.com/docs/characters/adaptive-animation e https://create.roblox.com/docs/reference/engine/classes/Seat . Um Seat fixa o avatar ao assento; NÃO dirige por si só um humanoide gigante, portanto precisa controller. VehicleSeat não é equivalente a montaria humanoide.

## 4. RunLaneService — invariantes de cargo

**Invariante A:** um cargoUid ativo existe em um estado autoritativo por vez.
**B:** um cargoUid entregue concede efeito NO MÁXIMO UMA VEZ.
**C:** posse não é derivada de nome do modelo no Workspace ou da UI.
**D:** carga carregada não pode ser colocada no inventário sem passar pela zona de entrega.
**E:** carga nunca vira ovo ou comida do inventário roubável; os sistemas são separados.

Definição de cargo:
{
  uid: string,
  kind: "ready_food" | "ingredient" | "recipe_scroll",
  canonicalItemId: string,
  weightClass: "light" | "medium" | "heavy",
  state: "world" | "reserved" | "carried" | "dropped" | "deposited" | "expired",
  holderUserId: number?,
  claimNonce: string?,
  spawnedAt: number,
  lastSafePosition: Vector3
}
Persistir somente o crédito final e IDs de descoberta no profile; objetos temporários são estado volátil do servidor e não devem ser duplicados em DataStore.

### Fluxo de reserva e entrega

Pickup request -> validar -> marcar state RESERVED -> anexar visual -> state CARRIED.
Drop/intercept -> validar atacante/alcance/cooldown -> state DROPPED com immunity curta -> soltar visual controladamente.
Deposit -> validar que player está em sua zona, cargoUid ainda CARRIED e server owner é player, origem válida e limite não excedido -> chamar adaptador PlotService.giveFood ou CookbookService unlock sem yield no meio da transição crítica -> marcar DEPOSITED no ledger server -> enviar confirmação -> remover visual.
Para entrega persistente através de falha abrupta do servidor, usar atomicidade da alteração do profile e um nonce guardado no mesmo perfil ou no ledger apropriado; detectar tentativas repetidas. Não confiar só na existência física do modelo para impedir prêmio duplo.

### Intercepção

Uma tentativa curta (não combate total), cooldown por atacante/alvo, aviso visual e áudio, sem permitir atacar dentro da base ou as primeiras entregas de novatos. Queda de carga nunca remove inventário permanente e é recuperável. Fazer testes em alta latência e simultaneidade.

## 5. Regras de movimento e balanceamento

Centralizar em ElementRunRules. Não guardar WalkSpeed em DataStore como valor editável do client. Guardar progressão original e calcular speed efetiva a cada estado server-side.

Sugestão para testes (não números oficiais):

speed = baseSpeed * progressionMultiplier * boostMultiplier * (1 - weightPenaltyEffective)
progressionMultiplier ≤ 1.08
boost fogo = 1.12 por 3 s, cooldown 25 s
weightPenaltyEffective = clamp(rawPenalty * (1 - stoneRelief), minPenaltyByWeight, rawPenalty)
stoneRelief enquanto boost = 0.40 por 4 s, cooldown 25 s
iceShield = bloquear uma interrupção por 2 s, cooldown 30 s

rawPenalty = 0 / .10 / .25 para light/medium/heavy.
minPenaltyHeavy = .08.
Sprint pode ser multiplicador separado com consumo de stamina e recuperação. Aplicar limites máximos após somar boosts para evitar overflow. Velocidade sem carga, com carga leve/média/pesada, sprint e poder precisam de testes comparáveis entre elementos.
Nenhum ataque de interrupção ganha crédito econômico sozinho; progresso vem da entrega e da alimentação.

### Exemplo de módulo puro de limite

~~~luau
local RunRules = {}

RunRules.BASE_SPEED = 20
RunRules.MAX_PROGRESSION = 1.08
RunRules.PENALTIES = { light = 0, medium = 0.10, heavy = 0.25 }

function RunRules.effectiveSpeed(progressionMultiplier: number, weightClass: string, relief: number, elementalBoost: number): number
    local progress = math.clamp(progressionMultiplier, 1, RunRules.MAX_PROGRESSION)
    local raw = RunRules.PENALTIES[weightClass] or 0
    local effectivePenalty = math.max(weightClass == "heavy" and 0.08 or 0, raw * (1 - math.clamp(relief, 0, 0.40)))
    local speed = RunRules.BASE_SPEED * progress * math.clamp(elementalBoost, 1, 1.12) * (1 - effectivePenalty)
    return math.clamp(speed, 0, 26)
end

return RunRules
~~~

É exemplo de regra matemática. **Não instalar diretamente sem adicionar sprint/stamina, validação de categoria, casos de peso e testes.** O valor 26 pode conflitar com sprint 27 se aplicado na camada errada; especificar fases separadas. É intencionalmente isolado para chamar atenção ao teto final.

## 6. PotServiceV3 — contratos de persistência

Não criar DataStore separado por panela sem motivo. O jogador já tem um profile com autosave/session lock; incorporar dois slots em slice versionado.

Estrutura ilustrativa:
{
  version = 1,
  slots = {
    { state="empty" },
    { state="empty" }
  },
  discoveredRecipeIds = {},
  claimedCookingJobs = {} -- lista limitada / nonce bounded
}

Job:
{
 state="cooking",
 jobId="guid do servidor",
 recipeId="meat_pepper",
 inputItemIds={"meat","pepper_rare"},
 startedAtUtc=serverUnixSeconds,
 endsAtUtc=serverUnixSeconds + duration,
 stateVersion=1
}

**Não aceitar client endsAtUtc, duration, recipe power ou ingredient IDs arbitrários.** Client pede recipeId e potIndex; servidor busca catalog e inventário. Na mesma mutação do profile em memória: verifica slot EMPTY e ingredientes, reduz quantidades, cria job com timestamps do servidor; marca dirty e salva em checkpoint oportuno. Se crash antes do save, esperar rollback do job E ingredientes juntos, nunca perder apenas um lado.
Conclusão: no login/refresh, job COOKING com now >= endsAtUtc vira READY sem precisar de timer rodando offline; emitir áudio/VFX só no cliente que está vendo. Claim confere pot, ready, storage space, nonce; incrementa um alimento pronto e remove job na mesma mutação/ledger. Se inventário cheio, permanece READY para claim posterior. Pergaminhos não entram nas panelas.
Ovo, medalhas, purchases, slots de plot, XP e economia não são removidos ou sobrescritos pela sanitização da V3. Planejar migração: profile sem slice começa com slots EMPTY, sem deletar desconhecidos.
Uma compra já processada via Marketplace/Receipts não pode ser perdida por atualizações de schemas.

## 7. RecipeCatalogV3 — catálogo e Livro

Definição por IDs canônicos. Não basear resultado na string do nome do item; usar IDs validados e ordenar entradas de par sem impor a ordem do jogador. Livro guarda descoberta pelo ID da receita, não por texto.
Apenas receitas explícitas do catálogo dão resultado; combinação inexistente não consome nada nem cria “lixo”. Ingredient count e max inventory auditados. O resultado de um cook claim entra no pipeline atual com um novo item ID **somente se** o projeto foi migrado para ele; caso contrário criar derivado de item existente com metadata segura.
Pergaminho de receita entregue: servidor marca discovered; não consome propriedade de outro jogador; tentativa repetida não gera coins infinitas. Pergaminho de receita descoberta novamente pode virar uma pequena recompensa única ou ficar sem prêmio — não farmar desbloqueio repetido.
Ao abrir Livro, receber snapshot filtrado: descobertas e pistas, sem expor todos segredos antes de jogar (contudo segredo não é segurança do servidor).

## 8. Integração com serviços antigos

- PlotService.feed/giveFood: preservar como fonte de verdade de alimentação e inventário. Adaptar only transactional entrega; não duplicar a função.
- GiantService.levelOf/scaleForLevel/spawnFor: reaproveitar dados de progressão, mapear aparência a estágios e montar rig visual novo, sem quebrar IDs de espécie.
- ArenaService: manter compatível, mas flag DISABLED para V3; não criar 2ª arena PvP no mesmo ciclo.
- EggService: preservar profile, ovos, recibos e condições legais; flag visual para evitar início com roubo de ovo. Nunca apagar os ovos do usuário.
- SocialFeastService: desligar entrada obrigatória e banner, mas não remover código; depois retomar como evento.
- MutationService antigo: auditar economicamente, não usar como serviço de mutação de gigante.
- Config: todas novas durations/powers/speeds e feature flags centralizadas, com defaults conservadores.
- Remotes: contrato explícito por serviço, rate limit e compatibilidade com scripts antigos.

## 9. Proteção de usuários e acessibilidade

- Sem dano permanente ou perda de nível/ovo por roubo. Nenhuma perda offline.
- Sem “pagar para escapar” ou temporizador de perda de itens.
- Botões com rótulos e feedback sonoro opcional; camera shake reduzido por setting.
- Jogador solo pode obter ingredientes e cozinhar todas receitas, inclusive as raras com maior paciência.
- Regras de boost são visuais sem flashes que encobrem HUD; não exigir precisão de mira PvP.
- Não se pode assumir que proprietário de rig é jogador por network ownership; posse econômica checada pela sessão.
- Moderação e odds de itens aleatórios pagos via políticas atuais. Consultar https://create.roblox.com/docs/production/monetization/paid-random-items . V3 NÃO adiciona paid-random items.

## 10. Implementação e ambiente de testes

Projetar com Rojo, Selene, StyLua e testes Luau já existentes. Limpar warnings reais e testar APIs apenas onde o Roblox Studio fornece Runtime. Não confiar em teste textual de delimitadores como compilação.
Fazer script de verificação de mapa e anexar relatório com conflitos de área. Fazer auditoria de remotes e handlers duplicados. Instalar versionamento e backup de DataStore de teste antes de alterar perfis.
Gates:
- Controlar o gigante por 2 min sem crash, travamento, falha de câmera, voo ou atravessar chão.
- Dois clientes concorrendo por UM cargo: exatamente um recebe prêmio, inclusive em condições de perda de conexão.
- Dois cooks offline concluídos após reentrar no servidor de teste, sem duplicação.
- Rookie entra sem amigos, alimenta pelo menos duas vezes e experimenta a pista.
- Exportar screenshots e vídeo com rig/escala/studs visivelmente corretos.
- Teste com max players configurado e simulação de rede móvel; descrever o que NÃO foi testado.
