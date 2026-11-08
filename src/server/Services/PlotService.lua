--!strict
-- PlotService — inventário, slots do pátio, alimentar o Gigante e renda passiva.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local GiantService = require(script.Parent.GiantService)
local FoodModels = require(script.Parent.Parent.FoodModels)
local TutorialService = require(script.Parent.TutorialService)
local Guard = require(script.Parent.Parent.Guard)

-- Maior índice de vaga possível (VIP tem mais vagas); o dono é conferido depois.
local MAX_SLOT_INDEX = math.max(Config.PlotSlots, Config.PlotSlotsVIP)

local PlotService = {}
local foodModels: { [Player]: { [number]: Model } } = {}
local globalCoinMultiplier = 1 -- alterado por EventService (Golden Hour)
-- Fase 0.7: membro do grupo é consultado UMA vez na entrada (IsInGroup pode ceder/yield).
local groupMember: { [Player]: boolean } = {}
local autoFeedTick: { [Player]: number } = {}
local fullTick: { [Player]: number } = {}
local AUTO_FEED_EVERY = 5
local FULL_PUSH_EVERY = 15

function PlotService.setGlobalMultiplier(m: number)
	globalCoinMultiplier = m
end

function PlotService.maxSlots(profile: DataService.Profile): number
	return if profile.passes.VIP then Config.PlotSlotsVIP else Config.PlotSlots
end

