# FeedAGiant V2 — execução via GitHub / estado do trabalho
Data-base: 2026-11-11. Escopo de produto: GDD V3 de 11/11/2026.
Branch isolada: feat/feedagiant-v2-rebuild-2026-11-11. Main intocada.

## Contrato de segurança
- O código e o place originais continuam preservados. Nenhuma migração destrutiva, merge ou publicação automática.
- RebuildV2 fica atrás de feature flag, desligada por padrão até testes reais no Roblox Studio.
- Não assumir que a versão GitHub corresponde ao Studio local durante o trabalho simultâneo do DeepSeek.
- Servidor determina ingredientes, posse, cooldown, tempo de panela, recompensas e movimentação. Cliente apenas solicita ações.
- Modelos externos somente após origem e licença confirmadas.
- Deixar eventuais pendências para Claude apenas quando Studio, rig, importação, animação, testes visuais e publicação manual forem indispensáveis.

## Entregas em fases
A. Auditoria das interfaces reais e regras/economia — iniciada.
B. Sistema de cozinha, ingredientes e duas panelas persistentes — implementação.
C. Pista, cargas, entrega e segurança de transporte — implementação.
D. Montaria Golem, câmera, animação e forças elementais — código/protótipo + validação Studio pendente.
E. HUD e direção visual, ilha e duas panelas físicas — implementar sem destruir o mapa legado.
F. QA, telemetria, regressões, changelog e handoff mínimo.

## Critérios para release
Nenhum documento, merge ou status de compilação substitui teste no Studio em PC, mobile e dois clientes. Não publicar, monetizar ou anunciar antes de aprovar alimentação, persistência, câmera, movimentação e desempenho.
