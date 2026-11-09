--!strict
-- EggService — Sistema de Ovos (aprovado em 08/11/2026; docs/VALIDACAO_OVOS_V1.md). Features.EggSystem.
--
-- Camada separada da Lunchbox: o ovo é um RITUAL (lugar físico, tempo, antecipação) e dá um GIGANTE.
--   * Ninho na praça, ao lado da loja de Lunchboxes (criado em tempo de execução: não muda o mapa assado).
--   * 5 tamanhos (GameRules.Eggs). Pequeno e Médio na loja de moedas; Grande/Enorme/Colossal só como
--     prêmio (Dragão 1 por dia; marcos de nível 100 e 200).
--   * Lugares do ninho por progresso: 1º sempre, 2º no nível 25, 3º no 50 (maior nível já alcançado).
--   * hatchAt absoluto (os.time): choca offline. Fome (-20%) e calor (-10%), 1 vez cada por ovo.
--   * Repetido vira XP daquela espécie; nunca perde nível.
--
-- ORDEM SEGURA DA ECLOSÃO (inegociável, pedido do usuário + vault "fwjelaa Systems - Data and Purchase
-- Guarantees"): valida tudo → sorteia no servidor → tira o ovo e entrega o gigante no MESMO instante,
-- sem nenhum yield no meio → pede um save imediato → SÓ ENTÃO avisa o cliente para animar.
-- Se o save extra falhar, a entrega NÃO é desfeita: o perfil em memória é a verdade (trava de sessão) e
-- o autosave/save de saída gravam. Desfazer apagaria o que o jogador viu (R1 da validação).
--
-- Itens aleatórios: a janela mostra as chances por espécie da MESMA tabela sorteada (GameLogic.eggOdds).
-- Ovos se compram só com moedas; quem tem itens aleatórios pagos restritos não compra moedas com Robux
-- (MonetizationService), então todas as moedas dele foram ganhas jogando (mesma regra das Lunchboxes).
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local CreatureAssets = require(game.ReplicatedStorage.Shared.CreatureAssets)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Analytics = require(script.Parent.Parent.Analytics)
local GameLogic = require(script.Parent.Parent.GameLogic)
local Guard = require(script.Parent.Parent.Guard)
local Hooks = require(script.Parent.Parent.Hooks)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GiantService = require(script.Parent.GiantService)
local DropService = require(script.Parent.DropService)
local MapService = require(script.Parent.MapService)
local CombatService = require(script.Parent.CombatService)
local Speed = require(script.Parent.Parent.Speed)

local E = GameRules.Eggs
local EggService = {}

local rng = Random.new()
local nestCenter: Vector3? = nil
local busy: { [Player]: boolean } = {}
local lastAnnounce = -math.huge
local warmAcc: { [Player]: { [string]: number } } = {}

local function on(): boolean
	return Features.on("EggSystem")
end

local function slotKeys(n: number): { string }
	local out = {}
	for i = 1, n do
		table.insert(out, tostring(i))
	end
	return out
end

local function commonFoodIndex(profile: any): number?
	for i, f in profile.inventory do
		local def = Config.FoodById[f.id]
		if def and def.rarity == "Common" then
			return i
		end
	end
	return nil
end

-- 09/11: cada base tem o seu ninho (Features.EggSteal). índice da base -> modelo e centro.
local baseNests: { [number]: { model: Model, center: Vector3, eggs: Folder } } = {}

local function ownNestCenter(player: Player): Vector3?
	local base = MapService.getBaseOf(player)
	local n = base and baseNests[base.index]
	return n and n.center
end

-- Perto do ninho da praça OU do ninho da própria base.
local function nearNest(player: Player, radius: number): boolean
	local root = Guard.rootOf(player)
	if not root then
		return false
	end
	local c = nestCenter
	if c and (root.Position - c).Magnitude <= radius then
		return true
	end
	local own = ownNestCenter(player)
	return own ~= nil and (root.Position - own).Magnitude <= radius
end

function EggService.state(player: Player): { [string]: any }?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local common = 0
	for _, f in profile.inventory do
		local def = Config.FoodById[f.id]
		if def and def.rarity == "Common" then
			common += 1
		end
	end
	return {
		eggs = profile.eggs,
		nest = profile.nest,
		slots = GameLogic.eggSlots(profile.peakLevel),
		now = os.time(),
		commonFood = common,
		coins = profile.coins,
	}
end

local renderBaseEggs: (Player) -> () -- definida mais abaixo (ninho da base)

function EggService.push(player: Player, open: boolean?)
	renderBaseEggs(player)
	local st = EggService.state(player)
	if st then
		st.open = open == true
		Remotes.EggState:FireClient(player, st)
	end
end

-- Entrega um ovo de PRÊMIO. Devolve false se não coube (quem chamou não marca o prêmio como dado,
-- então ele volta a ser tentado depois: nunca some em silêncio).
function EggService.giveEgg(player: Player, size: string, reason: string): boolean
	local profile = DataService.get(player)
	if not profile or not E.Sizes[size] then
		return false
	end
	if #profile.eggs >= E.MaxStoredHard then
		Remotes.Notify:FireClient(player, {
			text = "Você ganhou um ovo, mas está com ovos demais guardados. Choque um para receber!",
			color = Color3.fromRGB(255, 170, 60),
		})
		return false
	end
	table.insert(profile.eggs, size)
	DataService.markDirty(player)
	Analytics.event(player, "egg_received", 1, { size, reason })
	Remotes.Notify:FireClient(player, {
		text = string.format("Você ganhou um %s! Leve ao NINHO na praça.", E.Sizes[size].name),
		color = Config.Rarities[E.Sizes[size].rarity].color,
	})
	EggService.push(player)
	return true
end

---------------------------------------------------------------------------
-- Ações do jogador (todas validadas no servidor)
---------------------------------------------------------------------------
local function buy(player: Player, profile: any, size: any)
	local def = type(size) == "string" and E.Sizes[size]
	if not def or not def.price then
		return
	end
	if #profile.eggs >= E.MaxStored then
		Remotes.Notify:FireClient(player, {
			text = string.format("Você já tem %d ovos guardados. Choque um antes de comprar.", E.MaxStored),
			color = Color3.fromRGB(255, 90, 90),
		})
		return
	end
	if profile.coins < def.price then
		Remotes.Notify:FireClient(player, { text = "Moedas insuficientes!", color = Color3.fromRGB(255, 90, 90) })
		return
	end
	profile.coins -= def.price
	table.insert(profile.eggs, size)
	DataService.markDirty(player)
	PlotService.pushState(player)
	Analytics.event(player, "egg_bought", def.price, { size })
	Remotes.Notify:FireClient(player, {
		text = def.name .. " comprado! Coloque no ninho para chocar.",
		color = Config.Rarities[def.rarity].color,
	})
end

local function place(player: Player, profile: any, index: any)
	if not Guard.isIndex(index, #profile.eggs) then
		return
	end
	local free: string? = nil
	for _, k in slotKeys(GameLogic.eggSlots(profile.peakLevel)) do
		if profile.nest[k] == nil then
			free = k
			break
		end
	end
	if not free then
		Remotes.Notify:FireClient(player, {
			text = "O ninho está ocupado. Espere chocar (mais lugares nos níveis 25 e 50).",
			color = Color3.fromRGB(255, 170, 60),
		})
		return
	end
	local size: string = table.remove(profile.eggs, index) :: any
	local def = E.Sizes[size]
	profile.nest[free] = { size = size, hatchAt = os.time() + def.seconds, fed = false, warmed = false }
	local acc = warmAcc[player]
	if acc then
		acc[free] = nil
	end
	DataService.markDirty(player)
	Analytics.event(player, "egg_placed", def.seconds, { size })
end

local function feed(player: Player, profile: any, key: any)
	local slot = type(key) == "string" and profile.nest[key]
	if not slot or slot.fed or os.time() >= slot.hatchAt then
		return
	end
	local idx = commonFoodIndex(profile)
	if not idx then
		Remotes.Notify:FireClient(player, {
			text = "Você precisa de uma comida Comum na mochila para alimentar o ovo.",
			color = Color3.fromRGB(255, 170, 60),
		})
		return
	end
	table.remove(profile.inventory, idx)
	slot.fed = true
	slot.hatchAt = GameLogic.eggSpeedUp(slot.hatchAt, os.time(), E.FeedCut)
	DataService.markDirty(player)
	PlotService.pushState(player)
	Analytics.event(player, "egg_need_fed", 1, { slot.size })
	Analytics.event(player, "egg_care_star", 1, { slot.size, "fed" })
	Remotes.Notify:FireClient(
		player,
		{ text = "Ovo alimentado! -20% do tempo.", color = Color3.fromRGB(120, 230, 120) }
	)
end

local checkMilestones: (Player) -> () -- definida mais abaixo (prêmios por nível)

local function hatch(player: Player, profile: any, key: any)
	local slot = type(key) == "string" and profile.nest[key]
	if not slot or os.time() < slot.hatchAt or busy[player] then
		return
	end
	busy[player] = true
	-- 1) sorteio no servidor; 2) entrega e remoção SEM yield (mesmo instante)
	local size = slot.size
	local def = E.Sizes[size]
	local speciesId = if slot.species and Config.SpeciesById[slot.species]
		then slot.species -- ovo de tutorial: espécie definida ao colocar
		else GameLogic.eggRoll(size, rng:NextNumber())
	local isActive = speciesId == profile.species
	local rec: any = nil
	if isActive then
		rec = { level = profile.level, xp = profile.xp }
	elseif profile.ownedSpecies[speciesId] then
		rec = profile.giants[speciesId] or { level = 1, xp = 0 }
	end
	local levelBefore = profile.level
	local stars = GameLogic.eggStars(slot)
	local level, xp, duplicate, gain = GameLogic.eggApply(rec, def.level, stars)
	if not duplicate then
		-- espécie nova: nasce no nível do ovo, ou no herdado (30%) se for maior; nunca perde nada
		local hl, hx = GameLogic.inherit(profile.level, profile.xp)
		if hl > level then
			level, xp = hl, hx
		end
		profile.ownedSpecies[speciesId] = true
		profile.giants[speciesId] = { level = level, xp = xp, inherited = false }
	elseif isActive then
		profile.level, profile.xp = level, xp
	else
		profile.giants[speciesId] = { level = level, xp = xp, inherited = rec.inherited }
	end
	profile.peakLevel = math.max(profile.peakLevel, level)
	profile.nest[key] = nil
	local acc = warmAcc[player]
	if acc then
		acc[key] = nil -- o próximo ovo neste lugar começa o calor do zero (revisão cega)
	end
	profile.eggsHatched += 1
	DataService.markDirty(player)
	Analytics.event(
		player,
		"egg_hatched",
		level,
		{ size, speciesId, (if duplicate then "dup" else "new") .. tostring(stars) }
	)
	-- 3) save imediato; 4) só então a animação. pcall: um erro no save nunca deixa o ninho travado
	-- (revisão cega: busy ficava preso se saveNow lançasse erro).
	local okSave, saved = pcall(DataService.saveNow, player)
	busy[player] = nil
	if not okSave or not saved then
		warn("[EggService] save extra falhou; a entrega fica no perfil em memória (autosave/saída gravam)")
	end
	-- Nível do gigante ativo subiu pelo XP de repetido: avisa os outros sistemas (recordes, marcos).
	if isActive and profile.level > levelBefore then
		Hooks.fire("leveled", player, profile.level - levelBefore, profile.level)
	end
	checkMilestones(player)
	if player.Parent == nil then
		return
	end
	Remotes.EggHatched:FireClient(player, {
		size = size,
		speciesId = speciesId,
		level = level,
		duplicate = duplicate,
		xp = gain,
		stars = stars,
	})
	-- Vitrine (Ovos v2): espécie NOVA Épica ou melhor é anunciada para o servidor (1 a cada 10 s).
	local sp = Config.SpeciesById[speciesId]
	local order = ({ ["Épico"] = 4, ["Lendário"] = 5, ["Mítico"] = 6 } :: { [string]: number })[sp and sp.rarityTag or ""]
		or 0
	if not duplicate and order >= E.RareAnnounceOrder and os.clock() - lastAnnounce >= 10 then
		lastAnnounce = os.clock()
		Remotes.Notify:FireAllClients({
			text = string.format("%s chocou um %s (%s)!", player.DisplayName, sp.name, sp.rarityTag),
			color = Color3.fromRGB(255, 200, 80),
		})
	end
	if not duplicate then
		Hooks.fire("speciesUnlocked", player, speciesId)
	end
	if isActive then
		GiantService.refresh(player, true)
	end
	PlotService.pushState(player)
	EggService.push(player)
