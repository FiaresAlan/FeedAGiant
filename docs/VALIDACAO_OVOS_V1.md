# Validação — Sistema de Ovos (Ninho na Praça) + espécies iniciais (08/11/2026)

**Situação:** validado; **nada implementado**. A seção 14 do próprio pedido manda não codar antes das respostas. Cada item
foi conferido contra `docs/GAME_BRIEF.md`, o código atual e o vault do Fwjelaa. Seguem as respostas que faltam, já com a
minha recomendação em cada uma, para você só confirmar ou trocar.

---

## 1. Pacote "50 Stylized Eggs": análise (feita)

| Ponto | Resultado |
|---|---|
| Licença (`LICENSE.txt`) | ✅ Uso comercial e modificação permitidos. ⚠️ **Proibido redistribuir os arquivos**: no Roblox os modelos sobem como assets **privados**, nunca publicados no Creator Store. |
| Aviso de IA (`AI_NOTICE.txt`) | Feito com ajuda de IA generativa; os direitos de uso não mudam. Fica registrado (vault: *Roblox Policies on AI-Generated Content*). |
| Peso dos ovos (medido no Blender) | 3.168 a 8.748 triângulos cada (o Gelo é o mais pesado). Bem abaixo do teto de 20 mil. |
| Materiais | 3 a 24 materiais de cor por ovo. No Roblox, cada malha tem uma cor só: preciso **assar as cores numa textura pequena** (1 malha + 1 textura por ovo). É trabalho local, sem custo. |
| Estilo | **Voxel (bloquinhos)**. O briefing escolheu **cartoon pintado**. Funciona como "brinquedo colecionável", mas destoa um pouco dos gigantes. Ver a pergunta P7. |
| Ninho "de 1 lugar" | Plataforma de runas laranja com 4 garras (foto em `docs/qa/shots/ovos/ninho_render.png`). **Combina** com o estilo pintado. Porém tem **468.562 triângulos e 2 texturas 4K**: precisa ser re-assado para ~15 mil triângulos e 1K com o `tools/blender/rebake_creature.py` (o mesmo dos gigantes). **Serve.** |
| Temas que combinam com tamanhos (sugestão) | Pequeno = 06 Spotted · Médio = 47 Ice · Grande = 48 Lava · Enorme = 04 Golden · Colossal = 50 Rainbow. O tamanho do modelo é escalado no jogo (o mesmo modelo serve em vários tamanhos). |

## 2. Aderência ao jogo, item por item

| Item do pedido | Veredito | Observação |
|---|---|---|
| §0 "servidor sorteia e salva ANTES; cliente anima DEPOIS" | ✅ Concordo com a ordem | Sorteio e entrega no perfil sem nenhuma pausa no meio, depois um save imediato, e só então a animação. Ver a ressalva técnica R1. |
| §0.5 3 espécies iniciais fora da loja | ✅ Concordo com a ideia | Resolve o problema que apontei antes (a loja não perde venda). **Custo real: 3 modelos novos de gigante** (ver P1). Precisam de força e bônus parecidos com o Humano (grátis) para não ficarem melhores que as pagas. |
| §1 "Lunchbox = Comum/Rara" | ⚠️ Correção | A Lunchbox dá comida de 6 raridades em 5 caixas. Ela não muda; só o texto do pedido estava impreciso. |
| §2/§3 ovo dá **gigante** em nível 1-30 | ⚠️ **Decisão de economia** | Hoje os gigantes são vendidos (Goblin 8 mil … Hidra 600 mil moedas; Dragão e Fênix por Robux). Ovo de moedas com gigante aleatório compete com a loja de gigantes **e** vira item aleatório comprado com algo que se compra com Robux (moedas), o que exige chances por item e o bloqueio do PolicyService (o jogo já faz isso nas Lunchboxes). Ver P2. |
| Repetidos (já tem a espécie) | ❓ Falta regra | A posse de espécie é sim/não. Proposta em P3. |
| §3 nível inicial 1/5/10/20/30 | ✅ Encaixa | Nível 30 = estágio Adolescente (25+), ainda longe de DEUS (200). Entra no progresso por espécie que já existe (`profile.giants`). Se o jogador já tem a espécie num nível mais alto, nada é perdido. |
| §4 "se o save falhar, NADA é entregue" | ⚠️ **Discordo, com motivo técnico (R1)** | Explicação abaixo. |
| §5 Ninho na praça, 1 lugar, até 3 depois | ✅ | Precisa de um ponto exato (P4). 2º e 3º lugares: P5. |
| §6 VFX por raridade, ≤ 30 partículas | ✅ | Encaixa no orçamento do celular (vault: *ParticleEmitter - Engine Reference Card*, *Juice on a Budget*). Sem Bloom extra. `PreloadAsync` só para texturas próprias. |
| §7 fome (−20%) e calor (−10%), 1 vez por ovo | ✅ | Calor validado no servidor (distância medida a cada segundo, não confiar no cliente). |
| §8 `hatchAt` absoluto, choca offline | ✅ | Mesmo padrão da renda offline da exposição. |
| §9 notificação "ovo pronto" | ⏸️ **Bloqueada pelo ambiente** | Exige: jogo publicado com **≥ 100 visitas**, mensagem criada no Creator Dashboard, o pacote **Open Cloud** da Creator Store e uma **fila no MemoryStore** (quando o ovo choca de madrugada, nenhum servidor seu está rodando para aquele jogador). Vault: *Experience Notifications and Return Prompts* §2 e §5. Dá para deixar pronta e desligada; só funciona depois do lançamento. |
| §11 ovo de tutorial Médio (60-90 s) + chuva individual | ✅ com ajuste | Fica **depois** do passo "alimentar" do tutorial atual. A chuva individual é um modo novo do sistema de drops (só aquele jogador vê e pega). |
| §12 flags | ✅ | `EggSystem`, `EggNotifications`, `EggVFX`, `StarterSpecies`, todas desligadas. |
| §13 métricas | ✅ | `egg_notification_clicked` só funciona com o jogo publicado (dado de entrada pela notificação). |
| Bots | ✅ Intocados | Bots não chocam ovos nem ocupam o ninho. |

