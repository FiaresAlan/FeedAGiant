--!strict
-- FeedAGiant V2: dois slots de cozinha persistidos no mesmo profile e sem temporizador de servidor offline.
-- Nao alterar inventario, ovos, compras, receitas antigas ou perfil de producao fora da feature flag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Features)
local Config = require(Shared.Config)
local Catalog = require(Shared.RebuildV2.RecipeCatalog)
local CookRules = require(Shared.RebuildV2.CookRules)
local Remotes = require(Shared.Remotes)
local Guard = require(script.Parent.Parent.Guard)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)
local Analytics = require(script.Parent.Parent.Analytics)
local Hooks = require(script.Parent.Parent.Hooks)

local V2CookingService = {}

type CookSlot = {
	state: string,
	jobId: string?,
	recipeId: string?,
	startedAtUtc: number?,
	endsAtUtc: number?,
}
type CookData = {
	version: number,
	slots: { CookSlot },
	discoveredRecipeIds: { [string]: boolean },
}

local function freshData(): CookData
	return {
		version = 1,
		slots = { { state = "empty" }, { state = "empty" } },
		discoveredRecipeIds = {},
	}
end

local function cookData(player: Player): (any, CookData?)
	local profile = DataService.get(player)
	if not profile then
		return nil, nil
	end
	local data: any = (profile :: any).v2Cook
	-- Todas as alterações/migrações em memória são aditivas; não apagar um job antigo.
	if type(data) ~= "table" then
		data = freshData()
		(profile :: any).v2Cook = data
		DataService.markDirty(player)
	end
	if type(data.slots) ~= "table" then
		data.slots = freshData().slots
		DataService.markDirty(player)
	end
	if type(data.discoveredRecipeIds) ~= "table" then
		data.discoveredRecipeIds = {}
		DataService.markDirty(player)
	end
	for index = 1, 2 do
		if type(data.slots[index]) ~= "table" then
			data.slots[index] = { state = "empty" }
			DataService.markDirty(player)
		end
	end
	return profile, data :: CookData
end

local function nearOwnBase(player: Player): boolean
	local base = MapService.getBaseOf(player)
	local root = Guard.rootOf(player)
	if not base or not root then
		return false
	end
	local relative = base.origin:PointToObjectSpace(root.Position)
	-- Base radial pode ter decoracao; nao permitir cozinhar remotamente pela ilha.
	return math.abs(relative.X) <= Config.BaseSize / 2 + 8
		and math.abs(relative.Z) <= Config.BaseSize / 2 + 8
		and math.abs(relative.Y) < 45
end

local function isReady(slot: CookSlot, now: number): boolean
	return CookRules.isReady(slot, now)
end

local function visibleSlot(slot: CookSlot, now: number)
	local ready = isReady(slot, now)
	local recipe = if type(slot.recipeId) == "string" then Catalog.ById[slot.recipeId] else nil
	return {
		state = if ready then "ready" else slot.state,
		recipeId = if recipe then recipe.id else nil,
		recipeName = if recipe then recipe.name else nil,
		jobId = slot.jobId,
		endsAtUtc = slot.endsAtUtc,
		remaining = if slot.state == "cooking" and not ready then math.max(0, (slot.endsAtUtc or now) - now) else 0,
	}
end

function V2CookingService.pushState(player: Player)
	if not Features.on("RebuildV2") or player.Parent == nil then
		return
	end
	local _profile, data = cookData(player)
	if not data then
		return
	end
	local now = os.time()
	Remotes.V2CookState:FireClient(player, {
		now = now,
		slots = { visibleSlot(data.slots[1], now), visibleSlot(data.slots[2], now) },
		recipes = Catalog.publicRecipes(data.discoveredRecipeIds),
	})
end

local function notify(player: Player, msg: string)
	Remotes.Notify:FireClient(player, { text = msg, color = Color3.fromRGB(247, 194, 95) })
end

