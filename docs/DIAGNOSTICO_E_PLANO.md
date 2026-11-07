# Feed a Giant — Diagnóstico técnico e plano de desenvolvimento

**Data:** 07/11/2026 · **Responsável técnico:** Claude (diretor técnico) · **Base analisada:** `src/` (Config v4.0.0), `FeedAGiant.rbxl`, `assets/`

**Como foi feito**
- Leitura do código-fonte.
- Verificador Luau do kit (fwjelaa-check, selene, StyLua e luau-lsp).
- Teste de jogo no Roblox Studio, numa **cópia** do place.
- Medição dos modelos 3D no Blender.
- Pesquisa no vault do Fwjelaa.
- Revisão de segurança feita por um revisor independente, somente leitura.

Nada foi alterado no projeto. Este documento é o único arquivo novo.

---

## 1. Resumo para quem não é programador

O jogo **já tem muitos sistemas funcionando**: loja, gigante que cresce, roubo, combate de socos, arena, drops, eventos e espécies. Ele roda no Studio sem erros de script. O problema não é falta de conteúdo. São três coisas:

1. **Risco de perder o progresso e o dinheiro dos jogadores.** O salvamento e as compras com Robux têm falhas graves. Hoje, um jogador pode **perder todo o progresso** se o Roblox demorar a responder na entrada. Uma compra pode ser cobrada e não entregue. Isso precisa ser corrigido **antes** de publicar, porque gera avaliações negativas e reembolsos.
2. **O visual não vende o jogo.** O mapa é um chão verde plano com 8 retângulos cinza. O gigante é feito de blocos, as comidas são bolas e cubos, não há céu, iluminação nem cenário. No Roblox, o jogador decide em segundos se fica, e a thumbnail e os primeiros 60 segundos são o que mais pesa.
3. **Os modelos de criaturas que você tem (dragões, hidra, fênix, troll, goblin...) não entram no Roblox como estão.** Cada um tem de **185 mil a 800 mil triângulos**, e o limite do Roblox é **20 mil por peça**. Eles precisam ser otimizados no Blender, e os que não têm esqueleto precisam ser rigados. Dá para fazer, mas é trabalho de pipeline, não é só arrastar o arquivo.

**Minha recomendação:** primeiro deixar a base segura (Fase 0, curta). Depois fazer o salto visual (Fases 1 a 3), que é o que vai fazer o jogo parecer profissional. Por fim, o primeiro minuto do jogador e o lançamento.

---

## 2. Estado atual (o que existe)

| Área | O que tem | Avaliação |
|---|---|---|
| Código | 12 serviços de servidor, 9 controllers de cliente, Config central, localização PT/EN/ES parcial | Bem organizado e fácil de mexer. Bom ponto de partida |
| Loop | Lunchbox → comida → pátio (moedas) ou alimentar (XP) → gigante cresce → rebirth | Claro e testado em jogos de sucesso |
| Social | Roubo com canal de 3 s, socos, drops disputados, duelos e campeonato a cada 15 min | Rico, talvez até demais para o primeiro minuto |
| Espécies | 7 (Humano, Jacaré, Águia, Golem, Slime, Dragão, Fênix), todas feitas de blocos | A ideia é boa, mas o visual não diferencia as espécies |
| Mapa | Gerado por código: ilha de areia, 8 bases cinza, caminhos, 20 nuvens-bola | **Fraco.** Sem identidade nem marco visual |
| Iluminação | Só ClockTime e Brightness, sem Sky, Atmosphere, Bloom ou ColorCorrection | **Fraca** |
| Áudio | Os IDs de som carregam no Studio. Há 12 SFX e 15 narrações próprias em `assets/audio` que nunca foram enviados ao Roblox | Funciona com sons genéricos |
| UI | HUD completo, logo e ícones já enviados (carregam corretamente) | Funcional, com problemas de layout (seção 4) |
| Monetização | 8 Game Passes e 9 Dev Products **desenhados**, todos com ID 0 (nada à venda ainda) | Desenho OK, implementação insegura (seção 3) |
| Dados | DataStore com retry e autosave a cada 60 s | **Inseguro** (seção 3) |
| Ferramentas | Projeto Rojo, mas **sem git** e sem configuração de lint | Sem histórico. Uma mudança errada não tem volta |

---

## 3. Problemas encontrados, por gravidade

### Críticos (bloqueiam a publicação)

