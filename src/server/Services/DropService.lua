--!strict
-- DropService — COMIDAS E LUNCHBOXES QUE CAEM NO MAPA (reforma de 08/11/2026, pedido do usuário).
--
-- Antes: o círculo de disputa ("segure o círculo") e, na Chuva de Comida, comidas que entravam na
-- mochila só de encostar. O usuário pegou 20 a 50 comidas sem disputa, o que tirava o valor das caixas.
--
-- Agora (um sistema só para drops normais e para a Chuva):
--   1. O item cai do céu e fica no chão, com um cronômetro em cima ("libera em 0:12").
--   2. Enquanto o cronômetro corre, ninguém pega. O tempo depende da raridade (comida comum: na hora;
--      raras e caixas: mais expectativa e mais disputa) — Config.Drops.UnlockByRarity/UnlockByBox.
--   3. Liberado, o jogador PRECISA interagir (ProximityPrompt: E no teclado, X no controle, toque no
--      celular). Nada entra na mochila só de passar por cima.
--   4. O item vai para cima da cabeça e o jogador anda mais devagar quanto mais raro (peso).
--   5. Soco ou nocaute derrubam a carga no chão (libera de novo em ~1,5 s): qualquer um pode pegar.
--   6. Na própria base: comida vai para o pátio (rende moedas) ou, sem vaga, para a mochila; caixa vai
--      para "caixas guardadas" e o jogador escolhe quando abrir (não abre sozinha).
-- Tudo no servidor: distância, liberação, um item por vez, tempo mínimo de viagem (anti-teleporte),
-- dono da base. Um item só existe em um lugar (no chão, numa cabeça ou entregue): sem duplicar.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Speed = require(script.Parent.Parent.Speed)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Features = require(game.ReplicatedStorage.Shared.Features)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Hooks = require(script.Parent.Parent.Hooks)
local UIAssets = require(game.ReplicatedStorage.Shared.UIAssets)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CombatService = require(script.Parent.CombatService)
local MapService = require(script.Parent.MapService)
local Guard = require(script.Parent.Parent.Guard)
local FoodModels = require(script.Parent.Parent.FoodModels)
local ShopService = require(script.Parent.ShopService)

local DropService = {}

-- Ovos v2: (player, tamanho) -> entregue? Preenchido pelo EggService (sem require circular).
DropService.EggSink = nil :: ((Player, string) -> boolean)?
local D = Config.Drops

local MAX_TRAVEL_SPEED = 45 -- igual ao StealService: mais rápido que isso = teleporte
local DEPOSIT_MARGIN = 6

export type Kind = "food" | "box" | "egg"

type Item = {
	id: number,
	kind: Kind,
	foodId: string?,
	boxId: string?,
	eggSize: string?, -- Ovos v2: ovo do mapa (tamanho), entregue nos ovos guardados
	name: string,
	rarity: string, -- raridade da comida ou da caixa (para cor e peso)
	color: Color3,
	pos: Vector3,
	holder: Part, -- peça no chão (ou na cabeça)
	label: TextLabel,
	prompt: ProximityPrompt,
	unlockAt: number, -- os.clock()
	carrier: Player?,
	pickedAt: number,
	pickedPos: Vector3,
	landed: boolean,
	expiresAt: number,
	done: boolean,
}

local items: { [number]: Item } = {}
local carrying: { [Player]: Item } = {}
local baseSpeed: { [Player]: number } = {}
local nextId = 0
local folder: Folder

local BOX_RARITY = { common = "Common", rare = "Rare", epic = "Epic", legendary = "Legendary", mythic = "Mythic" }

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function activeCount(): number
	local n = 0
	for _, it in items do
		if not it.carrier then
			n += 1
		end
	end
	return n
end

