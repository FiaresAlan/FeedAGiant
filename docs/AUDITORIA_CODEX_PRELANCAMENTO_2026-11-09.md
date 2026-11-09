# Auditoria de lançamento e melhorias — 09/11/2026

**Referência analisada:** main @ `374c95436109d1023a43b4914dd8c11ac86ad6e3` (9/11/2026).
**Backup intocado:** `backup/2026-11-09-antes-auditoria-codex`.
**Execução:** `codex/feedagiant-qualidade-prelancamento-2026-11-09`.
**Alvo:** avaliação de beta controlada em sexta-feira, 13/11/2026. Não implica lançamento ou campanha paga.

## Resumo técnico

O projeto já dispõe de alimentação, progressão por espécie, ovos, roubo de comida e de ovos, bots, arena, boss, almoço em caixas, mutações, fusão, renda e viagens rápidas. O maior risco não é falta de sistemas: são regressões entre mecânicas, excesso de escolhas no começo, testes reais pendentes e divergência entre o código/Rojo e o place salvo.

### Achados confirmados no código (não presumir que documentação antiga é atual)

1. `PlotService.pickup` recolhia alimento do pátio sem verificar o teto normal da mochila (300). **Corrigido nesta branch**: notifica e mantém a comida no pátio.
2. `ShopService.openBox` verificava o espaço normal somente quando `force=false` e podia entregar lote incompleto até o teto estendido (2.000). **Corrigido parcialmente**: pré-validação conservadora da capacidade do lote todo, com teto normal/estendido/recibo pago. Uma falha excepcional de entrega no meio do lote ainda exige teste de transação e recibos no Studio.
3. `Hatch.play` ainda aplicava fundo preto com transparência 0,85 durante a revelação, apesar do requisito de não escurecer o mundo. **Corrigido** para 100% transparente. A animação fica em primeiro plano; inspecionar no celular se objetos da animação continuam obstruindo interação temporariamente.
4. O projeto já possui `Analytics.event` e funil `Tutorial_v1`. **Acrescentado** o registro de primeiro e segundo feed pelo servidor, uma vez por perfil novo ao alcançar contagens 1 e 2, sem dados pessoais.
5. `TutorialEgg=false` apesar de `StarterSpecies=true` e `EggSystem=true`: **não ativar de surpresa**. O primeiro minuto já usa oferta de espécie e tutorial de quatro etapas.
6. `Workspace.MainModule` suspeito foi retirado em uma sessão do Studio, conforme handoff, mas não foi verificado aqui que o place oficial foi salvo, reaberto e limpo. **Bloqueador para publicação até inspeção real.**
7. Teste em celular físico, reentrada com DataStore real, dois jogadores e re-bake MAP_VERSION 4 precisam ser confirmados na build candidata. O histórico de 156/156 é evidência de execução anterior, **não foi repetido nesta auditoria**.
8. Atenção: pagamento de LuckyBox é acoplado ao grant do `Receipts`, enquanto `ShopService.openBox` tem efeitos de estado e rede a cada item. Exercitar duplicação, quedas durante concessão, mochila cheia e elegibilidade regional, antes de ativar ID diferente de 0.
9. As descrições da loja anunciam Boxer Pro e Arena VIP com benefícios competitivos. Auditar efeito real sobre PvP e alinhar texto/implementação; a arena central havia sido balanceada para igualdade. Não mudar passes nem economia sem medições.
10. O `README.md` fala em 7 espécies, place não publicado, arquivos prontos e verba de ads diária elevada: está desatualizado em relação ao sistema atual. **Não executar tais instruções comerciais automaticamente.**

## Recomendações de produto, por impacto

