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
| Fase 0 — Fundação segura | ⏳ **Em andamento.** Só o item 0.1 (Git) está feito |
| Fase 1 — Mundo bonito | ⬜ Pendente (depende da decisão de estilo de arte, ver §6) |
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

## 4. Próxima tarefa exata

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