end

local ACTIONS: { [string]: (Player, any, any) -> () } = {
	buy = buy,
	place = place,
	feed = feed,
	hatch = hatch,
}

local function onRequest(player: Player, action: any, arg: any)
	if not on() or type(action) ~= "string" or not Guard.allow(player, "Egg") then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if action == "open" then
		EggService.push(player, true)
		return
	end
	local fn = ACTIONS[action]
	if not fn then
		return
	end
	-- todas as ações acontecem no ninho (o servidor mede a distância)
	if not nearNest(player, E.NestReach) then
		Remotes.Notify:FireClient(player, {
			text = if Features.on("EggSteal")
				then "Vá até o SEU NINHO (na sua base) ou o ninho da praça."
				else "Vá até o NINHO na praça.",
			color = Color3.fromRGB(255, 170, 60),
		})
		return
	end
	fn(player, profile, arg)
	if action ~= "hatch" then
		EggService.push(player)
	end
end

---------------------------------------------------------------------------
-- Ninho no mundo
---------------------------------------------------------------------------
local function loadMesh(name: string): MeshPart?
	local id = (CreatureAssets :: any)[name]
	local numeric = id and tonumber(string.match(id, "%d+"))
	if not numeric then
		return nil
	end
	local ok, model = pcall(function()
		return InsertService:LoadAsset(numeric :: number)
	end)
	if not ok or not model then
		warn("[EggService] não carregou", name, model)
		return nil
	end
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		mesh.Parent = nil
		-- A cor padrão da MeshPart (163,162,165) multiplica a textura e apaga as cores originais
		-- (mesmo bug das comidas cinza, item 13 de 08/11). Branco = cor da textura exata.
		mesh.Color = Color3.new(1, 1, 1)
	end
	model:Destroy()
	return mesh
