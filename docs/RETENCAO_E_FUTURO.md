# Loop de diversão, retenção e ideias futuras (itens 17 e 18 do pedido de 08/11/2026)

Escrito depois de implementar os itens 1–16. Nada daqui foi implementado sem estar no pedido. As ideias marcadas como **sugestão** precisam da aprovação do dono, porque mexem na economia ou na monetização.

## 1. O loop pedido e como ele está hoje

> Explorar → encontrar comida/Lunchbox → disputar → transportar até a base → guardar ou alimentar → renda/progresso → desbloquear criaturas → competir na arena → novas recompensas.

| Etapa | Como funciona agora | Avaliação |
|---|---|---|
| Explorar | Mapa fechado por montanhas, grama de terreno, lagos, estátuas das 12 espécies na praça | Mundo legível; o limite é natural. |
| Encontrar | Drops a cada 45–80 s (15% são Lunchboxes), e a Chuva de Comida com 14 itens. Cronômetro em cima de cada item. O chip do próximo evento fica no topo da tela, e há cronômetros no caldeirão e na arena | O cronômetro cria expectativa; a seta e o cartão "DISPUTA" mostram onde está o item. |
| Disputar | O item só libera depois do tempo (comum na hora, mítico 40 s). A coleta é manual (E/X/toque) | Tira a coleta "de graça" que o usuário viu (20–50 comidas). |
| Transportar | Item na cabeça, mais lento quanto mais raro. Soco ou nocaute derrubam a carga | Cria perseguição. Perto da própria base (zona segura de 45 studs) ninguém soca: o portador chega protegido nos últimos metros. Isso é intencional, mas pode ser ajustado. |
| Guardar / alimentar | Comida entregue vai para o pátio (rende moedas) ou para a mochila. A Lunchbox fica guardada até o jogador abrir | A escolha "expor = renda" contra "comer = XP" está clara: cada comida mostra "+N/s". |
| Renda / progresso | A renda soma todas as comidas expostas × multiplicadores (aparece na HUD). A meta do próximo estágio fica no cartão de META | Progressão visível na tela inteira. |
| Desbloquear criaturas | Estátuas com "ENCONTRAR <espécie>" mostram o preço e os atributos e pedem confirmação. Há também a Loja de Gigantes | A vitrine física dá vontade de "ter aquela". |
| Competir | Boxe entre jogadores (luta justa); arena dos gigantes contra um selvagem; Dragão a cada 15 min | Três modos no mesmo coliseu, um de cada vez. |
| Recompensas | Moedas, XP, caixa épica do Dragão (2 por dia), fogos e fanfarras para Lendária e Mítica | Momentos de pico audiovisuais. |

## 2. Pontos a observar quando houver jogadores (analytics)

- **Tempo até a 1ª entrega na base.** Se for longo, reduza `UnlockByRarity.Uncommon` ou aumente `BoxChance`.
- **Taxa de interceptação.** Se quase ninguém derrubar cargas, a zona segura de 45 studs pode estar grande demais para o novo sistema.
- **Uso da arena dos gigantes.** Se for baixo, o teto de 15 vitórias premiadas por dia e o descanso de 25 s podem ser afrouxados.
- **Caixas guardadas.** Se os jogadores acumularem 6 caixas sem abrir, o aviso "ABRIR" não está chamando atenção.

## 3. Oportunidades de retenção (melhorar o que existe; nada foi implementado)

1. **Diário com tarefas**. Hoje o Diário só dá o prêmio por sequência de dias. Proposta: 3 tarefas por dia, como "entregue 3 comidas", "vença 1 batalha de gigantes" e "abra 1 caixa guardada", usando eventos que já existem no código.
2. **Recompensa por coleção** (já sugerida em `PRE_LANCAMENTO.md`): completar uma raridade da Coleção dá 1 caixa.
3. **Ranking de batalhas de gigantes**: `profile.giantWins` já é salvo, então dá para mostrar um placar na praça.
4. **Evento "Dragão Dourado"** (raro): mesma luta com recompensa maior. Usa o BossService.
5. **Batalha de gigantes entre dois jogadores**: hoje é contra um gigante selvagem. O próximo passo é o desafio JxJ usando o mesmo convite do boxe.

## 4. Auras e cosméticos (item 17) — avaliação, NÃO implementado

| Pergunta | Avaliação |
|---|---|
| Combina com o jogo? | Sim: brilhos e partículas em volta do avatar combinam com o estilo cartoon e com os fogos e brilhos de raridade que já existem. |
| Retenção | Média: cosmético dá status social (outros veem), e o efeito aumenta se a aura for ganha por conquistas (ex.: 100 vitórias). |
| Monetização | Possível como Game Pass ou produto só cosmético. **Nunca** como item aleatório pago, para não cair nas regras de caixas pagas. |
| Desempenho | Limitar a 1 emissor por jogador e a ~10 partículas/s; desligar para jogadores a mais de 80 studs (vault: orçamento de partículas no celular). |
| Vantagem competitiva | Nenhuma: sem bônus de força, vida ou velocidade. Também não deve atrapalhar a leitura das lutas (transparência alta perto de outros jogadores). |
| Público 16+ → todas as idades | Sem problema de conteúdo. A venda segue as regras de compra para menores (preço claro, sem pressão). |

**Recomendação:** fazer depois do lançamento, começando com 3 auras ganhas por conquista e 2 pagas (só cosméticas). Preços e IDs são decisão do dono.
