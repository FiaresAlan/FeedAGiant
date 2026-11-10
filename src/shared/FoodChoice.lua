--!strict
-- FoodChoice: alimentação rápida CONSERVADORA.
-- Primeiro comida normal da mochila; depois do pátio. Itens raros, mutados ou
-- gigantescos só são alimentados após seleção explícita em ITENS.
local Config = require(script.Parent.Config)

local FoodChoice = {}
FoodChoice.MaxAutoRarityOrder = 2 -- Comum/Incomum

function FoodChoice.isSafe(item: any): boolean
	if type(item) ~= "table" or type(item.id) ~= "string" then
		return false
	end
	local def = Config.FoodById[item.id]
	if not def or item.mut ~= nil or item.big == true then
		return false
	end
	local rarity = Config.Rarities[def.rarity]
	return rarity ~= nil and rarity.order <= FoodChoice.MaxAutoRarityOrder
end

-- Devolve (slot do pátio, índice da mochila). Nunca consome nada: a decisão real
-- continua sendo validada e executada no servidor.
function FoodChoice.choose(plot: { [string]: any }, inventory: { any }, preferredId: string?): (number?, number?)
	-- A mochila vem antes do pátio para preservar renda passiva já exposta.
	local bestInv, bestOrder = nil :: number?, math.huge
	for index, item in inventory do
		if FoodChoice.isSafe(item) then
			local rank = if preferredId and item.id == preferredId
				then 0
				else Config.Rarities[Config.FoodById[item.id].rarity].order
			if rank < bestOrder then
				bestOrder, bestInv = rank, index
			end
		end
	end
	if bestInv then
		return nil, bestInv
	end
	local bestSlot, lowest = nil :: number?, math.huge
	for key, item in plot do
		local index = tonumber(key)
		if index and index % 1 == 0 and FoodChoice.isSafe(item) then
			local rank = if preferredId and item.id == preferredId
				then 0
				else Config.Rarities[Config.FoodById[item.id].rarity].order
			if rank < lowest or (rank == lowest and (bestSlot == nil or index < bestSlot)) then
				lowest, bestSlot = rank, index
			end
		end
	end
	return bestSlot, nil
end

return FoodChoice
