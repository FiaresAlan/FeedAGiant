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

## NÃO testado ainda
- 2 jogadores (roubo, soco no ladrão, duelo da arena): o MCP do Studio só inicia Play solo.
- Compras reais: os IDs de produtos/passes são 0 (placeholders); o fluxo de recibo é coberto pelo `Receipts.spec`.
- Persistência entre sessões: o armazenamento de teste dura só uma sessão.

## Ruído conhecido
`rbxassetid://203785492` e `81504106` não aparecem em nenhum arquivo do repositório: vêm do plugin "Ecos Tools" do Studio.