### R1 — Por que "se o save falhar, desfaz tudo" é pior aqui
O jogo usa **PlayerData com trava de sessão**: o perfil em memória é a verdade enquanto o jogador está no servidor, e é
salvo no autosave e na saída (também se o servidor fechar). Por isso:
- **cair no meio da animação não perde nada**: o gigante já está no perfil em memória e é salvo na saída;
- se um save **extra** falhar (DataStore lento), **desfazer** a entrega deixaria o jogador sem o gigante que ele viu, e o próximo save salvaria essa perda. Pior que não fazer nada.

**Proposta:** validar tudo → tirar o ovo e entregar o gigante **no mesmo instante (sem pausa)** → pedir um save imediato
(com limite de frequência) → só então mandar a animação. Se o save extra falhar, o autosave e o save de saída garantem.
É a regra do vault ("validar antes, depois mudar tudo de uma vez, sem pausa"; *fwjelaa Systems - Data and Purchase Guarantees*).

---

## 3. Perguntas (P1-P6 são as do pedido; P7-P9 são minhas)

| # | Pergunta | Minha recomendação |
|---|---|---|
| **P1** | Quais 3 espécies iniciais e como fazer os modelos? | Fogo, Gelo e Pedra, feitos com a IA do Studio (como os gigantes Humano, Jacaré, Águia e Slime), < 8 mil triângulos. **Exige subir 3 modelos (autorização)**. Atributos iguais aos do Humano, cada uma com 1 bônus pequeno de identidade. O Humano continua sendo o gigante de quem pular a escolha. |
| **P2** | Que gigantes cada tamanho de ovo pode dar? | **Pequeno e Médio** (loja de moedas): só gigantes **Comum a Raro** (Humano, Goblin, Jacaré, Zumbi), com chances por item na tela. **Grande, Enorme e Colossal** (eventos, Dragão, conquistas): Épico a Mítico. **Dragão e Fênix nunca** em ovo (são de Robux). |
| **P3** | E se sair um gigante que o jogador já tem? | Vira **XP daquela espécie** equivalente ao nível do ovo (ex.: Grande repetido = XP de 10 níveis). Nada de item "repetido" guardado. |
| **P4** | Onde fica o ninho na praça? | Ao lado da loja de Lunchboxes, no lado oposto ao caldeirão (eu marco o ponto e mostro a foto antes de fixar). |
| **P5** | Como abrem o 2º e o 3º lugar do ninho? | **Por nível do jogador**: 2º no nível 25 (Adolescente), 3º no nível 50 (Guerreiro). Sem moedas e sem Robux. |
| **P6** | Tabela de níveis 1/5/10/20/30? | Confirmo. |
| **P7** | Os ovos voxel servem, mesmo destoando do estilo pintado? | Usar os 5 do pacote (lista na seção 1) re-assados. Alternativa: eu modelo 5 ovos lisos pintados no Blender. |
| **P8** | Preço dos ovos de moedas (Pequeno e Médio)? | Pequeno 3.000 e Médio 12.000 (abaixo do Goblin/Jacaré da loja, mas aleatório e mais lento). Precisa do seu OK: é decisão de economia. |
| **P9** | Posso **subir ao Roblox** o ninho re-assado e os 5 ovos (privados) e, se aprovar P1, os 3 gigantes? | Você deu "permissão total para importar"; confirmo antes de enviar. |

**Sobre o place 115578986093768:** é o place em que o seu `rojo serve` sincroniza o código. Eu só testo no modo Play e
nunca salvo nele. Recomendo uma cópia separada para testes (eu crio com `rojo build` se você quiser).

---