| Prioridade | Área | Ação verificável | Evidência de aceite |
|---|---|---|---|
| P0 | Segurança | Salvar/reabrir cópia do place após remoção do MainModule; varrer scripts de assets externos | ausência de módulo suspeito e erros no console |
| P0 | Compras/dados | Reentrada, compra e concessão de Lunchbox no limite de 300/2000, após queda, recibo repetido | sem perda, entrega parcial nem duplicação |
| P0 | Mobile | Jogar 15 min em celular real, incluir roubo de ovo, cozinha, loja e arena | todos os controles alcançáveis, telas fecham, sem queda grave de FPS |
| P0 | Multiplayer | Dois jogadores em servidores de teste: roubo, proteção inicial, bots e ovos, duelo interrompido | estado idêntico servidor/cliente |
| P0 | Build | MAP_VERSION 4, código sincronizado, place oficial e cópia de teste identificados | builds consistentes e place final limpo |
| P1 | FTUE | Um único objetivo visível a cada instante; evitar abrir várias escolhas e avisos durante o primeiro feed | teste cego com 10 novos jogadores |
| P1 | Feeding | Ver reação de três espécies ao comer; sincronizar mordida e objeto, escala, feedback sonoro e câmera | vídeo em desktop e celular |
| P1 | Concorrência | Exibir primeiro contraste visual gigante pequeno vs gigante evoluído; permitir visitar bases | jogadores entendem ideia sem ler um painel |
| P1 | Ovos | Garantir clareza: ovo em cada base vs ninho da praça; proteger novato e último ovo | testar 2 contas, entrar/sair durante roubo e eclosão |
| P1 | Analítica | Instrumentar primeiro feed, segunda alimentação, tempo até first feed e abandono do tutorial | eventos no Analytics do place real |
| P2 | Economia | Simular renda offline, fusão x3,2, mutação, críticos e crescimento herdado de espécies | sem ganho exponencial acidental |
| P2 | Evento | Reduzir banners simultâneos/efeitos perto do spawn; dar prioridade a combate ativo | nenhuma UI tapa controle essencial |

## Estratégia de marketing específica

**Posicionamento proposto:** `Alimente o SEU gigante e veja ele ficar enorme`. Não vender primeiro "coleção", "roubo" ou "ganhe moeda"; são atrações secundárias. Já existem jogos com título Feed a Giant, portanto testar nome distintivo antes da campanha e preservar alinhamento entre título, icon, thumbnail e criatura que aparece no spawn.

### Experimentos de miniaturas

- **A (crescimento):** avatar pequeno, mesmo gigante enorme e pernil reconhecível; sem números ou moeda falsa. Estabelece posse e transformação.
- **B (perseguição):** jogador levando pernil gigante, rival correndo atrás e seu gigante esperando na base; só usar se gameplay PvP estável.
- **C (mistério):** ovo real rachando, modelo jogável verdadeiro, ninho correspondente; não representar tutorial de ovo que está desligado.
- Ícone: rosto da espécie inicial com comida destacada, legível a 100px. Contraste de silhuetas, sem textos longos. Capturas reais do Roblox com Freecam, nunca renderizar recursos ausentes.

Ativar 2–5 thumbnails na personalização do Creator Hub quando houver tráfego suficiente; comparar **qualified play through rate**, não apenas CTR. Referência: https://create.roblox.com/docs/production/publishing/thumbnails

### Distribuição e aprendizado

- Produzir 3 Shorts autênticos de 10–15 s: crescimento visível, fuga da comida e eclosão real. Gancho nos 2 primeiros segundos, final mostrando nome e Roblox.
- Criar um link de compartilhamento distinto para cada canal/criador; acompanhar origem, usuários com jogadas, tempo de sessão e retenção D1/D7 no painel de aquisição. Referência: https://create.roblox.com/docs/production/analytics/acquisition
- Primeiro teste com 10 pessoas, sem explicar controles. Medir: `spawn → primeira coleta → primeiro feed → segundo feed → crescimento percebido → retorno`.
- Não iniciar gasto significativo antes de confirmar os gates P0. A própria documentação prioriza retenção D1, loop central e desempenho antes de aquisição: https://create.roblox.com/docs/production/analytics/retention
- Não prometer crescimento orgânico, orçamento/ROI ou horários de alta sem observar métricas reais.

## Entrega de código nesta branch

- `src/server/Services/PlotService.lua`: limite na retirada do pátio; helper de capacidade com modalidade de entrega; telemetria da primeira e segunda alimentação.
- `src/server/Services/ShopService.lua`: valida lote inteiro de Lunchbox antes da cobrança/abertura.
- `src/client/Controllers/Hatch.lua`: remove escurecimento do mundo durante revelação.
- `tests/V3.spec.luau`: regressão de limite de mochila, lote e prêmio pago/gratuito.

**Validação efetuada aqui:** inspeção textual dos arquivos no GitHub e verificação estática das alterações (existência das checagens e do teste). **Não executados:** Roblox Studio, Rojo, Selene, Luau checker, testes automatizados in-engine, celular e 2 clientes. Não há acesso à máquina do usuário neste chat. Nenhum place alterado/publicado, nenhum Robux gasto.

## Go / No-Go de sexta-feira

**Go para beta fechado** somente com place comprovadamente limpo, transações/recibos e dados revalidados, loop jogável no celular, 2 clientes sem quebra e primeira alimentação clara. **No-Go para mídia paga** enquanto não houver evidência de experiência qualificada e retenção adequada em teste inicial. Não é recomendável introduzir grandes novos sistemas antes dessa validação.
