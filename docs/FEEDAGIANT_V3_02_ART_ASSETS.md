# FEED A GIANT V3 — DIREÇÃO DE ARTE, RIGGING, ASSETS E IMPORTAÇÃO
11/11/2026 | Plano de produção, não declaração de que downloads/imports já estejam concluídos

## 1. Norte artístico inegociável

Estética: brinquedo premium de montar / universo Roblox estilizado, com formas grandes, superfícies limpas, cores acessíveis, studs em superfícies artificiais e material de plástico pintado; **não copiar uma marca LEGO nem usar logotipo de terceiros**.
As criaturas devem parecer objetos de brinquedo **vivos e articulados**, não malhas infladas ou bonecos estáticos. A escala deve ser legível: avatar humano pequeno montado numa criatura ~3 vezes maior.
Evitar misturar low-poly cru sem texturas, fantasias medieval-realistas e render PBR fotográfico com studs de plástico. Kits de estilos diferentes exigem harmonização: paleta, roughness, escala, luz, tamanho de borda, quantidade de detalhes e sombra.

### Paleta de partida (hipótese de arte; aplicar e conferir no Studio)

- Piso da praça e pista: cinza azulado claro / marfim, detalhes de blocos azul petróleo.
- Barreiras e risco: amarelo âmbar/coral em pequenas áreas, sem excesso visual.
- Pedra: cinza basalto, bordas de rocha pintada, núcleo verde-água ou âmbar.
- Fogo: laranja queimado/vermelho com pontos de luz pequenos, sem partículas permanentes dominantes.
- Gelo: turquesa/azul gelo, cristais bem reconhecíveis e partículas esparsas.
- Cozinha: panelas em metal estilizado escuro, handles com madeira/plástico; comida colorida e legível.
- UI: fundo cinza translúcido mínimo, ícones grandes, texto com contraste; nenhuma janela escurece a experiência inteira.
- Vegetação: cores e formas estilizadas sem studs exagerados; água continua com material natural de fantasia.

### Diretriz de material

Studs apenas em pisos construídos, rampas, caminhos, bordas e plataformas. Alimentos, água, chamas, cristais e olhos não devem herdar textura de studs automaticamente. Usar SurfaceAppearance/SurfaceGui ou modelos próprios SOMENTE se atenderem custo mobile; baseplate com repetição de textura que não fique esticada e mantenha boa leitura de colisão.

## 2. Layout e acabamento por zona

### Base de cada jogador

Substituir a sensação de quadrado vazio por uma ilha/plataforma de exposição visualmente rica, **sem remover o identificador do plot**. Silhueta aproximada: área circular/poligonal e três níveis visuais, com centro ocupado pela criatura, duas panelas lateralmente acessíveis e um pedestal para ovo/coleção na borda.
O centro do gigante é elevado o suficiente para ser visto da praça, mas não bloqueia a visão da pista. As panelas são próximas o bastante para uso rápido, mas não atravessam pernas/câmera do gigante.
Decoração: luz por cores do gigante, bandeira do dono, detalhes modulares, recipientes, prateleiras e pequenas estátuas; evitar árvores de alta densidade bloqueando câmera.
Interações: **Montar**, **Alimentar**, **Panela A**, **Panela B**, **Livro de Receitas**, **Trocar Gigante** quando liberado. O UI contextual não exibe tudo ao mesmo tempo.

### Pista central

Material geométrico de encaixe com faixas planas e contorno modular. Largura real dimensionada para pelo menos duas criaturas passarem lado a lado sem colisão entre hitboxes; curvas evitadas para primeira versão.
Três camadas de arte: solo/guia funcional; laterais com pilastras/caixas/placas; fundo com montanhas estilizadas e silhueta da ilha. A competição deve continuar legível de longe: alimentos > silhueta dos gigantes > sinais da pista > decoração.
Áreas de risco sinalizadas por cores/símbolos, sem texto excessivo e sem “poder vermelho” que parece pagamento. Três pontos marcantes para foto: entrada, central de carga, zona de depósito.

### Cozinha de duas panelas

Duas panelas com diâmetro aproximado de 5–8 studs, adaptado à mão/câmera do avatar, montadas sobre bancadas estáveis. Cada uma possui fogo visível sob a panela, líquido superficial com pequenas bolhas e label de estado bem legível.
O som de preparo é ambiente e espacial; som “PRONTO” é curto e reconhecível. Comida pronta pode aparecer em bandeja sem simular fluidos ou centenas de ingredientes soltos.
Os efeitos variam com tipo de preparo, não geram sobreposição constante de partículas.
Se Cauldron antigo da praça existir, usá-lo como monumento visual ou mover para evento futuro; **não transformar a cozinha central social de 2 jogadores no único caminho para o usuário cozinhar sozinho**.

