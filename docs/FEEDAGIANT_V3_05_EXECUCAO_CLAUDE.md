# FEED A GIANT V3 — ORDEM EXATA DE EXECUÇÃO PARA CLAUDE CODE
11/11/2026 · Esta é a ÚNICA sequência autorizada para a atualização V3

## Princípios

- Documento V3 substitui todos os prompts mestres antigos, para esta rodada. Não juntar à lista de 500 ideias do V1/V2.
- Executar em branch própria, a partir do estado REAL mais recente no computador após auditoria; backup antes de mexer em Studio/Blender/Rojo.
- Nunca prometer que código isolado transforma mesh único em personagem articulado. A entrega depende de rig e animação visual real.
- Primeiro protótipo de controle e câmera, depois pista, depois cozinha/economia e só então as três espécies e polimento.
- Uma etapa concluída = código, modelo, screenshot/vídeo, teste, lista de regressão e commit. Sem evidência, não avançar.
- Não remover assets nem perder progresso de jogadores; recursos antigos ficam feature-flagged.
- Se um objetivo técnico falhar, reduzir escopo mantendo o loop, não construir sistema substituto gigantesco.

## Tarefa 00 — Auditoria local real e proteção

Localizar diretório do projeto no Windows; git status, branch, diffs, commits e place atual. Conferir versões de Studio, Rojo, Blender e ferramentas. Identificar módulos existentes (GiantService, PlotService, EggService, DataService, ArenaService, SocialFeastService, MutationService, Config e Remotes). Listar todos os modelos gigantes do ServerStorage, fontes, IDs e animações. Conferir se os 7 assets da cozinha e os 3 GLBs anteriores estão mesmo presentes no projeto atual e anotar licenças.
Gerar docs/V3_AUDITORIA_LOCAL_REAL.md com mapa de módulos, assets e Workspace, incluindo quais PRs foram incorporados. Criar branch de execução exclusiva e backup local do place/meshes. Nenhuma feature construída antes de concluir.

**Aceite 00:** proprietário consegue consultar backup + arquivo de auditoria; nenhuma alteração em main, produção, pagamentos ou place oficial.

## Tarefa 01 — Direção visual e um Golem de Pedra hero

Aprovar visual da criatura no Studio antes de fazer combate ou pista. Tentar re-rig do Golem existente APENAS se licenciado e retopologia viável. Senão construir rig bípede próprio com blocos/meshes articulados, seguindo a estética de brinquedo.
Entregar idle, walk, run, look at food, carryLight, carryHeavy, grip/chew/swallow, celebrate, reaction e mount pose. Priorizar 8 clipes principais com blends/markers sobre dezenas de clips pequenos. Implementar bones/joints reais, acessórios e mãos para cargas, mandíbula funcional.
Desligar animação antiga de inflar como linguagem principal; escala somente em mudança de estágio de crescimento.
Capturar vídeo de 20 s de giro, caminhada, corrida e alimentação, vista próxima e distante.

**Aceite 01:** Golem não parece balão; pés e mãos respondem; comida na mão vai à boca; silhueta legível sem interface; licença válida; há clip original reusável.

## Tarefa 02 — Montaria robusta

Implementar método de Rider que conecta avatar ao gigante sem ancorar a assembly errada. Projeto deve suportar teclado, Android e controle; testar personagem humano normal antes/depois; câmera de ombros que não tampa visão; dono único.
Usar control customizado com movimento de Humanoid. Avaliar abordagem A e documentar se precisar B; validar em servidor-client real. Usar input e remotes sanitizados.
Habilitar uma ação de teste “Montar”, voltar à base e desmontar. A pista ainda pode ser um piso temporário.

**Aceite 02:** montar/desmontar 20 vezes, sprint e curvas sem deslizar/travar; câmera livre; outros jogadores veem o rider no ombro; sem exploração de velocidade/posse; reset seguro.

## Tarefa 03 — Pista de transporte e 1 ingrediente

Criar pista/arena retilínea compacta proporcional ao gigante no MAPA EXISTENTE, com sinalização de risco e zona segura. Não remover radiais sem relatório de conflito; se necessário plataforma anexa, sem construir ilha nova enorme.
Um pickup leve e um pesado para testes. Pickups são entidades servidor-authoritative com IDs. Criar CargoCarry/Deposit e UI de peso/retorno. O ingrediente aparece nas mãos, colisão desativada enquanto carregado. Só entrega na zona da base.
Implementar disputa de cargo com interceptação simples, início protegido, dropped e cooldown, sem combate/boxe. Não tocar ovos no inventário nem passivos antigos.

**Aceite 03:** pessoa monta, vai, pega, volta e alimenta; segundo jogador pode tentar interceptar e não duplica item; carga pesada sente diferença na locomoção; solo funciona.

## Tarefa 04 — Duas panelas e catálogo de seis receitas

Integrar ingredientes ao inventário REAL com IDs existentes; criar RecipeCatalog determinístico, Livro de Receitas compacto e duas panelas por base. Começar com par comum de 12 s, depois colocar raro e um preparo offline demorado; então fechar seis receitas e calibração.
Implementar jobs por servidor com startedAt/endsAt no profile e claim idempotente, sem task offline. Não debitar ingredientes por tentativa inválida ou erro de UI. Se inventário lotado, manter pronto. Usuário pode cozinhar A e B simultaneamente e alimentar direto enquanto ambas cozinham.
Adicionar áudio/VFX específicos de fogão e “PRONTO” sem travar FPS. Inspecionar Kenney Food Kit/Quaternius já baixados; use arquivo real, nome real e licença válida, sem IDs inventados. Livro do HUD precisa mostrar combinação, descobrir, tempo e coleta.

**Aceite 04:** duas panelas independentes, recarrega depois de desconectar, item gerado exatamente 1 vez, Livro salva; compatível com 2 clientes.

## Tarefa 05 — Elementos, coleção e evolução

Aplicar mesma interface locomotora para Fogo/Gelo SE modelo e licença permitirem. Criar poderes moderados conforme GDD, com cooldown e efeitos visuais legíveis. Testar peso/sprint em todos três.
Preservar um gigante ativo e coleção de ovos/dados existentes. Mudar estágio visual base em três fases; tamanho na pista permanece padronizado. Não criar híbridos, reprodução ou ovo aleatório monetizado.
Se não conseguir 3 criaturas bem rigadas, reportar bloqueio ao proprietário; não anunciar como três criaturas disponíveis por meio de modelos rígidos infláveis.

**Aceite 05:** silhuetas distinguíveis, boosts acessíveis via touch, diferença de utilidade sem vitória automática por espécie e nenhum conflito na troca de gigante.

## Tarefa 06 — UX dos três minutos e base premium

A base deixa de parecer quadrado: plataforma com contorno orgânico de peças modulares, local do gigante, 2 panelas e livro, ovos existentes em nicho; manter parcelas associadas aos jogadores e pontos de spawn.
Fluxo iniciante com um único CTA: primeiro alimento, montar, pegar, entregar, receita de teste. Não forçar seis tutoriais, não sobrepor popup escuro. UI de Livro e panelas acessível em qualquer dispositivo.
Sons e movimentos precisam sincronizar com evento real. Rodar captura de vídeo dos primeiros 3 minutos sem narração nem atalhos de desenvolvedor.

**Aceite 06:** usuário sem explicação consegue duas alimentações e usa pista/panela, mesmo com servidor vazio.

## Tarefa 07 — Analytics e segurança da release candidate

Integrar V3MetricsService e eventos do documento 04. Usar testes unitários para dados e inventário, QA de 2 clientes, emulator mobile e dispositivo físico quando disponível. Audit de dados persistentes, receipts/ovos/coleção. Corrigir bugs de exploração e desempenho, com logs rastreáveis.
Importante: analytics nativo só gera registros reais em experiência publicada; primeiro implementar e testar lógica local via logger de fallback, depois validação de eventos em ambiente publicado apropriado, sem liberar ads automaticamente.

**Aceite 07:** todos os gates QA P0 passam; bug list com severidade, screenshots e métricas de performance; branch e commit enviados ao dono.

## Tarefa 08 — Revisão de produto SEM implementação nova

Testar se o usuário consegue identificar o que fazer sem tutorial, se gigante parece vivo, se pista diverte mesmo sem prêmio raro, se Livro é compreensível, se tempos de panela não bloqueiam. Registrar top 5 problemas observados.
Se falhar, corrigir o núcleo; não ativar a arena de boxe ou Boca do Colosso para tentar salvar a experiência.
Preparar relatório final e pedir autorização EXPRESSA para publicar teste. Ads só depois de aprovação separada.

---

## Cálculo de custo/esforço (orientação, não promessa de prazo)

A maior incerteza do projeto é rigging/animações controláveis. Dependendo de estado atual e da habilidade do Claude com Blender/Studio/MCP, pode consumir mais esforço que toda a pista e as receitas juntas. **Não prometer “fazer tudo em uma noite”.** Preferir mostrar Golem montável e loop de uma carga antes de ampliar para Fogo/Gelo/6 receitas. Uma imagem bonita não substitui vídeo de animação e controle.
Investimento em anúncios não cura bugs de câmera, servidor ou loop repetitivo; não usar recurso pago até todos os itens P0 estarem aprovados.

## Formato de relatório por etapa — obrigatório

- Etapa e objetivo
- Branch/commit/arquivos alterados
- O que existia e o que foi reaproveitado
- Evidência concreta: vídeo/screenshot/log/teste
- Regra de dados e integração testada
- Bugs conhecidos + plano de resolução
- Comparativo de FPS/memória quando relevante
- Próximo passo liberado SIM/NÃO e justificativa
- Critérios de segurança/publishing mantidos

## Prompt compacto para colar no Claude

Você é o desenvolvedor implementador de FeedAGiant V3. Leia docs/FEEDAGIANT_V3_00_COMECE_AQUI.md e os arquivos 01 a 05 desta branch ANTES de codificar. Eles são a única autoridade de escopo desta rodada e substituem o prompt mestre antigo. Comece APENAS pela Tarefa 00: inspecionar a instalação real, preservar todos dados e assets, reportar diferenças do GDD e criar backup/branch de trabalho. Não assumir que main representa o place mais novo. Depois execute 01, 02, 03 etc. com vídeo e testes como gates. Não apagar serviço antigo, não modificar main, não fazer merge, não publicar/place/asset e não gastar Robux sem aprovação. Preserve funcionalidade de inventário, ovos, compras e salvamento. Se a modelagem/rigging/artes não atenderem ao nível descrito, não declare sucesso nem avance. O objetivo é um MVP pequeno e com qualidade profissional: gigante montável, pista, ingredientes, duas panelas, seis receitas, Livro e telemetria.