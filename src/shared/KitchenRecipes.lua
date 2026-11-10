--!strict
-- KitchenRecipes — descobertas cosméticas e combinação de ingredientes na Cozinha Colossal.
-- Não altera chance, preço, inventário nem valor de alimentos especiais.
-- Qualquer par comum/incomum cozinha; algumas combinações revelam receitas únicas.
local Recipes = {}

export type Recipe = {
	id: string,
	name: string,
	color: Color3,
	hint: string,
	first: string,
	second: string,
}

Recipes.Specials = {
	{
		id = "fruit_feast",
		name = "SALADA DOS GIGANTES",
		color = Color3.fromRGB(109, 215, 120),
		hint = "MAÇÃ + BANANA",
		first = "apple",
		second = "banana",
	},
	{
		id = "king_sandwich",
		name = "SANDUÍCHE REAL",
		color = Color3.fromRGB(255, 198, 103),
		hint = "PÃO + HAMBÚRGUER",
		first = "bread",
		second = "burger",
	},
	{
		id = "fire_festival",
		name = "FESTIVAL DA FORNALHA",
		color = Color3.fromRGB(245, 111, 78),
		hint = "PIZZA + HAMBÚRGUER",
		first = "pizza",
		second = "burger",
	},
	{
		id = "world_banquet",
		name = "BANQUETE DO MUNDO",
		color = Color3.fromRGB(131, 199, 248),
		hint = "PIZZA + SUSHI",
		first = "pizza",
		second = "sushi",
	},
} :: { Recipe }

Recipes.Surprise = {
	id = "mystery",
	name = "PRATO SURPRESA",
	color = Color3.fromRGB(215, 186, 253),
	hint = "QUALQUER PAR DE COMIDAS",
	first = "",
	second = "",
} :: Recipe

function Recipes.fromPair(a: string, b: string): Recipe
	for _, recipe in Recipes.Specials do
		if (a == recipe.first and b == recipe.second) or (a == recipe.second and b == recipe.first) then
			return recipe
		end
	end
	return Recipes.Surprise
end

function Recipes.daily(now: number): Recipe
	local day = math.floor(now / 86400)
	return Recipes.Specials[day % #Recipes.Specials + 1]
end

function Recipes.known(saved: any, recipeId: string): boolean
	return type(saved) == "table" and saved[recipeId] == true
end

function Recipes.learn(saved: any, recipeId: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(saved) == "table" then
		for key, value in saved do
			if type(key) == "string" and value == true then
				out[key] = true
			end
		end
	end
	if recipeId ~= Recipes.Surprise.id then
		out[recipeId] = true
	end
	return out
end

function Recipes.count(saved: any): number
	local n = 0
	for _, r in Recipes.Specials do
		if Recipes.known(saved, r.id) then
			n += 1
		end
	end
	return n
end

return Recipes