## 3. Gigantes — requisitos visuais e esqueleto

### Regra principal

Cada criatura bípede controlável deve possuir hierarquia de articulações real, importada ou construída; pelo menos cabeça/pescoço, ombros, cotovelos, quadris, joelhos, pés, mandíbula ou solução equivalente e pontos de Attachment para carga/assento. O movimento não pode depender de escalar repetidamente a malha inteira.
Pode usar R15 compatível com animação adaptativa ou rig customizado sob Humanoid/Animator. Não presumir que um mesh único vira R15 por script. Se o GLB existente não tem estrutura anatômica, refazer com partes rígidas subdivididas/armature Blender. O alvo não é realismo anatômico, é **silhueta, timing, peso, mãos e expressividade**.

### Golem de Pedra — prioridade hero

Silhueta: torso trapezoidal largo, cabeça posicionada acima de peitoral, dois braços longos mas com articulações visíveis, punhos maiores, pés largos e estáveis. Evitar cilindro humano pintado de cinza. Rachaduras/cristais e chapas como peças fixas, materiais com contraste de borda.
Ponto de montaria entre ombros e alto das costas, avatar de escala normal com “alça” ou apoio visual simples; os braços do gigante não atravessam avatar.
Animações obrigatórias:
1. Idle (respiração por peito/cabeça/peso, 3–5 s; sem inflar todo mesh).
2. Walk (passadas alternadas, joelho e quadril, braços contrabalançando, loop).
3. Run (passada mais forte, aceleração e desaceleração, loop; evitar slide).
4. Turn left/right (rotação suave sem gimbal).
5. CarryLight (item nas mãos, tronco ajustado).
6. CarryHeavy (ombros/joelhos demonstram esforço, marcha lenta).
7. FeedAnticipation + Grab + Chew + Swallow + Celebrate (uma cadeia cronometrada; mandíbula funcional).
8. Intercept/HitReact (curto, inofensivo, controlado).
9. Mount/Unmount handoff sem animação de teleportação brusca.
Oito a nove clipes-base com subdivisões permitidas; dividir clips por eventos quando necessário. Não declarar como “feito” se apenas movimenta o RootPart sem gait.

### Fogo e Gelo

Somente após Golem atender todos os gates: usar mesmo esqueleto locomotor se corpos forem bípedes compatíveis. Personalizar silhueta (Fogo mais atlético com cauda/chifres; Gelo mais robusto com cristais/proporções próprias), materiais e poder. Não prometer que os GLBs de dragão existentes podem ser re-rigados automaticamente; decidir após inspecionar topologia e licença.
No MVP, todos três precisam ter locomotion e alimentação decentes para serem oferecidos na seleção. Se não for possível, não mostrar opção inacabada como jogável na versão publicada.

### Três estágios e tamanho

Base: Bebê, Jovem, Colosso com alterações significativas de silhueta e postura; escala limitada à base. Pista: modelo montável padronizado para evitar câmera e colisão injustas; jovens/colossos podem mudar acabamento cosmético, não envelopamento de colisão.
Não sacrificar fluidez de corrida para simular peso. Um gigante grande deve parecer pesado pelo movimento de pernas e som de passada, não por WalkSpeed extremamente baixo.

### Qualidade de rig/clip — gates

Sem peças atravessando tronco/assento; pés não flutuam nem deslizam visivelmente quando corrida normal; braço alcança a comida; item segue mão em vez de “teleportar” para boca; mastigação não atravessa a cabeça; ao desmontar a câmera volta ao avatar correto. Validar animação vista da base, atrás do ombro e por outro jogador a 30 studs. Registrar vídeo no Studio antes de avançar.

## 4. Pesquisa de assets verificáveis — licenças e aplicações reais

### A. Fontes prioritárias CC0 para jogo comercial

**Kenney Food Kit:** https://kenney.nl/assets/food-kit
O site lista 200 arquivos de comida 3D e licença CC0. Uso: maçãs, pão, queijo, carne, ingredientes, pratos, utensílios e composições de receitas. IMPORTANTE: confirmar os nomes EXATOS dentro do ZIP baixado; o catálogo contém muitos objetos, mas não presumir que todo alimento sugerido (pimenta, mel e fruta colossal) exista com o mesmo nome. Para itens ausentes, criar composição original estilizada a partir de peças simples. Kenney permite uso comercial e não exige crédito: https://kenney.nl/support

