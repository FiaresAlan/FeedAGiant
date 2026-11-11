# FEED A GIANT V3 — QUALIDADE, ANALYTICS E VALIDAÇÃO DE R$ 50
11/11/2026 | Especificação para desenvolvimento e teste antes de qualquer anúncio

## 1. Três níveis de evidência — não confundir

**Teste unitário:** prova uma regra de código isolada, por exemplo que um job de receita mítica dura certo tempo e que dois pedidos de claim dão no máximo 1 prêmio.
**Teste Studio/cliente-servidor:** prova que animações, câmera, colisões, UI, duas contas e persistência de teste funcionam.
**Experiência publicada para jogadores reais:** permite AnalyticsService real e comportamento de pessoas desconhecidas. Um Play Solo no Studio não produz prova de retenção.

Não usar o número antigo de “192 testes aprovados” como prova de que a V3 está testada. Esse número pertence a outra build e não cobre montaria, economia das panelas, novas recipes, balanceamento ou Android.

## 2. Checklist de QA em ordem de bloqueio

### P0 segurança e integridade

- [ ] Backup de arquivos/asset IDs/versão do place com checksum, git status e commit antes de trabalhar.
- [ ] O inventário, os ovos, os perfis, os recibos e todos os valores pagos anteriormente continuam preservados.
- [ ] Dois jogadores pegando o mesmo cargo ao mesmo tempo: só um obtém posse.
- [ ] Repetir a Remote de depositar 100 vezes com mesmo nonce: somente 1 prêmio.
- [ ] Desconectar em todos os estados WORLD/RESERVED/CARRIED/DROPPED/DEPOSITED: não duplica.
- [ ] Trocar personagem, entrar/morrer/desconectar montado: limpa rider/câmera/colisões e devolve controle.
- [ ] Remote de mudança de XP/tipo de prêmio/recipe tempo/cooldown enviado por client falso: rejeitado.
- [ ] Primeiro jogador consegue alimento sem depender de outro player.
- [ ] Primeiro banquete e duas primeiras entregas protegidos contra roubo de cargo.
- [ ] Receitas inválidas e falta de ingredientes não consomem recursos.
- [ ] Duas panelas com jobs independentes, de 10–30 min, reentrada após encerramento: tornam-se READY pelo relógio do servidor.
- [ ] Claim repetido ou inventário cheio: nenhum prato duplicado/perdido.
- [ ] Atualização de perfil antigo sem slice V3 preserva dados existentes desconhecidos.
- [ ] Acesso à loja e monetização anterior não gera regressão de recibos e itens adquiridos.

### P0 experiência

- [ ] Câmera terceira pessoa mostra player sobre ombros, gigante e carga sem clipping grave.
- [ ] Montar/desmontar 20 vezes seguidas não trava avatar nem duplica rig.
- [ ] Corrida tem animações de passada real, não slide ou stretch da malha inteira.
- [ ] Peso leve/médio/pesado perceptível sem ficar frustrante; indicador no HUD mostra classe de peso.
- [ ] Boost de cada elemento visível, duração/cooldown claros, sem glitch na câmera.
- [ ] Segurar comida não atravessa pernas/ombros do rider; escala está coerente.
- [ ] Receita é descoberta e aparece no Livro, mesmo após reentrada.
- [ ] Gigante aceita prato pronto de uma panela e mastiga com mandíbula e mãos articuladas.
- [ ] Primeira alimentação e primeira coleta acessíveis em 1–2 min.
- [ ] HUD não escurece game ao abrir Livro/loja/panelas.

### P1 dispositivos

- [ ] Android real OU emulador de Studio devidamente identificado com resolução 720×1600 e telas menores; não chamar emulador de aparelho físico.
- [ ] Gamepad/console, mouse/teclado e touch funcionam com botões óbvios.
- [ ] Controle de câmera não exige mirar enquanto corre em celular.
- [ ] 8 jogadores montados/carga/panelas sem pico anormal de frames ou memória.
- [ ] Streaming de mapa/LOD não faz perder controles ou ponto de depósito.
- [ ] Configuração de reduzir partículas/shake e opção de baixar volume.
- [ ] Sons espaciais não tocam globalmente como sirene a cada preparo.
- [ ] Avatar respawna de modo seguro após qualquer reset.
- [ ] Situações ruins: lag 150 ms, queda de conexão, FPS baixo, servidor quase vazio.

## 3. Instrumentação objetiva — eventos definidos

Todos os eventos abaixo devem ser gerados no SERVIDOR (AnalyticsService). Cliente só envia ações de gameplay validadas, não eventos de sucesso.

### Um funil de primeira visita

Ordem de eventos sugerida: 
1. PLAYER_JOINED
2. FIRST_FEED
3. FIRST_MOUNT
4. FIRST_CARGO_PICKUP
5. FIRST_CARGO_DEPOSIT
6. FIRST_RECIPE_DISCOVERED
7. FIRST_POT_START
8. FIRST_POT_CLAIM
9. SECOND_FEED
10. FIRST_NEXT_ACTIVITY

