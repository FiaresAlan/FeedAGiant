# FeedAGiant — Importação de assets 3D (sem publicar o jogo)
Data: 10/11/2026 · Branch: `codex/feedagiant-ilha-viva-2026-11-10`

**O que recebi:** `lista_de_arquivos_fbx.txt` com 94 nomes exatos de FBX do Fantasy Props MegaKit Standard e `Overview.html` com 200 modelos do Kenney Food Kit. Os dois arquivos ZIP estão no computador do usuário, mas **não foram anexados ao chat**; não consigo ler bytes, converter FBX nem enviar malhas à conta. Este documento referencia nomes exatos confirmados nos índices fornecidos.

## Importar primeiro: apenas 7 modelos
Não importar os 294 modelos. O jogo precisa de uma cozinha legível em celular, não de um museu de props.

| Prioridade | ZIP | Arquivo do pacote | Nome EXATO do objeto no Studio | Local no Explorer | Uso |
|---|---|---|---|---|---|
| P0 | Fantasy Props | `Cauldron.fbx` | `Cauldron` | `ServerStorage/FeedAGiantAssets/FantasyProps` | Panelão da Cozinha Colossal |
| P0 | Fantasy Props | `Workbench.fbx` | `Workbench` | mesmo diretório | Bancada do jogador A |
| P0 | Kenney Food Kit | `cutting-board.glb` ou FBX equivalente do pacote | `cutting-board` | `ServerStorage/FeedAGiantAssets/KenneyFood` | Tábua de corte |
| P0 | Kenney Food Kit | `carrot.glb` ou FBX equivalente | `carrot` | mesmo diretório | Ingrediente do corte |
| P1 | Fantasy Props | `Barrel_Apples.fbx` | `Barrel_Apples` | `ServerStorage/FeedAGiantAssets/FantasyProps` | Um barril perto do balcão |
| P1 | Fantasy Props | `Stall_Empty.fbx` | `Stall_Empty` | mesmo diretório | Cobertura visual da feira |
| P1 | Kenney Food Kit | `pot-stew.glb` ou FBX equivalente | `pot-stew` | `ServerStorage/FeedAGiantAssets/KenneyFood` | Sopa decorativa |

**Observação:** `Overview.html` confirma o nome dos modelos Kenney, mas não a extensão do arquivo 3D dentro do ZIP. Se o download oferecer `.obj`, `.fbx` ou `.glb`, use o formato que o Studio aceitar e renomeie o **Model** para o nome exato da coluna.

### Caminho no Studio
1. Faça uma **cópia local do place** antes de importar. Não publique.
2. No Roblox Studio, abra **View > Asset Manager** ou **Avatar > Import 3D** (dependendo da versão do Studio) e importe somente os sete modelos acima. Se o FBX criar várias peças, agrupe-as em um `Model` com o nome indicado.
3. No Explorer, crie `ServerStorage > FeedAGiantAssets > FantasyProps` e `ServerStorage > FeedAGiantAssets > KenneyFood`. Mova os modelos para os respectivos diretórios. **Não deixe os modelos em Workspace**: o código vai clonar os modelos automaticamente para a Cozinha.
4. Inspecione e remova **todo** `Script`, `LocalScript`, `ModuleScript`, `RemoteEvent`, `RemoteFunction`, `BindableEvent`, `BindableFunction`, `ClickDetector` e `ProximityPrompt` dos modelos importados. Não importar plugins/scripts de modelos gratuitos.
5. Rode Play Solo. `PlazaDistrict` chama `AssetDecorator.apply`; se um modelo estiver presente e válido, o decorador clona a geometria, deixa as peças sem colisão e oculta a peça primitiva correspondente. Se faltar, o jogo mantém a geometria original.
6. Confirme visualmente escala, rotação, textura e alinhamento. O importador usa altura-alvo para padronizar escala, mas a orientação do eixo local do FBX/GLB pode exigir correção de `offset` em `src/server/AssetDecorator.lua`.
7. Teste 2 jogadores na cozinha; os prompts estão ligados às **peças lógicas originais**, que são mantidas invisíveis. Se não forem alcançáveis após a troca de mesh, ajustar `offset`/posição antes de merge.
8. Faça comparação de FPS e memória em Android intermediário. Se piorar, remova o template da pasta; o fallback procedural volta automaticamente no próximo Play.

### Extras opcionais — somente após validar os 7 principais
`Stall_Cart_Empty.fbx`, `Crate_Wooden.fbx`, `FarmCrate_Carrot.fbx`, `FarmCrate_Apple.fbx`, `Banner_1_Cloth.fbx`, `Table_Plate.fbx`, `Table_Spoon.fbx`, `Lantern_Wall.fbx`, `Rope_1.fbx`, `Bench.fbx`, `Mug.fbx`, `Carrot.fbx` do Fantasy Props; `apple`, `bread`, `loaf`, `broccoli`, `pumpkin`, `bowl-soup`, `mushroom`, `watermelon` do Kenney. Esses extras **ainda não estão mapeados no decorador**, não serão inseridos automaticamente. Escolher 2–4 só se melhorarem a leitura de gameplay.

### Importante sobre Creator Store
**Não é necessário publicar esses modelos na Creator Store** para o jogo funcionar. Importar no Studio/Asset Manager e manter em `ServerStorage` é suficiente para uso privado no place. Publicar um asset na Creator Store pode expô-lo a terceiros e exige revisão das regras; não faça isso nesta fase. O usuário pode manter a cópia local do pack original como prova de origem e licença CC0.

### Limitações
- Este é um **adaptador de geometria**, não um conversor de ZIP/FBX. Sem os arquivos 3D reais dentro do Studio, não consigo verificar dimensões, orientação e materiais.
- Nenhum arquivo do computador do usuário foi acessado remotamente; o navegador conectado exige contexto originário e não funcionou aqui.
- A integração ainda precisa de teste Luau/Studio, sem afirmar que já passou.
- Não há dependência de asset IDs externos, `InsertService`, publicação ou acesso à conta do usuário.
