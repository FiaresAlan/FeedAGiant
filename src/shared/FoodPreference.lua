--!strict
-- FoodPreference — sabor favorito do dia: personalidade sem punição de ausência.
-- A preferência é determinística (espécie + dia UTC) e escolhe alimentos comuns
-- ou incomuns já existentes. Não há loja nem item novo: explorar e escolher importa.
local FoodPreference = {}
FoodPreference.BonusMult = 1.2
FoodPreference.Pool = { "apple", "bread", "banana", "pizza", "burger", "sushi" }

function FoodPreference.favorite(speciesId: string, timestamp: number): string
	local hash = 0
	for i = 1, #speciesId do
		hash = (hash * 33 + string.byte(speciesId, i)) % 65521
	end
	local day = math.floor(timestamp / 86400)
	local index = (hash + day) % #FoodPreference.Pool + 1
	return FoodPreference.Pool[index]
end

function FoodPreference.multiplier(speciesId: string, foodId: string, timestamp: number): number
	return if foodId == FoodPreference.favorite(speciesId, timestamp) then FoodPreference.BonusMult else 1
end

return FoodPreference
