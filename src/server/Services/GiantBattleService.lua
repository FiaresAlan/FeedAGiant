--!strict
-- GiantBattleService — ARENA DOS GIGANTES (pedido do usuário, item 9.2, 08/11/2026).
--
-- O próprio gigante do jogador (uma das espécies que ele POSSUI) entra no coliseu e luta contra um
-- gigante selvagem. É separado da luta de boxe entre jogadores (ArenaService), que continua igual.
-- Organização do coliseu (9.4): o mesmo chão serve aos dois modos, um de cada vez — boxe, Dragão e
-- gigantes não se misturam (isBusy). Quem está em volta assiste.
--
-- Atributos reais do jogo (Config.Species): vida = arenaHp, força = arenaPower, os dois crescem
-- devagar com o nível e o rebirth do jogador (Config.GiantBattle). O adversário é uma espécie
-- comprável com moedas, em nível parecido, então a luta é equilibrada.
-- As criaturas não têm esqueleto no Roblox (só troll e goblin tinham, no FBX): as animações aqui são
-- PROCEDURAIS e honestas — investida para atacar, tranco para trás ao apanhar, tombo no nocaute e
-- pulos de vitória. O jogador ajuda com o GOLPE FORTE (botão com recarga).
-- Recompensa (9.3): moedas e XP que já existem, valor pela fórmula de Config.GiantBattle; vitórias
-- contadas em profile.giantWins. Perder não tira nada.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)
local PlotService = require(script.Parent.PlotService)
local Guard = require(script.Parent.Parent.Guard)
local World = require(script.Parent.Parent.World)

local GiantBattleService = {}
local G = Config.GiantBattle

type Side = {
	speciesId: string,
	name: string,
	maxHp: number,
	hp: number,
	power: number,
	model: Model,
	home: CFrame,
	fill: Frame,
	hpText: TextLabel,
}

local active: { player: Player, me: Side, foe: Side, over: boolean, specialAt: number }? = nil
local lastBattle: { [Player]: number } = {}

GiantBattleService.IsArenaBusy = nil :: (() -> boolean)?

function GiantBattleService.isActive(): boolean
	return active ~= nil
end

function GiantBattleService.stats(speciesId: string, level: number, rebirths: number): (number, number)
	local sp = Config.SpeciesById[speciesId]
	if not sp then
		return 100, 10
	end
	local hp = math.floor(sp.arenaHp * (1 + level * G.HpPerLevel) * (1 + rebirths * G.PerRebirth))
	local power = sp.arenaPower * (1 + level * G.PowerPerLevel) * (1 + rebirths * G.PerRebirth)
	return hp, math.floor(power * 10) / 10
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function makeSide(speciesId: string, level: number, rebirths: number, home: CFrame, tint: Color3): Side?
	local entry = CreatureModels.BySpecies[speciesId]
	local t = entry and GiantService.template(entry.file)
	if not t then
		return nil
	end
	local model = t:Clone()
	model.Name = "Battle_" .. speciesId
	local _, size0 = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * G.ModelHeight / math.max(size0.Y, 1))
	local cf, size = model:GetBoundingBox()
	local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
	local offset = model:GetPivot():ToObjectSpace(bottom)
	model.PrimaryPart = nil
	model:PivotTo(home * CFrame.Angles(0, math.rad((entry :: any).yaw or 0) + math.pi, 0) * offset:Inverse())
	model.WorldPivot = home
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d:IsA("MeshPart") and d.TextureID ~= "" then
				d.Color = Color3.new(1, 1, 1)
			end
		end
	end
	local hp, power = GiantBattleService.stats(speciesId, level, rebirths)
	local sp = Config.SpeciesById[speciesId]
	-- Barra de vida em cima (todo mundo vê)
	local anchor = Instance.new("Part")
	anchor.Name = "BarAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = home * CFrame.new(0, G.ModelHeight + 3, 0)
	anchor.Parent = model
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 58)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 300
	bb.Parent = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = tint
	title.TextStrokeTransparency = 0
	title.Text = string.format("%s  Nv.%d", sp and sp.name or speciesId, level)
	title.Parent = bb
	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	bg.BorderSizePixel = 0
	bg.Position = UDim2.fromOffset(0, 30)
	bg.Size = UDim2.new(1, 0, 0, 22)
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = tint
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg
	corner:Clone().Parent = fill
	local hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0.2
	hpText.ZIndex = 2
	hpText.Parent = bg
	model.Parent = Workspace
	local side: Side = {
		speciesId = speciesId,
		name = sp and sp.name or speciesId,
		maxHp = hp,
		hp = hp,
		power = power,
		model = model,
		home = home,
		fill = fill,
		hpText = hpText,
	}
	hpText.Text = string.format("%d / %d", hp, hp)
	return side
