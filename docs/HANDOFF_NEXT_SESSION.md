# Handoff — Feed a Giant (para a próxima sessão / outra conta Claude)

**Data do handoff:** 07/11/2026 · **Repositório:** https://github.com/FiaresAlan/FeedAGiant (branch `main`)
**Pasta local do projeto:** `C:\Users\Administrador\Pictures\FeedAGiant PRINCIPAL`
**Idioma obrigatório:** comunicação, documentação e relatórios em **português brasileiro**.

> Leia este arquivo inteiro primeiro. Depois leia `docs/DIAGNOSTICO_E_PLANO.md`, que é o diagnóstico completo e o plano aprovado.

---

## 1. Papel e procedimento

- Você é o **diretor técnico** do projeto. Carregue a skill `roblox-director` antes de qualquer trabalho Roblox. Se ela não aparecer, leia `C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\skill\SKILL.md`.
- O procedimento é obrigatório: pesquisar no vault do Fwjelaa antes, nunca inventar APIs, IDs ou números, citar as notas, nota mínima 8,5/10 por revisão independente, registrar em `.fwjelaa/ledger.jsonl`.
- **Não use o scaffold de projetos novos** (`new_game.py`). O projeto já existe.

## 2. Condições do usuário (aprovadas em 07/11/2026, valem para toda a execução)

O usuário aprovou o plano e pediu para **manter as cinco fases como estão, sem reformular**, começando pela Fase 0.

1. Preservar sempre o projeto original, com backup e versionamento (commit) **antes** de alterações importantes.
2. Autonomia técnica total para pesquisar, programar, modelar e usar Blender, Roblox Studio, o assistente do Studio, MCPs, o Chrome e a internet.
3. **Não consultar o usuário para decisões técnicas rotineiras.** Decidir de forma profissional e documentar a escolha.
4. Para mudanças significativas de **economia, monetização, identidade visual ou experiência do jogador**: apresentar a justificativa **antes** de qualquer mudança irreversível.
5. Trabalhar por entregas verificáveis. Cada sistema só está concluído depois de testado.
6. Priorizar o desempenho em **celular**.
7. **Não publicar o jogo, não gastar Robux e não fazer uploads comerciais** sem autorização explícita.
8. Não sacrificar a qualidade por prazo. Usar as rubricas do Fwjelaa (`quality-score`) e o procedimento do `roblox-director`.

O usuário é **leigo** em programação: explicar resultados em linguagem simples.

## 3. Situação das fases

| Fase | Situação |
|---|---|
| Diagnóstico e plano | ✅ **Concluído** (`docs/DIAGNOSTICO_E_PLANO.md`) |
| Fase 0 — Fundação segura | ✅ **Concluída** (nota 8,75 por painel de 3 revisores cegos; §3a) |
| Fase 1 — Mundo bonito | 🟨 **Rascunho 7,9** (3 rodadas usadas; ver §2b). Estilo decidido: cartoon pintado |
| Fase 2 — Criaturas de verdade | ⬜ Pendente |
| Fase 3 — Efeitos e juice | ⬜ Pendente |
| Fase 4 — Primeiro minuto e retenção | ⬜ Pendente |
| Fase 5 — Pré-lançamento | ⬜ Pendente |

### Checklist da Fase 0

- [x] 0.1 `git init`, `.gitignore` e primeiro commit enviado ao GitHub
- [ ] 0.2 `docs/GAME_BRIEF.md` (preencher a partir de `GAME_DESIGN.md` e do diagnóstico) + `selene.toml` (std roblox) + `stylua.toml`, para o verificador Luau funcionar
- [ ] 0.3 Dados:
  - `UpdateAsync` com trava de sessão (lease e token);
  - carregamento que falha **nunca salva** (kick ou modo sem salvar);
  - `BindToClose` espera os saves de verdade;
  - `dirty` só é limpo quando o save deu certo;
  - inventário com limite.
