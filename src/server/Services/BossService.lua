--!strict
-- BossService — o DRAGÃO FAMINTO (pedido do usuário em 08/11/2026, substitui o "Boss Faminto" de
-- bloco + bola que ninguém entendia para que servia).
--
-- Como funciona (regra simples de explicar numa linha: "vença o dragão na arena e ganhe comida rara"):
--   * É um dos eventos do servidor (com contagem regressiva na HUD). O dragão pousa no meio da arena.
--   * Quem entra na arena vira lutador (modo de luta liga sozinho) e soca o dragão.
--   * O dragão escolhe um lutador, marca um círculo vermelho no chão e pisa depois de 1,4 s:
--     quem não sair do círculo apanha. Quem é nocauteado pelo dragão PERDE: ele come 1 comida da
--     mochila (no máximo 1 por evento e nunca comida comprada com Robux — a mochila não guarda isso).
--   * Se a vida do dragão chega a zero, todo mundo que ajudou (>= 3% do dano) GANHA uma caixa
--     épica grátis (comida Épica ou melhor), no máximo Config.Boss.WinsPerDay vezes por dia.
-- Vida escala com o número de lutadores (justo com 1 ou com 8). Tudo validado no servidor.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local GiantService = require(script.Parent.GiantService)
local CombatService = require(script.Parent.CombatService)
local World = require(script.Parent.Parent.World)

local BossService = {}

local B = Config.Boss
local BOSS_RADIUS = 7 -- corpo do dragão (para acertar e para não atravessar)
local STOMP_RADIUS = 10

type Fight = {
	model: Model,
	hitbox: Part,
	hp: number,
	maxHp: number,
	damage: { [Player]: number },
	ate: { [Player]: boolean },
	label: TextLabel,
	fill: Frame,
	center: Vector3,
	floorY: number,
	over: boolean,
}

local current: Fight? = nil

local function today(): number
	return math.floor(os.time() / 86400)
end

local function winsToday(profile: any): number
	if profile.bossDay ~= today() then
		return 0
	end
	return profile.bossWins or 0
end

local function inArena(player: Player, f: Fight): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = Vector3.new(root.Position.X - f.center.X, 0, root.Position.Z - f.center.Z).Magnitude
	return d <= World.Arena.outerR and math.abs(root.Position.Y - f.floorY) < 30
end

local function fighters(f: Fight): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if inArena(p, f) then
			table.insert(list, p)
		end
	end
	return list
end

local function updateBar(f: Fight)
	f.fill.Size = UDim2.fromScale(math.clamp(f.hp / f.maxHp, 0, 1), 1)
	f.label.Text = string.format("DRAGÃO FAMINTO  %d / %d", math.ceil(f.hp), f.maxHp)
end

-- Modelo: o dragão de cristal (malha enviada na Fase 2, sem uso como espécie). Sem ele, não há chefe.
local function buildBoss(center: Vector3, floorY: number): (Model?, Part?)
	local t = GiantService.template("crystal-dragon") or GiantService.template("hydra")
	if not t then
		return nil, nil
	end
	local model = t:Clone()
	model.Name = "HungryDragon"
	local _, size0 = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * B.Height / math.max(size0.Y, 1))
	local cf, size = model:GetBoundingBox()
	local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
	local offset = model:GetPivot():ToObjectSpace(bottom)
	model:PivotTo(CFrame.new(center.X, floorY, center.Z) * offset:Inverse())
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	-- Corpo sólido invisível: ninguém atravessa o dragão.
	local hitbox = Instance.new("Part")
	hitbox.Name = "BossHitbox"
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Size = Vector3.new(B.Height, BOSS_RADIUS * 2, BOSS_RADIUS * 2)
	hitbox.CFrame = CFrame.new(center.X, floorY + B.Height / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	hitbox.Anchored = true
	hitbox.Transparency = 1
	hitbox.CanQuery = false
	-- Pivô no chão, no centro e "em pé": girar o dragão para o alvo não deita o modelo.
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(center.X, floorY, center.Z)
	hitbox.Parent = model
	-- Fumaça saindo do nariz/corpo: sinal de "bravo".
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 70, 80))
	smoke.Size = NumberSequence.new(3, 9)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Speed = NumberRange.new(4, 8)
	smoke.Rate = 6
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.EmissionDirection = Enum.NormalId.Right -- cilindro deitado: Right = para cima
	smoke.Parent = hitbox
	return model, hitbox