function PlotService.pushState(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	Remotes.StateChanged:FireClient(player, {
		coins = profile.coins,
		level = profile.level,
		xp = profile.xp,
		xpNeeded = Config.xpNeeded(profile.level),
		rebirths = profile.rebirths,
		hunger = profile.hunger,
		inventory = profile.inventory,
		plot = profile.plot,
		maxSlots = PlotService.maxSlots(profile),
		cps = PlotService.coinsPerSecond(player),
		passes = profile.passes,
		shieldUntil = profile.shieldUntil,
		dailyStreak = profile.dailyStreak,
		lastDaily = profile.lastDaily,
		-- v2
		species = profile.species,
		ownedSpecies = profile.ownedSpecies,
		stage = Config.stageForLevel(profile.level).name,
		lastFed = profile.lastFed,
		freezeUntil = profile.freezeUntil,
		levelsLostToDecay = profile.levelsLostToDecay,
		peakLevel = profile.peakLevel,
		arenaWins = profile.arenaWins,
		arenaLosses = profile.arenaLosses,
		championUntil = profile.championUntil,
		duelProtectionUntil = profile.duelProtectionUntil,
		lastDuel = profile.lastDuel,
		dropsWon = profile.dropsWon,
		knockouts = profile.knockouts,
		speciesTokens = profile.speciesTokens or 0,
	})
end

function PlotService.coinsPerSecond(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, food in profile.plot do
		local def = Config.FoodById[food.id]
		if def then
			total += Config.Rarities[def.rarity].cps
		end
	end
	local sp = GiantService.species(profile)
	local rebirthBonus = Config.Rebirth.BonusPerRebirth * (if sp.id == "phoenix" then 2 else 1)
	local mult = 1 + profile.rebirths * rebirthBonus
	mult *= GiantService.moodMultiplier(profile)
	mult *= sp.coinMult
	mult *= 1 + profile.level * 0.01
	if profile.passes.DoubleCoins then
		mult *= 2
	end
	if groupMember[player] then
		mult *= 1.1
	end
	return math.floor(total * mult * globalCoinMultiplier)
end

local PLOT_FOOD_SIZE = 4.4 -- maior dimensão da comida 3D no pátio (vaga de 6x6 studs)
-- Letreiro da comida só de perto (antes: 400 studs; 16 nomes por base poluíam a tela).
local FOOD_LABEL_DISTANCE = 30

local function buildFoodModel(def: Config.FoodDef, slot: Part): Model
	local model = Instance.new("Model")
	model.Name = "Food_" .. def.id
	local bounds = FoodModels.boundsFor(def.id, PLOT_FOOD_SIZE)
	local p = Util.makePart({
		Name = "Body",
		Size = if bounds then bounds:Max(Vector3.new(1, 1, 1)) else Vector3.new(3, 3, 3),
		Color = def.color,
		Material = if Config.Rarities[def.rarity].order >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CFrame = if bounds
			then slot.CFrame * CFrame.new(0, 0.2 + math.max(bounds.Y, 1) / 2, 0)
			else slot.CFrame * CFrame.new(0, 2, 0),
		Parent = model,
	})
	if bounds then
		-- Fase 2: comida 3D (Grab3D CC0). A peça fica invisível e do tamanho da malha (clique certo).
		FoodModels.dress(p, def.id, PLOT_FOOD_SIZE)
	elseif def.shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif def.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(1.2, 3.5, 3.5)
		p.CFrame = slot.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
	elseif def.shape == "Wedge" then
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(3, 2.5, 3)
		w.Color = def.color
		w.Material = p.Material
		w.CFrame = slot.CFrame * CFrame.new(0, 1.6, 0)
		w.Parent = model
		p:Destroy()
		p = w :: any
	end
	model.PrimaryPart = p
	local rc = Config.Rarities[def.rarity].color
	local label = Util.makeBillboard(
		p,
		if bounds then def.name else def.name .. "\n" .. def.rarity,
		UDim2.fromOffset(120, 28),
		Vector3.new(0, p.Size.Y / 2 + 1.2, 0),
		rc
	)
	local board = label.Parent :: BillboardGui
	board.MaxDistance = FOOD_LABEL_DISTANCE
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 25
	click.Parent = p
	if not bounds then
		local sel = Instance.new("SelectionBox")
		sel.Adornee = p
		sel.Color3 = rc
		sel.LineThickness = 0.05
		sel.Parent = p
	end
	model:SetAttribute("FoodId", def.id)
	model:SetAttribute("SlotIndex", slot:GetAttribute("SlotIndex"))
	model:SetAttribute("BaseIndex", slot:GetAttribute("BaseIndex"))
	model.Parent = slot.Parent
	return model
end

function PlotService.rebuildPlot(player: Player)
	local profile = DataService.get(player)
	local base = MapService.getBaseOf(player)
	if not profile or not base then
		return
	end
	foodModels[player] = foodModels[player] or {}
	for idx, m in foodModels[player] do
		m:Destroy()
		foodModels[player][idx] = nil
	end
	for key, food in profile.plot do
		local idx = tonumber(key)
		local def = Config.FoodById[food.id]
		if idx and def and base.slots[idx] then
			local model = buildFoodModel(def, base.slots[idx])
			model:SetAttribute("OwnerUserId", player.UserId)
			foodModels[player][idx] = model
		end
	end
end

function PlotService.getFoodModel(player: Player, slot: number): Model?
	return foodModels[player] and foodModels[player][slot]
end

function PlotService.hasInventorySpace(profile: DataService.Profile, count: number?): boolean
	return #profile.inventory + (count or 1) <= Config.MaxInventory
end

-- Dá uma comida. Com a mochila cheia (MaxInventory), recusa (retorna false e avisa).
-- `force`: prêmios e itens que já existiam passam do limite normal até MaxInventoryHard.
-- `paid`: comprado com Robux, entrega sempre (um recibo pago não pode ser recusado).
function PlotService.giveFood(player: Player, foodId: string, force: boolean?, paid: boolean?): boolean
	local profile = DataService.get(player)
	if not profile or not Config.FoodById[foodId] then
		return false
	end
	local cap = if paid then math.huge elseif force then Config.MaxInventoryHard else Config.MaxInventory
	if #profile.inventory + 1 > cap then
		Remotes.Notify:FireClient(player, {
			text = "Mochila cheia! Alimente seu Gigante ou coloque comida no pátio.",
			color = Color3.fromRGB(255, 90, 90),
		})
		return false
	end
	table.insert(profile.inventory, { id = foodId, uid = DataService.newUid() })
	DataService.markDirty(player)
	PlotService.pushState(player)
	return true
end

function PlotService.place(player: Player, invIndex: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local item = profile.inventory[invIndex]
	if not item then
		return
	end
	local max = PlotService.maxSlots(profile)
	for i = 1, max do
		if not profile.plot[tostring(i)] then
			profile.plot[tostring(i)] = item
			table.remove(profile.inventory, invIndex)
			DataService.markDirty(player)
			PlotService.rebuildPlot(player)
			PlotService.pushState(player)
			TutorialService.signal(player, "Placed")
			return
		end
	end
	Remotes.Notify:FireClient(
		player,
		{ text = "Pátio cheio! Alimente seu Gigante para liberar espaço.", color = Color3.fromRGB(255, 90, 90) }
	)
end

function PlotService.pickup(player: Player, slot: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local item = profile.plot[tostring(slot)]
	if not item then
		return
	end
	profile.plot[tostring(slot)] = nil
	table.insert(profile.inventory, item)
	DataService.markDirty(player)
	PlotService.rebuildPlot(player)
	PlotService.pushState(player)
end

function PlotService.removeFromPlot(player: Player, slot: number): DataService.FoodInstance?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local item = profile.plot[tostring(slot)]
	if not item then
		return nil
	end
	profile.plot[tostring(slot)] = nil
	DataService.markDirty(player)
	PlotService.rebuildPlot(player)
	PlotService.pushState(player)
	return item
end

function PlotService.feed(player: Player, slot: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local item = profile.plot[tostring(slot)]
	if not item then
		return
	end
	local def = Config.FoodById[item.id]
	if not def then
		return
	end
	local fromModel = foodModels[player] and foodModels[player][slot]
	local from = if fromModel then fromModel:GetPivot().Position else nil
	profile.plot[tostring(slot)] = nil
	profile.totalFeeds += 1
	GiantService.addXp(player, Config.Rarities[def.rarity].xp, def.id, from)
	TutorialService.signal(player, "Fed")
	TutorialService.refresh(player) -- passo "grow" (nível 3) completa sozinho
	PlotService.rebuildPlot(player)
	PlotService.pushState(player)
end

function PlotService.feedFromInventory(player: Player, invIndex: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local item = profile.inventory[invIndex]
	if not item then
		return
	end
	local def = Config.FoodById[item.id]
	if not def then
		return
	end
	table.remove(profile.inventory, invIndex)
	profile.totalFeeds += 1
	local char = player.Character
	local from = if char then char:GetPivot().Position + Vector3.new(0, 2, 0) else nil
	GiantService.addXp(player, Config.Rarities[def.rarity].xp, def.id, from)
	TutorialService.signal(player, "Fed")
	TutorialService.refresh(player)
	PlotService.pushState(player)
end

function PlotService.init()
	-- Fase 2: carrega as comidas 3D em segundo plano e remonta os pátios quando terminar
	-- (quem entrou antes viu as formas antigas por alguns segundos).
	FoodModels.preload()
	FoodModels.whenReady(function()
		for _, player in Players:GetPlayers() do
			PlotService.rebuildPlot(player)
		end
	end)
	Remotes.RequestPlace.OnServerEvent:Connect(function(player, invIndex)
		if Guard.isIndex(invIndex, Config.MaxInventoryHard) and Guard.allow(player, "Plot") then
			PlotService.place(player, invIndex)
		end
	end)
	Remotes.RequestPickup.OnServerEvent:Connect(function(player, slot)
		if Guard.isIndex(slot, MAX_SLOT_INDEX) and Guard.allow(player, "Plot") then
			PlotService.pickup(player, slot)
		end
	end)
	Remotes.RequestFeed.OnServerEvent:Connect(function(player, arg)
		if not Guard.allow(player, "Plot") then
			return
		end
		if type(arg) == "table" and Guard.isIndex(arg.inv, Config.MaxInventoryHard) then
			PlotService.feedFromInventory(player, arg.inv)
		elseif Guard.isIndex(arg, MAX_SLOT_INDEX) then
			PlotService.feed(player, arg)
		end
	end)
	local getFullState: RemoteFunction = Remotes.GetFullState :: any
	getFullState.OnServerInvoke = function(player: Player): boolean?
		local profile = DataService.waitFor(player)
		if not profile then
			return nil
		end
		PlotService.pushState(player)
		return true
	end

	local function checkGroup(player: Player)
		if Config.GroupId == 0 then
			return
		end
		local ok, isMember = pcall(player.IsInGroup, player, Config.GroupId)
		if ok and player.Parent then
			groupMember[player] = isMember == true
		end
	end
	Players.PlayerAdded:Connect(checkGroup)
	for _, p in Players:GetPlayers() do
		task.spawn(checkGroup, p)
	end

	-- Renda passiva (1x/seg). Fase 0.7: o tick manda só {coins, cps, hunger} (pequeno);
	-- o estado completo vai só quando algo muda (pushState chamado pelas ações).
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile then
					local cps = PlotService.coinsPerSecond(player)
					if cps > 0 then
						profile.coins += cps
						DataService.markDirty(player)
					end
					-- Auto-Feed pass: alimenta a comida mais fraca a cada AUTO_FEED_EVERY segundos
					local fed = false
					if profile.passes.AutoFeed then
						autoFeedTick[player] = (autoFeedTick[player] or 0) + 1
						if autoFeedTick[player] >= AUTO_FEED_EVERY then
							autoFeedTick[player] = 0
							local bestSlot: number? = nil
							local bestOrder = 99
							for key, food in profile.plot do
								local def = Config.FoodById[food.id]
								if def and Config.Rarities[def.rarity].order < bestOrder then
									bestOrder = Config.Rarities[def.rarity].order
									bestSlot = tonumber(key)
								end
							end
							if bestSlot then
								PlotService.feed(player, bestSlot) -- já envia o estado completo
								fed = true
							end
						end
					end
					fullTick[player] = (fullTick[player] or 0) + 1
					if not fed and fullTick[player] >= FULL_PUSH_EVERY then
						fullTick[player] = 0
						PlotService.pushState(player) -- rede de segurança (antes: TODO segundo)
					elseif not fed then
						Remotes.StateChanged:FireClient(player, {
							coins = profile.coins,
							cps = cps,
							hunger = profile.hunger,
						})
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		groupMember[player] = nil
		autoFeedTick[player] = nil
		fullTick[player] = nil
		if foodModels[player] then
			for _, m in foodModels[player] do
				m:Destroy()
			end
			foodModels[player] = nil
		end
	end)
end

return PlotService
