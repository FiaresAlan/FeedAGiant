--!strict
-- StudioMemoryStore — substituto em memória do DataStore, SÓ para testes no Studio
-- (place não publicado não tem acesso a DataStore). Implementa o subconjunto que o
-- PlayerData usa: GetAsync e UpdateAsync(key, transform). Os dados duram só a sessão
-- de teste. Nunca é usado fora do Studio (PlayerData só o aceita com IsStudio()).
--
-- Chaves de teste (atributos em ServerStorage, só no Studio):
--   MemoryStoreFailNext (number) — as próximas N requisições lançam erro (simula queda).

local ServerStorage = game:GetService("ServerStorage")

local StudioMemoryStore = {}
StudioMemoryStore.__index = StudioMemoryStore

export type Store = typeof(setmetatable({} :: { _data: { [string]: any } }, StudioMemoryStore))

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function maybeFail()
	local n = ServerStorage:GetAttribute("MemoryStoreFailNext")
	if type(n) == "number" and n > 0 then
		ServerStorage:SetAttribute("MemoryStoreFailNext", n - 1)
		error("503: StudioMemoryStore simulated failure")
	end
end

function StudioMemoryStore.new(): Store
	return setmetatable({ _data = {} }, StudioMemoryStore)
end

function StudioMemoryStore.GetAsync(self: Store, key: string): any
	maybeFail()
	return deepCopy(self._data[key])
end

-- Mesma semântica do Roblox: transform recebe uma cópia do valor atual; retornar nil cancela.
function StudioMemoryStore.UpdateAsync(self: Store, key: string, transform: (any, any) -> any): any
	maybeFail()
	local result = transform(deepCopy(self._data[key]), nil)
	if result == nil then
		return nil
	end
	self._data[key] = deepCopy(result)
	return deepCopy(result)
end

-- Ajuda de teste: grava direto (ex.: simular sessão de outro servidor).
function StudioMemoryStore.RawSet(self: Store, key: string, value: any)
	self._data[key] = deepCopy(value)
end

function StudioMemoryStore.RawGet(self: Store, key: string): any
	return deepCopy(self._data[key])
end

return StudioMemoryStore