end

local function bar(model: Model, hitbox: Part): (TextLabel, Frame)
	local bb = Instance.new("BillboardGui")
	bb.Name = "BossBar"
	bb.Size = UDim2.fromOffset(360, 64)
	bb.StudsOffsetWorldSpace = Vector3.new(0, B.Height * 0.5 + 6, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.Adornee = hitbox
	bb.Parent = model
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 30)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 90, 90)
	label.TextStrokeTransparency = 0
	label.Parent = bb
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(30, 20, 30)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.new(1, 0, 0, 22)
	bg.Position = UDim2.fromOffset(0, 36)
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(230, 50, 60)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg
	local c2 = corner:Clone()
	c2.Parent = fill
	return label, fill
end

local function faceTowards(f: Fight, pos: Vector3)
	local pivot = f.model:GetPivot()
	local flat = Vector3.new(pos.X, pivot.Position.Y, pos.Z)
	if (flat - pivot.Position).Magnitude < 1 then
		return
	end
	local _, yaw, _ = CFrame.lookAt(pivot.Position, flat):ToEulerAnglesYXZ()
	local hb = f.hitbox.CFrame
	f.model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw, 0))
	f.hitbox.CFrame = hb -- o cilindro sólido não gira (não empurra ninguém de lado)
end

-- Círculo de aviso no chão e pisão 1,4 s depois.
local function stomp(f: Fight, target: Player)
	local char = target.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pos = Vector3.new(root.Position.X, f.floorY + 0.15, root.Position.Z)
	faceTowards(f, pos)
	local ring = Instance.new("Part")
	ring.Name = "StompWarning"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, STOMP_RADIUS * 2, STOMP_RADIUS * 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Transparency = 0.55
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(B.TelegraphSeconds), { Transparency = 0.15 }):Play()
	task.wait(B.TelegraphSeconds)
	ring:Destroy()
	if f.over then
		return
	end
	-- Explosão de poeira/fogo e dano em quem ficou dentro.
	local fx = Instance.new("Part")
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.Transparency = 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	fx.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 30))
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new(5, 0)
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(20, 35)
	pe.SpreadAngle = Vector2.new(180, 20)
	pe.Rate = 0
	pe.Parent = fx
	pe:Emit(60)
	task.delay(1.5, function()
		fx:Destroy()
	end)
	Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = pos })
	for _, p in fighters(f) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude <= STOMP_RADIUS then
			CombatService.npcHit(p, CombatService.maxHp(p) * B.StompHpFraction, pos, "boss")
		end
	end
end