local function pickFood(): Config.FoodDef
	local noRare = #Players:GetPlayers() < D.MinPlayersForRare
	local weights: { [string]: number } = {}
	for rawRarity, w in D.Weights do
		local r = rawRarity :: string
		if not (noRare and (r == "Legendary" or r == "Mythic" or r == "Secret")) then
			weights[r] = w :: number
		end
	end
	local rarity = Util.weightedPick(weights, 0)
	local pool = {}
	for _, f in Config.Foods do
		if f.rarity == rarity then
			table.insert(pool, f)
		end
	end
	if #pool == 0 then
		return Config.Foods[1]
	end
	return pool[math.random(1, #pool)]
end

local function pickBox(): string
	local noRare = #Players:GetPlayers() < D.MinPlayersForRare
	local weights: { [string]: number } = {}
	for id, w in D.BoxWeights do
		if not (noRare and (id == "legendary" or id == "mythic")) then
			weights[id :: string] = w :: number
		end
	end
	return Util.weightedPick(weights, 0)
end

local function broadcast(it: Item)
	Remotes.DropState:FireAllClients({
		id = it.id,
		kind = it.kind,
		foodId = it.foodId,
		boxId = it.boxId,
		name = it.name,
		rarity = it.rarity,
		pos = if it.carrier then nil else it.holder.Position,
		unlockAt = serverNow() + math.max(0, it.unlockAt - os.clock()),
		carrierId = if it.carrier then it.carrier.UserId else nil,
		carrierName = if it.carrier then it.carrier.DisplayName else nil,
		landed = it.landed,
	})
end

local function remove(it: Item)
	it.done = true
	items[it.id] = nil
	Remotes.DropState:FireAllClients({ id = it.id, removed = true })
	it.holder:Destroy()
end

-- Etiqueta do mundo: nome, raridade e o estado (caindo / libera em X / PEGUE!).
local function updateLabel(it: Item)
	local rar = Locale.rarity(it.rarity)
	if it.carrier then
		it.label.Text = string.format("%s (%s)", it.name, rar)
	elseif not it.landed then
		it.label.Text = string.format("%s (%s)\nCaindo!", it.name, rar)
	else
		local left = math.ceil(it.unlockAt - os.clock())
		if left > 0 then
			it.label.Text = string.format("%s (%s)\n🔒 libera em %d:%02d", it.name, rar, left // 60, left % 60)
		else
			it.label.Text = string.format("%s (%s)\nPEGUE! [E]", it.name, rar)
		end
	end
end

-- Visual do item: comida 3D ou a caixa (imagem da skin nova, de frente para a câmera, sobre uma
-- caixa colorida). Indicador no chão discreto (pequeno disco + brilho leve), pedido do usuário: o
-- círculo Neon grande antigo "ofuscava" o mapa.
-- Pernil cartoon (mesmas cores do pedaço grande do MeatService), ~3,6 studs, sem colisão.
local function dressMeatPortion(holder: BasePart)
	local function piece(name: string, shape: Enum.PartType, size: Vector3, color: Color3, offset: CFrame): Part
		local p = Util.makePart({
			Name = name,
			Shape = shape,
			Size = size,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CFrame = holder.CFrame * offset,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			Anchored = false,
			Parent = holder,
		})
		local w = Instance.new("WeldConstraint")
		w.Part0 = holder
		w.Part1 = p
		w.Parent = p
		return p
	end
	local meat = piece("Meat", Enum.PartType.Ball, Vector3.new(3, 3, 3), Color3.fromRGB(150, 78, 52), CFrame.new())
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = Vector3.new(1.3, 0.85, 1)
	m.Parent = meat
	local fat = piece(
		"Fat",
		Enum.PartType.Ball,
		Vector3.new(3.1, 3.1, 3.1),
		Color3.fromRGB(240, 196, 160),
		CFrame.new(0, 0.6, 0)
	)
	local fm = Instance.new("SpecialMesh")
	fm.MeshType = Enum.MeshType.Sphere
	fm.Scale = Vector3.new(1.15, 0.45, 0.9)
	fm.Parent = fat
	piece(
		"Bone",
		Enum.PartType.Cylinder,
		Vector3.new(2.2, 0.6, 0.6),
		Color3.fromRGB(250, 244, 228),
		CFrame.new(2.6, 0.2, 0)
	)
	piece("BoneKnob", Enum.PartType.Ball, Vector3.new(1, 1, 1), Color3.fromRGB(250, 244, 228), CFrame.new(3.7, 0.2, 0))
end

local function buildHolder(it: Item, at: Vector3): Part
	local rarColor = it.color
	local holder = Util.makePart({
		Name = "Drop_" .. it.id,
		Size = if it.kind == "box" then Vector3.new(3, 2.2, 2.2) else Vector3.new(2.6, 2.6, 2.6),
		Color = rarColor,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0,
		CFrame = CFrame.new(at),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	if it.kind == "egg" and it.eggSize then
		-- Ovos v2: o mesmo modelo do ninho (EggService publica em ReplicatedStorage.EggModels)
		local models = game:GetService("ReplicatedStorage"):FindFirstChild("EggModels")
		local t = models and models:FindFirstChild(it.eggSize)
		if t and t:IsA("BasePart") then
			holder.Transparency = 1
			local egg = t:Clone()
			local k = 3 / math.max(egg.Size.Y, 0.01)
			egg.Size = egg.Size * k
			egg.Anchored = false
			egg.Massless = true
			egg.CanCollide = false
			egg.CFrame = holder.CFrame
			local w = Instance.new("WeldConstraint")
			w.Part0 = holder
			w.Part1 = egg
			w.Parent = egg
			egg.Parent = holder
		end
	elseif it.kind == "food" and it.foodId == "giantmeat" then
		-- P0 v3: a porção da Carne Gigante era um cubo azul (cor da raridade Rara, sem modelo).
		-- Agora é um pernil cartoon de peças (carne, gordura e osso), soldado ao suporte.
		holder.Transparency = 1
		dressMeatPortion(holder)
	elseif it.kind == "food" and it.foodId and FoodModels.has(it.foodId) then
		holder.Transparency = 1
		FoodModels.dress(holder, it.foodId, 4)
	elseif it.kind == "box" then
		holder.Transparency = 1
		local skin = it.boxId and (UIAssets :: { [string]: string })["extra_box_" .. it.boxId]
		local bb = Instance.new("BillboardGui")
		bb.Name = "BoxSprite"
		bb.Size = UDim2.fromScale(5, 5)
		bb.LightInfluence = 0.3
		bb.MaxDistance = 250
		bb.Parent = holder
		if skin then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = skin
			img.Parent = bb
		else
			holder.Transparency = 0
		end
	end
	local light = Instance.new("PointLight")
	-- a carne usa luz branca-quente: a luz da própria cor deixava o pernil vermelho-vivo (foto fase8)
	light.Color = if it.foodId == "giantmeat" then Color3.fromRGB(255, 225, 190) else rarColor
	light.Range = 10
	light.Brightness = 1
	light.Shadows = false
	light.Parent = holder
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(rarColor)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 3 + Config.Rarities[it.rarity].order
	sparkle.Parent = holder
	local label = Util.makeBillboard(holder, "", UDim2.fromOffset(240, 60), Vector3.new(0, 4, 0), rarColor)
	local board = label.Parent :: BillboardGui
	board.MaxDistance = 220
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUp"
	prompt.ActionText = "PEGAR"
	prompt.ObjectText = it.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = D.PickupReach
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = false
	prompt.Parent = holder
	it.label = label
	it.prompt = prompt
	return holder
end

local function marker(it: Item)
	local blip = Util.makePart({
		Name = "Blip",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 3.2, 3.2),
		CFrame = CFrame.new(it.pos.X, it.pos.Y - 2.3, it.pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = it.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = it.holder,
	})
	blip.Anchored = true
end

-- Carregar drop deixa mais lento: só declara o multiplicador (Speed.lua soma com eventos e ponte).
local function setSpeed(player: Player, mult: number?)
	Speed.set(player, "carry", mult)
end

local function speedFor(it: Item): number
	if it.kind == "egg" then
		return GameRules.Eggs.DropSpeed
	end
	if it.kind == "box" then
		return D.SpeedByBox[it.boxId or "common"] or 0.9
	end
	return D.SpeedByRarity[it.rarity] or 1
end

-- Larga a carga no chão onde o jogador está (soco, nocaute, morte, saída, arena).
local function dropCarry(player: Player, reason: string?)
	local it = carrying[player]
	if not it then
		return
	end
	carrying[player] = nil
	player:SetAttribute("CarryingDrop", nil)
	setSpeed(player, nil)
	it.carrier = nil
	local root = Guard.rootOf(player)
	local at = if root then root.Position else it.pickedPos
	-- desce até o chão (raio) para não ficar flutuando
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	if player.Character then
		table.insert(ignore, player.Character :: Model)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	local ground = if hit then hit.Position else at - Vector3.new(0, 3, 0)
	it.pos = ground + Vector3.new(0, 2.4, 0)
	for _, d in it.holder:GetChildren() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			d:Destroy()
		end
	end
	it.holder.Anchored = true
	it.holder.CFrame = CFrame.new(it.pos)
	it.holder.Parent = folder
	marker(it)
	it.unlockAt = os.clock() + D.DroppedRelock
	it.expiresAt = os.clock() + D.ExpireAfter
	it.prompt.Enabled = false
	updateLabel(it)
	broadcast(it)
	if reason and player.Parent then
		Remotes.Notify:FireClient(player, { text = reason, color = Color3.fromRGB(255, 90, 90) })
	end
end

function DropService.dropCarried(player: Player)
	dropCarry(player, nil)
end

function DropService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

local function tryPickup(player: Player, it: Item)
	if it.done or it.carrier or not it.landed or os.clock() < it.unlockAt then
		return
	end
	if carrying[player] or player:GetAttribute("CarryingSteal") or CombatService.isKO(player) then
		Remotes.Notify:FireClient(
			player,
			{ text = "Você já está carregando algo! Leve até sua base.", color = Color3.fromRGB(255, 170, 60) }
		)
		return
	end
	if not Guard.withinReach(player, it.holder, D.PickupReach) then
		return
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	it.carrier = player
	carrying[player] = it
	player:SetAttribute("CarryingDrop", it.id)
	it.pickedAt = os.clock()
	it.pickedPos = it.holder.Position
	it.prompt.Enabled = false
	local blip = it.holder:FindFirstChild("Blip")
	if blip then
		blip:Destroy()
	end
	-- vai para cima da cabeça (soldado, sem peso físico)
	it.holder.Anchored = false
	it.holder.Massless = true
	it.holder.CFrame = head.CFrame * CFrame.new(0, 3.2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = it.holder
	weld.Parent = it.holder
	it.holder.Parent = char
	setSpeed(player, speedFor(it))
	updateLabel(it)
	broadcast(it)
	Remotes.Notify:FireClient(
		player,
		{ text = "Pegou! Leve até a SUA base (cuidado com os socos).", color = Color3.fromRGB(80, 255, 120) }
	)
end

local function deliver(player: Player, it: Item)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	carrying[player] = nil
	player:SetAttribute("CarryingDrop", nil)
	setSpeed(player, nil)
	it.carrier = nil
	if it.kind == "food" and it.foodId then
		profile.dropsWon += 1
		-- Pátio primeiro (rende moedas); sem vaga, mochila (entra mesmo cheia: foi disputada).
		local placed = false
		local max = PlotService.maxSlots(profile)
		for i = 1, max do
			if not profile.plot[tostring(i)] then
				profile.plot[tostring(i)] = { id = it.foodId, uid = DataService.newUid() }
				placed = true
				break
			end
		end
		if not placed then
			table.insert(profile.inventory, { id = it.foodId, uid = DataService.newUid() })
		end
		DataService.markDirty(player)
		PlotService.rebuildPlot(player)
		PlotService.pushState(player)
		Remotes.Notify:FireClient(player, {
			text = string.format(
				"%s entregue! %s",
				it.name,
				if placed then "Está no seu pátio rendendo moedas." else "Pátio cheio: foi para a mochila."
			),
			color = Config.Rarities[it.rarity].color,
		})
	elseif it.kind == "box" and it.boxId then
		local pending = (profile :: any).pendingBoxes :: { string }
		if #pending >= D.MaxPendingBoxes then
			-- sem lugar: a caixa volta ao chão na frente da base
			carrying[player] = it
			it.carrier = player
			dropCarry(player, "Você já tem caixas demais guardadas. Abra uma antes!")
			return
		end
		table.insert(pending, it.boxId)
		DataService.markDirty(player)
		PlotService.pushState(player)
		Remotes.PendingBox:FireClient(player, { boxId = it.boxId, count = #pending })
	elseif it.kind == "egg" and it.eggSize then
		-- Ovos v2: vai para os ovos guardados (EggService). Sem lugar, volta ao chão: nunca some.
		local sink = DropService.EggSink
		if not sink or not sink(player, it.eggSize) then
			carrying[player] = it
			it.carrier = player
			dropCarry(player, "Você já tem ovos demais guardados. Choque um antes!")
			return
		end
	end
	Hooks.fire("delivered", player, it.kind, it.foodId)
	remove(it)
	local rar = Config.Rarities[it.rarity]
	if rar.order >= 4 then
		Remotes.Notify:FireAllClients(
			Locale.msg("drop_won_broadcast", { p = player.DisplayName, f = it.name, r = it.rarity }, rar.color)
		)
	end
end

-- Quem carrega e chegou dentro do quadrado da PRÓPRIA base entrega (conferido no servidor).
local function checkDeliveries()
	for player, it in carrying do
		if not player.Parent then
			continue
		end
		local base = MapService.getBaseOf(player)
		local root = Guard.rootOf(player)
		if not base or not root then
			continue
		end
		local here = base.origin:PointToObjectSpace(root.Position)
		local half = Config.BaseSize / 2 + DEPOSIT_MARGIN
		if math.abs(here.X) <= half and math.abs(here.Z) <= half then
			local toBase = (base.origin.Position - it.pickedPos).Magnitude - Config.BaseSize * 0.75
			if os.clock() - it.pickedAt >= math.max(0, toBase) / MAX_TRAVEL_SPEED then
				deliver(player, it)
			end
		end
	end
end

local function fall(it: Item)
	local t0 = os.clock()
	local h = D.FallHeight
	while os.clock() - t0 < D.FallTime and not it.done do
		local a = (os.clock() - t0) / D.FallTime
		a = a * a
		it.holder.CFrame = CFrame.new(it.pos + Vector3.new(0, h * (1 - a), 0)) * CFrame.Angles(0, a * 9, 0)
		task.wait()
	end
	if it.done then
		return
	end
	it.holder.CFrame = CFrame.new(it.pos)
	it.landed = true
	it.unlockAt = os.clock() + it.unlockAt -- unlockAt guardava a DURAÇÃO até pousar
	it.expiresAt = os.clock() + D.ExpireAfter
	marker(it)
	Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = it.pos })
	updateLabel(it)
	broadcast(it)
end

-- Cria um item que cai em `pos` (chão). kind/ids opcionais: sem eles, sorteia (comida ou caixa).
function DropService.spawnAt(pos: Vector3, kind: Kind?, id: string?, silent: boolean?)
	local k: Kind = kind
		or (
			if DropService.EggSink
					and Features.on("EggSystem")
					and math.random() < GameRules.Eggs.DropChance
				then "egg"
				elseif math.random() < D.BoxChance then "box"
				else "food"
		)
	nextId += 1
	local it: Item
	if k == "egg" then
		local size = if id and GameRules.Eggs.Sizes[id] then id else GameRules.Eggs.DropSize
		local def = GameRules.Eggs.Sizes[size]
		it = {
			id = nextId,
			kind = "egg",
			eggSize = size,
			name = def.name,
			rarity = def.rarity,
			color = Color3.fromRGB(150, 230, 120),
			pos = pos,
			unlockAt = GameRules.Eggs.DropUnlock,
		} :: any
	elseif k == "box" then
		local boxId = id or pickBox()
		local box = Config.LunchboxById[boxId]
		local rarity = BOX_RARITY[boxId] or "Common"
		it = {
			id = nextId,
			kind = "box",
			boxId = boxId,
			name = box and box.name or "Lunchbox",
			rarity = rarity,
			color = if box then box.color else Config.Rarities[rarity].color,
			pos = pos,
			unlockAt = D.UnlockByBox[boxId] or 15,
		} :: any
	else
		local food = if id then Config.FoodById[id] else pickFood()
		it = {
			id = nextId,
			kind = "food",
			foodId = food.id,
			name = food.name,
			rarity = food.rarity,
			color = Config.Rarities[food.rarity].color,
			pos = pos,
			unlockAt = D.UnlockByRarity[food.rarity] or 5,
		} :: any
	end
	it.pickedAt = 0
	it.pickedPos = pos
	it.landed = false
	it.expiresAt = math.huge
	it.done = false
	it.holder = buildHolder(it, pos + Vector3.new(0, D.FallHeight, 0))
	items[it.id] = it
	it.prompt.Triggered:Connect(function(player)
		tryPickup(player, it)
	end)
	-- Aviso de texto só para drop importante (Épico ou melhor, caixa ou ovo): comida comum caindo não
	-- spamma mais a tela de todo mundo (pedido do usuário, 09/11, item 14).
	local important = it.kind ~= "food" or (Config.Rarities[it.rarity] and Config.Rarities[it.rarity].order >= 4)
	if not silent and important then
		Remotes.Notify:FireAllClients(
			Locale.msg("drop_incoming2", { f = it.name, r = it.rarity, n = math.floor(it.unlockAt) }, it.color)
		)
	end
	updateLabel(it)
	broadcast(it)
	task.spawn(function()
		local ok, err = pcall(function()
			fall(it)
		end)
		if not ok then
			warn("[DropService]", err)
			if not it.done then
				remove(it)
			end
		end
	end)
end

-- Carne Gigante (MeatService, 4.5): entrega uma porção JÁ na cabeça do jogador, como se ele tivesse
-- pegado um drop. Daí em diante vale tudo o que já existe: peso, soco derruba, outro jogador pode
-- pegar a porção caída, entrega só na própria base. Devolve false se ele não pôde carregar.
function DropService.giveCarried(player: Player, foodId: string, at: Vector3): boolean
	local food = Config.FoodById[foodId]
	if not food or carrying[player] or player:GetAttribute("CarryingSteal") then
		return false
	end
	nextId += 1
	local it: Item = {
		id = nextId,
		kind = "food",
		foodId = food.id,
		name = food.name,
		rarity = food.rarity,
		-- A porção usa a cor da carne (brilho, faíscas e nome), não o azul da raridade Rara.
		color = if food.id == "giantmeat" then food.color else Config.Rarities[food.rarity].color,
		pos = at,
		unlockAt = 0,
	} :: any
	it.pickedAt = 0
	it.pickedPos = at
	it.landed = true
	it.expiresAt = os.clock() + D.ExpireAfter
	it.done = false
	it.holder = buildHolder(it, at)
	items[it.id] = it
	it.prompt.Triggered:Connect(function(p)
		tryPickup(p, it)
	end)
	tryPickup(player, it)
	if it.carrier ~= player then
		remove(it)
		return false
	end
	return true
end

-- BOTS (BotService): itens no chão, livres e já liberados. Só leitura.
function DropService.freeItems(): { { id: number, pos: Vector3, rarity: string, foodId: string?, kind: string } }
	local out: { any } = {}
	for id, it in items do
		if not it.done and not it.carrier and it.landed and os.clock() >= it.unlockAt then
			table.insert(
				out,
				{ id = id, pos = it.holder.Position, rarity = it.rarity, foodId = it.foodId, kind = it.kind }
			)
		end
	end
	return out
end

-- Bot recolhe um drop de comida comum/incomum (o BotService só chama sem jogador real por perto).
-- Devolve o foodId ou nil. Caixas e raridades altas ficam sempre para os jogadores.
function DropService.botCollect(id: number): string?
	local it = items[id]
	if not it or it.done or it.carrier or not it.landed or it.kind ~= "food" then
		return nil
	end
	if Config.Rarities[it.rarity].order > 2 then
		return nil
	end
	local foodId = it.foodId
	remove(it)
	return foodId
end

-- Ponto aleatório na praça (entre o caldeirão e a loja), como antes.
function DropService.plazaPoint(): Vector3
	local a = math.random() * math.pi * 2
	local r = 45 + math.random() * 45
	return Vector3.new(math.cos(a) * r, 4.5, math.sin(a) * r)
end

function DropService.spawn(kind: Kind?, id: string?)
	if activeCount() >= D.MaxActive then
		return
	end
	DropService.spawnAt(DropService.plazaPoint(), kind, id)
end

function DropService.init()
	folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = Workspace

	-- Soco em quem carrega derruba a carga (o nocaute também, pois vem depois de um soco).
	local prevHit = CombatService.OnHit
	CombatService.OnHit = function(attacker: Player, victim: Player, heavy: boolean)
		if prevHit then
			prevHit(attacker, victim, heavy)
		end
		if carrying[victim] then
			dropCarry(victim, "Você levou um soco e derrubou a carga!")
		end
	end
	local prevKO = CombatService.OnNpcKO
	CombatService.OnNpcKO = function(victim: Player, source: string)
		if prevKO then
			prevKO(victim, source)
		end
		dropCarry(victim, "Nocauteado! Você derrubou a carga.")
	end

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			baseSpeed[player] = nil
			local hum = char:WaitForChild("Humanoid", 5)
			if hum and hum:IsA("Humanoid") then
				hum.Died:Connect(function()
					dropCarry(player, nil)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropCarry(player, nil)
		baseSpeed[player] = nil
	end)
	-- Abrir uma caixa guardada (o jogador confirma no cliente; nunca abre sozinha).
	Remotes.RequestOpenPending.OnServerEvent:Connect(function(player, index)
		if not Guard.isIndex(index, D.MaxPendingBoxes) or not Guard.allow(player, "Box") then
			return
		end
		local profile = DataService.get(player)
		if not profile then
			return
		end
		local pending: { string } = (profile :: any).pendingBoxes
		local boxId = pending[index]
		if not boxId then
			return
		end
		-- Mesmo sorteio e mesmas chances da caixa comprada (LunchboxOdds), sem cobrar: foi conquistada.
		table.remove(pending, index)
		if not ShopService.openBox(player, boxId, { free = true, force = true }) then
			table.insert(pending, index, boxId) -- não abriu (ex.: erro): a caixa continua guardada
		end
		DataService.markDirty(player)
		PlotService.pushState(player)
	end)

	-- Quem entra no jogo vê os itens que já estão no mapa.
	Players.PlayerAdded:Connect(function()
		task.wait(3)
		for _, it in items do
			broadcast(it)
		end
	end)

	-- Laço: cronômetros, liberação, entregas e itens esquecidos.
	task.spawn(function()
		while true do
			task.wait(0.25)
			checkDeliveries()
			local now = os.clock()
			for _, it in items do
				if it.done then
					continue
				end
				if it.landed and not it.carrier then
					local unlocked = now >= it.unlockAt
					if unlocked ~= it.prompt.Enabled then
						it.prompt.Enabled = unlocked
						broadcast(it)
					end
					if now >= it.expiresAt then
						remove(it)
						continue
					end
				end
				updateLabel(it)
			end
		end
	end)

	-- Drops normais
	task.spawn(function()
		task.wait(20)
		while true do
			if #Players:GetPlayers() > 0 then
				DropService.spawn()
			end
			local scale = math.clamp(#Players:GetPlayers() / 4, 0.7, 1.4)
			task.wait(math.random(D.MinInterval, D.MaxInterval) / scale)
		end
	end)
end

return DropService