- [ ] 0.4 Compras:
  - `ProcessReceipt` idempotente (`PurchaseId` guardado no perfil, lista limitada);
  - salvar antes de retornar `PurchaseGranted`;
  - corrigir o bug da Lucky Box (anti-spam de 0,4 s em `openBox`);
  - `RestoreLevels` não pode cobrar quando não há níveis perdidos.
- [ ] 0.5 Itens aleatórios pagos:
  - chance por comida, numa única tabela usada pelo sorteio e pela tela, incluindo o bônus de evento;
  - `PolicyService.ArePaidRandomItemsRestricted` checado por jogador, no servidor;
  - "Trocar Espécie" passa a deixar o jogador **escolher**.
- [ ] 0.6 Anti-exploit:
  - remover o bastão do v1 (`StealService.giveBat`);
  - checagem de distância no servidor para os ClickDetectors;
  - revalidar escudo e `uid` no fim do canal de roubo;
  - checar altura no drop;
  - `PromoCodes` para o servidor;
  - validar argumentos em `ArenaService:256` e `CombatService:341/344`.
- [ ] 0.7 Criar `leaderArena` (placar da Arena morto). Enviar ao cliente só o que mudou, em vez do estado inteiro a cada segundo. Guardar o resultado de `IsInGroup` em cache na entrada.
- [ ] 0.8 Verificador Luau com **overall PASS**, teste com 2 a 3 jogadores no Studio, revisão independente (anti-exploit e dados), nota ≥ 8,5 na rubrica `system`, registro no ledger

## 2a. Atualização de 07/11/2026 (madrugada): fim de tarde aplicado; Fase 2 iniciada

**O que o usuário decidiu:** clima de **fim de tarde** e, ao terminar, seguir **direto para a Fase 2**.

**O que foi feito:**
- Receita `GoldenAfternoon` em `src/shared/LightingRecipes.lua`. Base: vault §3.3 Golden hour, com ClockTime 16,8 e ambiente ~20% mais alto para não escurecer.
- O `Main.server.lua` aplica essa receita.
- Grama #7FA34E, menos saturada; postes de madeira com lâmpada Neon.
- Decisão registrada no GAME_BRIEF (§5 e tabela de decisões).

**Resultado medido:**
- Painel world: **7,9** de novo, mediana [2,2,1,1,1,2].
- Orçamento: 176k a 466k triângulos e 23 a 38 draw calls por vista.
- Gates OK: 24/24 rotas, 0/285 props flutuando.
- Fotos em `docs/qa/shots/fase1/`; as versões anteriores estão em `rodada1..3/`.

**Bloqueador consensual (W4):** o **céu de cima continua azul**, porque o céu padrão do Roblox não muda de cor. A solução é uma caixa de céu de entardecer (`make-map` `run.py sky` com HDRI CC0, 6 faces de 512²). Isso precisa de **upload de 6 imagens**, que depende de autorização do usuário. O W3 (sem texturas pintadas) se resolve com os assets da Fase 2.

**Fato novo:** existe um place publicado **"Alimente um Gigante" (placeId 115578986093768)**. Ele esteve aberto no Studio em 07/11/2026 (aberto pelo usuário) e fechou em seguida. Nenhuma ferramenta escreveu nele. Atualize "Fatos do projeto" no CLAUDE.md quando o usuário confirmar que é este jogo.

**Novos assets do usuário em `assets/` (fora do Git até decidir):**
- `Caldeirão FeedAGiant sem cor.glb`: 769 mil triângulos, versão-fonte sem material.
- `Caldeirão com textura basica + fogo.obj` + `.mtl` + `Geometry01_diff.png` (1024²): **20.000 triângulos exatos**, cerca de 21 × 19 × 13 de tamanho.
- `Caldeirão FeedAGiant referencia textura e cor.png`: cobre com rachaduras e alças de argola.
- Esses arquivos são o candidato para substituir o caldeirão de primitivas. Usá-los **exige upload do modelo**, que precisa de autorização.

**Fase 2 (em andamento):** veja §2-F2 logo abaixo.

### §2-F2. Fase 2 — criaturas (07/11/2026, madrugada)

