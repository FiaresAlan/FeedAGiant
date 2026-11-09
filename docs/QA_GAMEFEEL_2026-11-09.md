# FeedAGiant — qualidade de gameplay e checklist de QA
**Data:** 09/11/2026 · **Estado:** código implementado em branch, **não testado no Roblox Studio**.

## Proteção antes de testar
- Backup antes das mudanças desta rodada: `backup/2026-11-09-antes-melhorias-gamefeel` (PR anterior no commit `8f587f0284294e32bf05e67f449dd8f33fda9365`).
- Código novo: `codex/feedagiant-qualidade-prelancamento-2026-11-09`.
- Sem merge no `main`, sem salvar/substituir o place oficial, sem publicar, sem Robux.
- Para restaurar esta rodada: usar a branch de backup, que preserva o estado do PR antes das novas animações.

## O que foi alterado e o que NÃO foi alterado
1. **Alimentação:** a comida continua voando e a mordida ocorre no tempo existente. Adicionado `Highlight` temporário local, efeito por raridade, texto da primeira mordida e do nível obtido. Não muda XP, probabilidade de crítico, comida nem velocidade.
2. **Evolução:** evento inclui o estágio anterior para mostrar `ANTES → DEPOIS`. Mantém curva de tamanho, estágios e VFX já existentes.
3. **Ovos:** eclosão agora usa rachaduras 2D simuladas, fragmentos por raridade, menos tempo e fundo transparente. A revelação tenta mostrar o **modelo 3D real da espécie** a partir de `Workspace.GiantStatues.Statue_<id>`. Com StreamingEnabled ou malha ausente, a revelação mantém o texto existente. Não muda chance, tempo de incubação nem entregas.
4. **Disputa:** aviso pequeno de comida Épica+ a até 150 studs, apenas após nível 5 e no máximo um a cada 7 s. Não volta com painel permanente e não mostra seta para todos os drops. Não muda mecânica de roubo nem drops.
5. **Arena:** barra de vida pisca ao receber dano, sem criar um painel adicional. Não altera dano, combate, posicionamento ou resultados.
6. **Gigantes na base:** olhar suave para visitantes à frente, com busca a cada 0,7 s, apenas no cliente; placa de identificação mostra tamanho em vezes e só aparece a até 155 studs. Sem qualquer mudança na progressão.
7. **Pré-lançamento (PR anterior):** limite de recolha no pátio, validação de lote da Lunchbox, fundo de abertura transparente, analítica do primeiro/segundo feed e 3 testes de capacidade.

## Verificações obrigatórias antes de merge
| Teste | Passos | Aprovação |
|---|---|---|
| 1. Compilar Luau | Rodar o verificador do `CLAUDE.md`, Rojo build em cópia e suíte do `tests/Runner.luau` | 0 erro e todos testes passando |
| 2. Primeiro minuto | Entrar com conta nova, escolher espécie, alimentar 2 vezes, concluir tutorial | texto da primeira mordida aparece 1 vez e não bloqueia o HUD |
| 3. Reação do gigante | Alimentar comidas comum, épica e crítica perto da base; observar outro jogador | mordida/voo sincronizados, destaque some, sem acumular Highlight |
| 4. Primeira evolução | Chegar ao primeiro novo estágio; continuar alimentando após evolução | antes/depois correto, nenhuma mudança brusca para escala 1 |
| 5. Ovo comum e lendário | Iniciar eclusão após tempo; esperar eclodir, repetir com dois ovos | 1 recompensa por ovo, VFX sem tela preta e sem travar fila |
| 6. Espécie real no ovo | Fazer eclosão perto da praça com `GiantStatues` carregado | miniatura 3D da espécie correta, sem Scripts clonados |
| 7. Fallback de ovo | Testar com `StreamingEnabled` ou estátua ausente | texto do resultado permanece legível, nenhuma exceção |
| 8. Movimento reduzido | Ativar preferência, abrir caixa e eclodir ovo | sem rotação/tremida longa e sem tela escura |
| 9. Raridade próxima | No nível >= 5, receber drop Épico a <150 studs; outro a >150 | aviso só perto, autoesconde em ~2,2 s; sem spam |
| 10. Arena PvP/bot | Abrir luta, receber 1 golpe, sair/desconectar | barras de HP piscam, status limpa e não há exceção |
| 11. Visitar bases | Jogador A aproxima-se do gigante de B a <40 studs; recua | gigante olha levemente, volta ao idle, placas legíveis |
| 12. Celular físico | 15 min num Android intermediário; incluir eclosão e combate | legibilidade, controles acessíveis e FPS estável |
| 13. Perfil/recibo | Mochila com 300 e 2000 itens, abrir Lunchbox comum/paga, sair/reentrar | não duplicar ou perder comida, compra não confirma sem entrega |
| 14. Segurança do place | Abrir CÓPIA do place que o usuário salvou e conferir `Workspace.MainModule` | ausente no place final, sem scripts estranhos |
| 15. Multiplayer | 2 clientes testando ovos/roubo, boss e arena | sem desync, softlock, duplicação ou roubo de último ovo |

## Riscos conhecidos
- **Ainda sem rig por ossos para vários gigantes.** O movimento é procedural, não movimento facial real.
- **Rachaduras do ovo são efeitos 2D**, não fragmentação física da malha. O preview 3D depende de existir a estátua no cliente; a ausência não afeta o resultado concedido no servidor.
- **Efeitos audiovisuais ainda exigem validação real em dispositivos**, principalmente com muitos gigantes e ovos simultâneos.
- **Testes desta rodada:** inspeção estática das alterações e equilíbrio de delimitadores. O Roblox Studio, Rojo, Selene, DataStore e compras com Robux **não foram executados neste chat**.

