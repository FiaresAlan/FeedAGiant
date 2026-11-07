# Fase 0 — evidências de teste (07/11/2026)

Place de teste: `rojo build test.project.json` → cópia em pasta temporária, aberta no Studio (nunca o original).

## Verificador Luau
`python studio-kit/tools/luau_check.py --project .` → fwjelaa-check PASS, selene PASS, StyLua PASS, luau-lsp (strict, sourcemap Rojo) PASS → **overall PASS (39 arquivos)**.

## Testes automáticos (Edit mode)
`require(ServerScriptService.FwjelaaTests.Runner)()` → **39 passed, 0 failed, 7 spec modules**
(LunchboxOdds, Odds, PlayerData, Policy, RateLimit, Receipts, Signal). Erros no log são casos de falha propositais dos specs.

## Play solo (servidor real do Studio; DataStore = StudioMemoryStore porque o place não é publicado)
Script de sondagem injetado no servidor do place de teste (mesmo cache de módulos do jogo):

| Caso | Resultado |
|---|---|
| Servidor e cliente sobem | sem erro de script; 8 bases; `DataReady=true`, `PaidRandomAllowed` definido por jogador |
| `ShopService.openBox` 3× seguidas + 1 após 0,5 s | 4 entregas (inventário 2→6); anti-spam fica só no remote `RequestBuyBox` (0 cobrança recusada) |
| Alimentar do inventário | inventário 6→5, XP 0→10 (Common = 10) |
| Limite da mochila | 295 de 300 aceitos; ficou em 300 = `Config.MaxInventory` |
| `DataService.saveNow` | true |
| Queda do armazenamento (`MemoryStoreFailNext=50`) | save retorna false após 4 tentativas (7,6 s); jogador continua; ao normalizar, save = true |
| Falha ao carregar (`SimulateLoadFailure=true`) | jogador removido com mensagem; "Nothing was saved" (perfil real não é sobrescrito) |
| Parar o jogo (BindToClose) | sem erro no log |
| Sons da caixa | IDs da v4 (9114653986/9114611543/9114646405) davam "Asset type does not match"; trocados por `Config.Sounds`; sem erro depois |

## Rodada de correção 1 (commit a2e2680), place de teste novo
Correções vindas do painel (6,25) e da auditoria de código: `Guard.allow` (token bucket por jogador e ação) em TODOS os
`OnServerEvent`; `Guard.isIndex` (inteiro em faixa) em place/pickup/feed; depósito do roubo exige personagem dentro da
própria base (servidor) e tempo mínimo até a base; mochila nunca apaga itens na carga (teto duro 2000; pago entrega
sempre); caixa paga sorteia e mostra chances SEM bônus de evento; arena com ticks neutros, desistência = vitória de quem
ficou, `busy`/torneio sempre limpos (pcall); combate não recria estado de quem saiu e liga `CharacterAdded` para quem já
estava; canal de roubo em pcall; chuva de comida com `SetNetworkOwner(nil)`; equipar espécie já equipada não reconstrói.

| Caso | Resultado |
|---|---|
| Verificador Luau | overall PASS (39 arquivos) |
| Specs | 39 passed, 0 failed |
| `Guard.isIndex` 3 / 1.5 / NaN / inf / -1 / "3" / 13 (máx 12) | true, false, false, false, false, false, false |
| 20 tentativas de código seguidas | 3 aceitas (resto recusado com aviso) |
| Mochila com 300: normal / force | recusa / aceita |
| Mochila com 2000: force / pago / caixa paga / caixa grátis | recusa / aceita / aceita / recusa |
| Fuzz do cliente: 1.971 chamadas em todos os RemoteEvents (nil, NaN, inf, -1, 1.5, 1e9, string de 500, tabelas, Instance, Vector3) + 60 seguidas por remote | **0 erros no servidor**; `GetFullState` responde depois |

## Desempenho (play solo no PC, place de teste; NÃO é medição em celular)
| Medida | Valor |
|---|---|
| Cliente: fps médio em 30 s / pior quadro | 60,0 / 20,7 ms |
| Servidor: Heartbeat em 20 s / pior passo | 60,0 Hz / 20,1 ms |
| Rede servidor→cliente (DataSendKbps), mediana / máx. em 20 s | 0,90 / 1,40 kbps |
| Instâncias: Workspace / PlayerGui | 614 / 1.116 |
| Memória | o `GetTotalMemoryUsageMb` do Studio (~2,6 GB) mede o processo inteiro do Studio: não serve como número de celular |

## Painéis de revisão (rubrica `system`, 3 revisores cegos, mediana por critério, soma refeita)
| Rodada | Notas S1..S6 | Nota | Bloqueador |
|---|---|---|---|
| 1 (antes da correção) | [1,1,1,2,1,2] | 6,25 | sem limite de frequência nos remotes; 2 jogadores não testado |
| 2 (depois da correção 1) | [1,2,1,2,1,2] | 7,5 | S1: roubo/depósito/soco/duelo com 2 jogadores não testado |

## NÃO testado ainda
- 2 jogadores (roubo, depósito, soco no ladrão, duelo da arena): o MCP do Studio só inicia Play solo e o controle da tela do Studio não foi autorizado. Precisa do teste manual (Studio → Testar → Clientes e servidores, 2 jogadores).
- Compras reais: os IDs de produtos/passes são 0 (placeholders); o fluxo de recibo é coberto pelo `Receipts.spec`.
- Persistência entre sessões: o armazenamento de teste dura só uma sessão.

## Ruído conhecido
`rbxassetid://203785492` e `81504106` não aparecem em nenhum arquivo do repositório: vêm do plugin "Ecos Tools" do Studio.
