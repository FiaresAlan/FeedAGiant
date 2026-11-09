# Pedido do usuário (09/11/2026): 17 pontos ("tudo aprovado" + lista nova)

Backup antes: tag `backup-2026-11-09-antes-dos-17-pontos`. Para voltar a tudo: `git checkout backup-2026-11-09-antes-dos-17-pontos`.

Legenda: ✅ feito e testado no Play (cópia de teste, nunca o place oficial) · ☑️ feito, verificado por código/teste automático, sem teste visual completo.

| # | Pedido (resumo) | O que foi feito | Situação |
|---|---|---|---|
| 1 | O jogador anda demais | **Viagem rápida**: blips brilhantes levam a praça, base, arena, ninho, Ilha do Dragão e Gigante Ancestral (`TravelService`) | ✅ praça → ninho |
| 2 | Ninho maior, no centro da praça | Ninho de 26 studs no vão da praça (φ 270°, r 64), ovos 1,6x maiores, alcance 32 | ✅ foto |
| 3 | Bots chegam na comida, dançam e vão embora | Bot chega colado, abaixa 0,6 s e pega (antes desistia se havia jogador a 35 studs) | ✅ pegou 2 de 3 em 40 s |
| 4 | Não dá para bater nos bots e eles não batem | Soco acerta bot (vida 110, nocaute 3,5 s); o bot revida por 8 s | ☑️ (testado no duelo) |
| 5 | Atalhos entre pontos | Mesmo sistema do item 1 (um blip em cada base também) | ✅ |
| 6 | Blips: círculo brilhante para entrar e interagir | Disco neon + anel + coluna de luz + nome; pisar ou apertar E abre o menu | ✅ |
| 7 | ARENA mistura as telas; bots não aparecem como oponentes | Janela ARENA com 2 abas (BOXE e BATALHA DE GIGANTES); bots na lista como qualquer oponente; luta real contra bot (sem perder comida) | ✅ luta até o fim |
| 8 | Arena colada na praça, perto da panela | Coliseu foi de r 235 para r 192 (portão encosta na praça); a placa "MAIS REBIRTHS" que ficava na frente foi para 67,5° | ✅ (MAP_VERSION 4) |
| 9 | Bots nos placares | Bots entram nas 3 placas pelo nível, renascimentos e pontos de arena (só enquanto estão no servidor) | ☑️ (placar global indisponível no Studio) |
| 10 | Velocidade na ponte do Dragão | Turbo 2,4x em cima da ponte, com setas azuis no piso e aviso "TURBO DA PONTE!" | ☑️ |
| 11 | Convite quando o Dragão nasce | Cartão no lado direito: "O DRAGÃO NASCEU! VAMOS JOGAR?", time N de 4 (●○○○), prêmio e botão azul JOGAR que pulsa e leva à ilha; X fecha | ✅ |
| 12 | Faixa de evento tampa a tela | Faixa mora pequena no canto superior direito; ao anunciar aparece grande no centro e desliza de volta | ✅ foto |
| 13 | Tirar o painel de baixo "DISPUTA DE COMIDA" | Removido (a seta para a base continua só quando carrega) | ✅ |
| 14 | Voz da comida caindo irritante | Voz só no começo da Chuva de Comida; fora isso só um sino baixo para comida Épica+ ou que cai perto; aviso de texto só para drop importante | ☑️ |
| 15 | Dragão em cacos e mal animado | Trocado o dragão de cristal (malha de lascas) pelo dragão vermelho inteiro; animação no cliente: chega voando, respira, empina e bate no ataque, treme ao apanhar, fúria, cai na vitória ou foge voando | ✅ foto |
| 16 | Vencer o Dragão: Lunchbox + ovo | Vitória (até 2 por dia, como antes): Lunchbox Épica (4 a 5 comidas) + 1 ovo grátis (Pequeno 40 · Médio 32 · Grande 20 · Enorme 8); o painel diz o que caiu | ☑️ (specs) |
| 17 | Lunchboxes fracas | Comum 1 · Rara 2-3 · Épica 4-5 (1 Épico garantido) · Lendária 7-8 (1 Lendário) · Mítica 9-10 (1 Mítico); a loja mostra a tabela da comida garantida e a das demais | ✅ Lendária deu 7 |

## Testes
- Suíte no Play: **156 passou, 0 falhou** (15 módulos).
- O teste pegou um erro meu antes de chegar ao jogo: a função do ovo do Dragão estava dentro de outra função. Corrigido.
- O teste com foto mostrou que o cartão do convite cobria os botões da esquerda. Ele foi movido para a direita.

## Para você saber
- **Lucky Lunchbox (produto de Robux)**: agora entrega 2 a 3 comidas, todas Rare ou melhor (antes era 1). Só melhorou para quem compra. O texto do produto foi atualizado. Como é item aleatório pago, confira a política da Roblox antes de publicar (como já estava anotado).
- **Mapa assado**: como a arena e o ninho mudaram de lugar, o MAP_VERSION foi para 4. O place oficial ainda tem o mapa versão 3 assado. Ele continua funcionando: o jogo monta o mapa novo ao iniciar, só demora um pouco mais. Para assar de novo: abra o place e rode o bake, como da outra vez.
- Não testado: 2 jogadores reais, celular de verdade, DataStore real (placar global).

## Revisão cega
- Nota **5,8** (rascunho, abaixo de 8,5). Conta refeita: (3+3+2+4+1+1) ÷ 24 × 10.
- Defeitos reais encontrados, todos corrigidos e testados de novo no Play (156/156; duelo contra bot terminou em KO):
  - um erro no meio do duelo contra bot deixava o jogador preso no ringue;
  - se o bot saísse do servidor no meio da luta, o jogador ganhava de graça (agora a luta é anulada);
  - o bot aceitava o desafio mesmo que o Dragão começasse nesse meio tempo;
  - a viagem não conferia de novo depois de meio segundo de espera, e quem estava esperando no campeonato podia viajar;
  - as recusas de viagem não diziam o motivo.
- O que segura a nota:
  - faltam testes automáticos de viagem, duelo e bots;
  - falta o teste com 2 jogadores e no celular.