## Go / No-Go
Lançamento de teste apenas se: lugar sem módulo suspeito, compilação/suíte verdes, eclosão no celular e em multiplayer funcionando, primeira alimentação fluida, DataStore persistindo e produtos pagos corretos. Qualquer falha de segurança, dados ou recibos = **no-go**. Publicidade paga somente após métricas observadas de aquisição e retenção.

## Rodada local de 09/11/2026

O trabalho partiu do PR #1 no commit `40de2d6`. A branch foi clonada em pasta separada. Os diretórios locais preexistentes, os dois backups do PR e o place oficial foram preservados. A build de QA foi gerada a partir do código da branch e executada no Studio com `PlaceId = 0`.

### Alterações e verificações

| Área | Alteração | Evidência |
|---|---|---|
| Alimentação e evolução | Campos de analytics tipados, uma animação de escala por gigante, banner que cabe na largura do HUD e respeita a duração da evolução mais recente. | Duas alimentações consecutivas consumiram dois itens e incrementaram o contador no Studio. Transformação visual e desempenho em celular pendentes. |
| Eclosão | Prévia 3D opcional protegida, rachaduras removidas na revelação e limpeza da fila por item, inclusive quando um efeito falha. | Duas solicitações reais de eclosão pelo cliente, com ovos preparados no ninho da praça. O servidor removeu ambos e contabilizou as recompensas. O cliente mostrou dois resultados e escondeu a fila. Enquadramento 3D, assets, raridades altas e movimento reduzido pendentes. |
| Disputa e bases | Aviso de comida rara no pouso. Gigante gira para o lado do visitante usando a orientação de repouso. | Lógica revisada e compilada. Pouso, giro e desempenho com várias bases pendentes em sessão visual. |
| Arena | Cancelamento limpa contagem e música. Transferência conserva UID, mutação e tamanho, e só retira itens que cabem no vencedor. | Lógica revisada. Dano, cancelamento e transferência com dois jogadores ainda pendentes. |
| Onboarding | Caixa pendente usa o botão existente e o aviso sonoro, sem abrir janela. Retorno adia o resumo quando a espécie inicial está pendente. | Cliente recebeu a escolha e o servidor aceitou a espécie inicial. Primeiro minuto observado com jogador novo e sobreposições em celular pendentes. |
| Ovos e carga | Proteções são revalidadas ao terminar o roubo. A vítima que sai recebe o ovo antes do save, inclusive acima do limite de aquisição. Cargas de ovo e comida são mutuamente exclusivas. | Regras de roubo cobertas pela suíte existente. Corrida entre dois ladrões, saída da vítima, carga simultânea e reentrada reais pendentes. |
| Lunchboxes e mochila | Lote montado antes da cobrança, uma atualização de mochila por abertura, caixas de determinadas recompensas guardadas se não couberem, acesso a índices válidos acima do limite normal e limite de solicitações de estado completo. | Compra comum perto do teto recusada sem cobrança, compra subsequente entrega o lote completo e recompensa Épica fica guardada no teto estendido. Recibos reais e abertura de caixas guardadas acima da sexta posição pendentes. |

### Ferramentas

- **Luau 0.745.0:** 118 arquivos de `src` e `tests` compilados. **Luau LSP:** análise do código de jogo aprovada, com aviso preexistente de variável sombreada em `MapKit/Scatter.luau`.
- **Verificador do projeto:** `overall PASS (101 files)`, incluindo a checagem de padrões Roblox.
- **Selene 0.32.0:** zero erros, avisos ou falhas de sintaxe em `src`. **StyLua 2.6.0:** `stylua --check src tests` aprovado.
- **Rojo 7.7.1:** builds de produção e teste aprovadas. Sourcemap gerado. `rojo serve` local respondeu às consultas de metadados e árvore. Sincronização ao vivo pelo plugin no Studio não foi executada.
- **Roblox Studio:** `167 passed, 0 failed, 16 spec modules` em Play solo com os testes de integração da tabela. O DataStore caiu no modo em memória por se tratar de place local. IDs de produtos estão como placeholders. O console registrou falhas de carregamento de alguns assets, incluindo representações ainda em geração, e IDs associados ao plugin Ecos Tools.
- **Inspeção do place:** ausência de `Workspace.MainModule` na build Rojo de QA. Os três arquivos XML inspecionados (repositório, pasta local e backup local) também não contêm scripts sob Workspace. As cópias XML têm código histórico. O place oficial e os binários locais não foram inspecionados.

### Pendências antes de publicar

1. Em cópia de teste, usar três jogadores para dois roubos simultâneos em um ninho com dois ovos. Só uma retirada deve ocorrer. Testar ainda saída da vítima durante o transporte e devolução com bolsa de ovos acima do teto.
2. Usar dois clientes para disputa, escudo, arena, nocaute e desconexão. Na arena, validar um item mutado ou Gigantesco e um vencedor com mochila cheia.
3. Verificar o place oficial e confirmar o carregamento dos assets e a experiência em celular físico, incluindo eclosão, movimento reduzido e primeiros cinco minutos.
4. Validar DataStore persistente e os recibos num ambiente de teste autorizado. A devolução de ovos em desligamento abrupto do servidor ainda não é durável entre perfis. A caixa do Dragão com raridade mínima em todo o lote ainda pode falhar com mochila no teto, pois a fila atual guarda apenas IDs de caixas.

Status da rodada **rascunho, sem aprovação de lançamento**. As revisões independentes desta rodada foram de código. A avaliação visual, multiplayer e de prontidão segue pendente.
