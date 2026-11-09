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
--
-- 08/11/2026 (noite) — ILHA DO DRAGÃO (Sistema 4 da missão):
--   * a luta saiu do coliseu e foi para a ilha flutuante (World.BossIsland), ligada por uma ponte;
--   * FASES: até 50% de vida normal; "FÚRIA" (≤ 50%): pisões mais rápidos e em 2 alvos;
--     "CHUVA DE FOGO" (≤ 20%): além disso, 3 círculos espalhados perto dos lutadores;
--   * RECOMPENSA para todo participante válido (≥ 3% do dano OU ≥ 3 golpes acertados), vencendo ou
--     não (se o dragão fugir, metade) — ninguém é punido pelo resultado do grupo;
--   * BÔNUS proporcional ao dano (só na vitória) e o prêmio de conclusão (caixa épica, 2 por dia);
--   * quem ajudou e SAIU antes do fim recebe na próxima entrada (ProgressService.addPending,
--     idempotente por id da luta).
local Players = game:GetService("Players")
local Guard = require(script.Parent.Parent.Guard)
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
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Hooks = require(script.Parent.Parent.Hooks)
local GameLogic = require(script.Parent.Parent.GameLogic)
local ProgressService = require(script.Parent.ProgressService)
local Features = require(game.ReplicatedStorage.Shared.Features)
local rewardRng = Random.new()

local BossService = {}

local B = Config.Boss
local BOSS_RADIUS = 7 -- corpo do dragão (para acertar e para não atravessar)
local STOMP_RADIUS = 10

