# FEED A GIANT — Guia de Instalação e Lançamento

> **v2.0** — Espécies (7), estágios visuais Bebê→DEUS, encolhimento por ausência + bônus de retorno, combate de socos (PC/mobile), Disputa de Comida (drops), Giant Clash (duelos + campeonato a cada 15 min), 5 novos Game Passes e 5 novos Dev Products. Veja `GAME_DESIGN.md` §v2.

Jogo Roblox completo, 100% em Luau, com mapa gerado por código (sem assets externos).
Leia `GAME_DESIGN.md` para entender o design e por que cada mecânica existe.

---

## 1. O que está no pacote

| Caminho | O que é |
|---|---|
| `FeedAGiant.rbxl` | **Place file pronto.** Abra no Roblox Studio e clique em Play. |
| `FeedAGiant.rbxlx` | Mesmo place em XML (útil para diff/versionamento). |
| `src/` | Código-fonte Luau organizado para Rojo (servidor, cliente, shared). |
| `default.project.json` | Mapa do projeto Rojo (`src/` → árvore do DataModel). |
| `tools/Rojo_plugin_v7.4.4.rbxm` | Plugin Rojo para Studio (só se quiser editar código em VS Code). |
| `assets/Icon_512x512.png` | Ícone do jogo (upload no Creator Hub). |
| `assets/Thumbnail_1920x1080.png` | Thumbnail "antes e depois" (upload no Creator Hub). |
| `GAME_DESIGN.md` | Game Design Document completo. |

---

## 2. Rodar em 2 minutos (caminho rápido)

