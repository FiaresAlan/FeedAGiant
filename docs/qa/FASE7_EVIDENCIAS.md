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