| # | Problema | Onde | O que acontece com o jogador |
|---|---|---|---|
| C1 | Carregamento que falha vira perfil novo **e salva por cima** | `DataService.lua:125-151` | O Roblox demora a responder → o jogador entra zerado → o autosave **apaga o save verdadeiro** |
| C2 | Sem trava de sessão: salva com `SetAsync` cego | `DataService.lua:165` | Ao trocar de servidor rápido, o progresso volta no tempo ou itens se duplicam |
| C3 | Compra com Robux não é registrada nem salva antes de confirmar | `MonetizationService.lua:95-102` | Pagou e, se o servidor cair, não recebe nada. Também não há proteção contra entrega dupla |

Fontes no vault: *Session Locking and Profile Libraries*, *DataStore Fundamentals*, *Developer Products and ProcessReceipt* (Roblox docs).

### Altos

| # | Problema | Onde |
|---|---|---|
| H1 | **Lucky Box paga pode não entregar nada.** O anti-spam de 0,4 s de `openBox` descarta a caixa em silêncio, mas a compra é confirmada. O mesmo vale para a caixa épica do diário e o prêmio do campeonato | `ShopService.lua:40-44`, `MonetizationService.lua:47` |
| H2 | **Regras de itens aleatórios pagos (2026).** Lunchboxes (as moedas são vendidas por Robux), Lucky Box e "Trocar Espécie" (que na verdade sorteia, apesar de a descrição dizer "qualquer espécie") precisam mostrar a chance de **cada resultado**, somando 100%, e consultar `PolicyService` (`ArePaidRandomItemsRestricted`) por jogador | `Shop.lua`, `MonetizationService.lua:63-79` |
| H3 | Ao desligar o servidor, o jogo espera só 3 s fixos para salvar, e saves que falham são marcados como feitos | `DataService.lua:221-230, 164-173` |
| H4 | **O bastão do v1 ainda existe.** Ele bate por `Touched` numa peça controlada pelo cliente, sem checar distância nem zona segura. Um exploiter derruba e arremessa qualquer jogador do mapa | `StealService.lua:212-258` |
| H5 | Clique em comida (ClickDetector) sem checagem de distância no servidor. Segundo o vault, `MaxActivationDistance` **não** é validado no servidor. A confirmar no Studio, mas a correção é barata | `StealService.lua:295-312` |

### Médios

- **Placar da Arena morto.** `leaderArena` nunca é criado, então o placar "Reis da Arena" fica sempre vazio (`DataService.lua:13`).
- **O estado inteiro é enviado a todos os jogadores a cada segundo:** inventário completo, pátio e espécies (`PlotService.lua:319`). Pesa na rede, principalmente no celular. O vault recomenda enviar só o que mudou.
- **Inventário sem limite.** Ele cresce para sempre, deixa o save e a rede mais pesados e pode chegar ao limite de 4 MB por chave.
- **Códigos promocionais visíveis para qualquer jogador.** Ficam em `ReplicatedStorage/Config` e deveriam estar no servidor.
- **Roubo:** o escudo do dono não é checado de novo no fim dos 3 s, o ladrão pode levar outro item se o dono trocar o slot, e o depósito não verifica se houve teletransporte.
- **Drop:** quem flutua acima do círculo conta como "dentro" (`DropService.lua:206`).
- **Arena:** o vencedor leva 5% das moedas e 2 comidas do perdedor. Isso permite passar riqueza de contas alternativas e somado ao passe Dragão ("domina a arena") vira **pay-to-win em PvP**. É risco de avaliações ruins.
- **Encolhimento por ausência + produtos pagos para "restaurar níveis":** punir quem volta e cobrar para desfazer tende a afastar jogadores. Recomendo suavizar (seção 5, Fase 4).

### Baixos

- `RestoreLevels` cobra mesmo com 0 níveis perdidos.
- IDs de comida podem colidir entre servidores; o certo é usar `GenerateGUID`.
- Pequenos vazamentos de memória por jogador.
- A descrição do Auto-Feed diz "a cada 30 s", mas o código usa 5 s.
- Os sons Coin = Evolve e Whoosh = Punch usam o mesmo ID.

### Qualidade de código (verificador Luau: **FAIL** nas 4 etapas)

- **selene:** falha de configuração, porque os arquivos `.lua` são lidos como Lua 5.1 e não como Luau. Falta `selene.toml` com o padrão Roblox.
- **StyLua:** só formatação.
- **luau-lsp:** cerca de 10 erros de tipo reais, por exemplo `Remotes.lua:70` tipa a RemoteFunction como RemoteEvent, além de `State.lua:80` e `UI.lua:439`.
- **fwjelaa-check:** remotes sem validação em `ArenaService:256` e `CombatService:341/344`, `:Connect` dentro de loop em `EventService:61` e vários `FindFirstChild` encadeados.

**Nada disso derruba o jogo hoje**, mas a meta é PASS.

---

## 4. O que vi no Studio (teste de jogo)

