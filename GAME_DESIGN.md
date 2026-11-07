# FEED A GIANT — Game Design Document

> **Pitch de uma linha:** Você adota um Gigante bebê que come TUDO. Quanto mais ele come, mais cresce — até ficar maior que o mapa. Outros jogadores podem invadir seu lote e **roubar a comida do seu Gigante**. Alimente, cresça, defenda, roube. Um Gigante de 500 metros é a prova de que você é o melhor do servidor.

---

## 1. Por que ISSO vai viralizar (a análise que você não pediu, mas está aqui)

| Mecânica | Referência comprovada na Roblox | Como aplicamos |
|---|---|---|
| **Lote pessoal + roubo entre jogadores** | *Steal a Brainrot* (bilhões de visitas em 2025) | Cada jogador tem uma Base com um Gigante. Comida no Pátio pode ser roubada. |
| **Crescimento visual exagerado** | *Grow a Garden* (o maior jogo da história da Roblox em CCU) | O Gigante cresce FISICAMENTE. Um jogador novo vê um Gigante de 200m e pensa "quero isso". |
| **Loop de tycoon (gerar → gastar → gerar mais)** | Todos os tycoons de topo | Comida gera Moedas por segundo baseado em raridade e no Nível do Gigante. |
| **Eggs / Gacha com raridade** | *Pet Simulator 99*, *Adopt Me* | Comidas vêm de "Lunchboxes" (caixas) com raridades Common → Secret. |
| **Eventos globais de servidor** | *Blox Fruits*, *Grow a Garden* (weather events) | "Chuva de Meteoros de Comida", "Golden Hour", "Boss Gigante Faminto". |
| **Rebirth** | Quase todos os simuladores | Rebirth reseta o Gigante mas dá multiplicador permanente e cosmético. |
| **Thumbnail de "antes e depois"** | Padrão viral no YouTube/TikTok | Bebê minúsculo vs. Gigante maior que o mapa. Conteúdo pronto para criador. |

**Resumo em uma frase:** `Steal a Brainrot` + `Grow a Garden` + a dopamina de ver um número e um personagem ficando absurdamente grandes.

---

## 2. Core Loop (60 segundos de jogo)

1. **Ganhar Moedas** — a comida no Pátio da sua Base gera Moedas/seg.
2. **Comprar Lunchbox** — na Loja central (Common, Rare, Epic, Legendary, Mythic). Abertura com animação.
3. **Receber Comida** — item com raridade e valor de XP. Vai para o Inventário.
4. **Colocar no Pátio** — comida fica visível e começa a gerar Moedas.
5. **Alimentar o Gigante** — clicar "FEED" entrega o item ao Gigante → ganha XP → cresce em escala real.
6. **Defender/Roubar** — comida no Pátio pode ser roubada por quem invade. Base tem cooldown de escudo após spawn/compra.
7. **Rebirth** — Gigante Nível 50+ pode renascer: reseta nível, mantém cosméticos, +25% ganho permanente por rebirth.

---

## 3. Sistema do Gigante

- **Escala**: `scale = 1 + Level * 0.35` (nível 1 = 1.35x, nível 50 = 18.5x, nível 100 = 36x, nível 200 = 71x).
- **XP para subir**: `xpNeeded(level) = floor(50 * level^1.4)`.
- **Humor**: Faminto / Satisfeito / Feliz — afeta multiplicador de Moedas (0.8x / 1.0x / 1.25x). Fome cai com o tempo; alimentar sobe.
- **Visual**: Gigante é um modelo R6 em blocos (Part-based) com cor por nível (Branco → Verde → Azul → Roxo → Dourado → Arco-íris).
- **Reação**: Ao ser alimentado, salto + partículas + som. Ao subir de nível, pulso de escala.

## 4. Comidas (18 itens, 6 raridades)