type Fight = {
	model: Model,
	hitbox: Part,
	hp: number,
	maxHp: number,
	-- por UserId: quem sai e volta na mesma luta continua sendo UMA pessoa (revisão cega, rodada 1)
	damage: { [number]: number },
	hits: { [number]: number },
	levels: { [number]: number }, -- nível do gigante quando ajudou (para pagar quem saiu)
	id: string,
	phase: number,
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
	return d <= World.BossIsland.fightR + 4 and root.Position.Y > f.floorY - 6 and root.Position.Y < f.floorY + 40
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

-- Círculo de aviso no chão e pisão 1,4 s depois (em um jogador ou num ponto: chuva de fogo).
local function stompAt(f: Fight, pos: Vector3, turn: boolean)
	if turn then
		faceTowards(f, pos)
	end
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

local function stomp(f: Fight, target: Player)
	local char = target.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	stompAt(f, Vector3.new(root.Position.X, f.floorY + 0.15, root.Position.Z), true)
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
	local rewards = GameLogic.bossRewards(f.damage, f.hits, f.levels, won)
	for _, rw in rewards do
		local uid, coins, xp, bonus, share = rw.uid, rw.coins, rw.xp, rw.bonus, rw.share
		local box: string? = nil
		local p = Players:GetPlayerByUserId(uid)
		-- Online mas sem perfil carregado (saindo/entrando agora): vai para a fila como quem saiu,
		-- em vez de perder o prêmio (revisão cega do painel pós-testes).
		local profile: any = if p then DataService.get(p) else nil
		if p and profile then
			do
				if won then
					if winsToday(profile) < B.WinsPerDay then
						if profile.bossDay ~= today() then
							profile.bossDay = today()
							profile.bossWins = 0
						end
						profile.bossWins += 1
						box = B.RewardBox
					else
						Remotes.Notify:FireClient(
							p,
							Locale.msg("boss_limit", { n = B.WinsPerDay }, Color3.fromRGB(255, 200, 80))
						)
					end
				end
				profile.coins += coins + bonus
				DataService.markDirty(p)
				GiantService.addXp(p, xp, nil, nil)
				local eggName: string? = nil
				if box then
					ShopService.openBox(p, box, { free = true, force = true, minRarity = B.RewardMinRarity })
					-- + 1 ovo aleatório (item 16). Require tardio: o EggService já depende de serviços daqui.
					if Features.on("EggSystem") then
						local E = GameRules.Eggs
						local size = GameLogic.bossEgg(E.BossEggWeights, E.Order, rewardRng:NextNumber())
						local EggService = require(script.Parent.EggService) :: any
						if EggService.giveEgg(p, size, "boss") then
							eggName = E.Sizes[size].name
						end
					end
				end
				PlotService.pushState(p)
				Remotes.BossState:FireClient(p, {
					kind = "Rewards",
					won = won,
					coins = coins,
					bonus = bonus,
					xp = xp,
					share = share,
					box = box ~= nil,
					egg = eggName,
				})
				if won then
					Hooks.fire("bossHelped", p)
					Remotes.GiantReact:FireAllClients({ userId = p.UserId, kind = "cheer" })
				end
			end
		else
			-- Ajudou e saiu: fica guardado para a próxima entrada (sem caixa extra além do limite
			-- diário, que não dá para conferir offline: só moedas e XP).
			ProgressService.addPending(uid, {
				id = f.id,
				coins = coins + bonus,
				xp = xp,
				box = nil,
			})
		end
	end
	if won then
		Remotes.Notify:FireAllClients(Locale.msg("boss_down", { n = #rewards }, Color3.fromRGB(255, 200, 60)))
		Remotes.Fireworks:FireAllClients({ pos = f.center, big = true })
		TweenService:Create(f.hitbox, TweenInfo.new(1), { Transparency = 1 }):Play()
	else
		Remotes.Notify:FireAllClients(Locale.msg("boss_fled", nil, Color3.fromRGB(255, 120, 90)))
	end
	task.delay(if won then 1.5 else 0.2, function()
		f.model:Destroy()
	end)
end

-- Roda o evento inteiro (chamado pelo EventService). Bloqueia até acabar.
function BossService.run(duration: number)
	local center = World.BossIsland.center
	local floorY = World.BossIsland.top + 0.5
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
		hits = {},
		levels = {},
		id = string.format("boss-%d-%d", os.time(), math.random(1, 1e6)),
		phase = 1,
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
	local lastRain = os.clock()
	local BI = GameRules.BossIsland
	while not f.over and os.clock() - t0 < duration do
		task.wait(0.25)
		local list = fighters(f)
		for _, p in list do
			if not CombatService.inFightMode(p) then
				CombatService.setFightMode(p, true) -- entrou na ilha com o dragão: luvas na mão
			end
		end
		rescale()
		-- Fases pela vida que falta (anunciadas uma vez)
		local frac = f.hp / math.max(f.maxHp, 1)
		local phase = if frac <= BI.Phase3At then 3 elseif frac <= BI.Phase2At then 2 else 1
		if phase > f.phase then
			f.phase = phase
			Remotes.BossState:FireAllClients({ kind = "Phase", phase = phase })
			Remotes.Notify:FireAllClients(
				Locale.msg(if phase == 2 then "boss_phase2" else "boss_phase3", nil, Color3.fromRGB(255, 90, 60))
			)
		end
		local every = if f.phase >= 2 then B.StompEvery * BI.Phase2StompMult else B.StompEvery
		if #list > 0 and os.clock() - lastStomp >= every then
			lastStomp = os.clock()
			local alive = {}
			for _, p in list do
				if not CombatService.isKO(p) then
					table.insert(alive, p)
				end
			end
			local targets = if f.phase >= 2 then 2 else 1
			for _ = 1, math.min(targets, #alive) do
				local i = math.random(1, #alive)
				local target = table.remove(alive, i)
				if target then
					task.spawn(stomp, f, target)
				end
			end
		end
		-- Fase 3: chuva de fogo (3 círculos perto dos lutadores, a cada ~4 s)
		if f.phase >= 3 and #list > 0 and os.clock() - lastRain >= B.StompEvery * 1.3 then
			lastRain = os.clock()
			for _ = 1, 3 do
				local p = list[math.random(1, #list)]
				local r = Guard.rootOf(p)
				if r then
					local off = Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
					local at = Vector3.new(r.Position.X, f.floorY + 0.15, r.Position.Z) + off
					local flat = Vector3.new(at.X - f.center.X, 0, at.Z - f.center.Z)
					if flat.Magnitude > World.BossIsland.fightR then
						at = Vector3.new(f.center.X, at.Y, f.center.Z) + flat.Unit * World.BossIsland.fightR
					end
					task.spawn(stompAt, f, at, false)
				end
			end
		end
	end
	current = nil
	finish(f, f.hp <= 0)
end

-- Bots ajudam com dano pequeno. Não entram em f.damage (prêmios só para jogadores reais).
function BossService.botHit(damage: number): boolean
	local f = current
	if not f or f.over then
		return false
	end
	f.hp = math.max(0, f.hp - math.clamp(damage, 0, 40))
	updateBar(f)
	if f.hp <= 0 then
		current = nil
		task.spawn(finish, f, true)
	end
	return true
end

function BossService.center(): Vector3?
	local f = current
	return if f and not f.over then f.center else nil
end

function BossService.isActive(): boolean
	return current ~= nil or BossService.running
end

BossService.running = false
BossService.nextAt = 0
-- true = o coliseu está livre para o Dragão (sem luta de boxe nem batalha de gigantes).
BossService.CanStart = nil :: (() -> boolean)?

-- Cronômetro na entrada da arena (item 10): horário real do próximo Dragão, do mesmo laço que o cria.
local function buildArenaBoard(): TextLabel
	-- Na entrada da ponte da Ilha do Dragão, lida de quem vem da praça.
	local c = World.BossIsland.center
	local dir = Vector3.new(c.X, 0, c.Z).Unit
	local pos = dir * (World.BossIsland.bridgeFrom - 4) + Vector3.new(0, 26, 0)
	local anchor = Instance.new("Part")
	anchor.Name = "BossTimer"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = Workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(40, 10)
	bb.LightInfluence = 0
	bb.MaxDistance = 600
	bb.Parent = anchor
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(44, 47, 55)
	bg.BackgroundTransparency = 0.15
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 80)
	stroke.Thickness = 4
	stroke.Parent = bg
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 110)
	label.TextStrokeTransparency = 0.2
	label.Parent = bg
	return label
end

local function mmss(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function BossService.init()
	local board = buildArenaBoard()
	BossService.nextAt = os.time() + B.FirstDelay
	task.spawn(function()
		while true do
			task.wait(1)
			local left = BossService.nextAt - os.time()
			if BossService.running then
				board.Text = "DRAGÃO FAMINTO NA ILHA! Atravesse a ponte!"
			elseif left > 0 then
				board.Text = "DRAGÃO FAMINTO NA ILHA EM " .. mmss(left)
			else
				board.Text = "DRAGÃO: chegando..."
			end
			if left <= 0 and not BossService.running then
				local can = BossService.CanStart
				if not can or can() then
					BossService.running = true
					local ok, err = pcall(function()
						BossService.run(B.Duration)
					end)
					if not ok then
						warn("[BossService]", err)
					end
					BossService.running = false
					BossService.nextAt = os.time() + B.Every
				end
			end
		end
	end)
	CombatService.HitNpc = function(attacker, origin, look, range, damage, _heavy)
		local f = current
		if not f or f.over or not inArena(attacker, f) or CombatService.isKO(attacker) then
			return false -- nocauteado não causa dano nem conta como participação
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
		local uid = attacker.UserId
		f.damage[uid] = (f.damage[uid] or 0) + damage
		f.hits[uid] = (f.hits[uid] or 0) + 1
		local prof = DataService.get(attacker)
		if prof then
			f.levels[uid] = prof.level
		end
		updateBar(f)
		if f.hp <= 0 then
			current = nil
			task.spawn(finish, f, true)
		end
		return true
	end
	local prevNpcKO = CombatService.OnNpcKO
	CombatService.OnNpcKO = function(victim, source)
		if prevNpcKO then
			prevNpcKO(victim, source)
		end
		local f = current
		if source == "boss" and f then
			eatFrom(f, victim)
		end
	end
end

return BossService