## 4. Plano depois das respostas (fatias, cada uma com commit, teste no Play e revisão)
1. Assets: re-assar o ninho (468 mil → ~15 mil) e os 5 ovos (cores numa textura), fotos, upload privado (P9).
2. `EggService` (servidor): inventário de até 3 ovos, ninho com `hatchAt`, fome e calor, eclosão na ordem segura, chances por item, specs puras.
3. Ninho na praça + VFX por raridade + janela de eclosão (cliente).
4. Espécies iniciais + escolha no primeiro acesso (`StarterSpecies`).
5. Ovo de tutorial + chuva individual.
6. Notificação (desligada; só funciona depois de publicar com 100 visitas).

**O que NÃO foi feito agora:** nenhum código, nenhum upload, nenhuma mudança de economia. Só a análise do pacote (medição
e render do ninho) e este documento.

---

## 5. Implementação (08/11/2026, depois das respostas: "aceito todas, menos a 7")
P7 respondida: usar os ovos do pacote com as **texturas e cores originais**, escolhidos pelo nome, no melhor formato.

### Feito e testado no Studio (modo Play, nada salvo no place)
- **Assets:** escolhidos pelo nome e pela cor da raridade: Pequeno = `Egg_46_Moss` (verde), Médio = `Egg_47_Ice` (azul),
  Grande = `Egg_48_Lava`, Enorme = `Egg_04_Golden`, Colossal = `Egg_50_Rainbow`. Formato: **GLB** (o mesmo do projeto,
  mantém materiais). `tools/blender/prep_egg.py` junta as 3 a 21 cores de cada ovo numa paleta (1 malha, 1 textura,
  cores **exatas**). Ninho: 468.562 → 15.000 triângulos, textura 1K. Os 6 modelos subiram como assets **privados**;
  os arquivos ficam fora do Git (o repositório é público e a licença proíbe redistribuir).
- **Servidor** (`EggService`): loja de moedas (Pequeno 3.000, Médio 12.000), até 3 guardados, ninho com 1/2/3 lugares
  (níveis 1/25/50), `hatchAt` absoluto, fome −20% (gasta 1 comida Comum), calor −10% (30 s a ≤10 studs, medido no
  servidor), eclosão na ordem segura (entrega sem pausa → save → aviso), repetido vira XP, prêmios do Dragão (1 Ovo
  Grande por dia) e dos níveis 100 (Enorme) e 200 (Colossal), limite de pedidos (`Guard` "Egg"), métricas
  `egg_bought/placed/need_fed/need_warmed/hatched/received`.
- **Cliente** (`Eggs.lua`): janela NINHO DE OVOS com miniaturas 3D, CHANCES por espécie (mesma tabela do servidor),
  ovos do próprio jogador no ninho com cronômetro e efeito por raridade (verde → arco-íris; 0 a 3 feixes; ≤ 30
  partículas), animação de eclosão de 3 a 5 s e revelação. Dica de META "ovo pronto" / "choca em X min".
- **Testes:** `tests/Eggs.spec.luau` (18) → suíte no Play **108 passed, 0 failed**. Fluxo real: compra, colocar, recusas,
  eclosão com **save antes do aviso** (conferido), repetido → +XP, espécie nova no nível do ovo, 3 lugares, feixes 1/2/3.
  Fotos `docs/qa/shots/ovos/01-06`. Corrigido no teste: cor cinza padrão da malha apagava as cores (agora branco) e
  texto gigante nos lugares trancados.

### Não feito (e por quê)
| Item | Motivo | O que destrava |
|---|---|---|
| 3 espécies iniciais (Fogo, Gelo, Pedra) + escolha no 1º acesso | Os modelos pela IA do Studio são gerados **dentro do place aberto**, e o único Studio aberto é o seu place oficial (regra: nunca escrever nele). | Abrir uma cópia de teste (eu crio com `rojo build`) ou você gerar lá e me avisar. O código da escolha é pequeno depois disso |
| Ovo de tutorial (Médio, 75 s, chuva individual) | Choca a espécie inicial escolhida: depende do item acima | Idem |
| Notificação "ovo pronto" | Exige jogo publicado com ≥ 100 visitas, mensagem no Creator Dashboard, pacote Open Cloud e fila no MemoryStore | Lançamento |
| Teste com 2 jogadores e no celular | Não feito nesta sessão | Próxima rodada de testes |

### Revisão cega (1 revisor, rubrica system)
- Nota **7,5** (notas [1,2,1,2,2,1]; soma refeita pelo diretor: 18/24). Abaixo de 8,5 = **rascunho**.
- Corrigido depois: erro no save não trava mais o ninho (`pcall`); marcos e "subiu de nível" disparam depois da eclosão;
  animações em fila (uma por vez, testado com 2 eclosões seguidas); calor zera ao chocar/colocar.
  Suíte no Play de novo: **108 passed, 0 failed**.
- Para passar de 8,5: teste com 2 jogadores, medição no celular e teste automático do fluxo do EggService.
