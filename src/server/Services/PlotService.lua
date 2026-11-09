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
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Analytics = require(script.Parent.Parent.Analytics)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Hooks = require(script.Parent.Parent.Hooks)
local GameLogic = require(script.Parent.Parent.GameLogic)

-- Maior índice de vaga possível (VIP tem mais vagas); o dono é conferido depois.
local MAX_SLOT_INDEX = math.max(Config.PlotSlots, Config.PlotSlotsVIP)

local PlotService = {}
-- Renda da exposição de gigantes (RosterService preenche; aqui só para somar no tick e mostrar).
PlotService.DisplayIncome = nil :: ((Player) -> number)?
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

-- Índice de coleção (Fase 4): toda comida que passa pela mochila ou pelo pátio fica "descoberta".
-- Feito aqui porque todo caminho que entrega comida (caixa, drop, roubo, tutorial, código) termina
-- num pushState; marcar é idempotente e só toca o save quando aparece algo novo.
local function markDiscovered(player: Player, profile: DataService.Profile)
	local found = profile.discovered
	local changed = false
	local function mark(id: string)
		if not found[id] and Config.FoodById[id] then
			found[id] = true
			changed = true
		end
	end
	for _, food in profile.inventory do
		mark(food.id)
	end
	for _, food in profile.plot do
		mark(food.id)
	end
	if changed then
		DataService.markDirty(player)
	end
end