**Kenney Brick Kit (3D):** https://kenney.nl/assets/brick-kit
290 peças e CC0. Uso: estruturas da pista, bases, rampas, bancadas, bordas e cenário de brinquedo. Não aplicar studs como textura indiscriminadamente em todas as superfícies.

**Kenney Nature Kit (3D):** https://kenney.nl/assets/nature-kit
330 modelos e CC0. Uso: árvores, pedras, folhagens nas bordas, sem atrapalhar a pista.

**Kenney Furniture Kit (3D):** https://kenney.nl/assets/furniture-kit
140 modelos CC0. Uso opcional: prateleiras e detalhes das bases; não transformar a base em casa realista.

**Kenney Platformer Kit (3D):** https://kenney.nl/assets/platformer-kit
150 modelos CC0; módulos/plataformas e alguns personagens animados úteis para referência de articulação, não substitutos automáticos de um gigante.

**Kenney UI Pack:** https://kenney.nl/assets/ui-pack
430 itens CC0. Uso: botões, barras e painéis do Livro; adaptar à paleta V3, não usar UI chamativa que oculte jogabilidade.

**Kenney Input Prompts:** https://kenney.nl/assets/input-prompts
Ícones de controles teclado, toque e gamepad CC0; usar para onboarding contextual.

**Kenney Impact Sounds:** https://kenney.nl/assets/impact-sounds
130 efeitos CC0. Uso: pisada, queda de comida, impacto leve de interrupção; escolher sons específicos após ouvir cada sample.

**Kenney RPG Audio:** https://kenney.nl/assets/rpg-audio
50 arquivos CC0, passos e foley; uso para esforço/movimento, não exagerar o volume.

**Kenney Interface Sounds:** https://kenney.nl/assets/interface-sounds
100 arquivos CC0. Uso: livro descoberto, confirmação de entrega, coleta.

**Kenney Music Jingles:** https://kenney.nl/assets/music-jingles
85 clips CC0. Uso: vitória curta e receita pronta; NÃO tocar música de vitória a cada comida comum.

O catálogo é de páginas OFICIAIS que identificam os kits, não de IDs já importados para Creator Store. Não inventar links diretos para MeshIds ou rbxassetid.

### B. Fontes complementares com atenção à licença atual

**Quaternius Fantasy Props MegaKit:** https://quaternius.com/packs/fantasypropsmegakit
Inclui móveis, bancadas, comida, caldeirões e barris. Em conversas anteriores o usuário baixou o arquivo e importou Cauldron, Workbench, Stall_Empty e Barrel_Apples. Reutilizar os assets se estiverem de fato disponíveis no place e a procedência tiver sido registrada.

**Quaternius Cute Animated Monsters:** https://quaternius.com/packs/cutemonsters
Página descreve 21 monstros animados, vários formatos. Serve como pesquisa de rigs, animações ou alternativa para protótipo, NÃO prova de que há um Golem ideal ou de compatibilidade R15 sem retrabalho.

**Quaternius Ultimate Monsters:** https://quaternius.com/packs/ultimatemonsters.html
Página descreve 50 monstros animados; fonte alternativa para inspeção, não autorização para republicar raw pack.

**Aviso importante de licenciamento 2026:** páginas de alguns packs ainda exibem CC0, mas a página atual de licença do autor define Quaternius Asset License (QAL), com uso comercial permitido e restrição de revenda/redistribuição de assets como itens independentes: https://quaternius.com/license.html . Verificar o arquivo LICENSE do download concreto e registrar data/origem/versão ANTES de importar e publicar. Não embutir arquivos Quaternius brutos em ZIP de distribuição de assets do projeto sem confirmar direito. Se houver dúvida, optar por Kenney CC0 ou criação própria. Nenhum asset deve ser enviado ao Creator Store público só para uso privado no jogo.

### C. O que já existe no FeedAGiant

O proprietário possui referências de Golem de Pedra, Dragão Vermelho, Dragão de Cristal e Dragão Bebê nos ZIPs anteriores. Análises anteriores apontaram malhas sem rig apropriado. **A procedência e a licença comerciais desses GLBs não foram confirmadas.** São referências/candidatos, não assets liberados para uso comercial. Claude deve localizar os arquivos reais, verificar licença, topologia e rig; se não houver prova, substituir por modelo licenciado ou construção própria antes de anúncio.
Também já existe Kenney Food Kit e Fantasy Props baixados na máquina do proprietário; não repetir downloads se estiverem íntegros.

