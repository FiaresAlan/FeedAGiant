# Fase 7 — evidências da missão "evolução integrada" (08/11/2026, noite)

Testado na cópia `scratchpad/studio/FeedAGiant-s1.rbxl` (código sincronizado pelo `rojo serve`), 1 jogador no Studio.
Fotos em `docs/qa/shots/fase7/`. Verificador: `luau_check.py --project .` → **overall PASS (76 arquivos)**.
Testes automáticos existentes: **39 passaram, 0 falharam** (`[FwjelaaTests] 39 passed, 0 failed, 7 spec modules`).

## 1. Animações (GiantAnim v2) — medido no cliente
Modelos sem esqueleto no Roblox (medido: goblin, troll, dragão e hidra = 1 MeshPart, 0 Bones) → animação procedural.
Amostras da malha do humano (altura ~25 studs) durante 1 alimentação (t = segundos depois do GiantFed):

| t | inclinação (°) | altura da malha | fase |
|---|---|---|---|
| 0,03 → 0,57 | 0 → +10,2 (para trás) | 25,8 → 26,9 (estica) | antecipação enquanto a comida voa |
| 0,63 → 0,70 | +10 → −3,7 | 25,6 → 24,2 (achata 6%) | MORDIDA no instante em que a comida chega (voo = 0,6 s) |
| 0,77 → 1,30 | −7,4 / −10,5 / −1,5 | oscila ±4% | 2 mastigadas |
| 1,37 → 1,57 | 0 | volta ao repouso | assentar |

Estados ligados a eventos reais: `GiantFed` (normal / crítico / subir de nível → comemorar), `GiantEvolved` (evolução depois da mordida),
atributo `Mood` (birra de fome a cada 8-12 s), `GiantReact` (vitória na batalha, recorde, Dragão derrotado).
Personalidade por espécie em `src/shared/GiantPersonality.lua` (12 espécies).

## 2. Alimentação (servidor) — medido
- Maçã (Crescimento): 10 → **14 XP**; 2ª seguida com sequência ×1,1; Coxinha Cósmica subiu 10 níveis de uma vez.
- Escala do gigante: **1,35 constante** nas alimentações sem subir de nível (antes: voltava a 1 e crescia de novo a cada comida — bug corrigido).
- Crítica forçada (chance 100% só no teste): estrelas douradas + "subiu de nível" + recorde + tarefa (foto 05).

## 3. Coleção e exposição — medido
- Humano nível 11 (675 XP) → comprou Jacaré → **Jacaré nasceu no nível 7** (30% do XP total); Humano continuou 11/675.
- Comprar/equipar de novo **não transfere outra vez**.
- Exposição: taxa 1,55 moedas/s com o Jacaré nível 7 exposto.
- Offline 3 h: **+8.370** (esperado 8.370); offline 20 h: **+22.320 = teto de 8 h**; reentrada imediata: **+0**.

## 4. Batalha por turnos — medido (6 rodadas)
Humano (102 HP, força 10,3) × Goblin (97 HP, força 10,0). Golpes: Golpe Rápido (100%), Esquiva (95%, efeito), Rasante (70%).
Acertos, erros e esquiva sorteados no servidor; vitória paga **72 moedas + 46 XP** (fórmula antiga com o nível da espécie).
Fotos 03 (antes) e 04 (depois do ajuste de layout).

## 5. Carne Gigante — medido
6 porções com 1 jogador (4 + 2). 1º corte: porção na cabeça. Cortes 2 e 3 recusados enquanto carregava.
Entregou na base → cortou de novo (ok) → entregou → 3º corte **recusado (limite 2)**. 2 porções no pátio,
tarefa "Carne Gigante" 2/1, recorde `delivered` = 2. Selo na tela: "CARNE GIGANTE 4/6 porções · 0:39".

## 6. Ilha do Dragão — medido
Ilha construída (117 peças) com ponte e placa com cronômetro (foto 01). Luta simulada pelo mesmo caminho do soco (`CombatService.HitNpc`):
fase 2 ("Fúria") e fase 3 ("Chuva de fogo") anunciadas; vitória: **308 moedas de participação + 900 de bônus (100% do dano) + 123 XP + caixa épica**.
Recompensa pendente: 1ª entrada **+1.200**; 2ª entrada **+0**; mesmo id regravado **+0**.

## 7. Diário — visto
Foto 02: recompensa diária, 3 tarefas com barra e RESGATAR, bônus travado, recordes.