end

local NEST_PHI = 270
local NEST_R = 64
local NEST_WIDTH = 26
local NEST_EGG_SCALE = 1.6

local function buildNest()
	local map = Workspace:WaitForChild("Map", 60)
	local pad = map and map:WaitForChild("ShopPad", 60)
	if not pad or not pad:IsA("BasePart") then
		warn("[EggService] ShopPad não encontrado; ninho não criado")
		return
	end
	-- 09/11 (item 2, pedido do usuário): o ninho era pequeno e escondido ao lado da loja. Agora é GRANDE
	-- e fica no vão vazio da praça, do lado oposto à arena (φ 270°, r 64 do caldeirão), virado para o centro.
	local phi = math.rad(NEST_PHI)
	local spot = Vector3.new(math.sin(phi) * NEST_R, pad.Position.Y, -math.cos(phi) * NEST_R)
	local cf = CFrame.lookAt(spot, Vector3.new(0, spot.Y, 0))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { pad }
	local hit = Workspace:Raycast(cf.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local ground = if hit then hit.Position.Y else pad.Position.Y
	local base = CFrame.new(cf.Position.X, ground, cf.Position.Z) * (cf - cf.Position)

	local folder = Instance.new("Model")
	folder.Name = "EggNest"
	local nest = loadMesh("egg-nest")
	local top = ground + 1
	if nest then
		nest.Name = "Nest"
		nest.Anchored = true
		nest.CanCollide = true
		local k = NEST_WIDTH / math.max(nest.Size.X, nest.Size.Z, 0.01)
		nest.Size = nest.Size * k
		local h = nest.Size.Y
		nest.CFrame = base * CFrame.new(0, h / 2, 0)
		nest.Parent = folder
		top = ground + h * 0.55
	else
		-- reserva sem o modelo: pedestal redondo simples
		local p = Util.makePart({
			Name = "Nest",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, NEST_WIDTH, NEST_WIDTH),
			CFrame = base * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(214, 110, 60),
			Material = Enum.Material.SmoothPlastic,
		})
		p.Parent = folder
		top = ground + 2
	end
	local anchor = Util.makePart({
		Name = "Center",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(base.Position.X, top, base.Position.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	anchor.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenNest"
	prompt.ActionText = "NINHO DE OVOS"
	prompt.ObjectText = "Chocar gigantes"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(p)
		if on() and Guard.allow(p, "Egg") then
			EggService.push(p, true)
		end
	end)
	local label = Util.makeBillboard(
		anchor,
		"NINHO DE OVOS",
		UDim2.fromOffset(240, 50),
		Vector3.new(0, 16, 0), -- acima dos cronômetros dos ovos maiores (até 5,2 × 1,6 studs)
		Color3.fromRGB(255, 200, 90)
	)
	label.TextScaled = true
	folder.PrimaryPart = anchor
	folder:SetAttribute("SlotOffsets", "0,0,0;-7,0,2.5;7,0,2.5") -- posições dos ovos (cliente)
	folder:SetAttribute("EggScale", NEST_EGG_SCALE) -- ovos no ninho maiores (item 2)
	folder.Parent = Workspace
	nestCenter = anchor.Position
end

-- Modelos dos ovos para o cliente (janela de eclosão e ovos no ninho).
local function publishEggModels()
	local folder = Instance.new("Folder")
	folder.Name = "EggModels"
	for size, def in E.Sizes do
		local mesh = loadMesh(def.model)
		if mesh then
			mesh.Name = size
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

---------------------------------------------------------------------------
-- Calor (servidor mede) e prêmios
---------------------------------------------------------------------------
local function warmTick()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile and next(profile.nest) ~= nil then
			local acc = warmAcc[player] or {}
			warmAcc[player] = acc
			local near = nearNest(player, E.WarmRadius)
			for key, slot in profile.nest do
				if not slot.warmed and now < slot.hatchAt then
					acc[key] = if near then (acc[key] or 0) + 1 else 0
					if acc[key] >= E.WarmSeconds then
						acc[key] = 0
						slot.warmed = true
						slot.hatchAt = GameLogic.eggSpeedUp(slot.hatchAt, now, E.WarmCut)
						DataService.markDirty(player)
						Analytics.event(player, "egg_need_warmed", 1, { slot.size })
						Analytics.event(player, "egg_care_star", 1, { slot.size, "warm" })
						Remotes.Notify:FireClient(player, {
							text = "Ovo aquecido! -10% do tempo.",
							color = Color3.fromRGB(255, 180, 90),
						})
						EggService.push(player)
					end
				end
			end
		end
	end
end

function checkMilestones(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	for _, m in E.Milestones do
		local key = tostring(m.level)
		if profile.peakLevel >= m.level and not profile.eggMilestones[key] then
			if EggService.giveEgg(player, m.size, "milestone") then
				profile.eggMilestones[key] = true
			end
		end
	end
end

---------------------------------------------------------------------------
-- 09/11: NINHO EM CADA BASE + ROUBO LEVE DE OVO (GameRules.EggSteal)
---------------------------------------------------------------------------
local NEST_SPOT = CFrame.new(23, 0, 6) -- canto livre da base (pátio até x 16,5; escudo em 22,-18)
local NEST_WIDTH_BASE = 13
local BASE_EGG_SCALE = 1.15
-- ovos em triângulo, afastados (o Grande chega a ~4 studs de largura): não encostam um no outro
local NEST_OFFSETS = { Vector3.new(0, 0, -2.6), Vector3.new(-4.2, 0, 2.2), Vector3.new(4.2, 0, 2.2) }

type EggCarry = {
	size: string,
	from: Player,
	pickedAt: number,
	pickedPos: Vector3,
	model: Model?,
}
local carryingEgg: { [Player]: EggCarry } = {}
local eggChanneling: { [Player]: boolean } = {}

local function groundBelow(pos: Vector3): Vector3
	local hit = Workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0))
	return if hit then hit.Position else pos
end

local function buildBaseNests()
	local folder = Instance.new("Folder")
	folder.Name = "BaseNests"
	folder.Parent = Workspace
	for _, base in MapService.Bases do
		local spot = base.origin * NEST_SPOT
		local g = groundBelow(spot.Position)
		local cf = CFrame.new(g) * (spot - spot.Position)
		local model = Instance.new("Model")
		model.Name = "BaseNest" .. base.index
		local mesh = loadMesh("egg-nest")
		local top = g.Y + 1
		if mesh then
			mesh.Name = "Nest"
			mesh.Anchored = true
			mesh.CanCollide = true
			mesh.Size = mesh.Size * (NEST_WIDTH_BASE / math.max(mesh.Size.X, mesh.Size.Z, 0.01))
			mesh.CFrame = cf * CFrame.new(0, mesh.Size.Y / 2, 0)
			mesh.Parent = model
			top = g.Y + mesh.Size.Y * 0.55
		end
		local center = Util.makePart({
			Name = "Center",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(cf.Position.X, top, cf.Position.Z),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		center.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenNest"
		prompt.ActionText = "MEU NINHO"
		prompt.ObjectText = "Ovos"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = center
		prompt.Triggered:Connect(function(p)
			if not on() or not Guard.allow(p, "Egg") then
				return
			end
			if base.owner == p then
				EggService.push(p, true)
			else
				Remotes.Notify:FireClient(p, {
					text = "Este ninho não é seu. Clique num ovo para tentar ROUBAR (segure parado 5 s).",
					color = Color3.fromRGB(255, 200, 80),
				})
			end
		end)
		local eggs = Instance.new("Folder")
		eggs.Name = "Eggs"
		eggs.Parent = model
		model.PrimaryPart = center
		model:SetAttribute(
			"SlotOffsets",
			string.format(
				"%g,0,%g;%g,0,%g;%g,0,%g",
				NEST_OFFSETS[1].X,
				NEST_OFFSETS[1].Z,
				NEST_OFFSETS[2].X,
				NEST_OFFSETS[2].Z,
				NEST_OFFSETS[3].X,
				NEST_OFFSETS[3].Z
			)
		)
		model:SetAttribute("EggScale", BASE_EGG_SCALE)
		model.Parent = folder
		baseNests[base.index] = { model = model, center = center.Position, eggs = eggs }
	end
end

local tryStealEgg: (Player, Model) -> ()

-- Ovos do jogador no ninho da base dele, À VISTA de todos (quem não é o dono pode tentar roubar).
-- O dono vê a versão do cliente (com efeitos); a do servidor fica invisível só para ele.
renderBaseEggs = function(player: Player)
	if not Features.on("EggSteal") then
		return
	end
	local base = MapService.getBaseOf(player)
	local n = base and baseNests[base.index]
	local profile = DataService.get(player)
	if not n or not profile then
		return
	end
	n.model:SetAttribute("OwnerUserId", player.UserId)
	n.eggs:ClearAllChildren()
	local models = ReplicatedStorage:FindFirstChild("EggModels")
	for key, slot in profile.nest do
		local t = models and models:FindFirstChild(slot.size)
		local def = E.Sizes[slot.size]
		if t and t:IsA("BasePart") and def then
			local egg = Instance.new("Model")
			egg.Name = "Egg_" .. key
			local part = t:Clone()
			part.Name = "Body"
			part.Size = part.Size * (def.scale * BASE_EGG_SCALE / math.max(part.Size.Y, 0.01))
			local off = NEST_OFFSETS[tonumber(key) or 1] or Vector3.zero
			part.CFrame = CFrame.new(n.center + off + Vector3.new(0, part.Size.Y / 2, 0))
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = true
			part.Parent = egg
			egg.PrimaryPart = part
			egg:SetAttribute("OwnerUserId", player.UserId)
			egg:SetAttribute("NestKey", key)
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 20
			click.Parent = part
			click.MouseClick:Connect(function(clicker)
				if clicker ~= player then
					tryStealEgg(clicker, egg)
				end
			end)
			Util.makeBillboard(
				part,
				string.format("%s de %s", def.name, player.DisplayName),
				UDim2.fromOffset(200, 34),
				Vector3.new(0, part.Size.Y / 2 + 1.2, 0),
				Config.Rarities[def.rarity].color
			)
			egg.Parent = n.eggs
		end
	end
end

local function attachEggVisual(thief: Player, size: string): Model?
	local char = thief.Character
	local head = char and char:FindFirstChild("Head")
	local models = ReplicatedStorage:FindFirstChild("EggModels")
	local t = models and models:FindFirstChild(size)
	if not head or not head:IsA("BasePart") or not t or not t:IsA("BasePart") then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "CarriedEgg"
	local p = t:Clone()
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Size = p.Size * (2.6 / math.max(p.Size.Y, 0.01))
	p.CFrame = head.CFrame * CFrame.new(0, 2.6, 0)
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = p
	weld.Parent = p
	Util.makeBillboard(
		p,
		"ROUBANDO UM OVO!",
		UDim2.fromOffset(200, 36),
		Vector3.new(0, 2, 0),
		Color3.fromRGB(255, 80, 80)
	)
	model.Parent = char
	return model
end

-- Larga o ovo carregado. returnTo = o ovo VOLTA para a vítima (para a bolsa de ovos dela).
local function dropEgg(thief: Player, returnTo: boolean)
	local c = carryingEgg[thief]
	if not c then
		return
	end
	carryingEgg[thief] = nil
	thief:SetAttribute("CarryingEgg", nil)
	Speed.set(thief, "egg", nil)
	if c.model then
		c.model:Destroy()
	end
	if returnTo and c.from.Parent then
		local vp = DataService.get(c.from)
		if vp then
			table.insert(vp.eggs, c.size) -- volta mesmo acima do limite: o ovo já era dela
			DataService.markDirty(c.from)
			Remotes.Notify:FireClient(c.from, {
				text = "O ladrão derrubou o seu ovo: ele VOLTOU para você (coloque no ninho de novo)!",
				color = Color3.fromRGB(80, 255, 120),
			})
			EggService.push(c.from)
		end
	end
end

function EggService.isCarryingEgg(player: Player): boolean
	return carryingEgg[player] ~= nil
end

function EggService.dropCarriedEgg(player: Player)
	dropEgg(player, true)
end

local EGG_STEAL_TEXT = {
	newbie = "Este jogador é novo: os ovos dele não podem ser roubados.",
	last = "Não dá para roubar o ÚLTIMO ovo de alguém.",
	hatching = "Este ovo está quase chocando: não dá mais para roubar.",
	immune = "Este jogador acabou de perder um ovo: está protegido por 20 min.",
	daily = "Você já roubou 2 ovos hoje. Volte amanhã!",
}

tryStealEgg = function(thief: Player, egg: Model)
	if not on() or not Features.on("EggSteal") or not Guard.allow(thief, "Egg") then
		return
	end
	if
		carryingEgg[thief]
		or eggChanneling[thief]
		or thief:GetAttribute("CarryingSteal")
		or thief:GetAttribute("CarryingDrop")
	then
		return
	end
	local part = egg.PrimaryPart
	local ownerId = egg:GetAttribute("OwnerUserId")
	local key = egg:GetAttribute("NestKey")
	if not part or type(ownerId) ~= "number" or type(key) ~= "string" or not Guard.withinReach(thief, part, 20) then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner or owner == thief then
		return
	end
	local vp = DataService.get(owner)
	local tp = DataService.get(thief)
	local slot = vp and vp.nest[key]
	if not vp or not tp or not slot then
		return
	end
	if vp.shieldUntil > os.time() then
		Remotes.Notify:FireClient(
			thief,
			{ text = "Esta base está protegida por um escudo!", color = Color3.fromRGB(80, 200, 255) }
		)
		return
	end
	local count = 0
	for _ in vp.nest do
		count += 1
	end
	local now = os.time()
	local ok, why = GameLogic.eggStealAllowed(
		GameLogic.victimProgress(vp.level, vp.peakLevel, vp.rebirths),
		count,
		slot.hatchAt - now,
		vp.eggStolenAt,
		tp.eggStealDay,
		tp.eggStealsToday,
		now
	)
	if not ok then
		Remotes.Notify:FireClient(
			thief,
			{ text = EGG_STEAL_TEXT[why :: string] or "Não dá agora.", color = Color3.fromRGB(255, 200, 80) }
		)
		return
	end
	if #tp.eggs >= E.MaxStoredHard then
		Remotes.Notify:FireClient(
			thief,
			{ text = "Você já tem ovos demais guardados.", color = Color3.fromRGB(255, 170, 60) }
		)
		return
	end
	local def = E.Sizes[slot.size]
	local hatchAt0 = slot.hatchAt
	eggChanneling[thief] = true
	Remotes.StealAlert:FireClient(owner, { thiefName = thief.DisplayName, food = "o seu " .. def.name })
	Remotes.Notify:FireClient(thief, {
		text = string.format("Roubando %s... fique PARADO por %d s!", def.name, GameRules.EggSteal.ChannelSeconds),
		color = Color3.fromRGB(255, 200, 80),
	})
	local okRun, alive = pcall(function(): boolean
		local r0 = Guard.rootOf(thief)
		local p0 = r0 and r0.Position
		local t0 = os.clock()
		local still = p0 ~= nil
		while still and os.clock() - t0 < GameRules.EggSteal.ChannelSeconds do
			task.wait(0.1)
			local r = Guard.rootOf(thief)
			still = r ~= nil
				and p0 ~= nil
				and (r.Position - p0).Magnitude <= 6
				and not CombatService.isKO(thief)
				and egg.Parent ~= nil
		end
		return still
	end)
	eggChanneling[thief] = nil
	-- reconfere tudo depois dos 5 s
	local cur: any = DataService.get(owner)
	local still = cur and cur.nest[key]
	if
		not okRun
		or not alive
		or not owner.Parent
		or not cur
		or not still
		or still.hatchAt ~= hatchAt0
		or cur.shieldUntil > os.time()
	then
		Remotes.Notify:FireClient(thief, { text = "Roubo do ovo cancelado.", color = Color3.fromRGB(255, 90, 90) })
		return
	end
	local size = still.size
	cur.nest[key] = nil
	cur.eggStolenAt = os.time()
	local refund = GameLogic.eggStealRefund(def.price)
	cur.coins += refund
	DataService.markDirty(owner)
	EggService.push(owner)
	PlotService.pushState(owner)
	Remotes.Notify:FireClient(owner, {
		text = string.format(
			"%s roubou o seu %s! Você ganhou %d moedas de consolo. SOQUE o ladrão para o ovo voltar!",
			thief.DisplayName,
			def.name,
			refund
		),
		color = Color3.fromRGB(255, 70, 70),
	})
	local r = Guard.rootOf(thief)
	carryingEgg[thief] = {
		size = size,
		from = owner,
		pickedAt = os.clock(),
		pickedPos = if r then r.Position else part.Position,
		model = attachEggVisual(thief, size),
	}
	thief:SetAttribute("CarryingEgg", true)
	Speed.set(thief, "egg", GameRules.EggSteal.CarrySpeed)
	Analytics.event(thief, "egg_stolen", 1, { size })
	Remotes.Notify:FireClient(thief, {
		text = "Pegou o ovo! Leve até a SUA base (um soco faz você derrubar).",
		color = Color3.fromRGB(80, 255, 120),
	})
end

-- Chegou na própria base com o ovo: entra na bolsa de ovos do ladrão.
local function depositTick()
	for thief, c in carryingEgg do
		local base = MapService.getBaseOf(thief)
		local root = Guard.rootOf(thief)
		if base and root then
			local here = base.origin:PointToObjectSpace(root.Position)
			local half = Config.BaseSize / 2 + 4
			local minTime = math.max(0, (base.origin.Position - c.pickedPos).Magnitude - Config.BaseSize * 0.75) / 45
			if math.abs(here.X) <= half and math.abs(here.Z) <= half and os.clock() - c.pickedAt >= minTime then
				carryingEgg[thief] = nil
				thief:SetAttribute("CarryingEgg", nil)
				Speed.set(thief, "egg", nil)
				if c.model then
					c.model:Destroy()
				end
				local tp = DataService.get(thief)
				if tp then
					tp.eggStealDay, tp.eggStealsToday =
						GameLogic.countSteal(tp.eggStealDay, tp.eggStealsToday, os.time() // 86400)
					table.insert(tp.eggs, c.size)
					DataService.markDirty(thief)
					EggService.push(thief)
					Remotes.Notify:FireClient(thief, {
						text = string.format("Ovo roubado guardado: %s! Coloque no seu ninho.", E.Sizes[c.size].name),
						color = Config.Rarities[E.Sizes[c.size].rarity].color,
					})
				end
			end
		end
	end
end

function EggService.init()
	Remotes.RequestEgg.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
		warmAcc[p] = nil
		eggChanneling[p] = nil
		dropEgg(p, true) -- ladrão saiu do jogo: o ovo volta para a vítima
		for thief, c in carryingEgg do
			if c.from == p then
				dropEgg(thief, false) -- a vítima saiu: o ovo some com ela (já era dela)
			end
		end
		local base = MapService.getBaseOf(p)
		local n = base and baseNests[base.index]
		if n then
			n.eggs:ClearAllChildren()
			n.model:SetAttribute("OwnerUserId", nil)
		end
	end)
	-- Ladrão de ovo que leva soco derruba o ovo (volta para a vítima).
	local prevHit = CombatService.OnHit
	CombatService.OnHit = function(attacker: Player, victim: Player, heavy: boolean)
		if prevHit then
			prevHit(attacker, victim, heavy)
		end
		if carryingEgg[victim] then
			dropEgg(victim, true)
			Remotes.Notify:FireClient(
				victim,
				{ text = "Você levou um soco e derrubou o ovo!", color = Color3.fromRGB(255, 90, 90) }
			)
		end
	end
	local prevNpcKO = CombatService.OnNpcKO
	CombatService.OnNpcKO = function(victim: Player, source: string)
		if prevNpcKO then
			prevNpcKO(victim, source)
		end
		if carryingEgg[victim] then
			dropEgg(victim, true)
		end
	end
	Hooks.on("bossHelped", function(player: Player)
		if not on() then
			return
		end
		local profile = DataService.get(player)
		local today = os.time() // 86400
		if profile and profile.eggBossDay ~= today then
			if EggService.giveEgg(player, E.BossEggSize, "boss") then
				profile.eggBossDay = today
			end
		end
	end)
	Hooks.on("leveled", function(player: Player)
		if on() then
			checkMilestones(player)
		end
	end)
	-- Ovos v2: estrela de LAÇO. Cada vez que o jogador alimenta o PRÓPRIO gigante, os ovos chocando
	-- dele contam 1 (até o número do tamanho). Liga o ninho ao verbo principal do jogo.
	Hooks.on("fed", function(player: Player)
		if not on() then
			return
		end
		local profile = DataService.get(player)
		if not profile or next(profile.nest) == nil then
			return
		end
		local now = os.time()
		local changed = false
		for _, slot in profile.nest do
			local need = E.BondFeeds[slot.size] or math.huge
			local bond = slot.bond or 0
			if now < slot.hatchAt and bond < need then
				slot.bond = bond + 1
				changed = true
				if slot.bond >= need then
					Analytics.event(player, "egg_care_star", 1, { slot.size, "bond" })
					Remotes.Notify:FireClient(player, {
						text = "Seu ovo sentiu o gigante comer: estrela de LAÇO!",
						color = Color3.fromRGB(255, 220, 120),
					})
				end
			end
		end
		if changed then
			DataService.markDirty(player)
			EggService.push(player)
		end
	end)
	-- Ovos v2: ovos do mapa chegam pelo DropService (sem require circular).
	DropService.EggSink = function(player: Player, size: string): boolean
		if not on() then
			return false
		end
		-- confere o espaço ANTES: sem lugar, o DropService devolve o ovo ao chão com o aviso dele
		-- (antes saíam dois avisos contraditórios; revisão cega 09/11)
		local profile = DataService.get(player)
		if not profile or #profile.eggs >= E.MaxStoredHard then
			return false
		end
		local ok = EggService.giveEgg(player, size, "drop")
		if ok then
			Analytics.event(player, "egg_drop_delivered", 1, { size })
		end
		return ok
	end
	task.spawn(function()
		publishEggModels()
		buildNest()
		if Features.on("EggSteal") then
			buildBaseNests()
			for _, pl in Players:GetPlayers() do
				renderBaseEggs(pl)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if on() then
				warmTick()
				depositTick()
			end
		end
	end)
end

-- Ao entrar: estado inicial e marcos já alcançados (quem já passou do nível 100 antes dos ovos).
function EggService.onJoin(player: Player)
	if not on() then
		return
	end
	checkMilestones(player)
	EggService.push(player)
end

return EggService