- O servidor e o cliente sobem sem erros de script. Duas mensagens `rbxassetid` com erro vêm de fora do `src/`, provavelmente de um plugin. Fica para checar.
- **Mapa:** campo verde de 1200×1200 vazio. As bases de 60×60 ficam pequenas e distantes (raio 320). Não há marco visual nem céu. As nuvens são bolas brancas.
- **Placa da base** aparece espelhada ou de costas, e o nome do gigante fica por cima dela.
- **HUD:** os botões ITENS e CÓDIGOS aparecem sem ícone, o botão grande de alimentar aparece vazio, o texto de ajuda fica cortado e o painel "Disputa de Comida" ocupa um canto grande com uma ilustração estranha.
- **Gigante:** começa minúsculo e escondido atrás da placa da base.
- Total no Workspace: cerca de 250 peças no mapa. O desempenho está folgado, então há espaço de sobra para arte.

---

## 5. Os modelos em `assets/Personagens`

Medidos no Blender:

| Modelo | Triângulos | Esqueleto | Animações | Situação |
|---|---|---|---|---|
| baby-dragon | 400.000 | não | — | Precisa reduzir **20×** e rigar |
| crystal-dragon | 400.000 | não | — | Reduzir 20× e rigar |
| hydra | 400.000 | não | — | Reduzir 20× e rigar |
| phoenix | 400.000 | não | — | Reduzir 20× e rigar |
| dragon | 800.000 | não | — | Reduzir 40× e rigar |
| troll | 185.000 | 24 ossos | walk, run | Reduzir cerca de 10×. **Esqueleto aproveitável** |
| goblin | 300.000 | 24 ossos | walk, run | Reduzir 15×. **Esqueleto aproveitável** |
| stone-golem, stylized-zombie, wyvern | (só .obj em zip) | — | — | Mesma situação |

Esses modelos parecem gerados por IA, com uma textura PBR única. Para entrar no Roblox:

- reduzir para 8 a 15 mil triângulos;
- reduzir as texturas para 1024 px;
- rigar os que não têm esqueleto, com o padrão de criatura do vault (quadrúpede ou voador);
- testar o crescimento até 70–90× com `Model:ScaleTo`. O vault não tem dados sobre ossos nessa escala, então isso exige teste próprio.

**Decisão de estilo necessária.** Esses modelos são semi-realistas. Comidas e mapa podem seguir dois caminhos: (A) **cartoon estilizado**, que lê bem no celular e combina com o público de simuladores, ou (B) **semi-realista**, que combina com esses modelos. Misturar os dois fica feio.

---

## 6. Plano de desenvolvimento priorizado

Cada fatia segue o mesmo ciclo: pesquisa no vault → construção → verificador → teste no Studio → revisão independente (nota ≥ 8,5) → registro no ledger.

### Fase 0 — Fundação segura (prioridade máxima, 1 a 2 sessões)

1. `git init` e primeiro commit, para ter histórico e poder desfazer.
2. Criar `docs/GAME_BRIEF.md` com as decisões atuais, mais `selene.toml` e `stylua.toml`, para o verificador funcionar.
3. **Dados:** carregar e salvar com `UpdateAsync` mais trava de sessão. Carregamento que falha **nunca** salva. `BindToClose` espera os saves de verdade. Inventário com limite.
4. **Compras:** `ProcessReceipt` idempotente (guarda o `PurchaseId`), salva antes de confirmar, corrige o bug da Lucky Box.
5. **Itens aleatórios pagos:** tabela de chances por comida, a mesma usada no sorteio, com `PolicyService`. "Trocar Espécie" passa a deixar o jogador **escolher**, e deixa de ser sorteio.
6. **Anti-exploit:** remover o bastão do v1, adicionar checagem de distância nos cliques, revalidar o roubo no fim do canal, verificar a altura no drop e mover os códigos promocionais para o servidor.
7. Arrumar o placar da Arena e enviar só o que mudou para o cliente.
8. Meta: verificador Luau PASS e teste com 2 a 3 jogadores no Studio.

### Fase 1 — Mundo bonito (o maior ganho de primeira impressão, 2 a 4 sessões)

1. **Iluminação:** Sky, Atmosphere, Bloom, ColorCorrection e `LightingStyle` Soft, com os valores do vault.
2. **Mapa novo:**
   - hub central com **um marco gigante**, por exemplo uma "mesa de banquete" ou uma panela colossal, pelo menos 1,5× mais alto que todo o resto;
   - praça radial com loja, arena, drops e placares, todos visíveis do spawn;
   - 8 bases maiores e temáticas (cerca, pátio decorado, pedestal do gigante, placa corrigida);
   - terreno com relevo, água e vegetação.
