# Fase 1 — mundo novo: evidências (07/11/2026)

Estilo: cartoon pintado (GAME_BRIEF §5). Guia: `make-map/styles/simulator.md`. Luz: receita "Bright cartoon" ajustada
(`src/shared/LightingRecipes.lua`). Mundo gerado por código a cada início de servidor (`src/server/World.lua`, semente fixa)
com o MapKit do fwjelaa vendorizado (`src/vendor/server/MapKit`).

## O que existe agora (depois da rodada 4: clima de fim de tarde, escolhido pelo usuário)
- **Ilha** de grama (raio 470) com manchas de grama em dois tons, praia, faixa de água rasa e mar até o horizonte,
  tudo de peça (sem água de terreno).
- **Praça** em dois degraus (r 138 / r 120), anel e 8 faixas-guia no piso apontando para o centro.
- **Marco:** Caldeirão do Banquete sobre pedestal de pedra de 3 degraus; **fogo Neon com luz quente** (PointLight sem
  sombra); cobre, sopa, coxa, cenoura e concha gigantes; vapor; 4 bandeiras de 64 studs nas cores das bases (r 34).
- **4 mesas de banquete**, 5 canteiros, loja (barraca, norte), **evento dourado** (sul), **3 placares de madeira**.
- **Postes de luz** nas entradas e ao longo de todos os caminhos, com **arbustos** do lado oposto.
- **8 bases** com cor-tema, cerca branca; **placa nos fundos** com **contorno escuro no texto**.
- **3 lagos** com vitórias-régias e pedras; árvores em grupos, arbustos, flores, pedras e colinas baixas.
- **Luz (rodada 4):** fim de tarde. Sol baixo (ClockTime 16,8, latitude 30), luz alaranjada em cima e roxa embaixo, névoa
  alaranjada (Haze 1,5, Glare 0,4), Bloom 0,7 e raios de sol. Grama #7FA34E. Lâmpadas dos postes acesas (Neon).

## Verificação (place de teste, Play; rodada 4: rotas 24/24, 0/285 flutuando, 0 soltas, 4.859 peças, 48 Neon)
| Gate | Resultado |
|---|---|
| Verificador Luau | overall PASS (45 arquivos) |
| Caminhada (PathfindingService, agente raio 2 / altura 5) | **24/24 rotas** (8 bases → loja, faixa de drops, evento) |
| Props flutuando/enterrados (raycast do pivô) | **0 de 285** modelos de natureza; **0 de 40** arbustos dos caminhos |
| Peças não ancoradas no mapa | **0** |
| Decoração com colisão (flores, arbustos, nuvens) | **0** |
| Obstáculos sólidos na faixa de drops (r 36–96) | **0** |
| Bandeiras fora do caldeirão | mastro r 34 > raio do caldeirão 32,3 |
| Peças no mapa | 4.860 (alvo < 10.000) |

**Orçamento por vista (rodada 4, Q5/Q10):** base 304k/35 e 316k/38 · aérea 429k/35 e 466k/33 · praça 176k/23 e 189k/25 · natureza NO 379k/28 e 411k/34.

**Orçamento por vista (rodada 3)** (SceneAnalysisService, sem sombras, qualidade fixada; alvo celular 500k triângulos / 500 draw calls):

| Vista | Qualidade 5 | Qualidade 10 |
|---|---|---|
| Saindo da base, olhando o centro | 306k / 38 draws | 318k / 43 |
| Aérea | 431k / 39 | 467k / 40 |
| Praça | 189k / 32 | 202k / 37 |
| Natureza (nordeste) | 352k / 29 | 383k / 33 |
| Natureza (noroeste) | 380k / 33 | 412k / 38 |

Antes da troca da água: a água de terreno custava ~290k triângulos e ~300 draw calls por vista. Foi removida.

## Fotos (`docs/qa/shots/fase1/`)
- `00_antes.jpg`: estado antes da Fase 1, com o campo plano.
- `01_caminho_com_avatar.jpg`
- `02_aerea.jpg`
- `03_praca_banquete.jpg`
- `04_dentro_da_base.jpg`
- `05_chegando_na_base.jpg`

Capturas com o avatar R15 no quadro. A UI de tela e os letreiros flutuantes (nomes, drops, chuva de comida do evento)
foram desligados **só no cliente da foto**. As versões anteriores estão em `rodada1/`, `rodada2/` e `rodada3/`.

## Histórico das rodadas (rubrica `world`, 3 revisores cegos, mediana por critério, soma refeita)
| Rodada | O que mudou | Mediana W1..W6 | Nota |
|---|---|---|---|
| 1 | primeira versão + ajustes (borda, pedras, cores, caldeirão 1,7×, placares, faixas, slots, placa nos 2 lados) | [1,1,1,1,1,1] | 5,0 |
| 2 | placa para os fundos; pedestal e bandeiras; banquete; postes; lagos; névoa; mar sem água de terreno; fotos com avatar | [2,2,1,1,1,2] | 7,9 |
| 3 | sol de tarde e mais quente, correção de cor quente, raios de sol, fogo Neon com luz; placares de madeira; evento dourado; contorno no texto das placas; manchas de grama; arbustos nos caminhos | [2,2,1,1,1,2] | 7,9 (máx. de rodadas atingido) |
| 4 (decisão do usuário) | **clima de fim de tarde** (receita GoldenAfternoon: vault §3.3 Golden hour com ClockTime 16,8 e ambiente mais alto), grama verde-amarelada menos saturada, postes de madeira com lâmpada Neon | (este painel) | |

## Não feito / limites
- O marco e os props são primitivas, sem textura pintada. A textura pintada entra com os modelos da Fase 2.
- Desempenho medido só no PC, com a qualidade fixada em 5 e 10. Falta o teste em celular de verdade.
- Com pouca memória no PC, a qualidade automática do Studio encurtou a distância de desenho e escondeu o marco na vista
  aérea (rodada 3, primeira captura). Com memória livre, tudo aparece. `StreamingEnabled` está desligado; o marco já
  está marcado como `Persistent` para quando for ligado.
- Ao dar Play, o Studio mostra o aviso "Tecnologia de migração de iluminação", porque o projeto deixou de usar `Technology`
  (obsoleta).