end

local function setHp(s: Side, hp: number)
	s.hp = math.max(0, hp)
	s.fill.Size = UDim2.fromScale(s.hp / s.maxHp, 1)
	s.hpText.Text = string.format("%d / %d", math.ceil(s.hp), s.maxHp)
end

-- Move o modelo inteiro com um "valor" animado (TweenService não anima Model diretamente).
local function animate(s: Side, goal: CFrame, t: number, style: Enum.EasingStyle?)
	local v = Instance.new("CFrameValue")
	v.Value = s.model:GetPivot()
	local conn = v.Changed:Connect(function(cf)
		s.model:PivotTo(cf)
	end)
	local tw = TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad), { Value = goal })
	tw:Play()
	tw.Completed:Wait()
	conn:Disconnect()
	v:Destroy()
end

local function flash(s: Side, color: Color3)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.FillTransparency = 0.35
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = s.model
	task.delay(0.18, function()
		h:Destroy()
	end)
end

local function strike(att: Side, def: Side, mult: number): boolean
	local dir = (def.home.Position - att.home.Position).Unit
	local base = att.model:GetPivot()
	-- investida
	animate(att, base + dir * G.LungeDistance, 0.18, Enum.EasingStyle.Back)
	local crit = math.random() < G.CritChance
	local dmg = att.power * G.DamageScale * (0.85 + math.random() * 0.3) * mult * (if crit then G.CritMult else 1)
	setHp(def, def.hp - dmg)
	flash(def, if crit then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(255, 60, 60))
	Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = def.home.Position })
	-- tranco de quem apanhou
	local dbase = def.model:GetPivot()
	task.spawn(function()
		animate(def, dbase * CFrame.Angles(math.rad(-10), 0, 0) + dir * 1.5, 0.1)
		animate(def, dbase, 0.2)
	end)
	animate(att, base, 0.25)
	return crit
end

local function finish(player: Player, me: Side, foe: Side, won: boolean, reason: string?)
	local loser = if won then foe else me
	local winner = if won then me else foe
	-- tombo do perdedor e pulos do vencedor
	task.spawn(function()
		local p = loser.model:GetPivot()
		animate(loser, p * CFrame.Angles(0, 0, math.rad(80)) - Vector3.new(0, 1.5, 0), 0.6, Enum.EasingStyle.Bounce)
	end)
	task.spawn(function()
		local p = winner.model:GetPivot()
		for _ = 1, 3 do
			animate(winner, p + Vector3.new(0, 3, 0), 0.18)
			animate(winner, p, 0.18, Enum.EasingStyle.Bounce)
		end
	end)
	local coins, xp = 0, 0
	if player.Parent then
		local profile: any = DataService.get(player)
		if profile then
			if won then
				if profile.giantDay ~= today() then
					profile.giantDay = today()
					profile.giantRewardsToday = 0
				end
				profile.giantWins = (profile.giantWins or 0) + 1
				if (profile.giantRewardsToday or 0) < G.RewardedWinsPerDay then
					profile.giantRewardsToday = (profile.giantRewardsToday or 0) + 1
					coins = math.floor(G.WinCoinsBase + profile.level * G.WinCoinsPerLevel)
					xp = math.floor(G.WinXpBase + profile.level * G.WinXpPerLevel)
					profile.coins += coins
					GiantService.addXp(player, xp, nil, nil)
				end
			else
				profile.giantLosses = (profile.giantLosses or 0) + 1
			end
			DataService.markDirty(player)
			PlotService.pushState(player)
		end
		Remotes.GiantBattle:FireClient(player, {
			kind = "End",
			won = won,
			coins = coins,
			xp = xp,
			reason = reason,
		})
	end
	if won then
		Remotes.Fireworks:FireAllClients({ pos = me.home.Position, big = false })
	end
	task.wait(3)
	me.model:Destroy()
	foe.model:Destroy()
end

