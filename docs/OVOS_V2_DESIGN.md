# Ovos v2: o ninho divertido (09/11/2026)

Pedido do usuário (madrugada de 09/11): "desenvolva a lógica melhor referente ao uso dos ovos… como isso pode deixar a
gameplay divertida com tudo que você já conhece do projeto". Autonomia dada ("não peça autorização"). Tudo continua
atrás de `Features.EggSystem` (desligada). Nada pago, nenhuma moeda nova, nenhuma chance paga alterada.

## Diagnóstico do v1
1. **Cronômetro passivo:** coloca o ovo e espera. As duas ações (alimentar o ovo e aquecer) acontecem 1 vez e acabou.
2. **Desligado do coração do jogo:** alimentar o gigante, que é o verbo principal, não muda nada no ovo.
3. **O prêmio murcha:** quem já tem as espécies do ovo só ganha XP. O Pequeno, pelas faixas de 09/11, só dava o Humano,
   que todo mundo tem, e o Goblin ficou fora de todos os ovos.
4. **Poucas fontes:** loja, Dragão (1 por dia) e 2 marcos de nível. Nada no mapa, nada de disputa.
5. **Sem vitrine:** ninguém vê que o outro chocou algo raro.

## O que muda (e por quê)
### 1. Cuidado = estrelas (liga o ovo ao verbo principal)
Cada ovo no ninho junta até **3 estrelas de cuidado** enquanto choca:
- ⭐ **Alimentado:** dar 1 comida Comum ao ovo. É a ação que já existia: −20% do tempo que falta.
- ⭐ **Aquecido:** ficar 30 s perto do ninho. Já existia: −10%.
- ⭐ **Laço com o gigante:** **alimentar o SEU gigante** algumas vezes enquanto o ovo choca (Pequeno 3, Médio 5,
  Grande 8, Enorme 12, Colossal 20). O ovo sente o gigante comendo.

Na eclosão, cada estrela vale **+1 nível** na espécie nova ou **+25% de XP** no repetido. Exemplo: um Grande com 3
estrelas nasce no nível 13 em vez de 10.
**Por que:** quem só deixa o ovo no ninho continua ganhando o prêmio normal (sem castigo). Quem cuida ganha mais, e o
jeito de cuidar é jogar o loop principal. A aceleração máxima continua −28% (o pedido aprovado era até −30%).

### 2. Ovos no mapa (disputa)
**4% dos drops do mapa viram um Ovo Pequeno**, que se carrega como as caixas: na cabeça, 0,88 da velocidade, soco
derruba e outro jogador pode pegar. Entregue na própria base, ele vai para os ovos guardados.
**Por que:** usa o sistema de disputa que já existe e é o momento mais social do jogo. Ovo grátis jogando, sem custo.
Com os ovos guardados cheios (6), a entrega é recusada e o ovo volta ao chão: nunca some.

### 3. Faixas mais justas (revisão da decisão de 09/11, com a autonomia dada)
| Tamanho | Antes (09/11) | Agora |
|---|---|---|
| Pequeno | Comum (só o Humano) | **Comum + Incomum** (Humano 60%, Goblin 40%) |
| Médio | Comum + Raro | **Incomum + Raro** (Goblin 70%, Jacaré e Zumbi 30%) |
| Grande, Enorme, Colossal | Raro+Épico, Épico+Lendário, Lendário+Mítico | iguais |

**Por que:** o Pequeno deixa de ser "sempre repetido". O Goblin volta a existir em algum ovo, e o Médio passa a valer
mais que o Pequeno, como o preço (12 mil contra 3 mil) promete.

### 4. Vitrine: eclosão rara anunciada
Quando alguém choca uma espécie **Épica ou melhor** pela primeira vez, todos no servidor veem o aviso "Fulano chocou
um Gigante Hidra!". No máximo 1 aviso a cada 10 s.
**Por que:** é a aspiração do pedido original ("o jogador vê… e quer um"), sem custo de desempenho.

## Fora desta rodada (registrado)
- Ovos visíveis na base de cada jogador para os outros verem: custa partículas × 8 bases. Fica para depois da medição
  no celular.
- Ovo de tutorial: continua esperando a cópia de teste do place.
- Notificação: depois de publicar com 100 visitas.

## Métricas novas
`egg_care_star` (qual estrela), `egg_hatched` passa a levar o número de estrelas, `egg_drop_delivered`.

## Resultado (09/11/2026)
- **Testado no Play** (função ligada só na sessão):
  - 8 alimentações do gigante deram a estrela de laço (8/8), e o ovo ficou com 3 estrelas;
  - um Grande com 3 estrelas chocou um Águia novo no nível 18 (a herança de 30% era maior que 10+3; vale o maior);
  - o ovo do mapa caiu com o modelo 3D e a entrega levou de 0 para 1 ovo guardado;
  - suíte **134 passed, 0 failed**.
- **Revisão cega: 7,5** (rascunho). Já corrigido:
  - a entrega confere o espaço antes, sem dois avisos contraditórios;
  - as estrelas usam uma função só (`EggOdds.stars`), a mesma no servidor e na janela.
- **Mantido de propósito:** o anúncio raro tem limite de 1 a cada 10 s no servidor inteiro, para não virar spam.
- **Falta para 8,5:** teste automático da integração (alimentar o gigante → laço; entrega do mapa), e testes com 2
  jogadores e no celular.