**Aprovação do usuário:** "pode seguir, tem total aprovação". Vale para as espécies novas e os preços.

**Feito:**
- **Pipeline Blender sem interface:** `tools/blender/prep_creature.py`.
  - Junta as malhas e decima até o alvo (busca binária).
  - Deixa só a textura de cor, com 1024 px, rugosidade 1 e metal 0.
  - Ajusta a altura em studs, com os pés em Z = 0, e exporta GLB com prévia.
  - Com esqueleto: tira a armadura durante a decimação e recoloca depois; limita os pesos a 4 e normaliza.
  - `--merge 0` pula a solda. O troll é uma "sopa de triângulos" (15.831 pedaços) e só reduz sem solda.
  - `tools/blender/front_view.py` faz a vista de frente para conferir a orientação.
- **11 modelos em `assets/optimized/`** (prévias em `previews/`):

  | Modelo | Triângulos |
  |---|---|
  | dragon | 8.000 |
  | baby-dragon | 8.000 |
  | crystal-dragon | 14.060 |
  | hydra | 11.315 |
  | phoenix | 10.333 |
  | goblin | 7.999 (rig + andar/correr) |
  | troll | 8.000 (rig + andar/correr) |
  | stone-golem | 8.000 |
  | zombie | 7.999 |
  | wyvern | 8.000 |
  | cauldron (caldeirão do usuário) | 15.000; 64,7 × 57 × 38 studs, no lugar do marco de primitivas |

  Os que passam de 8 mil têm muitas penas ou escamas soltas; o mínimo possível é esse. Todos ficam abaixo de 20 mil.
  Golem, zumbi e wyvern são **CC0**, da Grab3D, feitos com ajuda de IA (a licença está no zip original).
- **Espécies novas em `Config.Species`:** goblin, zombie, troll, wyvern e hydra, com os preços e atributos do GAME_BRIEF. Testado: compra e equipa sem erro.
- **Código:**
  - `src/shared/CreatureModels.lua` liga cada espécie a um arquivo, com o bebê-dragão no estágio Bebê e um `yaw` por espécie.
  - `src/shared/CreatureAssets.lua` é **gerado** por `tools/gen_creature_assets.py` e hoje está vazio.
  - O `GiantService` carrega o Model com `InsertService:LoadAsset` (com cache em `ServerStorage.CreatureTemplates`), esconde o corpo de blocos e coloca a malha sobre o pedestal.
  - **Sem ID, nada muda** (testado).

**Bloqueado: upload.** `python -I tools/upload_models.py` foi **negado pelo classificador do modo automático** do Claude Code ("Public Data-Sharing Upload"). Para seguir, há dois caminhos:
- o usuário roda os dois comandos no terminal: `python -I tools/upload_models.py` e depois `python -I tools/gen_creature_assets.py`;
- ou o usuário adiciona uma regra de permissão para esse comando.

Depois disso: compilar o place de teste, conferir cada criatura no Studio (escala, frente, `yaw` dos dragões, que ficaram ~45° na vista de frente) e trocar o caldeirão de primitivas pelo modelo.

**Alerta de segurança:** a chave em `ROBLOX_API_KEY` tem escopos muito amplos: places, DataStores, Game Passes, `legacy-universe.badge manage-and-spend-robux`, `universe-places write`, entre outros. O ideal é criar uma chave só com `asset read/write` para uploads.

**Ainda falta na Fase 2:**
- testar no Studio, depois do upload;
- animações idle, comer, comemorar e bravo (skill `make-anim`; troll e goblin já têm andar e correr);
- comidas 3D;
- revisar o troll, que tem pequenas falhas na superfície por causa da redução forte; o vault recomenda retopologia para malhas que deformam;
- modelos para humano, jacaré, águia e slime, que hoje continuam de blocos.

## 2b. Atualização de 07/11/2026 (noite): FASE 1, MUNDO NOVO (7,9; abaixo de 8,5)

