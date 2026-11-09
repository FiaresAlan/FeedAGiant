# Noite de melhorias autônomas (09/11/2026)

O usuário me deu o papel de dono do jogo por ~7 horas: "procurar melhorias na internet, pesquisar concorrentes, copiar
e trazer". Única regra explícita: fazer backup antes.
- **Backup:** tag e branch `backup-2026-11-09-antes-da-noite` no GitHub; pasta local
  `backups/2026-11-09-antes-da-noite/`; o place publicado tem o histórico de versões da Roblox.
- **Limites que mantenho como dono:**
  - não publico e não gasto Robux;
  - não copio arte, nomes nem personagens de outros jogos, só a ideia da mecânica, adaptada;
  - nada de item aleatório pago novo;
  - tudo novo entra desligado em `Features.lua` e é testado no Play.

## Pesquisa (fontes na resposta final)
| Concorrente | Mecânica que retém | Como entra no Feed a Giant |
|---|---|---|
| Grow a Garden | **Clima + mutações:** eventos do servidor dão mutações às plantas, que passam a valer mais. É o motor de "voltar para ver o clima" | **Mutações na comida do pátio.** Durante os eventos que já existem (Hora Dourada, Chuva de Comida...), a comida exposta no pátio pode ganhar uma mutação (Dourada, Gigante, Arco-íris) que multiplica a renda e o XP ao alimentar |
| Pet Simulator 99 | **Índice:** registrar cada pet dá recompensas da coleção | **Prêmios do índice de comidas:** o jogo já registra as comidas descobertas, mas não premia. Marcos (10, 20, 30... comidas) dão moedas e um bônus permanente pequeno de renda |
| Steal a Brainrot | Trava da base no início, renda passiva, troca de unidades fracas por fortes | Já temos escudo, roubo e pátio. A ideia de "trocar a fraca pela forte" entra como dica do pátio |
| Simuladores em geral | Mostrar o que aconteceu enquanto o jogador estava fora (renda offline, coisas prontas) | **Painel "Bem-vindo de volta":** um resumo único ao entrar (renda da exposição, ovos prontos, prêmio diário, missão completa) com 1 botão por coisa pronta |

## Ordem
1. Mutações no pátio (maior impacto; liga eventos, pátio e alimentação).
2. Prêmios do índice de comidas.
3. Painel de boas-vindas.
4. Teste integrado com tudo ligado, revisão cega de cada parte, relatório.
