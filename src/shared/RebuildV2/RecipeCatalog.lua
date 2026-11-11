--!strict
-- FeedAGiant V2: receitas deterministicas. Modulo puro, sem sorteio nem dependencias de rede.
-- Itens exclusivos do novo loop sao registrados em FoodById (nao em Foods/lunchboxes).
local Catalog = {}

Catalog.Items = {
	cheese = { name = "Queijo", rarity = "Common", shape = "Block", color = Color3.fromRGB(255, 217, 105) },
	meat = { name = "Carne", rarity = "Common", shape = "Block", color = Color3.fromRGB(173, 75, 65) },
	potato = { name = "Batata", rarity = "Common", shape = "Ball", color = Color3.fromRGB(191, 151, 93) },
	honey = { name = "Mel", rarity = "Uncommon", shape = "Cylinder", color = Color3.fromRGB(244, 173, 39) },
	pepper_rare = { name = "Pimenta Rara", rarity = "Rare", shape = "Block", color = Color3.fromRGB(218, 55, 57) },
	colossal_fruit = { name = "Fruta Colossal", rarity = "Rare", shape = "Ball", color = Color3.fromRGB(142, 193, 64) },
	toast_cheese = { name = "Torrada de Queijo", rarity = "Common", shape = "Block", color = Color3.fromRGB(251, 189, 91) },
	toast_apple = { name = "Torrada de Maca", rarity = "Common", shape = "Block", color = Color3.fromRGB(242, 151, 94) },
	stew = { name = "Ensopado", rarity = "Uncommon", shape = "Cylinder", color = Color3.fromRGB(198, 118, 60) },
	caramel_apple = { name = "Maca Caramelizada", rarity = "Rare", shape = "Ball", color = Color3.fromRGB(228, 132, 58) },
	spicy_meat = { name = "Carne Apimentada", rarity = "Legendary", shape = "Block", color = Color3.fromRGB(237, 83, 43) },
	fruit_banquet = { name = "Banquete de Frutas", rarity = "Mythic", shape = "Block", color = Color3.fromRGB(173, 92, 224) },
}

Catalog.Recipes = {
	{ id = "toast_cheese", name = "Torrada de Queijo", ingredients = { "bread", "cheese" }, resultId = "toast_cheese", seconds = 12, rarity = "Common", hint = "Pao e um laticinio." },
	{ id = "toast_apple", name = "Torrada de Maca", ingredients = { "apple", "bread" }, resultId = "toast_apple", seconds = 15, rarity = "Common", hint = "Uma fruta sobre pao." },
	{ id = "stew", name = "Ensopado", ingredients = { "meat", "potato" }, resultId = "stew", seconds = 35, rarity = "Uncommon", hint = "Proteina e tuberculo." },
	{ id = "caramel_apple", name = "Maca Caramelizada", ingredients = { "apple", "honey" }, resultId = "caramel_apple", seconds = 90, rarity = "Rare", hint = "Fruta com algo doce." },
	{ id = "spicy_meat", name = "Carne Apimentada", ingredients = { "meat", "pepper_rare" }, resultId = "spicy_meat", seconds = 12 * 60, rarity = "Legendary", hint = "Carne e um ingrediente ardente." },
	{ id = "fruit_banquet", name = "Banquete de Frutas", ingredients = { "colossal_fruit", "honey" }, resultId = "fruit_banquet", seconds = 30 * 60, rarity = "Mythic", hint = "Uma fruta colossal e doçura." },
}

Catalog.ById = {}
local pairsToIds = {}

local function pairKey(a: string, b: string): string
	if a < b then
		return a .. "|" .. b
	end
	return b .. "|" .. a
end

for _, recipe in Catalog.Recipes do
	assert(not Catalog.ById[recipe.id], "ID duplicado: " .. recipe.id)
	Catalog.ById[recipe.id] = recipe
	local k = pairKey(recipe.ingredients[1], recipe.ingredients[2])
	assert(not pairsToIds[k], "Par de receitas duplicado: " .. k)
	pairsToIds[k] = recipe.id
end

function Catalog.fromIngredients(a: string, b: string)
	local id = pairsToIds[pairKey(a, b)]
	return if id then Catalog.ById[id] else nil
end

function Catalog.registerFoodDefs(foodById: { [string]: any })
	for id, props in Catalog.Items do
		assert(foodById[id] == nil, "ID de comida V2 em conflito: " .. id)
		foodById[id] = {
			id = id,
			name = props.name,
			rarity = props.rarity,
			shape = props.shape,
			color = props.color,
		}
	end
end

-- A lista completa pode aparecer no Livro, mas receitas ainda fechadas exibem apenas uma pista.
function Catalog.publicRecipes(discovered: { [string]: boolean })
	local out = {}
	for _, recipe in Catalog.Recipes do
		local unlocked = discovered[recipe.id] == true
		table.insert(out, {
			id = recipe.id,
			name = if unlocked then recipe.name else "Receita desconhecida",
			hint = if unlocked then nil else recipe.hint,
			rarity = recipe.rarity,
			seconds = if unlocked then recipe.seconds else nil,
			ingredients = if unlocked then recipe.ingredients else nil,
			resultId = if unlocked then recipe.resultId else nil,
			discovered = unlocked,
		})
	end
	return out
end

return Catalog