function PlotService.pushState(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	markDiscovered(player, profile)
	Remotes.StateChanged:FireClient(player, {
		discovered = profile.discovered,
		pendingBoxes = (profile :: any).pendingBoxes,
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
		-- coleção de gigantes (08/11/2026): nível de cada espécie e quais estão expostas
		giants = profile.giants,
		display = profile.display,
		displayCps = if PlotService.DisplayIncome then PlotService.DisplayIncome(player) else 0,
		streak = (PlotService.streakOf(player)),
		-- v3 (Features): contador do pity e proteções da sequência diária
		pityCount = (profile :: any).pityCount or 0,
		streakBackups = (profile :: any).streakBackups or 0,
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
			local trait = GameRules.traitOf(def.id)
			-- Mutação e Fusão (noite 09/11) num multiplicador só, testado (GameLogic.foodIncomeMult).
			-- Revisão cega: o "* fusionMult" tinha virado comentário depois de um "--" e a Gigantesca rendia x1.
			local extra = GameLogic.foodIncomeMult(food :: any)
			total += Config.Rarities[def.rarity].cps * (if trait then trait.incomeMult else 1) * extra
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

local function buildFoodModel(def: Config.FoodDef, slot: Part, mut: string?, big: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "Food_" .. def.id
	local size = PLOT_FOOD_SIZE * (if big then GameRules.Fusion.Scale else 1)
	local bounds = FoodModels.boundsFor(def.id, size)
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
		FoodModels.dress(p, def.id, size)
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
		-- item 6 + 4.3: renda base da comida exposta, já com a característica (ícone na frente)
		string.format(
			"%s%s  +%s/s",
			if GameRules.traitOf(def.id) then (GameRules.traitOf(def.id) :: GameRules.TraitDef).icon .. " " else "",
			def.name,
			tostring(
				math.floor(
					Config.Rarities[def.rarity].cps
							* (if GameRules.traitOf(def.id)
								then (GameRules.traitOf(def.id) :: GameRules.TraitDef).incomeMult
								else 1)
							* 10
						+ 0.5
				) / 10
			)
		),
		UDim2.fromOffset(170, 28),
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
	if big then
		label.Text = "Gigantesca · " .. label.Text
		model:SetAttribute("Fused", true)
	end
	-- Mutação: brilho da cor dela + nome na etiqueta (barato: 1 luz e 1 emissor leve por comida)
	local m = mut and GameRules.Mutations[mut]
	if m then
		label.Text = m.name .. " · " .. label.Text
		label.TextColor3 = m.color
		local light = Instance.new("PointLight")
		light.Color = m.color
		light.Range = 9
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = p
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(m.color)
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Size = NumberSequence.new(0.5, 0)
		pe.Lifetime = NumberRange.new(0.8, 1.2)
		pe.Rate = 4
		pe.Speed = NumberRange.new(1, 2)
		pe.SpreadAngle = Vector2.new(60, 60)
		pe.Parent = p
		model:SetAttribute("Mutation", mut)
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
			local model = buildFoodModel(def, base.slots[idx], (food :: any).mut, (food :: any).big)
			model:SetAttribute("OwnerUserId", player.UserId)
			foodModels[player][idx] = model
		end
	end
end

function PlotService.getFoodModel(player: Player, slot: number): Model?
	return foodModels[player] and foodModels[player][slot]
end

-- Um lote é aceito só se couber INTEIRO. Prêmios gratuitos podem usar o teto estendido;
-- recibos pagos mantêm a entrega garantida independentemente do espaço.
function PlotService.hasInventorySpace(
	profile: DataService.Profile,
	count: number?,
	force: boolean?,
	paid: boolean?
): boolean
	local cap = if paid then math.huge elseif force then Config.MaxInventoryHard else Config.MaxInventory
	return #profile.inventory + (count or 1) <= cap
end

-- Dá uma comida. Com a mochila cheia (MaxInventory), recusa (retorna false e avisa).
-- `force`: prêmios e itens que já existiam passam do limite normal até MaxInventoryHard.
-- `paid`: comprado com Robux, entrega sempre (um recibo pago não pode ser recusado).
function PlotService.giveFood(player: Player, foodId: string, force: boolean?, paid: boolean?): boolean
	local profile = DataService.get(player)
	if not profile or not Config.FoodById[foodId] then
		return false
	end
	if not PlotService.hasInventorySpace(profile, 1, force, paid) then
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
	-- Impede usar o pátio para ultrapassar o limite normal da mochila.
	-- O item permanece intacto no pátio se a retirada não couber.
	if not PlotService.hasInventorySpace(profile) then
		Remotes.Notify:FireClient(player, {
			text = "Mochila cheia! Alimente seu Gigante antes de recolher mais comida.",
			color = Color3.fromRGB(255, 170, 60),
		})
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

-- Perto do próprio gigante: distância no chão até a borda dele (cresce com o gigante) + folga.
PlotService.FEED_REACH = 28
function PlotService.nearGiant(player: Player): boolean
	local model = GiantService.getModel(player)
	local root = Guard.rootOf(player)
	if not model or not root then
		return false
	end
	local cf, ext = model:GetBoundingBox()
	local d = Vector3.new(root.Position.X - cf.Position.X, 0, root.Position.Z - cf.Position.Z).Magnitude
	return d - math.max(ext.X, ext.Z) / 2 <= PlotService.FEED_REACH + Guard.MARGIN
end

-- Alimentação com as novidades de 08/11/2026 (tudo decidido AQUI, no servidor):
--   * 4.1 sequência: cada alimentação até StreakWindow s depois da anterior sobe a sequência
--     (+10% de XP por passo, teto x1,5); demorou demais, recomeça do 1;
--   * 4.3 traço da comida (Crescimento / Renda / Picante / Doce, GameRules.Traits);
--   * 4.4 crítica: chance pequena (x3 com Picante) de x2,5 de crescimento.
local streaks: { [Player]: { n: number, at: number } } = {}
local function doFeed(
	player: Player,
	profile: DataService.Profile,
	def: Config.FoodDef,
	from: Vector3?,
	mut: string?,
	big: boolean?
)
	local now = os.clock()
	local trait = GameRules.traitOf(def.id)
	local prev = streaks[player]
	local n = GameLogic.nextStreak(
		if prev then prev.n else 0,
		if prev then prev.at else nil,
		now,
		if trait then trait.streakBonus else 0
	)
	local st = { n = n, at = now }
	streaks[player] = st
	local xp, crit, streakMult = GameLogic.feedXp(def.id, def.rarity, st.n, math.random())
	xp = math.floor(xp * GameRules.mutationXp(mut)) -- comida com mutação dá mais XP
	if big then
		xp = math.floor(xp * GameRules.Fusion.Mult) -- Gigantesca (Fusão)
	end
	if trait and trait.fillHunger then
		profile.hunger = 100
	end
	profile.totalFeeds += 1
	local levels = GiantService.addXp(player, xp, def.id, from, {
		crit = crit,
		streak = st.n,
		streakMult = streakMult,
		trait = if trait then trait.id else nil,
	})
	-- Funil do primeiro minuto: exatamente uma vez por conta para a 1ª e a 2ª alimentação.
	-- Não envia o inventário nem dados pessoais; ajuda a medir se o loop central é compreendido.
	if profile.totalFeeds == 1 then
		local fields: { string } = { def.rarity, if levels > 0 then "leveled" else "no_level" }
		Analytics.event(player, "ftue_first_feed", 1, fields)
	elseif profile.totalFeeds == 2 then
		local fields: { string } = { def.rarity }
		Analytics.event(player, "ftue_second_feed", 1, fields)
	end
	Hooks.fire("fed", player, { xp = xp, crit = crit, streak = st.n, levels = levels, foodId = def.id })
	TutorialService.signal(player, "Fed")
	TutorialService.refresh(player) -- passo "grow" (nível 3) completa sozinho
end

-- Para a HUD mostrar a sequência ativa (o cliente só exibe).
function PlotService.streakOf(player: Player): (number, number)
	local st = streaks[player]
	if not st or os.clock() - st.at > GameRules.Feed.StreakWindow then
		return 0, 0
	end
	return st.n, GameRules.Feed.StreakWindow - (os.clock() - st.at)
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
	local ok, err = pcall(doFeed :: any, player, profile, def, from, (item :: any).mut, (item :: any).big)
	if not ok then
		profile.plot[tostring(slot)] = item -- devolve a comida: nada se perde por um erro
		warn("[PlotService] alimentar falhou:", err)
	end
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
	local char = player.Character
	local from = if char then char:GetPivot().Position + Vector3.new(0, 2, 0) else nil
	local ok, err = pcall(doFeed :: any, player, profile, def, from, (item :: any).mut, (item :: any).big)
	if not ok then
		table.insert(profile.inventory, invIndex, item)
		warn("[PlotService] alimentar falhou:", err)
	end
	PlotService.pushState(player)
end

-- Fusão (noite 09/11; Features.Fusion): 3 comidas iguais da mochila → 1 Gigantesca. Tudo no servidor,
-- sem nenhum yield entre tirar as 3 e pôr a nova (nada some, nada duplica).
function PlotService.fuse(player: Player, foodId: any)
	if not Features.on("Fusion") or type(foodId) ~= "string" or not Config.FoodById[foodId] then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local picks = GameLogic.fusionPick(profile.inventory :: any, foodId)
	if not picks then
		Remotes.Notify:FireClient(player, {
			text = string.format("Precisa de %d iguais na mochila para fundir.", GameRules.Fusion.Count),
			color = Color3.fromRGB(255, 170, 60),
		})
		return
	end
	local mut = GameLogic.fusionMutation(profile.inventory :: any, picks)
	table.sort(picks, function(a, b)
		return a > b
	end)
	for _, i in picks do
		table.remove(profile.inventory, i)
	end
	table.insert(profile.inventory, { id = foodId, uid = DataService.newUid(), mut = mut, big = true } :: any)
	DataService.markDirty(player)
	PlotService.pushState(player)
	local def = Config.FoodById[foodId]
	Remotes.Notify:FireClient(player, {
		text = string.format(
			"FUSÃO! 3x %s viraram 1 %s GIGANTESCA (renda e XP x%s).",
			def.name,
			def.name,
			tostring(GameRules.Fusion.Mult)
		),
		color = Color3.fromRGB(255, 220, 120),
	})
	Analytics.event(player, "food_fused", 1, { def.rarity :: string, mut or "none" })
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
	Remotes.RequestFuse.OnServerEvent:Connect(function(player, foodId)
		if Guard.allow(player, "Plot") then
			PlotService.fuse(player, foodId)
		end
	end)
	Remotes.RequestPlace.OnServerEvent:Connect(function(player, invIndex)
		if not Guard.allow(player, "Plot") then
			return
		end
		local profile = DataService.get(player)
		if profile and Guard.isIndex(invIndex, #profile.inventory) then
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
		-- Teste do usuário (08/11): alimentava do outro lado do mapa. Agora só perto do gigante.
		if not PlotService.nearGiant(player) then
			Remotes.Notify:FireClient(player, Locale.msg("feed_far", nil, Color3.fromRGB(255, 170, 60)))
			return
		end
		if type(arg) == "table" then
			local profile = DataService.get(player)
			if profile and Guard.isIndex(arg.inv, #profile.inventory) then
				PlotService.feedFromInventory(player, arg.inv)
			end
		elseif Guard.isIndex(arg, MAX_SLOT_INDEX) then
			PlotService.feed(player, arg)
		end
	end)
	local getFullState: RemoteFunction = Remotes.GetFullState :: any
	getFullState.OnServerInvoke = function(player: Player): boolean?
		if not Guard.allow(player, "FullState") then
			return nil
		end
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
		local ok, isMember = pcall(player.IsInGroupAsync, player, Config.GroupId)
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
		streaks[player] = nil
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
