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
--
-- 08/11/2026 (noite) — BATALHA POR TURNOS (Sistema 3 da missão). O modo PvE desta arena evoluiu:
-- em vez de golpes automáticos + GOLPE FORTE, o jogador ESCOLHE um de 3 golpes por rodada
-- (GameRules.MoveKits: dano, chance de acerto e, às vezes, um efeito simples: tonto, defesa baixa ou
-- esquiva). Errar = perder o golpe. O servidor sorteia tudo; o cliente só manda o índice do golpe.
-- O adversário selvagem tem vida e força parecidas com as do gigante do jogador (luta justa;
-- a espécie muda só o visual e os golpes). O boxe entre jogadores (ArenaService) continua igual.
-- PvP por turnos: a estrutura (Side + resolve) já serve para dois jogadores; não foi ligado ainda.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Hooks = require(script.Parent.Parent.Hooks)
local GameLogic = require(script.Parent.Parent.GameLogic)
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
	model:PivotTo(home * CFrame.Angles(0, math.rad((entry :: any).yaw or 0), 0) * offset:Inverse()) -- frente do modelo = -Z (medido nas estátuas)
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

type Fx = { stun: boolean, weak: number, guard: boolean }

-- Resolve um golpe. Devolve (acertou, dano, efeito aplicado).
local function resolve(att: Side, def: Side, move: GameRules.MoveDef, attFx: Fx, defFx: Fx): (boolean, number, string?)
	local dir = (def.home.Position - att.home.Position).Unit
	local base = att.model:GetPivot()
	animate(att, base + dir * G.LungeDistance, 0.18, Enum.EasingStyle.Back)
	-- sorteio no GameLogic (o mesmo código testado em tests/GameLogic.spec)
	local hit, dmg, effect =
		GameLogic.rollMove(att.power, move, attFx, defFx, math.random(), math.random(), math.random())
	if hit then
		setHp(def, def.hp - dmg)
		flash(def, Color3.fromRGB(255, 60, 60))
		Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = def.home.Position })
		local dbase = def.model:GetPivot()
		task.spawn(function()
			animate(def, dbase * CFrame.Angles(math.rad(-10), 0, 0) + dir * 1.5, 0.1)
			animate(def, dbase, 0.2)
		end)
	else
		-- ERROU: o alvo desvia de lado
		local dbase = def.model:GetPivot()
		local side = dir:Cross(Vector3.yAxis)
		task.spawn(function()
			animate(def, dbase + side * 3, 0.12)
			animate(def, dbase, 0.2)
		end)
	end
	animate(att, base, 0.25)
	return hit, dmg, effect
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
				Hooks.fire("battleWon", player)
				Remotes.GiantReact:FireAllClients({ userId = player.UserId, kind = "cheer" })
				if (profile.giantRewardsToday or 0) < G.RewardedWinsPerDay then
					profile.giantRewardsToday = (profile.giantRewardsToday or 0) + 1
					local lv = GiantService.levelOf(profile, me.speciesId)
					coins = math.floor(G.WinCoinsBase + lv * G.WinCoinsPerLevel)
					xp = math.floor(G.WinXpBase + lv * G.WinXpPerLevel)
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
	local TB = GameRules.TurnBattle
	local center = World.Arena.center
	local y = center.Y + World.Arena.floorTop
	local axis = CFrame.lookAt(Vector3.new(center.X, y, center.Z), Vector3.new(0, y, 0))
	local homeMe = axis * CFrame.new(0, 0, G.Spacing / 2)
	local homeFoe = axis * CFrame.new(0, 0, -G.Spacing / 2)
	homeMe = CFrame.lookAt(homeMe.Position, homeFoe.Position)
	homeFoe = CFrame.lookAt(homeFoe.Position, homeMe.Position)
	-- Adversário: espécie comprável com moedas, nível parecido; vida e força ESPELHADAS do jogador
	-- (90% a 105%): a espécie muda o visual e os golpes, não a justiça da luta.
	local pool = {}
	for _, sp in Config.Species do
		if not sp.robux and CreatureModels.BySpecies[sp.id] and sp.id ~= speciesId then
			table.insert(pool, sp.id)
		end
	end
	local foeId = pool[math.random(1, #pool)]
	local myLevel = math.max(1, GiantService.levelOf(profile, speciesId))
	local foeLevel = math.max(1, myLevel + math.random(-TB.FoeLevelSpread, TB.FoeLevelSpread))
	local me = makeSide(speciesId, myLevel, profile.rebirths, homeMe, Color3.fromRGB(90, 220, 120))
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
	foe.maxHp = math.floor(me.maxHp * (0.9 + math.random() * 0.15))
	setHp(foe, foe.maxHp)
	foe.power = me.power * (0.9 + math.random() * 0.15)
	local myMoves = GameRules.movesFor(speciesId)
	local foeMoves = GameRules.movesFor(foeId)
	local state: any = {
		player = player,
		me = me,
		foe = foe,
		over = false,
		specialAt = 0,
		waiting = false,
		choice = nil,
	}
	active = state
	local moveInfo = {}
	for i, m in myMoves do
		moveInfo[i] = { name = m.name, power = m.power, accuracy = m.accuracy, desc = m.desc, effect = m.effect }
	end
	Remotes.GiantBattle:FireClient(player, {
		kind = "Start",
		me = { name = me.name, hp = me.maxHp, power = me.power, species = speciesId, level = myLevel },
		foe = { name = foe.name, hp = foe.maxHp, power = foe.power, level = foeLevel, species = foeId },
		moves = moveInfo,
		turnSeconds = TB.TurnSeconds,
	})
	task.wait(G.StartDelay)
	local meFx: Fx = { stun = false, weak = 0, guard = false }
	local foeFx: Fx = { stun = false, weak = 0, guard = false }
	local function report(side: string, moveName: string, hit: boolean, dmg: number, effect: string?)
		Remotes.GiantBattle:FireClient(player, {
			kind = "Result",
			side = side,
			move = moveName,
			hit = hit,
			dmg = dmg,
			effect = effect,
			meHp = me.hp,
			foeHp = foe.hp,
		})
	end
	local rounds = 0
	while me.hp > 0 and foe.hp > 0 and rounds < TB.MaxRounds and player.Parent do
		rounds += 1
		-- Vez do jogador
		if meFx.stun then
			meFx.stun = false
			report("me", "TONTO", false, 0, "stunned")
			task.wait(1.2)
		else
			state.choice = nil
			state.waiting = true
			local deadline = os.clock() + TB.TurnSeconds
			Remotes.GiantBattle:FireClient(player, { kind = "Turn", round = rounds, seconds = TB.TurnSeconds })
			while state.choice == nil and os.clock() < deadline and player.Parent do
				task.wait(0.1)
			end
			state.waiting = false
			if not player.Parent then
				break
			end
			local move = myMoves[state.choice or 1]
			local hit, dmg, effect = resolve(me, foe, move, meFx, foeFx)
			report("me", move.name, hit, dmg, effect)
			task.wait(0.9)
		end
		if foe.hp <= 0 then
			break
		end
		-- Vez do selvagem: prefere o golpe seguro; quando está perdendo, arrisca mais.
		if foeFx.stun then
			foeFx.stun = false
			report("foe", "TONTO", false, 0, "stunned")
			task.wait(1.0)
		else
			local r = math.random()
			local losing = foe.hp / foe.maxHp < me.hp / me.maxHp
			local idx = if r < (if losing then 0.35 else 0.55) then 1 elseif r < 0.78 then 2 else 3
			local move = foeMoves[idx]
			local hit, dmg, effect = resolve(foe, me, move, foeFx, meFx)
			report("foe", move.name, hit, dmg, effect)
			task.wait(0.9)
		end
	end
	state.over = true
	-- Sem escolher nenhum golpe (AFK, o servidor jogou sozinho) não há prêmio: anti-fazenda.
	local won = GameLogic.battleOutcome(me.hp, me.maxHp, foe.hp, foe.maxHp, state.acted or 0)
	if not player.Parent then
		won = false
	end
	finish(player, me, foe, won, if rounds >= TB.MaxRounds and me.hp > 0 and foe.hp > 0 then "tempo" else nil)
	if state.someoneWaiting then
		lastBattle[player] = os.clock() + 30 -- descanso extra: a vez é de quem estava esperando
	end
	active = nil
end

function GiantBattleService.init()
	Remotes.RequestGiantBattle.OnServerEvent:Connect(function(player, speciesId)
		if type(speciesId) ~= "string" or #speciesId > 32 or not Guard.allow(player, "Battle") then
			return
		end
		local profile = DataService.get(player)
		if not profile or not profile.ownedSpecies[speciesId] or not Config.SpeciesById[speciesId] then
			return -- só leva um gigante que é seu
		end
		local busy = GiantBattleService.IsArenaBusy
		if active or (busy and busy()) then
			-- alguém esperou: quem está lutando ganha um descanso maior depois (o coliseu gira)
			local a: any = active
			if a and a.player ~= player then
				a.someoneWaiting = true
			end
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
				-- nunca deixa modelos/barras no coliseu nem o coliseu preso
				local a: any = active
				if a then
					for _, side in { a.me, a.foe } do
						if side and side.model then
							side.model:Destroy()
						end
					end
				end
				active = nil
			end
		end)
	end)
	Remotes.RequestGiantMove.OnServerEvent:Connect(function(player, index)
		if type(index) ~= "number" or not Guard.isIndex(index, 3) then
			return
		end
		local a: any = active
		if not a or a.player ~= player or a.over or not a.waiting or a.choice ~= nil then
			return
		end
		if not Guard.allow(player, "Move") then
			return
		end
		a.choice = index
		a.acted = (a.acted or 0) + 1
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastBattle[p] = nil
	end)
end

return GiantBattleService
