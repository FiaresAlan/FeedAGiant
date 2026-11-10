--!strict
-- ArtManifest — modelos CONFIRMADOS nas listas enviadas pelo dono em 10/11/2026.
-- O código NÃO conhece IDs de asset da Roblox até a importação ser realizada.
-- Convenção: ServerStorage.FeedAGiantArt.<template> = Model ou MeshPart importado.
-- Todos os nomes de arquivos abaixo constam literalmente em Overview.html (Kenney)
-- ou lista_de_arquivos_fbx.txt (Quaternius). Nenhum asset remoto é carregado em runtime.
local Manifest = {}

Manifest.FolderName = "FeedAGiantArt"

export type Entry = {
	key: string,
	pack: string,
	file: string,
	template: string,
	purpose: string,
	tier: number, -- 1 essencial, 2 acabamento, 3 futuro; importar nessa ordem
}

Manifest.Items = {
	-- Food Kit, Kenney, 200 modelos CC0: importar do diretório FBX do zip.
	{ key = "board", pack = "Kenney Food Kit", file = "cutting-board.fbx", template = "Kenney_cutting-board", purpose = "tábua de corte na cozinha", tier = 1 },
	{ key = "carrot", pack = "Kenney Food Kit", file = "carrot.fbx", template = "Kenney_carrot", purpose = "ingrediente de corte", tier = 1 },
	{ key = "pot", pack = "Kenney Food Kit", file = "pot-stew.fbx", template = "Kenney_pot-stew", purpose = "panela do preparo", tier = 1 },
	{ key = "spoon", pack = "Kenney Food Kit", file = "cooking-spoon.fbx", template = "Kenney_cooking-spoon", purpose = "colher de preparo", tier = 1 },
	{ key = "burger", pack = "Kenney Food Kit", file = "burger-cheese-double.fbx", template = "Kenney_burger-cheese-double", purpose = "prato e apresentação da cozinha", tier = 1 },
	{ key = "apple", pack = "Kenney Food Kit", file = "apple.fbx", template = "Kenney_apple", purpose = "ingrediente na trilha", tier = 1 },
	{ key = "bread", pack = "Kenney Food Kit", file = "bread.fbx", template = "Kenney_bread", purpose = "ingrediente na trilha", tier = 1 },
	{ key = "pizza", pack = "Kenney Food Kit", file = "pizza.fbx", template = "Kenney_pizza", purpose = "prato visual alternativo", tier = 2 },
	{ key = "cake", pack = "Kenney Food Kit", file = "cake.fbx", template = "Kenney_cake", purpose = "foto/lanche de celebração", tier = 2 },
	{ key = "knife", pack = "Kenney Food Kit", file = "cooking-knife-chopping.fbx", template = "Kenney_cooking-knife-chopping", purpose = "bancada de corte", tier = 2 },
	{ key = "plate", pack = "Kenney Food Kit", file = "plate-dinner.fbx", template = "Kenney_plate-dinner", purpose = "serviço de banquete", tier = 2 },
	{ key = "bowl", pack = "Kenney Food Kit", file = "bowl-soup.fbx", template = "Kenney_bowl-soup", purpose = "concha da bancada", tier = 3 },

	-- Fantasy Props MegaKit [Standard], Quaternius, 94 FBX na lista enviada.
	{ key = "marketStall", pack = "Quaternius Fantasy Props", file = "Stall_Empty.fbx", template = "Quaternius_Stall_Empty", purpose = "barraca de frente para a cozinha", tier = 1 },
	{ key = "workbench", pack = "Quaternius Fantasy Props", file = "Workbench.fbx", template = "Quaternius_Workbench", purpose = "bancada da cozinha", tier = 1 },
	{ key = "barrel", pack = "Quaternius Fantasy Props", file = "Barrel.fbx", template = "Quaternius_Barrel", purpose = "barris da cozinha", tier = 1 },
	{ key = "appleCrate", pack = "Quaternius Fantasy Props", file = "FarmCrate_Apple.fbx", template = "Quaternius_FarmCrate_Apple", purpose = "primeira pista da trilha", tier = 1 },
	{ key = "carrotCrate", pack = "Quaternius Fantasy Props", file = "FarmCrate_Carrot.fbx", template = "Quaternius_FarmCrate_Carrot", purpose = "segunda pista da trilha", tier = 1 },
	{ key = "banner", pack = "Quaternius Fantasy Props", file = "Banner_1_Cloth.fbx", template = "Quaternius_Banner_1_Cloth", purpose = "bandeiras do mirante", tier = 2 },
	{ key = "lantern", pack = "Quaternius Fantasy Props", file = "Lantern_Wall.fbx", template = "Quaternius_Lantern_Wall", purpose = "iluminação visual das estações", tier = 2 },
	{ key = "cart", pack = "Quaternius Fantasy Props", file = "Stall_Cart_Empty.fbx", template = "Quaternius_Stall_Cart_Empty", purpose = "carrinho de mercado em segundo plano", tier = 2 },
	{ key = "cauldron", pack = "Quaternius Fantasy Props", file = "Cauldron.fbx", template = "Quaternius_Cauldron", purpose = "decoração de caldeirão menor, não substituir Ancestral", tier = 3 },
	{ key = "bench", pack = "Quaternius Fantasy Props", file = "Bench.fbx", template = "Quaternius_Bench", purpose = "banco do mirante", tier = 3 },
}

local byKey: { [string]: Entry } = {}
for _, item in Manifest.Items do
	byKey[item.key] = item
end

function Manifest.get(key: string): Entry?
	return byKey[key]
end

return Manifest