1. Instale o [Roblox Studio](https://create.roblox.com/).
2. Abra `FeedAGiant.rbxl` (File → Open from File).
3. Em **Home → Game Settings → Security**, ative **Enable Studio Access to API Services** (necessário para DataStore funcionar no Studio).
4. Clique em **Play**. Você nasce na sua Base com 2 comidas; pise no pad laranja central para abrir a Loja.
5. Para testar roubo: **Test → Clients and Servers → 2 Players → Start**.

## 3. Publicar

1. **File → Publish to Roblox As…** → crie uma nova experiência.
2. No [Creator Hub](https://create.roblox.com/dashboard/creations), abra a experiência:
   - **Basic Settings**: suba `assets/Icon_512x512.png` e `assets/Thumbnail_1920x1080.png`.
   - **Places → Configure**: Max Players = **8** (o mapa tem 8 bases).
   - **Access**: Public.
3. **Monetização** (Creator Hub → Monetization):
   - Crie 3 **Passes**: `2x Moedas` (299), `VIP` (499), `Auto-Feed` (399).
   - Crie 4 **Developer Products**: `10.000 Moedas` (99), `100.000 Moedas` (799), `Super Escudo` (49), `Lucky Lunchbox` (149).
   - Copie cada ID e cole em `ReplicatedStorage/Shared/Config` (seção `Config.GamePasses` / `Config.DevProducts`). Enquanto o ID for `0`, o jogo mostra um aviso amigável em vez de quebrar.
4. **Grupo**: se publicar pelo grupo, coloque o ID em `Config.GroupId` para membros ganharem +10% moedas.
5. Publique novamente após editar o Config.

## 4. Editar o código (opcional — fluxo profissional com Rojo)

1. Instale o Rojo CLI: `cargo install rojo` ou baixe em https://github.com/rojo-rbx/rojo/releases.
2. No Studio: **Plugins → Manage Plugins → Install from file** → `tools/Rojo_plugin_v7.4.4.rbxm`.
3. Na pasta do projeto: `rojo serve` e, no Studio, clique **Rojo → Connect**.
4. Edite qualquer arquivo em `src/` no VS Code; as mudanças aparecem ao vivo no Studio.
5. Para regenerar o place: `rojo build -o FeedAGiant.rbxl`.

## 5. Arquitetura (onde mexer em cada coisa)

```
src/
├─ shared/
│  ├─ Config.lua         ← TODO o balanceamento: preços, raridades, XP, eventos, IDs Robux
│  ├─ Remotes.lua        ← contrato cliente↔servidor (RemoteEvents)
│  └─ Util.lua           ← formatação, sorteio ponderado, construtores de Part
├─ server/
│  ├─ Main.server.lua    ← boot, entrada/saída de jogadores, kit inicial
│  └─ Services/
│     ├─ MapService      ← gera ilha central, 8 bases, slots, placas
│     ├─ DataService     ← DataStore com retry/autosave + OrderedDataStore p/ leaderboard
│     ├─ GiantService    ← modelo do Gigante, escala por nível, humor, XP
│     ├─ PlotService     ← inventário, pátio, alimentar, renda passiva, auto-feed
│     ├─ ShopService     ← lunchboxes (gacha), rebirth, códigos, daily
│     ├─ StealService    ← roubo com canal 3s, escudos, bastão
│     ├─ EventService    ← 4 eventos globais (Golden Hour, Chuva, Boss, Lucky)
│     ├─ MonetizationService ← passes e dev products (ProcessReceipt)
│     └─ LeaderboardService  ← placares físicos no mapa
└─ client/
   ├─ Main.client.lua    ← boot do cliente
   ├─ State.lua          ← cache do estado recebido do servidor
   ├─ UI.lua             ← kit de componentes (botões, janelas, estilo)
   └─ Controllers/
      ├─ HUD             ← moedas, nível/XP, fome, escudo, botões, ALIMENTAR
      ├─ Shop            ← lunchboxes, Robux, códigos
      ├─ Inventory       ← mochila + pátio (colocar / comer / recolher)
      ├─ Hatch           ← animação de abertura de caixa
      └─ Notifications   ← toasts, banner de evento, alerta de roubo
```

**Toda a segurança está no servidor**: cliente só envia pedidos (`RequestX`); o servidor valida moedas, slots, posse e cooldowns.

## 6. Checklist de balanceamento inicial (primeira semana)

| Métrica | Alvo | Onde ajustar |
|---|---|---|
| Tempo até 1ª Lunchbox | < 60 s | `Config.StartingCoins`, `price` da box comum |
| Tempo até Nv. 10 | ~10 min | `Config.xpNeeded`, `Rarities[*].xp` |
| Tempo até 1º Rebirth | ~2–3 h | `Config.Rebirth.MinLevel` |
| Taxa de roubo bem-sucedido | 30–40% | `Config.Steal.ChannelTime`, escudos |
| Intervalo de eventos | 6–9 min | `Config.Events.MinInterval/MaxInterval` |

## 7. Playbook de lançamento (viralização)

**Semana 0 — pré-lançamento**
- Publique com código `LAUNCH` ativo (2.500 moedas) e divulgue só no TikTok/Shorts: vídeo de 15 s mostrando o Gigante nível 1 → nível 150 (use o pulso de escala do `GiantService`).
- Thumbnail A/B: use a `Thumbnail_1920x1080.png` e uma variante só com o Gigante colossal. Troque a de menor CTR em 48 h.

**Semana 1 — launch**
- Ative anúncios Roblox Sponsored (mín. 500–1.000 R$/dia por 3 dias) segmentando 9–14 anos.
- Convide 5–10 micro-criadores (10k–100k) com código exclusivo (adicione em `Config.PromoCodes`).
- Monitore D1 retention no Creator Hub; se < 25%, reduza `HungerDecayPerSec` e aumente XP das comuns.

**Semana 2+** — siga o roadmap do `GAME_DESIGN.md` (Trading, Skins, Pets, Guerra de Gigantes). Toda atualização = novo evento + novo código = novo vídeo.

## 8. Problemas comuns

| Sintoma | Causa | Solução |
|---|---|---|
| "Falha ao carregar seus dados" no Studio | API Services desativado | Game Settings → Security → Enable Studio Access to API Services |
| Botões de Robux dizem "não configurado" | IDs ainda são `0` | Preencha `Config.GamePasses`/`Config.DevProducts` |
| Leaderboard vazio | OrderedDataStore só atualiza ao salvar | Jogue 1–2 min e saia; ou espere autosave |
| Jogador nasce fora da base | `Baseplate` muito pequeno após editar `BaseRadius` | Ajuste `Workspace.Baseplate.Size` no `default.project.json` |
