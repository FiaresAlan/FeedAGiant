# Fase 1 — mundo novo: evidências (07/11/2026)

Estilo: cartoon pintado (GAME_BRIEF §5). Guia: `make-map/styles/simulator.md`. Luz: receita "Bright cartoon"
(`src/shared/LightingRecipes.lua`). Mundo gerado por código a cada início de servidor (`src/server/World.lua`, semente fixa)
com o MapKit do fwjelaa vendorizado (`src/vendor/server/MapKit`).

## O que foi construído
- **Ilha** de grama (raio 470) com praia e água de terreno só perto da ilha (1.400 studs) + peça plana até o horizonte.
- **Praça** em dois degraus (r 138 / r 120), com anel e 8 faixas-guia no piso apontando para o centro.
- **Marco:** Caldeirão do Banquete no centro (escala 1,7; ~120 studs com o vapor): fogueira de pedra, caldeirão de cobre,
  sopa, coxa, cenoura e concha gigantes, vapor de nuvens.
- **Loja** (norte, barraca + plataforma Neon), **evento** (sul, pedestal Neon), **3 placares** entre os caminhos,
  5 canteiros com flores.
- **8 caminhos** de 14 studs com bordas, da base até a praça.
- **8 bases** com cor-tema (piso claro com studs, borda, slots e placa na cor-tema, cerca branca, arbustos na entrada).
- **Natureza:** 133 árvores em grupos, 170 arbustos, 162 flores, pedras e 14 colinas baixas; nada a menos de 6 studs
  dos caminhos.

## Verificação (place de teste, Play)
| Gate | Resultado |
|---|---|
| Verificador Luau | overall PASS (45 arquivos) |
| Caminhada (PathfindingService, agente raio 2 / altura 5) | **24/24 rotas** (8 bases → loja, faixa de drops, evento) |
| Props flutuando/enterrados (raycast do pivô) | **0 de 495** |
| Peças não ancoradas no mapa | **0** |
| Peças no mapa | 5.183 (alvo < 10.000) |
| Contrato com o jogo | `ShopPad`, `EventPad`, `Leaderboard1..3` em `Workspace.Map`; drops em r 50–82 (+14), fora do caldeirão (r ≤ 29) e da loja/evento (r ≥ 98) |

**Orçamento por vista** (SceneAnalysisService, sem sombras; alvo celular 500k triângulos / 500 draw calls):

| Vista | Triângulos | Draw calls |
|---|---|---|
| Saindo da base, olhando o centro | 403.462 | 291 |
| Aérea | 394.682 | 295 |
| Praça | 375.282 | 267 |
| Natureza | 442.988 | 356 |

## Fotos (`docs/qa/shots/fase1/`)
`00_antes.jpg` (antes: campo plano) · `01_vista_da_base.jpg` · `02_aerea.jpg` · `03_praca.jpg` · `04_base_amarela.jpg` ·
`05_base_verde_corrigida.jpg`. Capturas com a UI escondida (câmera travada no cliente).

## Rodada de correção 1 (feita antes do painel)
Borda da ilha facetada (4 cópias giradas do disco); pedras demais e pequenas (espaçamento 80→140, escala maior);
caminho e praça brancos demais (tons de areia mais quentes); caldeirão pequeno e escuro (escala 1,7, cobre);
verso dos placares escuro (azul); piso da praça vazio (8 faixas-guia); slots sumindo na base verde (slots na cor-tema);
verso da placa da base vazio (texto nos dois lados).

## Não feito / limites
- Terreno com relevo e lago/rio, e props do Asset Pack: ficam para uma próxima rodada (as colinas são de peças).
- O marco é feito de primitivas (sem malha nem textura pintada). As texturas pintadas entram com os modelos na Fase 2.
- Desempenho medido só no PC.
- O aviso "Tecnologia de migração de iluminação" aparece no Studio ao dar Play: é do Studio, porque o projeto
  deixou de usar `Technology` (obsoleta).