local function run(player: Player, speciesId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local center = World.Arena.center
	local y = center.Y + World.Arena.floorTop
	local axis = CFrame.lookAt(Vector3.new(center.X, y, center.Z), Vector3.new(0, y, 0))
	local homeMe = axis * CFrame.new(0, 0, G.Spacing / 2)
	local homeFoe = axis * CFrame.new(0, 0, -G.Spacing / 2)
	homeMe = CFrame.lookAt(homeMe.Position, homeFoe.Position)
	homeFoe = CFrame.lookAt(homeFoe.Position, homeMe.Position)
	-- Adversário: espécie comprável com moedas, nível parecido (±2)
	local pool = {}
	for _, sp in Config.Species do
		if not sp.robux and CreatureModels.BySpecies[sp.id] then
			table.insert(pool, sp.id)
		end
	end
	local foeId = pool[math.random(1, #pool)]
	local foeLevel = math.max(1, profile.level + math.random(-2, 2))
	local me = makeSide(speciesId, profile.level, profile.rebirths, homeMe, Color3.fromRGB(90, 220, 120))
	local foe = makeSide(foeId, foeLevel, profile.rebirths, homeFoe, Color3.fromRGB(255, 90, 90))
	if not me or not foe then
		if me then
			me.model:Destroy()
		end
		if foe then
			foe.model:Destroy()
		end
		Remotes.Notify:FireClient(
			player,
			{ text = "Gigante sem modelo 3D ainda.", color = Color3.fromRGB(255, 90, 90) }
		)
		return
	end
	local state = { player = player, me = me, foe = foe, over = false, specialAt = 0 }
	active = state
	Remotes.GiantBattle:FireClient(player, {
		kind = "Start",
		me = { name = me.name, hp = me.maxHp, power = me.power },
		foe = { name = foe.name, hp = foe.maxHp, power = foe.power, level = foeLevel },
		specialCooldown = G.SpecialCooldown,
	})
	task.wait(G.StartDelay)
	local t0 = os.clock()
	local turn = math.random() < 0.5
	while me.hp > 0 and foe.hp > 0 and os.clock() - t0 < G.MaxSeconds do
		if not player.Parent then
			break
		end
		if turn then
			local mult = 1
			if state.specialAt > 0 then
				mult = G.SpecialMult
				state.specialAt = 0
			end
			strike(me, foe, mult)
		else
			strike(foe, me, 1)
		end
		turn = not turn
		Remotes.GiantBattle:FireClient(player, { kind = "Tick", meHp = me.hp, foeHp = foe.hp })
		task.wait(G.TurnSeconds)
	end
	state.over = true
	local won = foe.hp <= 0 or (me.hp > 0 and me.hp / me.maxHp > foe.hp / foe.maxHp)
	if not player.Parent then
		won = false
	end
	finish(player, me, foe, won, if os.clock() - t0 >= G.MaxSeconds then "tempo" else nil)
	active = nil
end

function GiantBattleService.init()
	Remotes.RequestGiantBattle.OnServerEvent:Connect(function(player, speciesId)
		if type(speciesId) ~= "string" or not Guard.allow(player, "Duel") then
			return
		end
		local profile = DataService.get(player)
		if not profile or not profile.ownedSpecies[speciesId] or not Config.SpeciesById[speciesId] then
			return -- só leva um gigante que é seu
		end
		local busy = GiantBattleService.IsArenaBusy
		if active or (busy and busy()) then
			Remotes.Notify:FireClient(
				player,
				{ text = "O coliseu está ocupado. Tente em alguns segundos!", color = Color3.fromRGB(255, 170, 60) }
			)
			return
		end
		local last = lastBattle[player] or 0
		if os.clock() - last < G.Cooldown then
			Remotes.Notify:FireClient(player, {
				text = string.format(
					"Seu gigante está descansando: %ds.",
					math.ceil(G.Cooldown - (os.clock() - last))
				),
				color = Color3.fromRGB(255, 170, 60),
			})
			return
		end
		lastBattle[player] = os.clock()
		task.spawn(function()
			local ok, err = pcall(function()
				run(player, speciesId)
			end)
			if not ok then
				warn("[GiantBattleService]", err)
				active = nil
			end
		end)
	end)
	Remotes.RequestGiantSpecial.OnServerEvent:Connect(function(player)
		local a = active
		if not a or a.player ~= player or a.over or not Guard.allow(player, "Combat") then
			return
		end
		local now = os.clock()
		local last = (a :: any).lastSpecial or 0
		if now - last < G.SpecialCooldown then
			return
		end
		(a :: any).lastSpecial = now
		a.specialAt = now -- o próximo ataque do seu gigante sai forte
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastBattle[p] = nil
	end)
end

return GiantBattleService
