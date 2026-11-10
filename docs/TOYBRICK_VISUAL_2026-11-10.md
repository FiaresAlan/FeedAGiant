# FeedAGiant — Tema ToyBrick / studs clássicos
**Data:** 10/11/2026
**Base:** PR #3 `codex/feedagiant-ilha-viva-2026-11-10` @ `8b91e8928c97734a77a4323d68047d9c6aeaffa7`.
**Backup pré-trabalho:** `backup/2026-11-10-antes-toybrick`.
**Branch:** `codex/feedagiant-toybrick-2026-11-10`.
**Estado:** implementado em Luau, **não validado visualmente no Roblox Studio** nesta conversa.

## Direção da imagem de referência
- Roblox clássico / brinquedo estilizado: **studs quadrados reais** em baseplates modulares.
- Materiais limpos, com leve reflexo; cores claras e vivas; bordas azuladas e acabamento pastel.
- Céu azul, luz diurna legível, névoa baixa e sombras diretas.
- Superfícies artificiais com a mesma linguagem; grama, montanhas, árvores, lagos, comida e criaturas continuam visualmente reconhecíveis, sem estampas absurdas sobre meshes orgânicas.
- Não reproduzir HUD, textos, roleta, produtos, IP ou layout do jogo mostrado. A referência é **material/estilo**, não conteúdo de terceiro.

## Alterações técnicas

### Superfícies/objetos convertidos automaticamente
1. **Todas as oito bases:** piso grande da base com studs, cor pastel derivada da cor original; slots e pedestal do gigante recebem studs sem perder a cor de identificação.
2. **Caminhos:** os oito caminhos e suas bordas ganham Plastic com studs, piso claro e bordas azuladas.
3. **Praça central:** malha quadriculada modular de 12 studs, topo em y≈2,2, sem colisão e sem raycast; o cauldron não é ocultado. Mantém as faixas de orientação existentes.
4. **Chão da ilha:** placas verdes de 56 studs com studs clássicos e leve alternância de tons, preservando áreas próximas aos três lagos, costa, rochas e montanhas. Terreno físico original permanece responsável por movimento/caminhada.
5. **Arena e Ilha do Dragão:** placas de 6 ou 8 studs no piso externo, centro do combate e coroa preservados; ponte existente recebe studs sem alterar a rampa/corrimão.
6. **Ilha Viva:** cozinha, mirante e totens da trilha recebem pisos de studs com a mesma paleta; bancada, mesas e assentos passam para a família visual ToyBrick.

**Orçamento geométrico calculado a partir dos loops do código:** aproximadamente **160 placas de prado, 232 de praça, 28 de arena, 44 da Ilha do Dragão e 43 do distrito = 507 partes visuais**. Não foram criados milhares de studs individualmente. O motor desenha o padrão no `Part.TopSurface` de material `Plastic`. O número final de partes pode mudar com mapas assados ou revisões futuras; confirmar no Studio.

### Iluminação
Nova receita `ToyboxDaylight` em `src/shared/LightingRecipes.lua`: 13h42 (ClockTime 13.7), atmosfera azulada, menos Haze/Density, bloom reduzido e sombra global. O céu dourado anterior é substituído pela receita sem herdar suas texturas.

### Reversão
- Nova flag: `Features.ToyBrickVisual = true`.
- Para testar o tema anterior: alterar para `false` **antes de iniciar um novo Play**; em Studio é possível também definir no ReplicatedStorage o atributo `Feature_ToyBrickVisual=false` antes do Play.
- `ToyBrickTheme.apply(workspace.Map)` reaplica, removendo qualquer overlay anterior.
- `ToyBrickTheme.remove(workspace.Map)` remove as placas e restaura material, `MaterialVariant`, cor, stud surface, reflexo e propriedades físicas dos `Part` convertidos. Para zerar tudo, restaurar a branch backup.
- Se o Studio tiver salvo um mapa assado que já contém o overlay, chamar `remove` em uma cópia do place antes de re-assar. Nunca sobrescrever place oficial sem QA.

**Atenção a colisões:** overlays têm `Anchored=true`, `CanCollide=false`, `CanTouch=false`, `CanQuery=false`, `CastShadow=false`. Pisos existentes mantêm `CanCollide`. Como `Material=Plastic` pode mudar atrito e densidade, o tema salva se os pisos tinham `CustomPhysicalProperties` e preserva os valores físicos do material anterior durante a conversão. O rollback devolve o comportamento anterior.

## Limitações reais da engine
- `Enum.SurfaceType.Studs` só produz esse visual nas superfícies de **Parts regulares com material Plastic**, não em Terrain ou MeshParts da mesma forma. Para MeshParts, seria preciso criar um MaterialVariant/SurfaceAppearance com imagens PBR/normal map, que exigem upload e teste do asset.
- As placas verdes são overlays visuais sobre Terrain, não uma retexturização destrutiva de voxels. Ondulações e pontos com rocha podem emergir acima delas.
- Padrão nativo é semelhante, mas não garante **identidade pixel a pixel** com a imagem enviada (a textura do jogo da referência pode ter detalhes próprios).
- Não altera jogo publicado, testes de monetização, HUD nem progressão.

## QA prioritário antes de mesclar/publicar
1. Rojo build, Selene, StyLua, Luau parser e suíte incluindo `tests/ToyBrickTheme.spec.luau`.
2. Play em **cópia do place** e screenshot em 3 ângulos: vista aérea, câmera do jogador na praça e base de gigante. Comparar com imagem de referência e com tema anterior.
3. Confirmar studs visíveis no `Plastic` em Play, sobretudo chão da ilha, praça e bases.
4. Se o mapa já estiver assado, confirmar overlay aparece **uma única vez**, sem recursão.
5. Testar rolar, pular, carregar comida, mira e arena; piso e projeções não podem impedir prompts, raycasts ou teletransportes.
6. Testar **Android intermediário** e GPU/Memória com 8 bases e várias criaturas visíveis; comparar FPS com tema desligado. Reduzir o overlay de prado se houver queda.
7. Comparar galeria de fotos e iluminação de ovos/lunchboxes; efeitos devem permanecer legíveis com a luz mais clara.
8. Inspecionar pontos de água: nenhuma placa de prado deve cobrir lago, inclusive bordas.
9. Voltar a `ToyBrickVisual=false` e verificar rollback visual e da física.
10. Só considerar merge após testes anteriores de DataStore, recibos, multiplayer e segurança do place oficial. Este PR não elimina bloqueadores do PR #1/2/3.

## Referências técnicas oficiais
- SurfaceType.Studs: https://create.roblox.com/docs/reference/engine/enums/SurfaceType
- BasePart.TopSurface: https://create.roblox.com/docs/reference/engine/classes/BasePart
- MaterialVariant para customização futura: https://create.roblox.com/docs/parts/materials
- Física por Material: https://create.roblox.com/docs/reference/engine/datatypes/PhysicalProperties

**Não foi necessário baixar, comprar ou publicar nenhum modelo/textura para esta versão.**
