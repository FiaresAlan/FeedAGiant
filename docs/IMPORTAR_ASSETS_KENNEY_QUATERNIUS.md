# FeedAGiant — Importação de assets 3D (sem publicar o jogo)
Data: 10/11/2026 · Branch: `codex/feedagiant-ilha-viva-2026-11-10`

Os sete arquivos abaixo foram conferidos nos ZIPs originais de Kenney e Quaternius. As duas licenças incluídas nos pacotes são CC0.

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

Os FBX Fantasy Props estão em `Exports/FBX` e referenciam mapas em `Textures`. Os GLB Kenney estão em `Models/GLB format`. Mantenha `Textures/colormap.png` junto deles nessa estrutura relativa para conservar as cores.

### Caminho no Studio
1. Faça uma **cópia local do place** antes de importar. Não publique.
2. No Roblox Studio, use **Arquivo > Importar** (Ctrl+M). A prévia permite conferir escala, textura e a opção **Fazer o upload para a Roblox**. Mesmo desmarcada, a versão testada do Studio criou IDs Roblox para malhas e para a textura Kenney. Para uma sessão que precise ser totalmente offline, pare na prévia e use o fallback procedural. Se o FBX criar várias peças, agrupe-as em um `Model` com o nome indicado.
3. No Explorer, crie `ServerStorage > FeedAGiantAssets > FantasyProps` e `ServerStorage > FeedAGiantAssets > KenneyFood`. Mova os modelos para os respectivos diretórios. **Não deixe os modelos em Workspace**: o código vai clonar os modelos automaticamente para a Cozinha.
4. Inspecione e remova **todo** `Script`, `LocalScript`, `ModuleScript`, `RemoteEvent`, `RemoteFunction`, `BindableEvent`, `BindableFunction`, `ClickDetector` e `ProximityPrompt` dos modelos importados. Não importar plugins/scripts de modelos gratuitos.
5. Rode Play Solo. `PlazaDistrict` chama `AssetDecorator.apply`; se um modelo estiver presente e válido, o decorador clona a geometria e deixa as peças sem colisão. As peças substituídas ficam invisíveis, preservando os prompts. A sopa Kenney fica sobre a bandeja. Se faltar um modelo, o jogo mantém a geometria original.
6. Confirme visualmente escala, rotação, textura e alinhamento. O decorador usa a base da caixa da malha e a altura prevista para cada peça. A posição e a rotação de teste ficam em `src/server/AssetDecorator.lua`.
7. Teste 2 jogadores na cozinha; os prompts estão ligados às **peças lógicas originais**, que são mantidas invisíveis. Se não forem alcançáveis após a troca de mesh, ajustar `offset`/posição antes de merge.
8. Faça comparação de FPS e memória em Android intermediário. Se piorar, remova o template da pasta; o fallback procedural volta automaticamente no próximo Play.

### Extras opcionais — somente após validar os 7 principais
`Stall_Cart_Empty.fbx`, `Crate_Wooden.fbx`, `FarmCrate_Carrot.fbx`, `FarmCrate_Apple.fbx`, `Banner_1_Cloth.fbx`, `Table_Plate.fbx`, `Table_Spoon.fbx`, `Lantern_Wall.fbx`, `Rope_1.fbx`, `Bench.fbx`, `Mug.fbx`, `Carrot.fbx` do Fantasy Props; `apple`, `bread`, `loaf`, `broccoli`, `pumpkin`, `bowl-soup`, `mushroom`, `watermelon` do Kenney. Esses extras **ainda não estão mapeados no decorador**, não serão inseridos automaticamente. Escolher 2–4 só se melhorarem a leitura de gameplay.

### Importante sobre Creator Store
**Não é necessário publicar esses modelos na Creator Store** para o jogo funcionar. Importar no Studio/Asset Manager e manter em `ServerStorage` é suficiente para uso privado no place. Publicar um asset na Creator Store pode expô-lo a terceiros e exige revisão das regras; não faça isso nesta fase. O usuário pode manter a cópia local do pack original como prova de origem e licença CC0.

### Portabilidade
- Os templates importados podem guardar IDs de malhas e texturas com acesso vinculado à conta Roblox. A build Rojo do repositório usa o fallback procedural quando não há templates.
- Confira a [documentação do importador](https://create.roblox.com/docs/studio/importer) e o [registro desta rodada de QA](qa/ILHA_VIVA_2026-11-10.md) antes de repetir a importação.