## NÃO testado (dito como não testado)
- 2 ou mais jogadores (disputa real da carne, socos derrubando porção, dragão com vários lutadores, divisão do bônus).
- Celular físico, emulador de celular e controle.
- Desempenho medido (triângulos/draw calls da ilha; estimativa: 117 peças simples + 8 Fire).
- DataStore real (o Studio usa a memória; a fila de pendentes usa o mesmo substituto).
- Espécies uma a uma em todos os estágios (a personalidade foi conferida no código; só humano e dragão vistos no jogo).

## 8. Rodada 1 de correções (depois de 3 revisores cegos do sistema + 1 de animação)
Notas da rodada 0: sistema 6,3 / 6,25 / 6,3 (mediana [1,1,1,2,2,1] = 15/24 = **6,3**); animação **5,6** (18/32).
Corrigido: comida devolvida se a alimentação der erro; Carne Gigante nunca fica "presa"; pendências esperam o perfil e só
saem da fila depois do save confirmado; campos novos saneados na carga; contribuição do Dragão por UserId (sair e voltar
não duplica) e nocauteado não causa dano; batalha: 1 escolha por turno, AFK não ganha prêmio (medido: `AFK END won=false
coins=0`), modelos limpos em erro, quem segura o coliseu com fila ganha +30 s de descanso; animação: mola de
follow-through (balanço atrasado depois da mordida/pouso), poeira na aterrissagem e no pisão da birra, fila de reações
preservada, cache dos gigantes (sem varrer o Workspace a 30 Hz).
Reteste: alimentação ok (inv 5→4, XP 0→14), console sem erro do jogo, verificador PASS.

## 9. Teste com 2 jogadores (08/11/2026, noite — "Servidor e clientes", 2 jogadores)
Cópia `FeedAGiant-s1.rbxl`, modo do Studio "Servidor e clientes" com Player1 (UserId -1) e Player2 (-2). Console do servidor sem erro do jogo.

**Carne Gigante (disputa real):**
- 8 porções com 2 jogadores (4 + 2×2), conferido na placa.
- Player1 cortou → Player2 ligou o modo de luta e **socou o Player1: o 2º soco derrubou a porção** → Player2 pegou a porção caída
  → levou até a **própria** base → servidor registrou `CORTOU Player1 | ENTREGUE Player2 giantmeat`.
- Os dois cortaram do MESMO pedaço (8 → 7 → 6): vários jogadores ganham, não só o primeiro.
- Achado e corrigido: quem tentava cortar já carregando algo era recusado **sem aviso**. Agora aparece "Você já está carregando uma
  porção!…" (`meat_carrying`, PT/EN/ES). Retestado com 1 jogador: aviso chegou.
- Observação de teste (não é bug): o botão de proximidade só aparece com a carne na tela; a câmera do jogador de teste estava de costas.

**Dragão com 2 jogadores e saída no meio:**
- Socos REAIS (modo de luta + `RequestPunch`) dos dois na ilha: 900/900 → 779 (Player1, 10 socos); ao chegar o 2º lutador a vida
  escalou para **1.500**; Player2 tirou 97 com 8 socos.
- Player2 **saiu (Kick) no meio da luta**; o Player1 terminou (golpes acelerados pelo servidor, mesmo caminho do soco).
- Fases 2 e 3 anunciadas. Player1: `share 0,936 → participação 308 + bônus 1.685 + 123 XP + caixa épica`.
- Player2 (fora do servidor): **pendência gravada `moedas 422 (308 + 114 = 6,4% do bônus) xp 123`**, paga na próxima entrada
  (resgate idempotente já medido na seção 6).

**Ainda não testado:** reentrada real do Player2 em outro servidor (o Studio não reconecta clientes de teste), celular e controle.

## 10. Testes automáticos dos sistemas novos
As regras puras saíram dos serviços para `src/server/GameLogic.lua` (sequência, XP da alimentação/crítica, transferência de 30%,
taxa e renda offline, sorteio dos golpes, resultado da batalha com regra anti-AFK, recompensas do Dragão por UserId, pendências
idempotentes, porções e recusas da carne). Os serviços chamam essas funções; `tests/GameLogic.spec.luau` testa o mesmo código.
33 testes novos, com os números medidos em jogo como valor esperado (14 XP da maçã, jacaré nível 7, 8.370 e 22.320 de renda
offline, 308/123/bônus do Dragão com 2 jogadores, pendência de 1.200 paga uma vez).
Resultado no Studio: **`[FwjelaaTests] 72 passed, 0 failed, 8 spec modules`** (39 antigos + 33 novos).
Depois da refatoração, reteste no jogo: alimentação (crítica de 35 XP), compra de espécie com herança e uma batalha inteira
(vitória, 84 moedas) sem erro no console. Verificador: PASS (77 arquivos).

