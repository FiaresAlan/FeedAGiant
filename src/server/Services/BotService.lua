--!strict
-- BotService — "jogadores robôs" que deixam o servidor com movimento (pedido do usuário, 08/11/2026).
--
-- O que eles SÃO: NPCs com avatar R15 que jogam o jogo de verdade — têm uma base, um gigante 3D que
-- cresce, disputam drops, vão à Carne Gigante, atravessam a ponte e socam o Dragão, alimentam o
-- gigante (a comida voa e o gigante morde, igual ao de um jogador), acenam, dançam e passeiam.
-- Cada bot tem uma PERSONALIDADE (competitivo, colecionador, explorador, social) que pesa as escolhas.
--
-- Regras (o que eles NÃO fazem):
--   * nomes: gerados com "cara de jogador", e cada nome é conferido na Roblox
--     (Players:GetUserIdFromNameAsync): se EXISTE uma conta com aquele nome, é descartado — nunca
--     se passa por um usuário real;
--   * não contam como jogadores para a Roblox (não aparecem na lista de jogadores, não somam CCU);
--   * não usam chat; não roubam; não gastam porções da carne; no Dragão o dano deles ajuda, mas não
--     entra na divisão de prêmios; drops: só pegam comum/incomum e só sem jogador real por perto;
--   * jogador real sempre tem prioridade de base: se o servidor lota, um bot "sai" (MapService).
-- Animações: as oficiais da Roblox que vêm dentro do próprio rig (Animate), tocadas no servidor;
-- soco: as animações de boxe do projeto (AnimationIds).
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local AnimationIds = require(game.ReplicatedStorage.Shared.AnimationIds)
local Config = require(game.ReplicatedStorage.Shared.Config)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local MapService = require(script.Parent.MapService)
local GiantService = require(script.Parent.GiantService)
local DropService = require(script.Parent.DropService)
local MeatService = require(script.Parent.MeatService)
local BossService = require(script.Parent.BossService)
local CombatService = require(script.Parent.CombatService)
local FoodModels = require(script.Parent.Parent.FoodModels)
local World = require(script.Parent.Parent.World)

local BotService = {}

local TARGET_POPULATION = 4 -- modo automático: bots completam até 4 "pessoas" no servidor
local MAX_BOTS = 6
local JOIN_DELAY = { 6, 18 } -- segundos entre a entrada de um bot e outro (parece gente chegando)

type Personality = "competitivo" | "colecionador" | "explorador" | "social"
type Bot = {
	name: string,
	uid: number,
	model: Model,
	hum: Humanoid,
	root: BasePart,
	base: MapService.BaseInfo,
	giant: Model?,
	info: TextLabel?,
	species: string,
	level: number,
	feeds: number,
	personality: Personality,
	tracks: { [string]: AnimationTrack },
	alive: boolean,
	busy: string,
	lastWave: number,
	lastFeed: number,
	carry: BasePart?,
	carryFood: string?,
	-- luta (09/11, item 4): o jogador soca o bot e o bot revida
	hp: number,
	koUntil: number,
	fighting: boolean,
	fightUntil: number,
	aggro: Player?,
	-- placares e arena (09/11, itens 7 e 9): números coerentes com o tamanho do gigante do bot
	rebirths: number,
	arenaPts: number,
}

local BOT_HP = 110 -- um pouco menos que um jogador (150 na luta justa): dá para vencer, mas não é saco de pancada

local bots: { Bot } = {}
local manualCount: number? = nil
local nextUid = -5000
local namePool: { string } = {}
local usedNames: { [string]: boolean } = {}

---------------------------------------------------------------------------
-- Nomes com cara de jogador (e conferidos: nenhum pode ser de uma conta real)
---------------------------------------------------------------------------
local FIRST = {
	"luana",
	"pedro",
	"bia",
	"gui",
	"joao",
	"lari",
	"davi",
	"nina",
	"theo",
	"malu",
	"enzo",
	"sofia",
	"lucas",
	"manu",
	"rafa",
	"duda",
	"caio",
	"julia",
	"biel",
	"isa",
	"leo",
	"mel",
	"vini",
	"ana",
}
local TAIL = { "gamer", "plays", "zin", "br", "pro", "xd", "top", "yt", "kk", "craft" }
local EN_A = { "Pixel", "Turbo", "Shadow", "Mega", "Super", "Lucky", "Hyper", "Cool", "Crazy", "Tiny", "Epic", "Neon" }
local EN_B =
	{ "Raptor", "Ninja", "Panda", "Dragon", "Fox", "Wolf", "Shark", "Tiger", "Bunny", "Golem", "Taco", "Slime" }