- **Estilo de arte decidido pelo usuário:** cartoon pintado (stylised PBR). Está registrado no GAME_BRIEF §5 e no CLAUDE.md.
- **Luz:** `src/shared/LightingRecipes.lua` (receita Bright cartoon do vault, ajustada para sol de tarde e tom quente).
- **Mundo novo gerado por código:** `src/server/World.lua`, com o MapKit do fwjelaa em `src/vendor/server/MapKit`.
  - Ilha com praia e mar só de peça (a água de terreno custava cerca de 300 draw calls por vista).
  - Praça com o Caldeirão do Banquete: pedestal, fogo brilhando e 4 bandeiras.
  - Mesas de banquete, postes de luz, 3 lagos e bases com cor-tema e placa nos fundos.
  - O Baseplate saiu dos project.json.
  - Os drops agora caem a partir de r 50, e a chuva de comida a partir de r 40.
- **Gates:** 24/24 rotas de caminhada, 0 props flutuando, faixa de drops livre, 4.860 peças, no máximo 467k triângulos e 43 draw calls por vista (alvo de celular: 500k e 500).
- **Painel world:** 5,0 → 7,9 → 7,9. As 3 rodadas de correção foram usadas. Ledger e fotos em `docs/qa/FASE1_MUNDO_EVIDENCIAS.md` e `docs/qa/shots/fase1/`.
- **Bloqueadores, com mediana W3 = 1 e W4 = 1:**
  - **W3:** tudo são primitivas sem textura pintada. Isso se resolve com os modelos e MaterialVariants pintados da Fase 2.
  - **W4:** os 3 revisores dizem que a luz ainda parece "dia padrão". Ajustes sutis não movem a nota. A sugestão deles é uma luz de fim de tarde mais forte (ClockTime 16,5 a 17, névoa e horizonte alaranjados, grama menos saturada). **Isso muda o clima e a identidade visual, então é decisão do usuário.**
- **Próxima tarefa:** perguntar ao usuário se quer (a) aceitar 7,9 por enquanto e seguir para a Fase 2, que deve subir o W3, ou (b) testar o clima de fim de tarde mais forte no mundo atual.
- **Ambiente:** o Studio tem limite de janelas abertas e fica sem memória com muitas cópias de teste. Feche cada cópia ao terminar: Arquivo → Fechar local → Não salvar.

## 3. Atualização final de 07/11/2026: FASE 0 CONCLUÍDA (8,75)

- Teste com 2 jogadores feito ao vivo (Studio → Servidor e clientes, com controle de tela autorizado pelo usuário). Roubo, soco no ladrão, depósito anti-teletransporte, duelo completo e saída no meio do duelo funcionam. Detalhes em `docs/qa/FASE0_EVIDENCIAS.md`.
- 2 bugs achados e corrigidos: o aviso "Ninguém no círculo" se acumulava no painel de disputa (vinha da v4); o duelo recusava os ids negativos dos jogadores de teste.
- Painel 3: [2,2,1,2,1,2] = **8,75**. Ledger atualizado.
- **Como testar 2 jogadores:** seletor do Studio → "Servidor e clientes", contador de jogadores → 2, Play. O MCP lista servidor e clientes como instâncias separadas; os `require` de um script injetado no servidor compartilham o estado do jogo.
- **Pendências:** (1) decisão do usuário sobre a LuckyBox comprada por conta restrita (abaixo); (2) medir o desempenho no celular ou no emulador; (3) checagem de velocidade no servidor (drop/soco), da auditoria.
- **Próxima tarefa:** Fase 1 (mundo bonito). Ela está bloqueada pela decisão de estilo de arte (§6, pendente 1): apresentar as opções ao usuário antes de construir.

## 3a. Atualização de 07/11/2026, 2ª sessão: Fase 0 testada, nota 7,5 (abaixo de 8,5)

