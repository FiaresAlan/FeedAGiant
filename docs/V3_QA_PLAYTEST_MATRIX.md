# FeedAGiant V3 — matriz de QA executável no Roblox Studio

**Escopo:** QA da branch \`feat/feedagiant-v3-integracao-segura-2026-11-11\`, PR #5 (draft), não da \`main\`.

**Evidência até esta data:** somente inspeção de código e commits no GitHub. As caixas abaixo começam desmarcadas intencionalmente. Nenhum teste de física, dispositivo, persistência, câmera, áudio ou publicação foi executado nesta sessão de desenvolvimento.

## Preparação obrigatória

- [ ] Fazer cópia local do place atual e anotar caminho + SHA-256 do \`.rbxlx/\`.rbxl\`; proteger objetos no ServerStorage, anim IDs e fontes de asset.
- [ ] Comparar \`git status\`, branches e commits locais com a base remota, incluindo alterações feitas por outros agentes.
- [ ] Abrir cópia de QA, sincronizar a branch pelo Rojo. No projeto com testes, usar \`test.project.json\` (mapeia \`tests/\` em \`ServerScriptService/FwjelaaTests\`).
- [ ] Habilitar **somente no Studio**, antes de iniciar Play, no Command Bar:
  ~~~luau
  game:GetService("ReplicatedStorage"):SetAttribute("Feature_RebuildV2", true)
  ~~~
- [ ] Executar \`tools/V3StudioAudit.luau\` no Command Bar em modo servidor; copiar Output. É apenas leitura.
- [ ] Rodar \`require(game.ServerScriptService.FwjelaaTests.Runner)()\` no ambiente QA com mapeamento de testes. Registrar total, falhas, log e versão do Studio; **a existência das specs não é aprovação**.

## QA P0 — primeira rodada

| ID | Cenário | Aprovação | Estado |
|---|---|---|---|
| QA-01 | Servidor 1 player, escolhe Pedra; monta F, anda, sprint Shift, usa Q, desmonta | Avatar retoma controle e câmera | NÃO RODADO |
| QA-02 | 20 ciclos montar/desmontar, 10 reset/morte, desconexão e troca de personagem | Zero rigs duplicados, sem root preso | NÃO RODADO |
| QA-03 | Dois clientes: rival vê rider, criaturas/mãos e posição da carga | Replicação e câmera sem clipping importante | NÃO RODADO |
| QA-04 | Solo: pegar \`apple\`, voltar à base, entregar, alimentar | Inventário +1 no depósito, -1 no feed, XP único | NÃO RODADO |
| QA-05 | Dois clientes tentam mesma carga no mesmo instante | Um só \`cargoUid\` recebe holder | NÃO RODADO |
| QA-06 | Repetir depósito via remoto 100 vezes no mesmo estado | Item creditado no máximo uma vez | NÃO RODADO |
| QA-07 | Primeiras duas entregas do novato, depois interceptação legítima | Proteção antes da 3ª, cooldown e drop sem perder item salvo | NÃO RODADO |
| QA-08 | Interromper carregador, morrer, resetar, desconectar em carry/drop | Cargo retorna/despawns sem duplicar | NÃO RODADO |
| QA-09 | Reabrir mochila velha e conferir ovos, produtos e raridades | Nenhum valor antigo apagado, receipts mantidos | NÃO RODADO |
| QA-10 | Dois slots: Pão+Queijo 12s e Fruta+Mel 90s, desconectar/reentrar | Timers UTC independentes, READY salvo | NÃO RODADO |
| QA-11 | Repetir claim de panela 100 vezes e começar job inválido | 1 prato máximo, ingredientes preservados | NÃO RODADO |
| QA-12 | Mochila cheia, prato READY, liberar espaço e reclamar | Prato não some, nem duplica | NÃO RODADO |
| QA-13 | Receita não descoberta via ID, combinação válida, pergaminho repetido | ID desconhecido rejeitado; combinação descobre; sem farm | NÃO RODADO |
| QA-14 | Três elementos em QA Studio, peso pesado e boost, 8 players | Silhuetas distintas, mesma hitbox, sem exploit de velocidade | NÃO RODADO |
| QA-15 | Abrir livro e mochila, correr, montar e desmontar em 720x1600 e landscape | Controles touch legíveis sem overlay escuro | NÃO RODADO |
| QA-16 | Testar com latência simulada 150ms e perda de frames | Sem controle travado, salto súbito ou duplicação | NÃO RODADO |
| QA-17 | Som de panela pronto e bolhas em 8 bases | Som espacial curto, partículas leves, sem sirene global | NÃO RODADO |
| QA-18 | Registrar FIRST_FEED → FIRST_MOUNT → PICKUP → DEPOSIT → RECIPE → POT → CLAIM → SECOND_FEED | Analytics.recent tem eventos na ordem real | NÃO RODADO |
| QA-19 | Conta antiga que ficou dias fora | V3 não reduz níveis e não destrói saves; sem roubo antigo | NÃO RODADO |
| QA-20 | Render e Play Solo, 2 clientes, Android real/emulador identificado e gamepad | FPS, memória, clips e defeitos medidos | NÃO RODADO |

### Scripts de replay para cliente de QA

Executar **apenas no cliente do Roblox Studio**, depois de se aproximar da própria entrega com carga:

~~~luau
local r = game.ReplicatedStorage.Shared.Remotes
r = require(r)
for _ = 1, 100 do r.V2LaneRequest:FireServer("deposit") end
~~~

Para claim, executar **apenas quando a panela A tiver um prato READY**. O teste consulta o ID do job recebido do servidor, sem inventar \`jobId\`:

~~~luau
local r = require(game.ReplicatedStorage.Shared.Remotes)
local snapshot
local conn = r.V2CookState.OnClientEvent:Connect(function(s) snapshot = s end)
r.V2CookRequest:FireServer("snapshot")
task.wait(0.5)
local job = snapshot and snapshot.slots and snapshot.slots[1] and snapshot.slots[1].jobId
assert(type(job) == "string", "Panela A nao tem job valido")
for _ = 1, 100 do r.V2CookRequest:FireServer("claim", 1, job) end
conn:Disconnect()
~~~

Esses scripts não simulam simultaneidade perfeita nem falha do DataStore. Registrar item IDs e quantidade **antes e depois** em conta de teste.

### Telemetria QA

No **Command Bar do servidor** do Play Studio:

~~~luau
local a = require(game.ServerScriptService.Server.Analytics)
for _, event in a.recent do print(event.name, table.concat(event.fields, ", ")) end
~~~

O logger local prova que hooks foram chamados; **não** comprova que o AnalyticsService da experiência publicada registrou o evento. Na aplicação publicada, validar a ingestão separadamente após autorização do proprietário.

## Gates de negócio e publicação

- [ ] Evidências de vídeo: base, montaria, entrega, 20s de marcha e alimentação, outro jogador observando
- [ ] Licenças de cada rig/clip/mesh/audio por ID original, autor, permissão e data
- [ ] Acesso de Robux e recibos antigos auditados com contas fictícias
- [ ] Benchmarks FPS/memória e diferenças PC/touch/gamepad
- [ ] Rollback \`RebuildV2 = false\` testado; perfil antigo permanece íntegro
- [ ] Checklist P0 sem falhas críticas e aprovação expressa do proprietário para publicar cópia QA
- [ ] Aprovação expressa separada antes de qualquer ads/Robux

**Estado global: NO-GO para publicação.** O código pode ser avaliado em cópia local, sem aprovação automática de fases. Não fazer merge antes de completar os gates.