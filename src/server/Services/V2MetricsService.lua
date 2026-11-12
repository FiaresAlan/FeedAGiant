--!strict
-- V3: eventos de gameplay verificados exclusivamente no servidor.
-- Analytics.recent funciona como logger em Studio; Roblox Analytics requer experiencia publicada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.RebuildV2.StageRules)
local Catalog = require(ReplicatedStorage.Shared.RebuildV2.RecipeCatalog)
local Analytics = require(script.Parent.Parent.Analytics)
local Hooks = require(script.Parent.Parent.Hooks)
local Guard = require(script.Parent.Parent.Guard)
local Mount = require(script.Parent.V2MountService)
local DataService = require(script.Parent.DataService)

local Metrics = {}
local records: { [Player]: any } = {}
local milestones = { 60, 300, 600, 900, 1800 }

-- Ordem literal do GDD V3, enviada apenas quando a acao ocorreu nesta ordem.
-- Nunca inventar um passo anterior ou intermedio para "completar" o funil.
local funnelSteps = {
	"PLAYER_JOINED",
	"FIRST_FEED",
	"FIRST_MOUNT",
	"FIRST_CARGO_PICKUP",
	"FIRST_CARGO_DEPOSIT",
	"FIRST_RECIPE_DISCOVERED",
	"FIRST_POT_START",
	"FIRST_POT_CLAIM",
	"SECOND_FEED",
	"FIRST_NEXT_ACTIVITY",
}

local function emit(player: Player, name: string, fields: { string }?, value: number?)
	if Features.on("RebuildV2") then
		Analytics.event(player, name, value or 1, fields)
	end
end

local function stageOf(player: Player): (string, string)
	local profile = DataService.get(player)
	if not profile then return "unknown", "unknown" end
	local key = Stages.stage(profile.level)
	return key, profile.species
end

local function funnel(player: Player, name: string)
	local r = records[player]
	if not r or not r.eligible then return end
	if funnelSteps[r.nextFunnel] ~= name then return end
	Analytics.onboarding(player, r.nextFunnel, name)
	r.nextFunnel += 1
end

-- A etapa final requer uma NOVA atividade depois da segunda alimentacao.
local function nextActivity(player: Player)
	local record = records[player]
	if record and record.nextFunnel == #funnelSteps then
		funnel(player, "FIRST_NEXT_ACTIVITY")
	end
end

local function step(player: Player, id: string, phase: number)
	local r = records[player]
	if not r or not Features.on("RebuildV2") or r.seen[id] then return end
	r.seen[id] = true
	r.phase = math.max(r.phase, phase)
	emit(player, "v3_" .. id, { tostring(phase) })
end

function Metrics.onJoin(player: Player)
	if not Features.on("RebuildV2") then return end
	local profile = DataService.get(player)
	if not profile then return end
	local race = (profile :: any).v2Race
	local deliveries = if type(race) == "table" then tonumber(race.deliveries) or 0 else 0
	records[player] = {
		enteredAt = os.clock(),
		activeSeconds = 0,
		phase = 0,
		feeds = 0,
		seen = {},
		-- O funil de onboarding e exclusivo da primeira visita elegivel.
		-- Roblox deduplica o onboarding entre sessoes.
		eligible = profile.totalFeeds == 0 and deliveries == 0 and profile.level == 1,
		nextFunnel = 1,
	}
	emit(player, "PLAYER_JOINED", { "v3", "server", if records[player].eligible then "new" else "return" })
	funnel(player, "PLAYER_JOINED")
	step(player, "entered", 0)
end