**Estado:** itens 0.2 a 0.7 implementados **e testados** em play solo. Detalhes e números em `docs/qa/FASE0_EVIDENCIAS.md`.
- Verificador Luau **overall PASS** (39 arquivos); 39 specs passam; falhas de carga e de armazenamento simuladas se comportam certo; fuzz com 1.971 chamadas sem erro no servidor; 60 fps no PC.
- Rodada de correção 1 feita (limite de frequência em todos os remotes, índices inteiros, depósito do roubo conferido no servidor, mochila sem apagar itens, caixa paga sem bônus de evento, arena/combate/roubo mais robustos). 3 sons quebrados da caixa (IDs da v4) trocados por `Config.Sounds`.
- Painel de 3 revisores cegos: 6,25 → **7,5**. Ledger em `.fwjelaa/ledger.jsonl`.
- **Bloqueador (S1):** teste com 2 jogadores (roubo, depósito, soco no ladrão, duelo, sair no meio). O MCP só faz play solo e o controle de tela do Studio foi negado nesta sessão. Precisa do usuário rodar (Studio → Testar → Clientes e servidores, 2 jogadores) ou autorizar o controle de tela.
- Restam 2 rodadas de correção (máx. 3).

**Pendências que dependem do usuário (condição 4, economia/monetização):**
1. LuckyBox comprada direto pelo cliente (`PromptProductPurchase`) por conta com restrição de itens aleatórios pagos: o recibo não pode ser recusado. Proposta: entregar um item fixo equivalente (ex.: uma comida Rare escolhida) em vez do sorteio. Precisa de aprovação.
2. Itens do 0.8 ainda não tratados (médios da auditoria): checagem de velocidade/teleporte no servidor para quem disputa drop e no alcance do soco; roubo/duelo mexem em dois perfis sem transação (inerente, só registrado).

**Próxima tarefa exata:** com o teste de 2 jogadores feito (pelo usuário ou com acesso à tela), registrar o resultado em `FASE0_EVIDENCIAS.md`, corrigir o que falhar e chamar novo painel de 3 revisores. Com ≥ 8,5, marcar a Fase 0 como concluída.

## 3b. Atualização de 07/11/2026 (sessão interrompida por limite de uso)

**Itens 0.2 a 0.7 implementados no código, mas AINDA NÃO TESTADOS no Studio.** Último commit: "WIP Fase 0.3–0.7".

**O que foi feito:**
- **0.2:** concluído. Criados `GAME_BRIEF.md`, `CLAUDE.md`, `selene.toml` e `stylua.toml`, mais um commit separado só com a formatação.
- **Módulos do Fwjelaa vendorizados:**
  - `src/vendor/shared` (vira `ReplicatedStorage.fwjelaa`): Signal, Odds e RateLimit;
  - `src/vendor/server` (vira `ServerScriptService.fwjelaa`): PlayerData, Receipts, Policy e StudioMemoryStore;
  - ajustes locais documentados no cabeçalho de cada arquivo;
  - `test.project.json` mapeia `tests/` para `ServerScriptService.FwjelaaTests`.
- **0.3:** `DataService` virou uma fachada sobre o PlayerData, mantendo a mesma interface. Também:
  - `DataService.start()` é chamado no fim do `Main`;
  - `Config.MaxInventory = 300`;
  - `PlotService.giveFood(player, id, force)` retorna boolean.
- **0.4:** `MonetizationService` reescrita sobre Receipts e Policy. Os passes são reconferidos na entrada. "Trocar Espécie" virou **Ficha de Espécie** (`profile.speciesTokens`), em que o jogador escolhe a espécie.
- **0.5:** `src/shared/LunchboxOdds.lua` é a tabela única de chances, com a mesma distribuição da v4 (verificada no teste `tests/LunchboxOdds.spec.luau`). A loja ganhou o botão CHANCES. Os produtos `paidRandom`/`fundsRandom` ficam bloqueados para quem tem restrição.
- **0.6:**
  - bastão removido (agora ladrão socado derruba a comida);
  - `src/server/Guard.lua` confere distância nos cliques e toques;
  - o roubo reconfere escudo e uid no fim e bloqueia depósito por teleporte;
  - o drop confere a altura;
  - os códigos foram para `src/server/Secrets.lua`;
  - argumentos validados na Arena e no Combat.
