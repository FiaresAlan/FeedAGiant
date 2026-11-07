# Fase 1 — mundo novo: evidências (07/11/2026)

Estilo: cartoon pintado (GAME_BRIEF §5). Guia: `make-map/styles/simulator.md`. Luz: receita "Bright cartoon"
(`src/shared/LightingRecipes.lua`). Mundo gerado por código a cada início de servidor (`src/server/World.lua`, semente fixa)
com o MapKit do fwjelaa vendorizado (`src/vendor/server/MapKit`).

## O que existe agora (depois da rodada de correção 2)
- **Ilha** de grama (raio 470) com praia, faixa de água rasa e mar até o horizonte, tudo de peça (sem água de terreno).
- **Praça** em dois degraus (r 138 / r 120), anel e 8 faixas-guia no piso apontando para o centro.
- **Marco:** Caldeirão do Banquete sobre **pedestal de pedra de 3 degraus**, cobre, sopa, coxa, cenoura e concha
  gigantes, vapor de nuvens; **4 bandeiras** de 64 studs nas cores das bases (r 34, fora do caldeirão e da faixa de drops).
- **4 mesas de banquete** com toalha, bancos e comida; 5 canteiros; loja (norte), evento (sul), 3 placares.
- **Postes de luz:** 2 em cada entrada de caminho na praça + ao longo de todos os caminhos (a cada ~45 studs, alternando).
- **8 caminhos** de 14 studs com bordas.
- **8 bases** com cor-tema (piso claro, borda, slots e pedestal na cor-tema, cerca branca). **Placa nos fundos**, alta e
  virada para o centro: não tapa mais a vista do caldeirão.
- **3 lagos** com vitórias-régias e pedras; árvores em grupos, arbustos, flores, pedras e colinas baixas.
- Névoa mais forte (Atmosphere Density 0,3 / Haze 1,2) para dar profundidade.

## Verificação (place de teste, Play)
| Gate | Resultado |
|---|---|
| Verificador Luau | overall PASS (45 arquivos) |
| Caminhada (PathfindingService, agente raio 2 / altura 5) | **24/24 rotas** (8 bases → loja, faixa de drops, evento) |
| Props flutuando/enterrados (raycast do pivô) | **0 de 285** |
| Peças não ancoradas no mapa | **0** |
| Decoração com colisão (flores, arbustos, nuvens) | **0** |
| Obstáculos sólidos na faixa de drops (r 36–96) | **0** |
| Bandeiras fora do caldeirão | mastro r 34 > raio do caldeirão 32,3 |
| Peças no mapa | 4.734 (alvo < 10.000) |

**Orçamento por vista** (SceneAnalysisService, sem sombras, qualidade fixada; alvo celular 500k triângulos / 500 draw calls):

| Vista | Qualidade 5 | Qualidade 10 |
|---|---|---|
| Saindo da base, olhando o centro | 272k / 31 draws | 287k / 41 draws |
| Aérea | 394k / 34 | 430k / 38 |
| Praça | 175k / 28 | 188k / 33 |
| Natureza (nordeste) | 314k / 28 | 345k / 32 |
| Natureza (noroeste) | 347k / 33 | 379k / 38 |

Medido antes da troca da água: a água de terreno custava ~290k triângulos e ~300 draw calls por vista. Foi removida.

## Fotos (`docs/qa/shots/fase1/`)
`00_antes.jpg` (antes: campo plano) · `01_caminho_com_avatar.jpg` · `02_aerea.jpg` · `03_praca_banquete.jpg` ·
`04_dentro_da_base.jpg` · `05_chegando_na_base.jpg`. Capturas com o avatar R15 no quadro e com a UI de tela e os letreiros
flutuantes (nomes, drops, chuva de comida do evento) desligados **só no cliente da foto**. As fotos da primeira versão
estão em `rodada1/`.

## Histórico das rodadas
| Rodada | O que mudou | Nota do painel |
|---|---|---|
| 1 (antes do painel) | borda da ilha arredondada, menos pedras, caminho/praça mais quentes, caldeirão 1,7× e de cobre, placares azuis, faixas no piso, slots na cor-tema, placa nos dois lados | 5,0 (mediana [1,1,1,1,1,1]) |
| 2 | placa para os fundos; pedestal e bandeiras no marco; mesas de banquete; postes nas entradas e nos caminhos; 3 lagos; névoa; mar sem água de terreno; fotos com avatar e sem letreiros | (este painel) |

## Não feito / limites
- O marco e os props são primitivas sem textura pintada; a textura pintada entra com os modelos na Fase 2.
- O texto branco da placa da base amarela tem pouco contraste (`05_chegando_na_base.jpg`). Próximo ajuste: contorno escuro no texto.
- Desempenho medido só no PC (qualidade fixada em 5 e 10). Falta o teste em celular de verdade.
- Ao dar Play, o Studio mostra o aviso "Tecnologia de migração de iluminação", porque o projeto deixou de usar `Technology` (obsoleta).
