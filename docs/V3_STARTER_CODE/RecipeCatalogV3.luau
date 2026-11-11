--!strict
-- Snippet V3: tabela de regras determinística, com IDs PROVISÓRIOS.
-- Integrar somente depois de mapear ingredientes e outputs ao FoodCatalog REAL.
local Recipes = {}

local list = {
    { id="toast_cheese", label="Torrada de queijo", inputs={"bread","cheese"}, output="prepared_toast_cheese", duration=12, rarity="common" },
    { id="toast_apple", label="Torrada de maçã", inputs={"apple","bread"}, output="prepared_toast_apple", duration=15, rarity="common" },
    { id="stew_meat_potato", label="Ensopado", inputs={"meat","potato"}, output="prepared_stew", duration=35, rarity="uncommon" },
    { id="caramel_apple", label="Maçã caramelizada", inputs={"apple","honey"}, output="prepared_caramel_apple", duration=90, rarity="rare" },
    { id="spicy_meat", label="Carne apimentada", inputs={"meat","pepper_rare"}, output="prepared_spicy_meat", duration=720, rarity="legendary" },
    { id="colossal_fruit_feast", label="Banquete de frutas", inputs={"colossal_fruit","honey"}, output="prepared_colossal_feast", duration=1800, rarity="mythic" },
}

local byId = {}
local byPair = {}

local function key(a: string, b: string): string
    if a <= b then return a .. ":" .. b end
    return b .. ":" .. a
end

for _, r in list do
    assert(byId[r.id] == nil, "duplicate recipe ID")
    local signature = key(r.inputs[1], r.inputs[2])
    assert(byPair[signature] == nil, "ambiguous pair recipe")
    byId[r.id] = r
    byPair[signature] = r
end

function Recipes.getById(recipeId: string)
    return byId[recipeId]
end

function Recipes.findPair(a: string, b: string)
    if typeof(a) ~= "string" or typeof(b) ~= "string" then return nil end
    return byPair[key(a,b)]
end

function Recipes.all()
    return list -- Não expor tabela alterável ao cliente como verdade econômica.
end

return Recipes