-- O dragão come uma comida da mochila de quem foi nocauteado (no máximo 1 por evento).
local function eatFrom(f: Fight, victim: Player)
	if f.ate[victim] then
		return
	end
	f.ate[victim] = true
	local profile = DataService.get(victim)
	if not profile then
		return
	end
	if #profile.inventory == 0 then
		Remotes.Notify:FireClient(victim, Locale.msg("boss_lose_empty", nil, Color3.fromRGB(255, 90, 90)))
		return
	end
	local idx = math.random(1, #profile.inventory)
	local item = table.remove(profile.inventory, idx)
	local def = item and Config.FoodById[item.id]
	DataService.markDirty(victim)
	PlotService.pushState(victim)
	Remotes.Notify:FireClient(
		victim,
		Locale.msg("boss_lose", { f = if def then def.name else "comida" }, Color3.fromRGB(255, 90, 90))
	)
end

local function finish(f: Fight, won: boolean)
	if f.over then
		return
	end
	f.over = true
	if won then
		local total = 0
		for _, d in f.damage do
			total += d
		end
		for p, d in f.damage do
			if not p.Parent or d < total * 0.03 then
				continue
			end
			local profile: any = DataService.get(p)
			if not profile then
				continue
			end
			if winsToday(profile) >= B.WinsPerDay then
				Remotes.Notify:FireClient(
					p,
					Locale.msg("boss_limit", { n = B.WinsPerDay }, Color3.fromRGB(255, 200, 80))
				)
				continue
			end
			if profile.bossDay ~= today() then
				profile.bossDay = today()
				profile.bossWins = 0
			end
			profile.bossWins += 1
			DataService.markDirty(p)
			ShopService.openBox(p, B.RewardBox, { free = true, force = true, minRarity = B.RewardMinRarity })
		end
		Remotes.Notify:FireAllClients({
			text = "O DRAGÃO FAMINTO caiu! Os lutadores ganharam comida rara!",
			color = Color3.fromRGB(255, 200, 60),
		})
		Remotes.Fireworks:FireAllClients({ pos = f.center, big = true })
		-- Dragão cai e some.
		TweenService:Create(f.hitbox, TweenInfo.new(1), { Transparency = 1 }):Play()
	else
		Remotes.Notify:FireAllClients({
			text = "O Dragão Faminto voou embora... volte no próximo evento!",
			color = Color3.fromRGB(255, 120, 90),
		})
	end
	task.delay(if won then 1.5 else 0.2, function()
		f.model:Destroy()
	end)
end

-- Roda o evento inteiro (chamado pelo EventService). Bloqueia até acabar.
function BossService.run(duration: number)
	local center = World.Arena.center
	local floorY = center.Y + World.Arena.floorTop
	local model, hitbox = buildBoss(center, floorY)
	if not model or not hitbox then
		warn("[BossService] modelo do dragão não carregou; evento sem chefe")
		return
	end
	local label, fill = bar(model, hitbox)
	local f: Fight = {
		model = model,
		hitbox = hitbox,
		hp = 0,
		maxHp = 0,
		damage = {},
		ate = {},
		label = label,
		fill = fill,
		center = center,
		floorY = floorY,
		over = false,
	}
	local function rescale()
		local n = math.max(1, #fighters(f))
		local newMax = B.BaseHp + B.HpPerFighter * (n - 1)
		if newMax > f.maxHp then
			f.hp += newMax - f.maxHp
			f.maxHp = newMax
		end
		updateBar(f)
	end
	rescale()
	model.Parent = Workspace
	current = f
	Remotes.Notify:FireAllClients(Locale.msg("boss_spawned", nil, Color3.fromRGB(255, 90, 90)))

	local t0 = os.clock()
	local lastStomp = os.clock()
	while not f.over and os.clock() - t0 < duration do
		task.wait(0.25)
		local list = fighters(f)
		for _, p in list do
			if not CombatService.inFightMode(p) then
				CombatService.setFightMode(p, true) -- entrou na arena com o dragão: luvas na mão
			end
		end
		rescale()
		if #list > 0 and os.clock() - lastStomp >= B.StompEvery then
			lastStomp = os.clock()
			local alive = {}
			for _, p in list do
				if not CombatService.isKO(p) then
					table.insert(alive, p)
				end
			end
			if #alive > 0 then
				task.spawn(stomp, f, alive[math.random(1, #alive)])
			end
		end
	end
	current = nil
	finish(f, f.hp <= 0)
end

function BossService.isActive(): boolean
	return current ~= nil
end

function BossService.init()
	CombatService.HitNpc = function(attacker, origin, look, range, damage, _heavy)
		local f = current
		if not f or f.over or not inArena(attacker, f) then
			return false
		end
		local delta = Vector3.new(f.center.X - origin.X, 0, f.center.Z - origin.Z)
		local dist = delta.Magnitude - BOSS_RADIUS
		if dist > range then
			return false
		end
		if delta.Magnitude > 1 and look:Dot(delta.Unit) < 0.2 then
			return false
		end
		f.hp = math.max(0, f.hp - damage)
		f.damage[attacker] = (f.damage[attacker] or 0) + damage
		updateBar(f)
		if f.hp <= 0 then
			current = nil
			task.spawn(finish, f, true)
		end
		return true
	end
	CombatService.OnNpcKO = function(victim, source)
		local f = current
		if source == "boss" and f then
			eatFrom(f, victim)
		end
	end
end

return BossService