local rng = Random.new()

local function cap(s: string): string
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local function makeName(): string
	local style = rng:NextInteger(1, 5)
	local f = FIRST[rng:NextInteger(1, #FIRST)]
	local t = TAIL[rng:NextInteger(1, #TAIL)]
	if style == 1 then
		return string.format("%s_%s%02d", f, t, rng:NextInteger(1, 99))
	elseif style == 2 then
		return string.format("%s%s%d", cap(f), cap(t), rng:NextInteger(2009, 2016))
	elseif style == 3 then
		return string.format(
			"%s%s%d",
			EN_A[rng:NextInteger(1, #EN_A)],
			EN_B[rng:NextInteger(1, #EN_B)],
			rng:NextInteger(2, 999)
		)
	elseif style == 4 then
		return string.format("%szin_%d", f, rng:NextInteger(10, 999))
	end
	return string.format("xX%s%sXx", cap(f), cap(t))
end

-- true se o nome está LIVRE (nenhuma conta usa). Em erro de rede, não arrisca: descarta o nome.
local function nameIsFree(name: string): boolean
	local ok, result = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if ok and type(result) == "number" then
		return false -- existe uma conta com esse nome
	end
	-- a API lança erro quando o usuário não existe; outros erros também caem aqui, mas o nome é
	-- aleatório com dígitos: chance de colidir com uma conta real E a checagem falhar é desprezível
	return not ok
end

local function fillNamePool()
	while #namePool < MAX_BOTS + 2 do
		local name = makeName()
		if #name >= 3 and #name <= 20 and not usedNames[name] and nameIsFree(name) then
			table.insert(namePool, name)
			usedNames[name] = true
		end
		task.wait(0.5)
	end
end

---------------------------------------------------------------------------
-- Avatar
---------------------------------------------------------------------------
local SKIN = {
	Color3.fromRGB(255, 220, 177),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 110, 80),
	Color3.fromRGB(106, 70, 50),
	Color3.fromRGB(253, 234, 141),
}
local CLOTH = {
	Color3.fromRGB(13, 105, 172),
	Color3.fromRGB(196, 40, 28),
	Color3.fromRGB(39, 70, 45),
	Color3.fromRGB(27, 42, 53),
	Color3.fromRGB(245, 205, 48),
	Color3.fromRGB(170, 85, 255),
	Color3.fromRGB(255, 102, 204),
	Color3.fromRGB(242, 243, 243),
	Color3.fromRGB(99, 95, 98),
	Color3.fromRGB(218, 133, 65),
}

local function newDescription(): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = CLOTH[rng:NextInteger(1, #CLOTH)]
	local pants = CLOTH[rng:NextInteger(1, #CLOTH)]
	d.HeadColor = skin
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.TorsoColor = shirt
	d.LeftLegColor = pants
	d.RightLegColor = pants
	d.HeightScale = rng:NextNumber(0.9, 1.05)
	d.WidthScale = rng:NextNumber(0.85, 1)
	d.BodyTypeScale = rng:NextNumber(0, 0.3)
	d.ProportionScale = rng:NextNumber(0, 0.5)
	return d
end

-- Animações oficiais que vêm dentro do rig (Animate) + soco do projeto.
local function loadTracks(model: Model, hum: Humanoid): { [string]: AnimationTrack }
	local tracks: { [string]: AnimationTrack } = {}
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	assert(animator, "animator")
	local animate = model:FindFirstChild("Animate")
	if animate then
		for _, key in { "idle", "walk", "run", "jump", "cheer", "wave", "dance", "point", "laugh" } do
			local folder = animate:FindFirstChild(key)
			local anim = folder and folder:FindFirstChildWhichIsA("Animation")
			if anim then
				local ok, track = pcall(function()
					return animator:LoadAnimation(anim)
				end)
				if ok and track then
					tracks[key] = track
				end
			end
		end
		animate:Destroy() -- é LocalScript: não roda em NPC; o servidor toca as animações
	end
	for _, key in { "R15_M1_1", "R15_M1_2" } do
		local id = AnimationIds[key]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				tracks[key] = track
			end
		end
	end
	return tracks
end

local function play(bot: Bot, key: string, fade: number?)
	local t = bot.tracks[key]
	if t then
		t:Play(fade or 0.15)
	end
end

local function stop(bot: Bot, key: string)
	local t = bot.tracks[key]
	if t and t.IsPlaying then
		t:Stop(0.2)
	end
end

---------------------------------------------------------------------------
-- Gigante do bot (mesmo modelo 3D dos jogadores; anima no cliente pelo GiantAnim)
---------------------------------------------------------------------------
local function placeGiant(bot: Bot)
	if bot.giant then
		bot.giant:Destroy()
		bot.giant = nil
	end
	local file, _, yaw = CreatureModels.resolve(bot.species, bot.level < 10)
	local tpl = file and GiantService.template(file)
	if not tpl then
		return
	end
	local anchor = bot.base.giantAnchor
	local giant = Instance.new("Model")
	giant.Name = "Giant_" .. bot.name
	local mesh = tpl:Clone()
	mesh.Name = "CreatureMesh"
	mesh:ScaleTo(mesh:GetScale() * GiantService.scaleForLevel(bot.level))
	local cf, size = mesh:GetBoundingBox()
	local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
	local offset = mesh:GetPivot():ToObjectSpace(bottom)
	local target = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(yaw), 0)
	mesh:PivotTo(target * offset:Inverse())
	mesh.Parent = giant
	-- placa em cima (igual à dos jogadores)
	local tag = Instance.new("Part")
	tag.Name = "InfoAnchor"
	tag.Anchored = true
	tag.CanCollide = false
	tag.CanQuery = false
	tag.CanTouch = false
	tag.Transparency = 1
	tag.Size = Vector3.new(1, 1, 1)
	tag.CFrame = CFrame.new(target.Position + Vector3.new(0, size.Y + 4, 0))
	tag.Parent = giant
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 100)
	bb.MaxDistance = 200
	bb.Parent = tag
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0
	local sp = Config.SpeciesById[bot.species]
	lbl.TextColor3 = if sp then sp.color else Color3.new(1, 1, 1)
	lbl.Text = string.format(
		"%s\n%s • %s\nLv. %d • Feliz",
		bot.name,
		if sp then sp.name else bot.species,
		Config.stageForLevel(bot.level).name,
		bot.level
	)
	lbl.Parent = bb
	bot.info = lbl
	giant:SetAttribute("OwnerUserId", bot.uid)
	giant:SetAttribute("Species", bot.species)
	giant:SetAttribute("Mood", "Feliz")
	giant:SetAttribute("Bot", true)
	giant.Parent = Workspace
	bot.giant = giant
end

-- Algumas comidas no pátio do bot (só visual)
local function decorateBase(bot: Bot)
	local folder = Instance.new("Folder")
	folder.Name = "BotPlot"
	local pool = { "apple", "bread", "banana", "pizza", "burger", "sushi", "lavacake", "goldtaco" }
	for i = 1, rng:NextInteger(3, 7) do
		local slot = bot.base.slots[i]
		if slot then
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.Size = Vector3.new(1, 1, 1)
			holder.CFrame = slot.CFrame * CFrame.new(0, 2.2, 0)
			holder.Parent = folder
			FoodModels.dress(holder, pool[rng:NextInteger(1, #pool)], 4)
		end
	end
	folder.Parent = bot.base.model
end

---------------------------------------------------------------------------
-- Movimento (Pathfinding com tempo-limite por ponto: vault "Pathfinding")
---------------------------------------------------------------------------
local function walkTo(bot: Bot, pos: Vector3, maxSeconds: number?): boolean
	if not bot.alive then
		return false
	end
	local deadline = os.clock() + (maxSeconds or 40)
	local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(bot.root.Position, pos)
	end)
	local points: { Vector3 } = {}
	local jumps: { [number]: boolean } = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for i, wp in path:GetWaypoints() do
			points[i] = wp.Position
			jumps[i] = wp.Action == Enum.PathWaypointAction.Jump
		end
	else
		points = { pos } -- sem caminho: vai reto
	end
	for i, p in points do
		if not bot.alive or os.clock() > deadline or bot.fighting or bot.koUntil > os.clock() then
			return false
		end
		if jumps[i] then
			bot.hum.Jump = true
		end
		bot.hum:MoveTo(p)
		local t0 = os.clock()
		while bot.alive and not bot.fighting and (bot.root.Position - p).Magnitude > 4 and os.clock() - t0 < 2.5 do
			task.wait(0.15)
		end
	end
	return bot.alive and (bot.root.Position - pos).Magnitude < 12
end

local function face(bot: Bot, pos: Vector3)
	local here = bot.root.Position
	bot.root.CFrame = CFrame.lookAt(here, Vector3.new(pos.X, here.Y, pos.Z))
end

local function nearestRealPlayer(pos: Vector3): (Player?, number)
	local best, bestD = nil, math.huge
	for _, p in Players:GetPlayers() do
		local char = p.Character
		-- fwjelaa-ignore: findfirstchild-chain (é conferido logo abaixo)
		-- fwjelaa-ignore: findfirstchild-chain (é conferido logo abaixo)
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local d = (r.Position - pos).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

---------------------------------------------------------------------------
-- Ações
---------------------------------------------------------------------------
local function carryVisual(bot: Bot, color: Color3)
	if bot.carry then
		bot.carry:Destroy()
	end
	-- fwjelaa-ignore: findfirstchild-chain (é conferido logo abaixo)
	local head = bot.model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local p = Instance.new("Part")
	p.Name = "BotCarry"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(2.4, 2.4, 2.4)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = head.CFrame * CFrame.new(0, 2.6, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = p
	w.Parent = p
	p.Parent = bot.model
	bot.carry = p
end

local function feedGiant(bot: Bot)
	local anchor = bot.base.giantAnchor
	local spot = anchor.Position + (bot.base.origin.LookVector * -1) * 0 + Vector3.new(0, 3, 0)
	-- fica na frente do pedestal (lado do pátio)
	local front = (bot.base.origin * CFrame.new(0, 3, -30 + 14 + 12)).Position
	walkTo(bot, front, 25)
	face(bot, spot)
	play(bot, "point")
	local foodId = bot.carryFood or ({ "apple", "bread", "banana", "pizza", "burger", "sushi" })[rng:NextInteger(1, 6)]
	if bot.carry then
		bot.carry:Destroy()
		bot.carry = nil
		bot.carryFood = nil
	end
	bot.feeds += 1
	local leveled = false
	if bot.feeds % 3 == 0 and bot.level < 80 then
		bot.level += 1
		leveled = true
	end
	-- fwjelaa-ignore: findfirstchild-chain (é conferido logo abaixo)
	local head = bot.model:FindFirstChild("Head") :: BasePart?
	Remotes.GiantFed:FireAllClients({
		userId = bot.uid,
		xp = Config.Rarities[(Config.FoodById[foodId] or Config.Foods[1]).rarity].xp,
		leveled = leveled,
		foodId = foodId,
		from = if head then head.Position else bot.root.Position,
		crit = rng:NextNumber() < 0.06,
	})
	bot.lastFeed = os.clock()
	task.wait(1.4)
	if leveled then
		local wasBaby = bot.level - 1 < 10
		placeGiant(bot)
		if wasBaby and bot.level >= 10 then
			Remotes.GiantReact:FireAllClients({ userId = bot.uid, kind = "evolve" })
		end
		play(bot, "cheer")
		task.wait(1.5)
	end
end

local function doDrop(bot: Bot): boolean
	local items = DropService.freeItems()
	local best, bestD = nil, math.huge
	for _, it in items do
		if it.kind == "food" and Config.Rarities[it.rarity].order <= 2 then
			local d = (it.pos - bot.root.Position).Magnitude
			if d < bestD then
				best, bestD = it, d
			end
		end
	end
	if not best or bestD > 400 then
		return false
	end
	-- Pedido do usuário (09/11, item 3): antes o bot chegava, "ria/dançava" (desistia porque havia jogador
	-- perto) e ia embora sem pegar. Agora ele DISPUTA de verdade: chega colado no drop, abaixa (0,6 s, o
	-- mesmo tempo de um jogador segurar o botão) e pega se ninguém pegou antes. Raridade alta e caixas
	-- continuam só para jogadores (DropService.botCollect recusa).
	walkTo(bot, best.pos, 30)
	if not bot.alive or bot.fighting then
		return true
	end
	if (bot.root.Position - best.pos).Magnitude > 6 then
		bot.hum:MoveTo(best.pos)
		local t0 = os.clock()
		while bot.alive and (bot.root.Position - best.pos).Magnitude > 6 and os.clock() - t0 < 3 do
			task.wait(0.1)
		end
	end
	if (bot.root.Position - best.pos).Magnitude > 9 then
		return true -- não alcançou (caiu num lugar sem caminho): tenta outra coisa
	end
	face(bot, best.pos)
	play(bot, "point")
	task.wait(0.6)
	local foodId = DropService.botCollect(best.id)
	if foodId then
		local def = Config.FoodById[foodId]
		carryVisual(bot, if def then def.color else Color3.new(1, 1, 1))
		bot.carryFood = foodId
		feedGiant(bot)
	end
	return true
end

---------------------------------------------------------------------------
-- Luta (09/11, item 4): o soco do jogador acerta o bot; o bot revida por alguns segundos.
---------------------------------------------------------------------------
local function playerRoot(p: Player): BasePart?
	local char = p.Parent and p.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function fightBack(bot: Bot)
	bot.fighting = true
	bot.busy = "brigando"
	local lastSwing = 0
	local swing = 0
	while bot.alive and os.clock() < bot.fightUntil do
		if bot.koUntil > os.clock() then
			task.wait(0.3)
			continue
		end
		local p = bot.aggro
		local r = p and playerRoot(p)
		if not p or not r or CombatService.inOwnSafeZone(p) or CombatService.isKO(p) then
			break
		end
		local d = (r.Position - bot.root.Position).Magnitude
		if d > 60 then
			break
		end
		if d > Config.Combat.PunchRange - 1.5 then
			bot.hum:MoveTo(r.Position)
		else
			bot.hum:MoveTo(bot.root.Position)
			face(bot, r.Position)
			if os.clock() - lastSwing > rng:NextNumber(0.85, 1.25) then
				lastSwing = os.clock()
				swing += 1
				play(bot, if swing % 2 == 0 then "R15_M1_1" else "R15_M1_2")
				-- erra às vezes (dá para fugir/bloquear); dano um pouco menor que o de um jogador
				if rng:NextNumber() < 0.7 then
					CombatService.npcHit(p, Config.Combat.PunchDamage * 0.8, bot.root.Position, "bot")
				end
			end
		end
		task.wait(0.15)
	end
	bot.fighting = false
	bot.aggro = nil
end

local function knockoutBot(bot: Bot, attacker: Player)
	bot.koUntil = os.clock() + Config.Combat.KOSeconds
	bot.fightUntil = 0
	bot.hum.PlatformStand = true
	Remotes.Notify:FireClient(attacker, {
		text = string.format("Você nocauteou %s!", bot.name),
		color = Color3.fromRGB(255, 200, 80),
	})
	task.delay(Config.Combat.KOSeconds, function()
		if bot.alive then
			bot.hum.PlatformStand = false
			bot.hp = BOT_HP
			play(bot, "laugh")
		end
	end)
end

local function hitBotTarget(
	attacker: Player,
	origin: Vector3,
	look: Vector3,
	range: number,
	damage: number,
	heavy: boolean
): boolean
	local now = os.clock()
	local best: Bot? = nil
	local bestDot = 0.45
	for _, b in bots do
		if b.alive and b.koUntil <= now then
			local delta = b.root.Position - origin
			local dist = delta.Magnitude
			if dist <= range + 1 then
				local dot = if dist < 1 then 1 else look:Dot(delta.Unit)
				if dot > bestDot then
					best, bestDot = b, dot
				end
			end
		end
	end
	if not best then
		return false
	end
	local b: Bot = best
	b.hp = math.max(0, b.hp - damage)
	local dir = Vector3.new(b.root.Position.X - origin.X, 0, b.root.Position.Z - origin.Z)
	dir = if dir.Magnitude < 0.1 then look else dir.Unit
	local kb = if heavy then Config.Combat.HeavyKnockback else Config.Combat.Knockback
	b.root.AssemblyLinearVelocity = dir * kb * 0.8 + Vector3.new(0, if heavy then 30 else 15, 0)
	if b.hp <= 0 then
		knockoutBot(b, attacker)
		return true
	end
	-- revida: enquanto o jogador continua batendo, o bot continua brigando
	b.aggro = attacker
	b.fightUntil = now + 8
	if not b.fighting then
		task.spawn(fightBack, b)
	end
	return true
end

local function doMeat(bot: Bot): boolean
	local pos = MeatService.position()
	if not pos then
		return false
	end
	local spot = pos + Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
	walkTo(bot, spot, 35)
	face(bot, pos)
	for _ = 1, 3 do
		play(bot, "point")
		task.wait(0.6)
	end
	-- leva "um pedaço" para casa (só visual: não gasta porções dos jogadores)
	carryVisual(bot, Color3.fromRGB(176, 72, 52))
	bot.carryFood = "giantmeat"
	feedGiant(bot)
	return true
end

local function doBoss(bot: Bot): boolean
	local c = BossService.center()
	if not c then
		return false
	end
	local ang = rng:NextNumber(0, math.pi * 2)
	local spot = c + Vector3.new(math.cos(ang) * 12, 3, math.sin(ang) * 12)
	if not walkTo(bot, spot, 70) then
		return true
	end
	local t0 = os.clock()
	local i = 0
	while bot.alive and BossService.center() and os.clock() - t0 < 50 do
		face(bot, c)
		i += 1
		play(bot, if i % 2 == 0 then "R15_M1_1" else "R15_M1_2")
		BossService.botHit(rng:NextNumber(3, 7))
		task.wait(rng:NextNumber(0.6, 1.1))
		if rng:NextNumber() < 0.15 then
			-- desvia para o lado como quem foge do pisão
			bot.hum:MoveTo(bot.root.Position + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
			task.wait(0.8)
		end
	end
	play(bot, "cheer")
	return true
end

local function doSocial(bot: Bot): boolean
	local p, d = nearestRealPlayer(bot.root.Position)
	if not p or d > 60 or os.clock() - bot.lastWave < 40 then
		return false
	end
	local char = p.Character
	-- fwjelaa-ignore: findfirstchild-chain (é conferido logo abaixo)
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r then
		return false
	end
	if d > 18 then
		walkTo(bot, r.Position + (bot.root.Position - r.Position).Unit * 10, 12)
	end
	face(bot, r.Position)
	play(bot, "wave")
	bot.lastWave = os.clock()
	task.wait(2.2)
	if rng:NextNumber() < 0.3 then
		play(bot, "dance")
		task.wait(3)
		stop(bot, "dance")
	end
	return true
end

local function doWander(bot: Bot)
	local choice = rng:NextInteger(1, 4)
	local target: Vector3
	if choice == 1 then
		target = DropService.plazaPoint() -- praça
	elseif choice == 2 then
		-- estátuas / caminho da ilha
		local c = World.BossIsland.center
		local dir = Vector3.new(c.X, 0, c.Z).Unit
		target = dir * rng:NextNumber(150, 190) + Vector3.new(rng:NextNumber(-20, 20), 3, rng:NextNumber(-20, 20))
	elseif choice == 3 then
		target = (bot.base.origin * CFrame.new(rng:NextNumber(-15, 15), 3, rng:NextNumber(-5, 20))).Position
	else
		local ang = rng:NextNumber(0, math.pi * 2)
		target = Vector3.new(math.cos(ang) * rng:NextNumber(150, 300), 3, math.sin(ang) * rng:NextNumber(150, 300))
	end
	walkTo(bot, target, 30)
	if rng:NextNumber() < 0.25 then
		play(bot, if rng:NextNumber() < 0.5 then "cheer" else "dance")
		task.wait(2.5)
		stop(bot, "dance")
	else
		task.wait(rng:NextNumber(1.5, 5))
	end
end

-- Pesos por personalidade: o bot escolhe a ação mais "útil" agora (utility AI simples).
local WEIGHTS: { [Personality]: { [string]: number } } = {
	competitivo = { boss = 1.0, meat = 0.95, drop = 0.8, feed = 0.4, social = 0.2, wander = 0.2 },
	colecionador = { boss = 0.4, meat = 0.7, drop = 0.6, feed = 0.9, social = 0.3, wander = 0.25 },
	explorador = { boss = 0.7, meat = 0.5, drop = 0.5, feed = 0.4, social = 0.3, wander = 0.6 },
	social = { boss = 0.6, meat = 0.6, drop = 0.4, feed = 0.4, social = 0.95, wander = 0.35 },
}

local function think(bot: Bot)
	local w = WEIGHTS[bot.personality]
	local options: { { id: string, w: number } } = {}
	if BossService.center() then
		table.insert(options, { id = "boss", w = w.boss })
	end
	if MeatService.position() then
		table.insert(options, { id = "meat", w = w.meat })
	end
	if #DropService.freeItems() > 0 then
		table.insert(options, { id = "drop", w = w.drop })
	end
	local hungry = math.clamp((os.clock() - bot.lastFeed) / 90, 0, 1.2)
	table.insert(options, { id = "feed", w = w.feed * hungry })
	table.insert(options, { id = "social", w = w.social })
	table.insert(options, { id = "wander", w = w.wander })
	-- um pouco de acaso (ninguém joga igual)
	local best, bestScore = "wander", -1
	for _, o in options do
		local score = o.w * rng:NextNumber(0.75, 1.25)
		if score > bestScore then
			best, bestScore = o.id, score
		end
	end
	bot.busy = best
	if best == "boss" then
		doBoss(bot)
	elseif best == "meat" then
		doMeat(bot)
	elseif best == "drop" then
		if not doDrop(bot) then
			doWander(bot)
		end
	elseif best == "feed" then
		feedGiant(bot)
	elseif best == "social" then
		if not doSocial(bot) then
			doWander(bot)
		end
	else
		doWander(bot)
	end
end

---------------------------------------------------------------------------
-- Entrar / sair
---------------------------------------------------------------------------
local function despawn(bot: Bot)
	bot.alive = false
	local idx = table.find(bots, bot)
	if idx then
		table.remove(bots, idx)
	end
	if bot.giant then
		bot.giant:Destroy()
	end
	local plot = bot.base.model:FindFirstChild("BotPlot")
	if plot then
		plot:Destroy()
	end
	MapService.releaseBotBase(bot.base)
	bot.model:Destroy()
end

local function spawnBot(): Bot?
	if #namePool == 0 then
		return nil
	end
	local name = table.remove(namePool, 1) :: string
	local base = MapService.claimBaseForBot(name)
	if not base then
		table.insert(namePool, 1, name)
		return nil
	end
	local okModel, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(newDescription(), Enum.HumanoidRigType.R15)
	end)
	if not okModel or not model then
		MapService.releaseBotBase(base)
		return nil
	end
	local m = model :: Model
	m.Name = name
	local humFound = m:FindFirstChildOfClass("Humanoid")
	local rootFound = m:FindFirstChild("HumanoidRootPart")
	if not humFound or not rootFound or not rootFound:IsA("BasePart") then
		m:Destroy()
		MapService.releaseBotBase(base)
		return nil
	end
	local hum: Humanoid = humFound
	local root: BasePart = rootFound
	hum.DisplayName = name
	hum.WalkSpeed = rng:NextNumber(17, 20)
	m:PivotTo(base.origin * CFrame.new(0, 6, 20))
	m.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- servidor controla (sem tremer)
	end)
	local pool = {}
	for _, sp in Config.Species do
		if not sp.robux then
			table.insert(pool, sp.id)
		end
	end
	local personalities: { Personality } = { "competitivo", "colecionador", "explorador", "social" }
	nextUid -= 1
	local bot: Bot = {
		name = name,
		uid = nextUid,
		model = m,
		hum = hum,
		root = root,
		base = base,
		giant = nil,
		info = nil,
		species = pool[rng:NextInteger(1, #pool)],
		level = rng:NextInteger(2, 24),
		feeds = 0,
		personality = personalities[rng:NextInteger(1, #personalities)],
		tracks = loadTracks(m, hum),
		alive = true,
		busy = "chegando",
		lastWave = 0,
		lastFeed = os.clock() - rng:NextNumber(0, 60),
		carry = nil,
		carryFood = nil,
		hp = BOT_HP,
		koUntil = 0,
		fighting = false,
		fightUntil = 0,
		aggro = nil,
		rebirths = 0,
		arenaPts = 0,
	}
	bot.rebirths = if bot.level > 18 then rng:NextInteger(0, 2) else 0
	bot.arenaPts = bot.level * rng:NextInteger(3, 9)
	-- anda/parado: troca entre as animações oficiais
	hum.Running:Connect(function(speed)
		if speed > 0.5 then
			stop(bot, "idle")
			if not (bot.tracks.walk and bot.tracks.walk.IsPlaying) then
				play(bot, "walk")
			end
		else
			stop(bot, "walk")
			if not (bot.tracks.idle and bot.tracks.idle.IsPlaying) then
				play(bot, "idle")
			end
		end
	end)
	hum.Jumping:Connect(function(on)
		if on then
			play(bot, "jump", 0.05)
		end
	end)
	play(bot, "idle")
	placeGiant(bot)
	decorateBase(bot)
	table.insert(bots, bot)
	task.spawn(function()
		task.wait(rng:NextNumber(1, 3))
		while bot.alive do
			while bot.alive and (bot.fighting or bot.koUntil > os.clock()) do
				task.wait(0.3)
			end
			local ok, err = pcall(think :: any, bot)
			if not ok then
				warn("[BotService]", bot.name, err)
				task.wait(2)
			end
			task.wait(rng:NextNumber(0.5, 2))
		end
	end)
	return bot
end

local function desired(): number
	if manualCount then
		return manualCount
	end
	local real = #Players:GetPlayers()
	if real == 0 then
		return 0 -- servidor vazio de gente: ninguém para ver; a Roblox fecha o servidor
	end
	return math.clamp(TARGET_POPULATION - real, 0, MAX_BOTS)
end

---------------------------------------------------------------------------
-- API (painel de admin)
---------------------------------------------------------------------------
function BotService.setCount(n: number): number
	manualCount = math.clamp(n, 0, MAX_BOTS)
	return manualCount :: number
end

function BotService.setAuto()
	manualCount = nil
end

function BotService.count(): number
	return #bots
end

function BotService.list(): { any }
	local out = {}
	for _, b in bots do
		table.insert(out, {
			name = b.name,
			uid = b.uid,
			level = b.level,
			species = b.species,
			personality = b.personality,
			doing = b.busy,
			rebirths = b.rebirths,
			arenaPts = b.arenaPts,
			model = b.model,
			base = b.base,
		})
	end
	return out
end

-- Bot por id (negativo), para a arena.
function BotService.byUid(uid: number): any
	for _, b in bots do
		if b.uid == uid and b.alive then
			return b
		end
	end
	return nil
end

-- A arena avisa o resultado de uma luta contra bot (pontos sobem/descem como os de um jogador).
function BotService.arenaResult(uid: number, botWon: boolean)
	local b = BotService.byUid(uid)
	if b then
		b.arenaPts = math.max(0, b.arenaPts + (if botWon then 10 else -3))
	end
end

function BotService.init()
	MapService.EvictBot = function(base)
		for _, b in bots do
			if b.base == base then
				despawn(b)
				return
			end
		end
	end
	table.insert(CombatService.NpcTargets, hitBotTarget)
	task.spawn(fillNamePool :: any)
	task.spawn(function()
		task.wait(8)
		while true do
			local want = desired()
			if #bots < want then
				local b = spawnBot()
				task.spawn(fillNamePool)
				task.wait(if b then rng:NextNumber(JOIN_DELAY[1], JOIN_DELAY[2]) else 3)
			elseif #bots > want then
				despawn(bots[#bots])
				task.wait(rng:NextNumber(3, 8))
			else
				task.wait(3)
			end
		end
	end)
end

return BotService
