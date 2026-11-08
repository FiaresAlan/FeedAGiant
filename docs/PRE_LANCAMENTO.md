# Pré-lançamento — Feed a Giant (Fase 5)

Atualizado em 08/11/2026. **Nada foi publicado, nenhum Robux foi gasto.** Este arquivo separa o que já está pronto do que só o dono da conta pode fazer.

Fontes do vault: `11 Monetization Publishing and Live Ops/Publishing an Experience.md` (regras de lançamento de outubro de 2026) e `27 Marketing and Growth/Launch Strategy - The First Two Weeks.md`.

---

## 1. O que já está pronto (feito pelo Claude)

| Item | Onde | Situação |
|---|---|---|
| Dados seguros: trava de sessão, autosave, BindToClose, compras gravadas junto com a entrega | `DataService`, `src/vendor/server/PlayerData.luau`, `Receipts.luau` | Fase 0, nota 8,75 |
| Remotes validados no servidor, com limite de frequência | `src/server/Guard.lua` e serviços | Fase 0 |
| Chances das caixas visíveis antes da compra; a Lucky Box paga não sorteia item pago | `LunchboxOdds`, `Shop.lua` (janela CHANCES) | Fase 0 |
| Produtos aposentados (congelar fome, restaurar níveis) recusados no servidor | `Config.DevProducts` (`retired = true`), `MonetizationService.canPrompt` | Fase 4 |
| Tutorial do primeiro minuto com funil de analytics `Tutorial_v1` (um passo por etapa, mais pulos e dicas como eventos) | `TutorialService` | Fase 4 |
| Idiomas: português (base), inglês e espanhol | `Locale.lua` (textos do código) e `src/localization/Strings.csv` (tradução automática) | Textos novos (coleção, faixa rara, raridades) nos três idiomas dentro do `Locale.lua` |
| Interface para celular: HUD, janelas e coluna de botões encolhem para caber em 844×390 | `UI.window` (FitScale), `HUD.buildSideButtons` (grade) | Fase 4; **falta jogar num celular de verdade** |
| Índice de coleção, abertura de caixa 3D, moedas voando, faixa de comida rara | `Collection.lua`, `FoodView.lua`, `Hatch.lua`, `Effects.lua` | Fases 3 e 4; fotos em `docs/qa/shots/fase4/` |

## 2. O que só você pode fazer (antes de publicar)

Em ordem. Nenhum destes passos foi feito por mim, porque mexem com dinheiro, identidade ou com o jogo público.

1. **Conta:** verificação de idade e 2 passos (2SV) ligados na conta que publica. A conta precisa ter pelo menos 2 dias.
2. **Público-alvo:** decidir entre só 16+ ou todas as idades.
   - Todas as idades exige Roblox Plus/Premium por 2 meses **ou** uma taxa reembolsável por jogo (1.000 Robux, segundo a página de publicação de outubro de 2026). Isso é gasto de Robux: **decisão sua**.
   - Mesmo com todas as idades, um jogo novo começa só para 16+ até atingir o mínimo de jogadores engajados. O painel "Audience Reach" mostra o número atual.
3. **Questionário de maturidade:** responder no Creator Hub. O jogo tem luta de boxe sem sangue (socos, nocaute, empurrão) e roubo de comida entre jogadores. Responda com sinceridade.
4. **Criar os produtos e passes** no Creator Hub e copiar os IDs para `src/shared/Config.lua`:
   - `Config.GamePasses`: DoubleCoins, VIP, AutoFeed, DragonGiant, PhoenixGiant, Guardian, BoxerPro, ArenaVIP (hoje todos `0`).
   - `Config.DevProducts`: Coins10k, Coins100k, SuperShield, LuckyBox, StaminaRefill, ArenaRematch, SpeciesReroll (hoje `id = 0`; com 0 o jogo não oferece nem entrega).
   - **Não crie** FreezeDecay7d nem RestoreLevels: estão aposentados.
   - Os preços vêm do Creator Hub (o jogo lê com `GetProductInfoAsync`). Os preços sugeridos estão em `Config.GamePassInfo` e `Config.DevProductInfo` (ver `docs/GAME_BRIEF.md`).
5. **Grupo (opcional):** `Config.GroupId` com o ID do seu grupo dá +10% para membros.
6. **Levar o código para o place oficial:** abrir "Alimente um Gigante" no Studio, conectar o Rojo (`rojo serve`) e depois re-assar o mapa (MAP_VERSION 2, com a arena). O passo a passo está no handoff, §A4b.
7. **Configurações do jogo:** Game Settings → Security → "Enable Studio Access to API Services" (para testar o DataStore real no Studio). Salvar.
8. **Ícone e miniaturas:** o vault recomenda 2 a 5 miniaturas diferentes e um ícone que funcione pequeno. As referências estão em `assets/` (logo e thumbnail). Fotos do jogo em `docs/qa/shots/` podem servir de base.
9. **Testes que eu não consegui fazer** (o controle de tela foi negado enquanto você estava fora):
   - **Dois jogadores**: duelo na arena, soco no ladrão e empurrão. Use Studio → Test → Clients and Servers → 2 jogadores.
   - **Celular de verdade**: abrir pelo app do Roblox, de preferência num aparelho simples, e conferir a HUD, a loja e a coleção.
   - **DataStore real**: entrar, comprar uma caixa, sair, voltar e ver se a comida continua.
10. **Publicar** só depois dos itens 1 a 9: primeiro privado com amigos (aba Playtest), depois público.

## 3. Primeiras duas semanas (vault, Launch Strategy)

- Não lance numa sexta à noite. Escolha um dia em que você possa acompanhar.
- Olhe o funil `Tutorial_v1` (Creator Hub → Analytics → Funnels). Corrija primeiro **o maior abandono**, uma mudança por vez.
- Metas iniciais (regra prática, substitua pelos seus dados): cada passo do tutorial mantém ≥ 90% de quem chegou nele; tutorial concluído por ≥ 70%.
- Não lance conteúdo novo na primeira semana enquanto o tutorial ainda estiver perdendo jogadores.

## 4. Sugestões em aberto (não feitas: mexem na economia)

- **Recompensa por coleção:** dar algo ao completar cada raridade (por exemplo, todas as Comuns → 1 caixa grátis). Aumenta a retenção, mas muda a economia. Quando você quiser, é uma linha no `Collection` e no servidor.
- **Música:** 5 faixas (pátio, loja, arena, evento, vitória). Precisa escolher áudios licenciados da Creator Store ou enviar arquivos seus; ficou para quando você puder ouvir e aprovar.
