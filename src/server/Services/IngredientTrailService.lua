--!strict
-- IngredientTrailService — mini expedição de ingredientes no anel da praça.
-- 3 estações percorridas EM ORDEM, 180 s, sem teleportes nem mapa adicional.
-- A falha só reinicia o percurso; não há perda de itens ou compras.
-- Progresso da sessão é temporário; limite de prêmios usa slice persistente.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local FoodPreference = require(game.ReplicatedStorage.Shared.FoodPreference)
local Rules = require(game.ReplicatedStorage.Shared.IngredientTrailRules)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local IngredientTrailService = {}

local REACH = 14
local runs: { [Player]: { step: number, deadline: number, startedAt: number } } = {}
-- As instâncias só existem enquanto o mapa estiver ativo; não armazenar refs globais.

local function on(): boolean
	return Features.on("IngredientTrail")
end

local function notify(player: Player, message: string, color: Color3?)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, {
			text = message,
			color = color or Color3.fromRGB(148, 234, 221),
		})
	end
end

local function progress(profile: any): any
	local value = profile.ingredientTrail
	if type(value) ~= "table" then
		value = { v = 1, day = 0, rewards = 0, lifetime = 0, bestSeconds = 0 }
		profile.ingredientTrail = value
	end
	return value
end

local function finish(player: Player, profile: any, now: number)
	local run = runs[player]
	if not run then
		return
	end
	local seconds = math.max(1, now - run.startedAt)
	local saved = progress(profile)
	local best, improved = Rules.best(saved.bestSeconds, seconds)
	local medal = Rules.medal(seconds)
	runs[player] = nil

	-- Depois do limite diário ainda é possível jogar por recorde; não há farm.
	if not Rules.canClaim(saved, now) then
		saved.bestSeconds = best
		DataService.markDirty(player)
		notify(player, string.format("TRILHA %s! %d s%s · hoje sem novo prêmio.",
			medal, seconds, if improved then " · NOVO RECORDE!" else ""))
		Analytics.event(player, "ingredient_trail_practice", seconds, { medal })
		return
	end
	local updated = Rules.claim(saved, now)
	updated.bestSeconds = best
	(profile :: any).ingredientTrail = updated
	profile.coins += Rules.RewardCoins
	DataService.markDirty(player)
	-- Com mochila cheia, prêmios em moedas continuam entregues sem criar dívida
	-- ou oferecer compra de espaço. A comida extra é sempre comum/incomum.
	local foodId = FoodPreference.favorite(profile.species, now)
	local gotFood = if PlotService.hasInventorySpace(profile)
		then PlotService.giveFood(player, foodId)
		else false
	PlotService.pushState(player)
	notify(player,
		string.format("TRILHA %s! %d s%s · +%d moedas%s", medal, seconds,
			if improved then " · NOVO RECORDE!" else "", Rules.RewardCoins,
			if gotFood then " + " .. foodId else " (mochila cheia, sem comida extra)"),
		Color3.fromRGB(255, 220, 114))
	Analytics.event(player, "ingredient_trail_finished", seconds, {
		medal,
		if gotFood then "food" else "coins_only",
	})
end

local function interact(player: Player, step: number, part: BasePart)
	if not on() or not Guard.allow(player, "Trail") or not Guard.withinReach(player, part, REACH) then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	if step == 0 then
		local run = runs[player]
		if run and now < run.deadline then
			notify(player, string.format("Sua Trilha está ativa: procure a pista %d de 3!", run.step + 1))
			return
		end
		runs[player] = { step = 0, deadline = now + Rules.DurationSeconds, startedAt = now }
		if Rules.canClaim(progress(profile), now) then
			notify(player, "TRILHA INICIADA! Encontre as 3 pistas em até 3 minutos para ganhar moedas e comida!")
		else
			notify(player, "MODO RECORDE! Prêmios de hoje concluídos. Tente melhorar seu tempo nas 3 pistas!")
		end
		Analytics.event(player, "ingredient_trail_started", 1)
		return
	end
	local run = runs[player]
	if not run or now >= run.deadline then
		runs[player] = nil
		notify(player, "O prazo da Trilha acabou. Reinicie na placa TRILHA DA COMIDA; nada foi perdido.")
		return
	end
	if not Rules.canAdvance(run.step, step, run.deadline, now) then
		notify(player, string.format("Essa não é a próxima pista! Encontre a PISTA %d.", run.step + 1))
		return
	end
	run.step = step
	if step >= Rules.LastStage then
		finish(player, profile, now)
	else
		notify(player, string.format("PISTA %d/3! Continue pelo anel até a PISTA %d. Restam %d s.", step, step + 1, run.deadline - now))
	end
end

local function hook()
	local map = Workspace:WaitForChild("Map", 60)
	local root = map and map:FindFirstChild("LivingPlazaDistrict")
	local trail = root and root:FindFirstChild("IngredientTrail")
	if not trail then
		warn("[IngredientTrail] trilha não encontrada na praça; verifique PlazaDistrict.build")
		return
	end
	for step = 0, Rules.LastStage do
		local name = if step == 0 then "TrailStart" else "TrailStep" .. tostring(step)
		local part = trail:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TrailPrompt"
			prompt.ActionText = if step == 0 then "COMEÇAR TRILHA" else "COLETAR PISTA " .. tostring(step)
			prompt.ObjectText = if step == 0 then "Trilha da Comida" else "Ingredientes da Ilha"
			prompt.HoldDuration = if step == 0 then 0.3 else 0.7
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.MaxActivationDistance = REACH
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Enabled = on()
			local current = step
			prompt.Triggered:Connect(function(player: Player)
				interact(player, current, part)
			end)
		end
	end
end

function IngredientTrailService.init()
	DataService.registerSlice("ingredientTrail", function()
		return { v = 1, day = 0, rewards = 0, lifetime = 0, bestSeconds = 0 }
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
	end)
	task.defer(hook)
end

return IngredientTrailService