local function begin(player: Player, index: number, recipe: any, mustBeDiscovered: boolean)
	if not nearOwnBase(player) then
		notify(player, "Volte para a sua base para cozinhar.")
		return
	end
	local profile, data = cookData(player)
	if not profile or not data or not recipe then
		return
	end
	if mustBeDiscovered and not Catalog.canStartById(recipe.id, data.discoveredRecipeIds) then
		notify(player, "Descubra esta receita combinando os ingredientes primeiro.")
		return
	end
	local slot = data.slots[index]
	if slot.state ~= "empty" then
		notify(player, "Esta panela ja esta ocupada.")
		return
	end
	local indices = CookRules.selectIndices(profile.inventory, recipe.ingredients)
	if not indices then
		notify(player, "Faltam ingredientes desta receita na mochila.")
		return
	end
	if not Config.FoodById[recipe.resultId] then
		warn("[V2Cooking] resultado sem catalogo:", recipe.resultId)
		return
	end
	-- Preparar o UID antes de consumir itens; a mutacao seguinte nao faz yield.
	local jobId = DataService.newUid()
	local now = os.time()
	for _, i in indices do
		table.remove(profile.inventory, i)
	end
	data.slots[index] = {
		state = "cooking",
		jobId = jobId,
		recipeId = recipe.id,
		startedAtUtc = now,
		endsAtUtc = now + recipe.seconds,
	}
	data.discoveredRecipeIds[recipe.id] = true
	DataService.markDirty(player)
	PlotService.pushState(player)
	V2CookingService.pushState(player)
	Hooks.fire("v2_cooked", player, recipe.id)
	Analytics.event(player, "v2_cook_started", 1, { recipe.id, tostring(index) })
end

local function claim(player: Player, index: number, expectedJobId: any)
	if not nearOwnBase(player) then
		notify(player, "Volte para a sua base para retirar o prato.")
		return
	end
	local profile, data = cookData(player)
	if not profile or not data then
		return
	end
	local slot = data.slots[index]
	if not CookRules.canClaim(slot, expectedJobId, os.time()) then
		V2CookingService.pushState(player)
		return
	end
	local recipe = if type(slot.recipeId) == "string" then Catalog.ById[slot.recipeId] else nil
	if not recipe or not Config.FoodById[recipe.resultId] then
		warn("[V2Cooking] job desconhecido preservado para recuperacao:", slot.jobId)
		return
	end
	if not CookRules.hasSpace(#profile.inventory, Config.MaxInventory) then
		notify(player, "Mochila cheia. O prato continua pronto na panela.")
		return
	end
	-- NAO chamar giveFood/SaveNow entre estas duas mutacoes (sem yield).
	-- Um retry sobre o mesmo jobId encontra o slot vazio e nao cria outra recompensa.
	table.insert(profile.inventory, { id = recipe.resultId, uid = DataService.newUid() })
	data.slots[index] = { state = "empty" }
	DataService.markDirty(player)
	PlotService.pushState(player)
	V2CookingService.pushState(player)
	notify(player, "Prato pronto! Ja esta na sua mochila.")
	Analytics.event(player, "v2_cook_claimed", 1, { recipe.id, tostring(index) })
end

-- Pergaminhos conquistados na pista: descoberta permanente; repeticao nao gera premio infinito.
function V2CookingService.unlockRecipe(player: Player, recipeId: any): boolean
	if type(recipeId) ~= "string" or not Catalog.ById[recipeId] then return false end
	local _profile, data = cookData(player)
	if not data then return false end
	if data.discoveredRecipeIds[recipeId] then
		-- Repeticoes nao multiplicam recompensas; o pergaminho pode ser entregue.
		-- Nenhum inventario, moeda ou XP e alterado por desbloqueio repetido.
		return true
	end
	data.discoveredRecipeIds[recipeId] = true
	DataService.markDirty(player)
	V2CookingService.pushState(player)
	Analytics.event(player, "v2_recipe_unlocked", 1, { recipeId, "scroll" })
	return true
end

function V2CookingService.onJoin(player: Player)
	V2CookingService.pushState(player)
end

function V2CookingService.init()
	-- PlayerData exige registro ANTES de DataService.start().
	DataService.registerSlice("v2Cook", freshData)
	Remotes.V2CookRequest.OnServerEvent:Connect(function(player: Player, action: any, index: any, arg: any, other: any)
		if not Features.on("RebuildV2") or type(action) ~= "string" or not Guard.allow(player, "V2Cook") then
			return
		end
		if action == "snapshot" then
			V2CookingService.pushState(player)
			return
		end
		if not Guard.isIndex(index, 2) then
			return
		end
		if action == "claim" then
			claim(player, index, arg)
		elseif action == "start" and type(arg) == "string" and #arg <= 48 then
			begin(player, index, Catalog.ById[arg], true)
		elseif action == "combine" and type(arg) == "string" and type(other) == "string"
			and #arg <= 48 and #other <= 48 then
			local recipe = Catalog.fromIngredients(arg, other)
			if recipe then
				begin(player, index, recipe, false)
			else
				notify(player, "Essa combinacao ainda nao produz uma receita.")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(_player)
		-- Jobs offline persistem por UTC no profile; nada a agendar nem descartar.
	end)
end

return V2CookingService
