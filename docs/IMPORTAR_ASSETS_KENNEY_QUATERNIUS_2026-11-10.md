# FeedAGiant — o que importar dos dois pacotes que você baixou

**Origem EXATA:** `Overview.html` do Kenney Food Kit (200 modelos, nenhuma animação, CC0) e `lista_de_arquivos_fbx.txt` do Fantasy Props MegaKit [Standard] (94 FBX listados). Ambos foram fornecidos pelo dono em 10/11/2026.

**Atenção:** somente os índices HTML/TXT foram anexados nesta conversa, não os próprios arquivos .zip de meshes. Os FBX reais ainda estão no computador do dono. Este repositório não inclui nem inventa IDs do Creator Hub.

**Código que os usa:** `src/shared/ArtManifest.lua`, `src/server/ArtFactory.lua` e `src/server/PlazaDistrict.lua`.

## Posição e modo de importação

1. No Roblox Studio, faça uma **cópia local do place** e sincronize a branch `codex/feedagiant-assets-gameplay-2026-11-10` via Rojo antes de importar; não substitua a versão oficial.
2. Abra o 3D Importer (**File → Import**) e escolha os arquivos FBX listados abaixo, diretamente de seus ZIPs extraídos. É compatível com FBX, glTF e OBJ. Não publique assets para a **Creator Store**: eles são apenas conteúdo privado do seu jogo.
3. Confirme a conta/criador correta no importador e escolha `Upload to Roblox` apenas quando estiver testando a versão que pretende usar em jogo (o importador oferece esse controle). A experiência publicada precisará ter permissão para usar seus MeshParts e texturas.
4. Para Kenney, mantenha o arquivo compartilhado `Models/FBX format/Textures/colormap.png` acessível durante a importação. Se algum FBX aparecer sem textura, associe `TextureID` à imagem importada antes de salvar o place.
5. Crie o Folder **`ServerStorage.FeedAGiantArt`** e mova os Models/MeshParts importados para dentro dele, renomeados **EXATAMENTE** conforme a coluna `nome no Studio`.
6. Atalho opcional: selecione os modelos recém-importados no Explorer, abra **Command Bar** e execute o conteúdo de `tools/StudioOrganizarAssets.command.luau`. Ele organiza apenas objetos selecionados que coincidem com o Manifest, sem apagar nada e bloqueando modelos com Scripts ou Remotes.
7. Rode `require(game.ServerScriptService.Server.ArtFactory)` somente para verificar que o ModuleScript existe. Em seguida, faça **Play** numa cópia: `PlazaDistrict` detecta os templates automaticamente e esconde as primitivas substituídas. Se um asset não estiver presente, o fallback geométrico continua; **não há require(assetId) em runtime**.
8. Confira escala, rotação, colisão, faces, texturas, custo no celular e Output. Não coloque scripts baixados na Workspace. Faça backup do place com os MeshParts: Rojo sincroniza os scripts, mas o Folder com as malhas importadas depende do place, não do Git.

## Tier 1 — importar primeiro (12 modelos)

Esses modelos mudam diretamente o visual da Cozinha e da Trilha. Priorize-os antes de qualquer outro.

| # | Pacote | FBX exato | Nome no Studio | Utilização |
|---|---|---|---|---|
| 1 | Kenney | `cutting-board.fbx` | `Kenney_cutting-board` | tábua de corte na cozinha |
| 2 | Kenney | `carrot.fbx` | `Kenney_carrot` | ingrediente de corte |
| 3 | Kenney | `pot-stew.fbx` | `Kenney_pot-stew` | panela do preparo |
| 4 | Kenney | `cooking-spoon.fbx` | `Kenney_cooking-spoon` | colher de preparo |
| 5 | Kenney | `burger-cheese-double.fbx` | `Kenney_burger-cheese-double` | prato e apresentação da cozinha |
| 6 | Kenney | `apple.fbx` | `Kenney_apple` | ingrediente na trilha |
| 7 | Kenney | `bread.fbx` | `Kenney_bread` | ingrediente na trilha |
| 8 | Quaternius | `Stall_Empty.fbx` | `Quaternius_Stall_Empty` | barraca de frente para a cozinha |
| 9 | Quaternius | `Workbench.fbx` | `Quaternius_Workbench` | bancada da cozinha |
| 10 | Quaternius | `Barrel.fbx` | `Quaternius_Barrel` | barris da cozinha |
| 11 | Quaternius | `FarmCrate_Apple.fbx` | `Quaternius_FarmCrate_Apple` | primeira pista da trilha |
| 12 | Quaternius | `FarmCrate_Carrot.fbx` | `Quaternius_FarmCrate_Carrot` | segunda pista da trilha |