Implementar com LogOnboardingFunnelStepEvent (que suporta steps one-time). Se houver ordem divergente (primeiro montar antes do feed), não inventar conclusão de step: reavaliar a ordem no onboarding e ter custom events separados para ações fora da sequência. Funis iniciam apenas se etapa 1 enviada. Associar jogadores da primeira visita conforme schema real, não repetir etapas como se fossem novos usuários.

### Custom events recomendados

| Nome estável | Quando enviar | Campos não pessoais |
|---|---|---|
| MOUNT_STARTED | servidor aprovou montar | element, device, firstTime |
| MOUNT_ENDED | desmontagem válida | element, reason, duration |
| CARGO_PICKED | pickup válido | weightClass, element, zone |
| CARGO_DROPPED | queda real | reason, weightClass, zone |
| CARGO_INTERCEPTED | ação de roubo validada | weightClass, zone, role |
| CARGO_DEPOSITED | inventário/receita realmente creditado | kind, weightClass, element |
| FEED_COMPLETED | alimento debitado e XP processado | foodClass, stage, element |
| POT_STARTED | job e ingredientes persistíveis | recipeClass, potIndex, durationBucket |
| POT_READY_CLAIMED | prêmio concedido no perfil | recipeClass, potIndex, offlineCompleted |
| RECIPE_DISCOVERED | descoberta nova confirmada | recipeClass, source, stage |
| BOOST_USED | boost executado no server | element, cargoClass, source |
| ERROR_RECOVERY | recuperação de estado transacional | component, reason, device |

Evitar explosão de eventNames: usar custom fields de 3 categorias suportadas. Não enviar nome do jogador, ID completo, mensagens, PII ou texto livre.
Para velocidade de entrega: evento com valor numérico da duração de corrida, agregado e amostrado; distinguir inativo/AFK pelo tempo entre ações e pelo deslocamento validado, não pelo cronômetro de sessão sozinho.
Metas e cálculos são HIPÓTESES; NÃO pressupor que AnalyticsService real funciona no Studio. Documentação oficial: https://create.roblox.com/docs/production/analytics/funnel-events e https://create.roblox.com/docs/production/analytics/custom-events

## 4. Métricas e hipóteses de corte

**Mais importantes:** primeiro feed em 2 min, primeira montaria, primeira entrega, segundo ciclo de alimentação voluntário, primeira receita concluída, retenção no dia seguinte, falhas de câmera e rate de recuperação de item.
**Não interpretar como sucesso:** um jogador parado 30 min, um pico único de efeito de receita, 100% do clique dos anúncios sem gameplay posterior ou um evento pago que dá XP artificial.

Hipóteses orientadoras para uma amostra exploratória (não benchmark):
- A maioria das contas que ficam ao menos 3 min devem alimentar ao menos uma vez.
- Pelo menos metade das pessoas que montaram devem conseguir uma entrega sem ajuda.
- Uma parte relevante dos jogadores que completam uma entrega deve voluntariamente iniciar outra ação relacionada à comida.
- Repetição do ciclo e retorno D1 são sinais mais confiáveis de interesse que duração bruta.
- Com menos de 30 jogadores qualificados, não declarar “bom” ou “ruim” por porcentagem pontual. Reportar contagem absoluta e intervalos de incerteza.

### Exemplos de interpretação

40 jogadores entram; 35 dão 1 comida; 6 repetem: provável problema de recompensa no feed, mas medir se câmera, conteúdo e o tempo disponível explicam a queda.
40 entram; 25 montam; só 4 depositam carga: investigar controle, feedback, roubo injusto e extensão da pista, antes de aumentar prêmios.
40 entram; 25 depositam; 3 cozinham: Livro/panelas pouco claros, receitas sem valor, controles complexos ou tutorial escondido.
40 entram; 30 cozinham; 20 alimentam pela segunda vez: sinal favorável de entendimento, mas retorno posterior ainda precisa ser medido.
Os números acima são exemplos analíticos, não projeções de conversão.

## 5. Particularidade muito importante do algoritmo Roblox

Roblox Discovery avalia Home Recommendations por janelas de Day 1, Day 2–7 e Day 8–28, além de sinais de entrada e bounce. **Tráfego pago via Ads Manager não entra diretamente nos sinais de ranqueamento de Recommended For You (RFY)**, segundo o Discovery FAQ. Portanto, gastar R$ 50 em Ads é um teste EXPLORATÓRIO de gameplay e dados, não uma garantia de empurrão orgânico no algoritmo. A plataforma pode continuar testar organicamente conforme sinais próprios.
Fontes:
https://create.roblox.com/docs/discovery
https://create.roblox.com/docs/discovery-faq