- **0.7:** `leaderArena` criado. O tick manda só `{coins, cps, hunger}`, e o estado completo vai quando algo muda e a cada 15 s. `IsInGroup` é guardado em cache.

**Próxima tarefa exata:**
1. Rodar o verificador. Faltavam:
   - um `fwjelaa-ignore` justificado em `EventService.lua:68` (o Touched é ligado por peça, que é destruída depois);
   - os avisos `UDim2.fromScale`/`fromOffset` do selene;
   - as variáveis sem uso `stBg`, `hBg` e o `i` de `MapService`;
   - o `elseif` vazio em `Arena.lua:258`;
   - talvez `Remotes.GetFullState.OnServerInvoke` em `PlotService` precise de cast.
2. Montar o place de teste: `rojo build test.project.json -o <scratchpad>/x.rbxl`, abrir e rodar `require(game.ServerScriptService.FwjelaaTests.Runner)()`.
3. Play test: entrar, comprar caixa, alimentar, depois testar `MemoryStoreFailNext` e `SimulateLoadFailure`, e por fim 2 jogadores (roubo, soco no ladrão).
4. Revisão independente (rubrica `system`) e registro no ledger.

## 4. Próxima tarefa exata (original)

**Fase 0, item 0.2.** Criar `docs/GAME_BRIEF.md`, `selene.toml` e `stylua.toml`, rodar o verificador e confirmar que restam só erros reais de código, não de configuração. Comando:

```
python "C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\tools\luau_check.py" --project "C:\Users\Administrador\Pictures\FeedAGiant PRINCIPAL"
```

Depois, seguir para **0.3 (DataService)**, que é o problema mais grave do jogo. Antes de mexer em dados, rodar o loop de alto risco: ler `## Common mistakes` e `## Checklist` de *Session Locking and Profile Libraries* e *DataStore Fundamentals* no vault, e usar a skill `fwjelaa-datastore-safety`. Fazer um commit antes de cada item.

## 5. Arquivos modificados ou criados até agora

| Arquivo | O quê |
|---|---|
| `docs/DIAGNOSTICO_E_PLANO.md` | Novo. Diagnóstico completo e plano das 5 fases |
| `docs/HANDOFF_NEXT_SESSION.md` | Novo. Este arquivo |
| `.gitignore` | Novo. Ignora as travas do Studio e os modelos 3D brutos (§7) |

**Nenhum arquivo de código (`src/`), place (`.rbxl`/`.rbxlx`) ou asset foi alterado.** Todo o código está como foi recebido (Config v4.0.0).

## 6. Decisões

**Tomadas:**
- Ordem: Fase 0 primeiro (aprovado pelo usuário).
- Os modelos 3D brutos ficam fora do Git: são 550 MB e ninguém trabalha neles nesse formato. Na Fase 2, os modelos **otimizados** (≤ 20 mil triângulos) entram no repositório.
- Conflito de fontes: o revisor disse que `ClickDetector.MaxActivationDistance` é validado pelo servidor, mas o vault (*Clickable and Interactive Parts*, rótulo Roblox docs) diz que **não**. Vale o vault: fazer a checagem de distância no servidor, que é barata.

**Pendentes** (não bloqueiam a Fase 0):
1. **Estilo de arte** (bloqueia a Fase 1): (A) cartoon estilizado, que recomendei por ser legível no celular e próprio do público de simuladores, ou (B) semi-realista, como os modelos atuais. É mudança de identidade visual, então segue a condição 4: apresentar a justificativa e confirmar antes.
2. **Suavizar o encolhimento e o pay-to-win da arena** (Fase 4): é mudança de economia e experiência, então também segue a condição 4.
3. **Uploads** (sons, modelos, imagens): só com autorização explícita (condição 7).

## 7. Problemas encontrados

Detalhes completos com arquivo e linha estão em `docs/DIAGNOSTICO_E_PLANO.md` §3.

- **Críticos:**
  - C1: carregamento que falha salva o perfil padrão por cima do save real (`DataService.lua:125-151`).
  - C2: sem trava de sessão.
  - C3: `ProcessReceipt` não é idempotente nem durável.