function Metrics.init()
	Hooks.on("v2_mounted", function(player: Player)
		local _, species = stageOf(player)
		emit(player, "MOUNT_STARTED", { species, "unknown_device", "server" })
		funnel(player, "FIRST_MOUNT")
		step(player, "first_mount", 1)
		nextActivity(player)
	end)
	Hooks.on("v2_unmounted", function(player: Player, species: string, duration: number)
		emit(player, "MOUNT_ENDED", { species, "unmount", "server" }, math.floor(duration))
	end)
	Hooks.on("v2_boost_used", function(player: Player, species: string, weight: string)
		emit(player, "BOOST_USED", { species, weight, "mounted" })
	end)
	Hooks.on("v2_picked", function(player: Player, kind: string, weight: string)
		local _, species = stageOf(player)
		emit(player, "CARGO_PICKED", { kind, weight, species })
		funnel(player, "FIRST_CARGO_PICKUP")
		step(player, "first_pickup", 2)
		nextActivity(player)
	end)
	Hooks.on("v2_dropped", function(player: Player, weight: string, reason: string)
		emit(player, "CARGO_DROPPED", { weight, reason, "lane" })
	end)
	Hooks.on("v2_intercepted", function(attacker: Player, target: Player, weight: string)
		emit(attacker, "CARGO_INTERCEPTED", { weight, "attacker", "lane" })
		emit(target, "CARGO_INTERCEPTED", { weight, "victim", "lane" })
	end)
	Hooks.on("v2_delivered", function(player: Player, kind: string, weight: string, elapsed: number)
		local _, species = stageOf(player)
		emit(player, "CARGO_DEPOSITED", { kind, weight, species })
		emit(player, "DELIVERY_DURATION_SEC", { kind, weight, "seconds" }, math.max(0, math.floor(elapsed)))
		funnel(player, "FIRST_CARGO_DEPOSIT")
		step(player, "first_delivery", 3)
	end)
	Hooks.on("v2_recipe_discovered", function(player: Player, recipeId: string, source: string)
		local recipe = Catalog.ById[recipeId]
		emit(player, "RECIPE_DISCOVERED", { if recipe then recipe.rarity else "unknown", source, "v3" })
		funnel(player, "FIRST_RECIPE_DISCOVERED")
	end)
	Hooks.on("v2_cooked", function(player: Player, recipeId: string)
		local recipe = Catalog.ById[recipeId]
		emit(player, "POT_STARTED", { if recipe then recipe.rarity else "unknown",
			if recipe and recipe.seconds >= 600 then "long" else "short", "v3" })
		funnel(player, "FIRST_POT_START")
		step(player, "first_cook", 4)
		nextActivity(player)
	end)
	Hooks.on("v2_cook_claimed", function(player: Player, recipeId: string)
		local recipe = Catalog.ById[recipeId]
		emit(player, "POT_READY_CLAIMED", { if recipe then recipe.rarity else "unknown", "claim", "v3" })
		funnel(player, "FIRST_POT_CLAIM")
		step(player, "first_claim", 5)
		nextActivity(player)
	end)
	Hooks.on("fed", function(player: Player, details: any)
		local r = records[player]
		if not r or not Features.on("RebuildV2") then return end
		r.feeds += 1
		local stage, species = stageOf(player)
		local food = if type(details) == "table" and type(details.foodId) == "string"
			then Config.FoodById[details.foodId] else nil
		emit(player, "FEED_COMPLETED", { if food then food.rarity else "unknown", stage, species })
		if r.feeds == 1 then
			funnel(player, "FIRST_FEED")
			step(player, "first_feed", 6)
		elseif r.feeds == 2 then
			funnel(player, "SECOND_FEED")
			step(player, "second_feed", 7)
		end
	end)
	Hooks.on("v2_error_recovered", function(player: Player, component: string, reason: string)
		emit(player, "ERROR_RECOVERY", { component, reason, "server" })
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			if not Features.on("RebuildV2") then continue end
			for player, r in records do
				if player.Parent == nil then continue end
				local session = Mount.session(player)
				local active = session and session.move.Magnitude > 0.05
					and os.clock() - session.lastInputAt < 1
				if not active then
					local root = Guard.rootOf(player)
					active = root ~= nil and root.AssemblyLinearVelocity.Magnitude > 2
				end
				if active then
					r.activeSeconds += 5
					for _, seconds in milestones do
						if r.activeSeconds >= seconds then
							step(player, "active_" .. tostring(seconds) .. "s", r.phase)
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local r = records[player]
		if not r then return end
		emit(player, "V3_SESSION_END", {
			"phase_" .. tostring(r.phase),
			"active_" .. tostring(math.floor(r.activeSeconds)),
			"feeds_" .. tostring(r.feeds),
		}, math.floor(math.max(0, os.clock() - r.enteredAt)))
		records[player] = nil
	end)
end

return Metrics