## 5. Matriz de importação e substituição

| Objeto na experiência | Prioridade | Fonte | Integração exigida |
|---|---|---|---|
| Golem articulado montável | P0 | original rig próprio; Quaternius apenas se licença e visual compatíveis | Humanoid, Animator, attachments, 9 ações validadas |
| Dragão Fogo/Gelo | P1 | GLBs existentes com licença validada ou originais | mesma interface de rig, silhueta própria |
| Base e barreira toy bricks | P0 | Brick Kit/Studio Parts | pivôs, colisão simplificada e studs coerentes |
| Pista e faixas | P0 | Brick Kit + Roblox Parts | navegação/câmera, sem blocos soltos |
| Vegetação de fundo | P1 | Nature Kit | colisões só quando necessárias |
| Maçã, pão, queijo, carne | P0 | Food Kit | nome exato depois de inspecionar ZIP, scale e thumbnail |
| Mel, pimenta, fruta gigante | P1 | Food Kit SE existir, senão composição própria | não inventar asset do pack |
| Duas panelas | P0 | Fantasy Props com licença ou Parts próprios | panela, líquido, chama, feedback ready |
| Livro e HUD | P0 | UI Pack + Input Prompts | responsive, sem overlay |
| Passos, coleta, receita, entrega | P0 | Kenney Impact/RPG/Interface/Music | mixagem e distância 3D |

### Estrutura de pasta sugerida no Studio

ServerStorage/FeedAGiantAssets/Creatures/{Stone,Fire,Ice}
ServerStorage/FeedAGiantAssets/Foods/{Apple,Bread,Cheese,Meat,Potato,Honey,PepperRare,ColossalFruit}
ServerStorage/FeedAGiantAssets/World/{BrickModules,Plants,CookingProps}
ReplicatedStorage/Shared/{AssetManifest,Config,RecipeCatalog,ElementBalance}
SoundService/FeedAGiantAudio
Workspace/World/{Bases,BanquetRun,CentralPlaza}

Essa estrutura é uma proposta. NÃO rearranjar o projeto existente cegamente; usar paths reais se o layout atual for equivalente.

## 6. Padrão de otimização mobile

- Colisões simples (primitivas invisíveis) separadas de mesh visual decorativo; pequenos enfeites CanCollide false; nada de 50 MeshParts físicos para uma comida carregada.
- Modelos de ingredientes carregados preferem renderização cliente autoritativa em cima de attachment, estado sincronizado pelo servidor.
- Materiais repetidos e poucos atlas; LOD/SLIM e streaming onde fizerem sentido, testando regressão dos scripts que dependem de Workspace.
- Partículas ativas somente ao alimentar, finalizar receita ou ativar boost; cap de emissão adaptativo por distância/qualidade.
- Em 8 jogadores, animais distantes devem reduzir atualização visual; o servidor não precisa atualizar animação procedural de cada osso toda frame.
- Som com atenuação local e mixagem; não usar 8 panelas emitindo cliques altos ao mesmo tempo.
- UI deve se adequar à tela pequena e safe areas; câmera com clipping e bloqueios resolvidos. 
Referência oficial: https://create.roblox.com/docs/performance-optimization/improve

## 7. Checklist de aprovação visual obrigatório

1. Um screenshot de close-up de cada gigante no estágio montável; silhuetas distinguíveis sem legenda.
2. Vídeo de 15 s com corrida, curva, sprint, boost e portador de carga pesada.
3. Vídeo de 15 s com comida pegada, mão, mandíbula, mastigar, engolir e celebrar.
4. Dois screenshots de base: vazio/sem jogador e com gigante+panelas+livro.
5. Um panorama da pista com marcação legível e sem poluição visual; um screenshot ao nível do jogador.
6. Medição de FPS e memória em PC e Android/simulador, registrando exatamente dispositivo e método.
7. Verificação de permissão de uso comercial e origem de todos os assets externos, listados por arquivo e licença.
8. Nenhuma malha “inflável”, textura esticada, animação que atravessa pernas, corpo que escorrega, decal sem licença ou efeito que esconde interação.
9. A iluminação deve ficar boa tanto na praça quanto na base e pista; não escurecer visão da jogabilidade para aumentar dramaticidade.
10. Não publicar o asset como item público no Creator Store sem pedido explícito.