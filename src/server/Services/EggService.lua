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

local E = GameRules.Eggs
local EggService = {}

local rng = Random.new()
local nestCenter: Vector3? = nil
local busy: { [Player]: boolean } = {}
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

local function nearNest(player: Player, radius: number): boolean
	local root = Guard.rootOf(player)
	local c = nestCenter
	return root ~= nil and c ~= nil and (root.Position - c).Magnitude <= radius
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

function EggService.push(player: Player, open: boolean?)
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
	local level, xp, duplicate, gain = GameLogic.eggApply(rec, def.level)
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
	Analytics.event(player, "egg_hatched", level, { size, speciesId, if duplicate then "dup" else "new" })
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
	})
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
		Remotes.Notify:FireClient(
			player,
			{ text = "Vá até o NINHO na praça.", color = Color3.fromRGB(255, 170, 60) }
		)
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

local function buildNest()
	local map = Workspace:WaitForChild("Map", 60)
	local pad = map and map:WaitForChild("ShopPad", 60)
	if not pad or not pad:IsA("BasePart") then
		warn("[EggService] ShopPad não encontrado; ninho não criado")
		return
	end
	-- ao lado da loja, do lado oposto ao caldeirão (direita de quem olha a loja), no chão
	local cf = pad.CFrame * CFrame.new(-26, 0, -2)
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
		local h = nest.Size.Y
		nest.CFrame = base * CFrame.new(0, h / 2, 0)
		nest.Parent = folder
		top = ground + h * 0.55
	else
		-- reserva sem o modelo: pedestal redondo simples
		local p = Util.makePart({
			Name = "Nest",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 14, 14),
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
	prompt.MaxActivationDistance = 14
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
		Vector3.new(0, 11, 0), -- acima dos cronômetros dos ovos maiores (até 5,2 studs)
		Color3.fromRGB(255, 200, 90)
	)
	label.TextScaled = true
	folder.PrimaryPart = anchor
	folder:SetAttribute("SlotOffsets", "0,0,0;-4.5,0,1.5;4.5,0,1.5") -- posições dos ovos (cliente)
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

function EggService.init()
	Remotes.RequestEgg.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
		warmAcc[p] = nil
	end)
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
	task.spawn(function()
		publishEggModels()
		buildNest()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if on() then
				warmTick()
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
