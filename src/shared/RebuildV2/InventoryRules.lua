--!strict
-- Identifica a instancia real de comida: a UI pode estar paginada ou desatualizada.
-- Nao permite usar UIDs de outros jogadores: a busca sempre e no inventario do dono.
local InventoryRules = {}

function InventoryRules.findUid(inventory: any, uid: any): number?
	if type(inventory) ~= "table" or type(uid) ~= "string" or #uid == 0 or #uid > 80 then
		return nil
	end
	for index, food in inventory do
		if type(food) == "table" and food.uid == uid then
			return index
		end
	end
	return nil
end

return InventoryRules