| Raridade | Chance (Common Box) | XP | Moedas/seg | Exemplos |
|---|---|---|---|---|
| Common | 70% | 10 | 1 | Maçã, Pão, Banana |
| Uncommon | 20% | 30 | 3 | Pizza, Hambúrguer, Sushi |
| Rare | 7% | 100 | 10 | Bolo de Lava, Taco Dourado, Ramen Épico |
| Epic | 2.5% | 350 | 35 | Donut de Diamante, Sorvete Galáctico, Churrasco Infinito |
| Legendary | 0.45% | 1200 | 120 | Pizza Dourada, Hambúrguer Lendário |
| Mythic | 0.05% | 5000 | 500 | Lasanha do Universo, Coxinha Cósmica |
| Secret | evento | 20000 | 2000 | Brigadeiro Infinito (só em eventos) |

Lunchboxes de maior tier deslocam a tabela para cima (ver `Config.lua`).

## 5. Roubo (PvP leve)

- Entrar no Pátio de outro jogador e tocar em uma comida: inicia *canal de roubo* de **3 segundos** (dono recebe alerta e um raio vermelho aparece).
- Se o ladrão completar, a comida vai para sua mão (não pode comprar/colocar enquanto carrega). Precisa levar até a própria Base e tocar no Pátio para "depositar".
- Dono pode **bater** no ladrão (ferramenta Bat) → derruba o item.
- **Escudo**: 60s ao entrar no servidor, 20s após cada compra na Loja; compra de **Super Escudo** (Robux) dá 10 min.
- Comida sendo "alimentada" ao Gigante **não pode ser roubada** — incentivo a alimentar rápido (decisão: XP agora vs. Moedas passivas).

## 6. Eventos de servidor (a cada 6–9 min, aleatório)

| Evento | Duração | Efeito |
|---|---|---|
| Golden Hour | 90s | Moedas 2x para todos |
| Chuva de Comida | 60s | Comidas Common/Uncommon caem no mapa central, grátis para quem pegar |
| Boss Faminto | 120s | Um Gigante NPC aparece no centro; jogadores jogam comida nele; top 3 ganham Legendary garantida |
| Lucky Boxes | 60s | Chances de raridade +50% |

## 7. Monetização (configurada em `MonetizationService.lua`)

| Tipo | Item | Preço sugerido |
|---|---|---|
| Game Pass | 2x Moedas | 299 R$ |
| Game Pass | VIP (nametag, 1.5x XP, Pátio +4 slots) | 499 R$ |
| Game Pass | Auto-Feed (alimenta automaticamente) | 399 R$ |
| Dev Product | 10.000 Moedas | 99 R$ |
| Dev Product | 100.000 Moedas | 799 R$ |
| Dev Product | Super Escudo 10 min | 49 R$ |
| Dev Product | Lucky Lunchbox (Rare garantida) | 149 R$ |

> IDs são placeholders (`0`). Crie os passes no Creator Hub e cole os IDs em `ReplicatedStorage/Shared/Config.lua`.

## 8. Retenção

- **Daily Reward**: 7 dias crescentes (Moedas → Lunchbox Epic no dia 7).
- **Quests diárias**: "Alimente 20 vezes", "Roube 3 comidas", "Abra 10 Lunchboxes".
- **Leaderboard global**: Maior Gigante (nível) e Mais Rebirths — OrderedDataStore.
- **Grupo**: +10% Moedas para membros do grupo (preencha `GroupId`).

## 9. Mapa

- Ilha central circular (Loja, Portal de Eventos, Leaderboards).
- 8 Bases em círculo ao redor (até 8 jogadores por servidor — ideal para sensação de servidor "cheio").
- Cada Base: plataforma 60x60, Pátio com 12 slots (16 VIP), Pedestal do Gigante, Placa com nome.
- Gerado 100% por script (`MapService`) — nada de dependência de assets externos.

## 10. Fases de conteúdo pós-lançamento (roadmap de 4 semanas)

1. **Semana 1**: Launch + Código promocional `GIGANTE` (1.000 moedas) + evento Secret.
2. **Semana 2**: Trading entre jogadores; novas 6 comidas.
3. **Semana 3**: Skins de Gigante (Robux) e Pets que coletam comida.
4. **Semana 4**: Modo "Guerra de Gigantes" (servidor vs. servidor via leaderboard).