## Tier 2 — acabamento opcional (7 modelos)

Importar apenas depois de verificar FPS e o enquadramento dos 12 anteriores.

| # | Pacote | FBX exato | Nome no Studio | Utilização |
|---|---|---|---|---|
| 1 | Kenney | `pizza.fbx` | `Kenney_pizza` | prato visual alternativo |
| 2 | Kenney | `cake.fbx` | `Kenney_cake` | foto/lanche de celebração |
| 3 | Kenney | `cooking-knife-chopping.fbx` | `Kenney_cooking-knife-chopping` | bancada de corte |
| 4 | Kenney | `plate-dinner.fbx` | `Kenney_plate-dinner` | serviço de banquete |
| 5 | Quaternius | `Banner_1_Cloth.fbx` | `Quaternius_Banner_1_Cloth` | bandeiras do mirante |
| 6 | Quaternius | `Lantern_Wall.fbx` | `Quaternius_Lantern_Wall` | iluminação visual das estações |
| 7 | Quaternius | `Stall_Cart_Empty.fbx` | `Quaternius_Stall_Cart_Empty` | carrinho de mercado em segundo plano |

## Tier 3 — decoração futura (3 modelos)

**Não são necessários para testar a versão atual.** Servem para futuras variações; o importador pode deixá-los para depois.

| # | Pacote | FBX exato | Nome no Studio | Utilização |
|---|---|---|---|---|
| 1 | Kenney | `bowl-soup.fbx` | `Kenney_bowl-soup` | concha da bancada |
| 2 | Quaternius | `Cauldron.fbx` | `Quaternius_Cauldron` | decoração de caldeirão menor, não substituir Ancestral |
| 3 | Quaternius | `Bench.fbx` | `Quaternius_Bench` | banco do mirante |

## Estrutura esperada no Explorer

```text
ServerStorage
└── FeedAGiantArt
    ├── Kenney_cutting-board
    ├── Kenney_carrot
    ├── Kenney_pot-stew
    ├── Kenney_cooking-spoon
    ├── Kenney_burger-cheese-double
    ├── Kenney_apple
    ├── Kenney_bread
    ├── Quaternius_Stall_Empty
    ├── Quaternius_Workbench
    ├── Quaternius_Barrel
    ├── Quaternius_FarmCrate_Apple
    └── Quaternius_FarmCrate_Carrot
```

O Manifest identifica `22` modelos opcionais. **Apenas 12 são prioritários.** O código utiliza outros modelos do Tier 2 ou 3 apenas se eles existirem.

## Segurança e preservação

- Nunca inserir FBX com Script/LocalScript/ModuleScript/RemoteEvent escondido. O assistente de importação fornecido recusa modelos que contenham esses objetos; `ArtFactory` verifica novamente no servidor e cria **somente geometria visual ancorada**.
- O limite do código é de 32 partes por prop e 26 studs por objeto, com colisão, toque e raycast desativados para decorar sem quebrar os sistemas do jogo.
- Não publicar assets individuais na Creator Store, não comprar modelos, não usar `require(assetId)`, não inserir código externo. O projeto passou por um incidente com `Workspace.MainModule` e a quarentena de assets não é opcional.
- Esta versão não substitui o caldeirão Ancestral, modelos de gigantes nem o mapa oficial. O artefato salvo continua dependendo do QA no Studio e de um backup de place.

Referências técnicas: https://create.roblox.com/docs/studio/importer e https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities
