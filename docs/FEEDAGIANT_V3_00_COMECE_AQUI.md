# FEED A GIANT — V3 / LEIA PRIMEIRO

**Data:** 11/11/2026
**Autoridade:** este conjunto de documentos substitui, PARA ESTA RODADA, o Documento Mestre V1 (10/11) e o Prompt Claude V2 (11/11). Não concatene prompts. Preserve backups, dados e código funcional.
**Estado:** especificação de desenvolvimento, NÃO prova de que os sistemas já estejam implementados.
**Escopo:** vertical slice de alto acabamento, não lançamento automático.

## Mensagem curta para Claude

Leia integralmente estes arquivos, nesta ordem:

1. docs/FEEDAGIANT_V3_01_GDD_MVP.md — produto, mapa, loop, criatura, receitas, economia, fases.
2. docs/FEEDAGIANT_V3_02_ART_ASSETS.md — direção de arte, rig, animações, assets com URLs e licenças.
3. docs/FEEDAGIANT_V3_03_TECNICA_DADOS.md — arquitetura, rede, algoritmos, salvamento e antiexploit.
4. docs/FEEDAGIANT_V3_04_QA_ANALYTICS_ADS.md — testes, eventos, critérios de lançamento e experimento pago.
5. docs/FEEDAGIANT_V3_05_EXECUCAO_CLAUDE.md — etapas de implementação, prompts curtos, gates e entregas.

### Fonte do projeto

Repositório: https://github.com/FiaresAlan/FeedAGiant
O branch base main consultado em 11/11/2026 continha o commit 374c95436109d1023a43b4914dd8c11ac86ad6e3. Existe PR #3 draft e versões ZIP de Ilha Viva/Ilha de Encaixe; o projeto REAL LOCAL do proprietário pode ser posterior. **O Claude deve identificar o código e place locais atuais, os arquivos não commitados, IDs e progresso de edição ANTES de fazer qualquer alteração.** Jamais presumir que main reflete o jogo mais novo.

### Regra para poupar tempo e créditos de IA

- Inspecione antes de implementar. Gere um inventário de módulos existentes e pontos de integração. Não reescreva DataStore, inventário, ovos, receita, arena, HUD ou serviços de compra sem necessidade técnica real.
- Execute somente uma etapa por vez e produza uma evidência verificável antes de iniciar a seguinte.
- Se um asset não tem procedência/licença confirmada, NÃO o publique nem alegue que é livre. Use protótipo CC0/autor próprio até verificar.
- Não mude main, não faça merge, não publique jogo/assets, não configure anúncio, não gaste Robux e não altere a experiência oficial sem autorização.
- Se a função antiga não combinar com V3, desligue no HUD/entrada por flag, sem apagar serviços ou dados.
- Nunca diga "testado" se só houve leitura de código, validação de sintaxe ou testes locais sem Studio.
- Bugs de persistência, duplicação de comida, montaria, câmeras, colisões e experiência mobile são bloqueadores de entrega.

### Decisão de produto definitiva desta rodada

**Fantasia:** Você monta um gigante elemental, corre a uma pista disputada por outras criaturas, conquista comida/ingredientes/pergaminhos, retorna à base, descobre e cozinha receitas em duas panelas e alimenta seu gigante para evoluí-lo. O gigante é seu veículo/companheiro e sua progressão tem efeito perceptível na próxima corrida.

**Não objetivos P0:** PvP de boxe, duas modalidades de arena, academia, expedição na Boca do Colosso, reprodução/fusão, nova moeda, cidade nova, cozinha central obrigatória, PvP em bases, perdas offline, 20 receitas, 20 espécies, vantagens pagas, compra automática.

**Gate de validação:** uma pessoa desconhecida deve conseguir montar, pegar comida, entregar, cozinhar uma receita e alimentar pelo menos duas vezes sem explicações externas, com feedback audiovisual de alta qualidade e sem falhas graves.

## Entregas do Claude esperadas

- Branch exclusiva e backup do place+dados de testes; histórico de commits pequenos.
- MVP integrado real no Studio; design de mapa e rigs/animados, não só scripts.
- Screenshots e vídeo curtos das três câmeras (base, montaria e entrega); demonstrar animações.
- Testes unitários, integração servidor-cliente, 2 clientes, Android físico ou simulação de dispositivos explicitamente identificada.
- Relatório com arquivos alterados, IDs novos, assets e licenças, bugs restantes, rollback, métricas instrumentadas e plano de publish manual.
- Ao fim, o usuário decide se publica e se investe em ads.

## Fontes técnicas e pesquisa

- Roblox Discovery: https://create.roblox.com/docs/discovery
- Discovery FAQ: https://create.roblox.com/docs/discovery-faq
- Roblox Onboarding: https://create.roblox.com/docs/production/game-design/onboarding
- Roblox Importer: https://create.roblox.com/docs/studio/importer
- Adaptive Animation: https://create.roblox.com/docs/characters/adaptive-animation
- Analytics Custom Events: https://create.roblox.com/docs/production/analytics/custom-events
- Ads Manager: https://create.roblox.com/docs/production/promotion/ads-manager

**Aviso de evidência:** os tempos, velocidades, chances, balanceamento e metas descritos nos arquivos V3 são HIPÓTESES para playtest, não métricas observadas no FeedAGiant nem garantias de sucesso.