## 6. Experimento pago exploratório de R$ 50

NÃO criar campanha automaticamente. O usuário só autoriza gasto mediante uma decisão explícita depois de ver QA.

### Antes do pagamento

- [ ] Jogo publicado em estado liberado para jogar, com acesso e privacidade escolhidos pelo proprietário.
- [ ] UI e câmera de Android testadas e mínimo 2 clientes multiplayer.
- [ ] Primeira alimentação/primeira entrega/duas panelas funcionam.
- [ ] Dados persistentes em test account e receipts auditados.
- [ ] AnalyticsService e eventos estão instrumentados e funcionando no ambiente publicado privado/teste onde possível.
- [ ] Ícone e thumbnail usam personagem e ação realmente presentes no jogo. Não prometer arena de boxe se ainda não existe.
- [ ] Consultar Ads Manager e valores mínimos/vigentes na conta. R$ 50 é um teto de intenção, não promessa de que a plataforma venderá campanha exatamente nesse valor.
- [ ] Selecionar objetivo Plays, público New Players se disponível e localização/idade/device coerentes com experiência.
- [ ] Campanha com orçamento total/lifetime limitado aos créditos aprovados, **auto-reload desativado**, sem data/compra sem confirmação.
- [ ] Manter no máximo um ou dois criativos inicialmente para não dividir ainda mais uma amostra pequena.

### Criativos corretos para V3

C1: Gigante bípede com avatar nos ombros carregando comida gigante, outro gigante atrás; a ação “pegar e escapar” precisa existir.
C2: comparação antes/depois do gigante alimentado, panela e receita ao fundo. Tamanho final apresentado deve existir no jogo.
Renderização com captura real do Studio; edição só para legibilidade, sem inventar mecânicas.

### Após teste

Aguardar atrasos normais de relatórios. Exportar impressões, cliques, jogos, custo por partida, qualificados, funil, duração ativa, D1 e repetição do feed; observar também travamentos. Com orçamento pequeno e amostra limitada, aceitar resultado inconclusivo.
Se o funil quebrou, CORRIGIR e retestar antes de novo gasto. Não trocar o nome, produto, anúncios e mapa simultaneamente, pois impede atribuir melhorias.

Fonte oficial: https://create.roblox.com/docs/production/promotion/ads-manager

## 7. Critérios de GO / NO-GO

**GO técnico para teste pago:** nenhum bug P0 aberto; montaria fluida e verificável em vídeo; alimentação expressiva; 2 panelas com saves offline; pista sem exploits básicos; controle mobile aceitável; observabilidade com eventos; licença dos modelos conferida; owner aprova publicação e verba.
**NO-GO técnico:** camera prendendo, avatar deslizando, malha inflável, perda/duplicação de itens, FPS ruim em celular, timer offline quebrado, provedor de asset não verificado, monetização irregular, saldo de anúncio sem limite.
**GO produto para avançar depois da campanha:** sinais de repetição voluntária de feed/entregas, resposta qualitativa via dados e pelo menos alguma procura por receitas; não concluir sem coorte.
**PIVOT:** se várias iterações de qualidade não elevarem a repetição central, considerar escopo diferente ou outro projeto. Não “salvar” gameplay ruim adicionando boxe/dungeon.

## 8. Política de monetização e públicos menores

V3 não cria novo produto pago. Itens aleatórios pagos, reprodução/fusão com chance e boost de sorte exigem regras e divulgações atualizadas; por ora não implantar. Política oficial: https://create.roblox.com/docs/production/monetization/paid-random-items.
Evitar vantagem pay-to-win em sprint, força, proteção e chance de carga; monetização futura preferida: cosméticos de criatura, acabamento de base, efeitos de panela sem aumento competitivo ou passes de conveniência que não prendam a progressão essencial.
Não vender proteção obrigatória contra roubo; não cobrar para recuperar carga; não punir jogador offline.

## 9. Relatório final que o Claude deve produzir

Nome de saída: V3_RELEASE_CANDIDATE_REPORT.md

1. Branch/commit e place IDs usados. Nenhum merge/pub sem aprovação.
2. Resumo do que funcionou (com vídeos ou provas) versus planejado/desativado.
3. Inventário de assets importados: arquivo local, URL original, licença, mesh/anim IDs, caminho Studio.
4. Comparativo de performance PC/mobile, quantos players, FPS e memória.
5. Lista de eventos Analytics, passos de funil e evidência do logger em ambiente disponível.
6. Testes automatizados e manuais executados, quantidades e resultados; bugs conhecidos.
7. Checkpoint de persistência: dados antigos, recipes, jobs, ovos e recibos.
8. Plano de rollback para features e saves.
9. Checklist de publicação manual e anúncios ainda não executados.
10. Próxima tarefa sugerida SOMENTE se a entrega passou nos gates.