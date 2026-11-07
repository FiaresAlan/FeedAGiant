# Briefing do jogo — Feed a Giant

> Fonte da verdade do projeto. Preenchido em 07/11/2026 a partir de `GAME_DESIGN.md`, `README.md`, do código (Config v4.0.0) e das decisões aprovadas pelo usuário. Campo marcado **[PENDENTE]** = decisão do usuário ainda não tomada; não construir nada que dependa dele.

## 1. Identidade
- **Nome:** Feed a Giant (FEED A GIANT).
- **Pitch:** você adota um Gigante bebê que come tudo. Quanto mais ele come, mais cresce, até ficar maior que o mapa. Outros jogadores podem invadir sua base e roubar a comida do seu Gigante.
- **Gênero:** simulador / tycoon de coleção e crescimento, com PvP leve (roubo, socos, duelos).
- **Referências** (só a lógica, nunca nome, arte ou personagens):
  - jogos de "roubar da base" → roubo com contra-jogo;
  - jogos de "fazer crescer" → progresso visível no próprio objeto;
  - simuladores com ovos → caixas com raridades.

## 2. Público e plataforma
- **Faixa etária:** público geral de simuladores Roblox (crianças e adolescentes). Conteúdo sem violência gráfica: os socos derrubam ("tonto"), não matam.
- **Dispositivos:** **celular primeiro** (condição do usuário), depois PC. Console não é prioridade.
- **Sessão típica:** 10 a 30 min, com retorno diário.
- **Idiomas:** PT-BR (padrão), EN, ES.

## 3. Jogabilidade
- **Verbos:** comprar caixa, colocar comida no pátio, alimentar, roubar, defender (soco e bloqueio), disputar drop, duelar.
- **Loop de 30 s:** ganhar moedas → comprar lunchbox → comida → pátio (renda) ou alimentar (XP).
- **Loop de 5 min:** subir de nível, o gigante cresce e muda de estágio, eventos e drops.
- **Loop da sessão:** rebirth (nível 50+), espécies, campeonato a cada 15 min, placares.
- **Progressão:** nível até 250, 7 estágios (Bebê → DEUS), rebirths com multiplicador, 7 espécies.
- **Social:** até 8 jogadores por servidor, 1 base cada.

## 4. Escopo
- **Plano aprovado:** `docs/DIAGNOSTICO_E_PLANO.md`, com as fases 0 a 5 mantidas sem reformulação.
- **Escala:** hub central + 8 bases em anel (raio 320 studs). Vai ser redesenhado na Fase 1.
- **Fora do escopo até a Fase 5:** trocas entre jogadores, pets, guerra entre servidores.

## 5. Direção de arte
- **Estilo:** **[PENDENTE]**. Opção (A), cartoon estilizado (recomendada), ou (B) semi-realista. Bloqueia a Fase 1. Exige justificativa e confirmação do usuário (condição 4).
- **Paleta e clima:** [PENDENTE, junto com o estilo]. Hoje é diurno, saturado, com Neon nos destaques.
- **Assets existentes:**
  - `assets/ui` (logo, ícones, painel, já enviados ao Roblox);
  - `assets/Personagens (goblin, dragao)`, só local: 185k a 800k triângulos, precisam ser otimizados para no máximo 20 mil.
- **Fontes permitidas:** Blender (próprio), Asset Pack do Fwjelaa, Creator Store, modelos CC0 da internet (Poly Pizza, Poly Haven), IA do Studio.

## 6. UI, áudio e sensação
- **UI:** HUD existente (`src/client/UI.lua` e Controllers). Corrigir o layout no celular na Fase 4.
- **Áudio:** SFX e narrações próprios em `assets/audio` (pendente de upload autorizado). Hoje usa a biblioteca Roblox.
- **VFX importantes:** alimentar, subir de nível, evoluir, abrir caixa, roubo, socos (Fase 3).

## 7. Dados e economia
- **O que salva:** moedas, nível, XP, rebirths, inventário, pátio, espécies, passes, estatísticas, códigos, diário.
- **Moeda:** Moedas (soft). Sem troca entre jogadores.
- **Monetização:**
  - 8 Game Passes e 9 Dev Products desenhados em `Config.lua`, todos com ID 0;
  - preços sugeridos em `Config.GamePassInfo` e `Config.DevProductInfo`;
  - itens aleatórios pagos devem cumprir as regras de 2026: chances por item e `PolicyService`.
- **Limites éticos** (a revisar, Fase 4): reduzir o pay-to-win na arena e suavizar o encolhimento por ausência. Mudanças de economia exigem justificativa antes (condição 4).

## 8. Restrições
- **Técnicas:**
  - desempenho no celular primeiro;
  - StreamingEnabled ao redesenhar o mapa;
  - 20 mil triângulos por malha;
  - partículas no máximo a 100/s por emissor no celular.
- **Políticas:** regras de itens aleatórios pagos de 2026, nada de conteúdo impróprio.
- **Não fazer:**
  - publicar, gastar Robux ou fazer upload comercial sem autorização;
  - mexer no place original (testar em cópia);
  - reformular as fases.

## 9. Recursos disponíveis
- **Arquivos:** `FeedAGiant.rbxl`, `.rbxlx`, `src/` (Rojo), `assets/`, `tools/Rojo_plugin`.
- **Place ID / Universe ID:** ainda não publicado (PlaceId 0).
- **Dono dos assets:** conta do usuário (logo, ícones e painel já enviados).
- **Repositório:** https://github.com/FiaresAlan/FeedAGiant (`main`).

## 10. Autorizações
- **Upload de assets ao Roblox:** [ ] sim [ ] não [x] **perguntar a cada lote** (condição 7: nada comercial sem autorização).
- **Publicar no place (sem tornar público):** [ ] sim [x] **não**.
- **Tornar público / lançar:** sempre perguntar.
- **Gastar Robux:** nunca sem pedido explícito.

## 11. Critérios de sucesso
- **Fase 0:**
  - verificador Luau com overall PASS;
  - teste com vários jogadores no Studio sem perda nem duplicação;
  - revisão independente nota ≥ 8,5 (rubrica `system`).
- **Lançamento** (sinais do algoritmo de 2026): pouca saída antes de 60 s, retorno nos dias 1, 2 a 7 e 8 a 28. Ainda não há métricas reais.

---
## Decisões do diretor técnico

| Data | Decisão | Alternativas consideradas | Motivo | Notas do vault citadas |
|---|---|---|---|---|
| 07/11/2026 | Fase 0 (segurança) antes do visual | Começar pelo visual | Perda de save e cobrança sem entrega geram avaliações ruins e reembolsos; aprovado pelo usuário | Session Locking and Profile Libraries; Developer Products and ProcessReceipt |
| 07/11/2026 | Modelos 3D brutos fora do Git | Git LFS; versionar tudo | 550 MB em formatos duplicados, inutilizáveis sem otimização; os otimizados entram na Fase 2 | AI Pitfalls - Assets and Import |
| 07/11/2026 | Manter a extensão `.lua` (não renomear para `.luau`) | Renomear tudo | Rojo e luau-lsp tratam os dois iguais; renomear só gera ruído no histórico | — |
| 07/11/2026 | Formatação StyLua aplicada num commit separado, sem mudar lógica | Formatar junto com as correções | Deixa os diffs das correções legíveis | — |
| 07/11/2026 | Checagem de distância no servidor para ClickDetector | Confiar em MaxActivationDistance | O vault (Roblox docs) diz que não é validado no servidor; o revisor discordou; a checagem é barata | Clickable and Interactive Parts |