3. Props do Asset Pack do Fwjelaa ou da Creator Store, como árvores, pedras, barracas e cercas. Com sua permissão, também posso buscar modelos CC0 na internet (Poly Pizza, Poly Haven) e passar pelo pipeline de otimização.
4. `StreamingEnabled` e orçamento para celular (300–600 mil triângulos visíveis).
5. Ferramenta: skill `make-map` e `fwjelaa-worldbuilding`, com capturas e teste de caminhada.

### Fase 2 — Criaturas de verdade (2 a 4 sessões)

1. Pipeline no Blender (sem interface): reduzir, ajustar escala e pivô, exportar FBX e importar no Studio.
2. Relação modelo → espécie:
   - Dragão → dragon ou crystal-dragon;
   - Fênix → phoenix;
   - Golem → stone-golem;
   - novas espécies: Hidra, Wyvern, Troll, Goblin, Zumbi.
   - Bebê-dragão vira o estágio "Bebê" do dragão.
3. Animações: idle, comer, comemorar e "ficar bravo" por estágio, com a skill `make-anim`. Troll e goblin já trazem walk e run.
4. Crescimento real: o modelo escala de verdade com `ScaleTo`, e câmera e placa acompanham.
5. **Comidas 3D** (maçã, pizza, sushi...) em vez de bolas e cubos, num lote só de props.

### Fase 3 — Efeitos e "juice" (1 a 2 sessões)

- **Alimentar:** a comida voa até a boca, o gigante dá uma mordida com partículas, e há um número de XP flutuante e um som.
- **Subir de nível e evoluir:** pulso de escala, coluna de luz, tremor de câmera, banner e narração (os arquivos já existem).
- **Abrir lunchbox:** tremor, brilho pela raridade e banner global para Lendário ou acima, com limite para não virar spam.
- **Roubo:** feixe, alerta e trilha no ladrão. **Socos:** impacto e hit-stop. **Moedas:** partículas indo para o HUD.
- Música (5 faixas) e envio dos SFX e narrações próprios. **Upload só com sua autorização.**
- Orçamento de partículas para celular (máximo de 100/s por emissor no celular, segundo o vault).

### Fase 4 — Primeiro minuto e retenção (1 a 2 sessões)

- **FTUE:**
  - primeira ação em 10 a 20 s;
  - primeira recompensa em menos de 60 s;
  - objetivo com 8 palavras ou menos;
  - setas-guia;
  - nada de pop-ups no começo.

  O algoritmo de 2026 mede quem sai antes de 60 s e quem volta nos dias 1, 2 a 7 e 8 a 28.
- **Coleção:** índice de comidas e espécies com silhuetas.
- Suavizar o encolhimento (por exemplo, "o gigante fica com fome e triste", mas **não perde nível**) e limitar o pay-to-win da arena (pareamento por nível, sem tirar moedas do perdedor).
- Corrigir os problemas de layout do HUD e testar no celular.

### Fase 5 — Pré-lançamento

- Teste com vários jogadores e no celular.
- **Você** cria os passes e produtos no Creator Hub e eu coloco os IDs.
- Localização PT/EN/ES fechada, analytics de onboarding e economia, nova thumbnail com o mundo bonito.
- Publicação **somente quando você autorizar**.

---

## 7. Decisões que preciso de você

1. **Estilo de arte:** (A) cartoon estilizado (recomendo, por ser o que o público de simuladores e o celular leem melhor; nesse caso as criaturas recebem uma pintura mais "toon") ou (B) semi-realista, no estilo dos modelos atuais.
2. **Ordem:** começar pela Fase 0, que recomendo, ou pular direto para o visual.
3. **Uploads:** posso enviar modelos, sons e imagens para a sua conta Roblox quando chegar a hora? (Nunca publico o jogo nem gasto Robux sem você pedir.)
4. **Mudanças de design:** posso suavizar o encolhimento e o pay-to-win da arena?

---

*Skills e notas usadas:*
- *Skills: roblox-director, fwjelaa-anti-exploit-review, fwjelaa-datastore-safety, fwjelaa-monetization-compliance (pelo revisor) e fwjelaa-lookup.*
- *Notas do vault: Session Locking and Profile Libraries; DataStore Fundamentals; Developer Products and ProcessReceipt; Regional Compliance - Paid Random Items; Paid Random Items and Odds Disclosure in Practice; Clickable and Interactive Parts; Network Performance; Engine Limits Cheat Sheet; AI Pitfalls - Assets and Import; Creature Rig Conventions; Lighting Technologies and Settings; Atmosphere Sky Clouds and Post-Processing; Level Design for Roblox; Particle Emitters In Depth; Art Budgets - Triangles Draw Calls Memory; Discovery and the Algorithm; Onboarding and FTUE; Teardown - Steal An Egg.*
