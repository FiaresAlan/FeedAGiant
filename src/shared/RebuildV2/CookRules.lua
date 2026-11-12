--!strict
-- Regras puras de ingredientes, tempo offline e claim de panela.
-- Alteracoes persistentes no perfil acontecem exclusivamente no servico.
local Rules = {}

function Rules.selectIndices(inventory: { any }, ingredients: { string }): { number }?
	if type(inventory) ~= "table" or type(ingredients) ~= "table" or #ingredients ~= 2 then
		return nil
	end
	local selected: { number } = {}
	local used: { [number]: boolean } = {}
	for _, id in ingredients do
		if type(id) ~= "string" then return nil end
		local index: number? = nil
		for i, item in inventory do
			if type(item) == "table" and item.id == id and not used[i] then
				index = i
				break
			end
		end
		if not index then
			return nil
		end
		used[index] = true
		table.insert(selected, index)
	end
	-- Quem muta o inventario deve remover do maior indice para o menor.
	table.sort(selected, function(a, b)
		return a > b
	end)
	return selected
end

-- Tempo restante para jobs validos; nil identifica timestamp corrompido.
-- O job nao e apagado automaticamente: a recompensa pode ter sido paga.
function Rules.remainingSeconds(slot: any, nowUtc: number): number?
	if type(slot) ~= "table" or slot.state ~= "cooking" then return nil end
	local endTime = slot.endsAtUtc
	if type(endTime) ~= "number" or endTime ~= endTime or math.abs(endTime) == math.huge then
		return nil
	end
	return math.max(0, endTime - nowUtc)
end

function Rules.isReady(slot: any, nowUtc: number): boolean
	if type(slot) ~= "table" then return false end
	return slot.state == "ready" or (slot.state == "cooking" and Rules.remainingSeconds(slot, nowUtc) == 0)
end

function Rules.canClaim(slot: any, jobId: any, nowUtc: number): boolean
	return type(jobId) == "string"
		and #jobId > 0
		and type(slot) == "table"
		and slot.jobId == jobId
		and Rules.isReady(slot, nowUtc)
end

function Rules.hasSpace(inventoryCount: number, maxInventory: number): boolean
	return inventoryCount < maxInventory
end

return Rules