## 11. Celular emulado (iPhone 17 Pro no emulador de dispositivo do Studio, paisagem, tela útil 750×323)
Medido com `Stats.SceneTriangleCount`, `SceneDrawcallCount`, `ShadowsTriangleCount` e `RenderCPUFrameTime` (média de 10 quadros),
interface escondida, qualidade fixada em 3, 5 e 10. Cenário de pior caso: 3 gigantes expostos na vitrine, Carne Gigante e Dragão ativos.
Alvo do projeto (celular): **500 mil triângulos / 500 draw calls por vista**.

| Vista | Q03 | Q05 | Q10 |
|---|---|---|---|
| Ilha (luta, perto do dragão) | 114k / 117 | 118k / 114 | 122k / 117 |
| Praça olhando a ponte e a ilha | 229k / 176 | 231k / 176 | 248k / 190 |
| Carne Gigante na praça | 268k / 180 | 271k / 180 | 281k / 186 |
| Base com gigante e vitrine (3 estátuas) | 195k / 129 | 197k / 131 | 201k / 133 |
| Aérea (260 studs de altura, não é câmera de jogo) | **649k** / 342 | **663k** / 339 | **690k** / 341 |

CPU de renderização: 3,2 a 4,6 ms por quadro em todas as vistas. Sombras: no máximo 12k triângulos / 6 draws.
**Todas as vistas de jogo dentro do orçamento.** A aérea passa de 500k; decomposição (Q05, escondendo só no cliente):
ilha + dragão = **8k / 5 draws** (praça olhando a ilha: 17k / 19); estátuas da praça ≈ 90k; natureza ≈ 230k; o resto
(≈ 317 draws de base) é terreno, montanhas e bases — tudo de antes desta missão.

**Custo da animação (GiantAnim, medidor só de Studio em `Workspace.GiantAnimMs`):** 1 gigante < 0,01 ms por passo;
**8 gigantes animando ao mesmo tempo (máximo do servidor) = 0,09 a 0,1 ms por passo**, a 30 passos por segundo.

**Interface no celular (fotos 06 a 08):** a HUD cabe. Achado e corrigido: na batalha por turnos o placar ficava em y = 200, em
cima dos golpes (y = 196) — sumia. Agora é posicionado pela altura da tela, logo acima dos golpes (medido: placar 107–188,
golpes 196–307) e fica por cima do botão LUTAR e do cartão de disputa durante a luta.
Ainda sobrepostos (de antes desta missão): faixas do tutorial sobre o selo de evento; joystick sobre o cartão META.
**Não é celular físico:** o emulador muda tela e toque, não o processador do aparelho.

## 12. HUD compacta para celular (pedido do usuário: "a HUD no celular tampa boa parte da experiência")
Base: vault "UI Scale HUD Hide and Compact Mode" §3 (modo compacto = variação de layout, não só menor; "Mais" em gaveta; ligar
sozinho com altura < 500 px lógicos) e "HUD Design" §1 (centro da tela livre; canto inferior direito reservado ao pulo).
Com a tela útil abaixo de 500 px de altura (`HUD.compact`):
- a grade de 8 botões vira **LOJA + MENU**; o MENU (ícone de 3 barras, vira X) abre a gaveta com os outros 7 botões AO LADO,
  no alto (longe do joystick e do cartão de disputa); tocar num botão da gaveta fecha a gaveta e abre a janela;
- o selo "!" do Diário/Coleção aparece no MENU quando a gaveta está fechada;
- cartão de nível recolhido (fica só "Nv." no cartão de moedas; ▼ expande);
- cartão de META sai do canto inferior esquerdo (joystick) e vai para o alto, ao lado do LOJA/MENU; some com a gaveta aberta;
- selo do escudo vai para baixo do LOJA/MENU (encostava no aviso de evento);
- a faixa própria do tutorial no topo fica sempre desligada (o módulo a religava e duplicava o texto do cartão de META);
- botão LUTAR em tela de toque sobe para cima do botão de pulo do Roblox.
Medido no iPhone 17 Pro emulado (tela útil 750×323): moedas 7–187 × 3–53; LOJA/MENU 7–137 × 58–120; META 144–342 × 58–148;
LUTAR 558–738 × 145–205 (acima do pulo); centro e base da tela livres. Telas altas (iPad 10ª geração, console 1080p) continuam com a
HUD completa (fotos 12 e a de console não guardada). Fotos 09 (fechada), 10 (gaveta aberta), 11 (Diário aberto pela gaveta).
Ainda não resolvido: textos dentro das janelas (ex.: Diário) ficam pequenos no celular, porque a janela encolhe para caber.