- **Altos:**
  - Lucky Box paga pode não entregar nada.
  - Regras de itens aleatórios pagos de 2026 não são cumpridas.
  - `BindToClose` com espera fixa de 3 s.
  - O bastão do v1 pode ser explorado.
  - ClickDetector sem checagem de distância.
- **Modelos 3D** (`assets/Personagens (goblin, dragao)/`, **só na máquina local, fora do Git**):
  - têm de 185 mil a 800 mil triângulos, contra o limite do Roblox de 20 mil por peça;
  - só o troll e o goblin têm esqueleto (24 ossos, animações walk e run);
  - os de dragão, hidra, fênix e crystal-dragon não têm esqueleto;
  - stone-golem, stylized-zombie e wyvern existem só em `.obj` zipado.

  **Se a próxima sessão rodar em outra máquina, essa pasta precisa ser copiada manualmente.**
- **Visual:** mapa plano e vazio, sem Sky, Atmosphere ou pós-processamento, placa da base espelhada, ícones ITENS e CÓDIGOS vazios, botão de alimentar vazio.
- **Mensagens** `rbxassetid://203785492` e `81504106` com erro no console vêm de fora do `src/`, provavelmente do plugin "Ecos Tools" instalado no Studio. Fica para confirmar.

## 8. Testes realizados

| Teste | Como | Resultado |
|---|---|---|
| Verificador Luau | `luau_check.py --project ...` | **FAIL** nas 4 etapas. selene falha por configuração (falta `selene.toml`); StyLua só formatação; luau-lsp com cerca de 10 erros de tipo reais (`Remotes.lua:70`, `State.lua:80-81`, `UI.lua:439-440`, `Combat.lua:43-45`, `Drops.lua:24-27`); fwjelaa-check com remotes sem validação, `:Connect` dentro de loop em `EventService:61` e `FindFirstChild` encadeado |
| Teste de jogo no Studio | **Cópia** do place em pasta temporária, Play solo | Servidor e cliente sobem sem erro de script, 8 bases, cerca de 250 peças no mapa. DataStore em memória, porque o place não está publicado |
| Assets no Studio | `ContentProvider:PreloadAsync` | Logo, ícones, painel e os sons da biblioteca carregam (Success) |
| Modelos 3D | Blender 5.4 sem interface, script de medição | Contagem de triângulos, ossos e animações na tabela de §7 |
| Revisão de segurança | Revisor independente, somente leitura (skills anti-exploit, datastore-safety, monetization-compliance) | 3 críticos, 5 altos, 8 médios, 7 baixos |

Nenhuma nota de qualidade (0–10) foi dada ainda: as notas são por entrega, a partir da Fase 0.

## 9. Ambiente e ferramentas

Verificado em 07/11/2026 nesta máquina.

- **Kit:** `C:\Users\Administrador\Desktop\Roblox Claude Work\studio-kit\`
- **Vault Fwjelaa:** `C:\Users\Administrador\Desktop\Roblox Claude Work\fwjelaa-vault-0.1.0\fwjelaa\fwjelaa vault\` (`_tools\vault.py`)
- **Blender:** `C:\Users\Administrador\Desktop\blender-5.4.0-alpha+main.50d477803fa8-windows.amd64-release\blender.exe` (fora do PATH)
- **Studio MCP:** sempre rodar `list_roblox_studios` e conferir o place antes de escrever. **Testar sempre numa cópia do `.rbxl`, nunca no original.**
- **Rojo:** `default.project.json` mapeia `src/` para o DataModel. `FeedAGiant.rbxl` é o place compilado.
- **Git:** usuário `Alan Fiares`, remoto `origin` = `https://github.com/FiaresAlan/FeedAGiant.git`.

## 10. Estado do Git no momento do handoff

- O repositório foi iniciado neste handoff, com branch `main` e primeiro commit contendo o projeto como recebido mais os documentos.
- Enviado para `origin/main`.
- Árvore de trabalho limpa depois do commit, exceto os modelos 3D ignorados de propósito.
