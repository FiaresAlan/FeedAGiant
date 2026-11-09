--!strict
-- SocialFeastService — BANQUETE EM DUPLA, cooperação presencial e opcional.
-- Duas pessoas REAIS se encontram na praça e oferecem uma comida comum/incomum.
-- A primeira comida fica apenas PROMETIDA, no inventário; só as duas são consumidas
-- depois de confirmar presença, estoque e elegibilidade de ambos, sem yields.
-- Se faltar parceiro, alguém desconectar, o prazo vencer ou o servidor cair:
-- NENHUM item foi removido. Não existe perda offline ou prêmio pago.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Features = require(game.ReplicatedStorage.Shared.Features)
local Rules = require(game.ReplicatedStorage.Shared.SocialFeastRules)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local GiantService = require(script.Parent.GiantService)

local SocialFeastService = {}

type Reservation = { player: Player, foodUid: string, untilTime: number }
local reservation: Reservation? = nil
local cooldownUntil = 0
local individualCooldown: { [number]: number } = {}
local stand: BasePart? = nil
local label: TextLabel? = nil
local prompt: ProximityPrompt? = nil
local sparks: ParticleEmitter? = nil

local function on(): boolean
	return Features.on("SocialFeast")
end

local function notify(player: Player, message: string, color: Color3?)
	if player.Parent then
		Remotes.Notify:FireClient(player, {
			text = message,
			color = color or Color3.fromRGB(255, 224, 125),
		})
	end
end

local function ownedSlice(profile: any): any
	local s = profile.communityFeast
	if type(s) ~= "table" then
		s = { v = 1, day = 0, count = 0, total = 0 }
		profile.communityFeast = s
	end
	return s
end

local function expire(now: number)
	local current = reservation
	if current and (now >= current.untilTime or not current.player.Parent) then
		reservation = nil
		if current.player.Parent then
			notify(current.player, "O Banquete em Dupla expirou. Sua comida continua guardada!")
		end
	end
end

local function updateDisplay(now: number)
	local l, p = label, prompt
	if not l or not p then
		return
	end
	if not on() then
		l.Text = ""
		p.Enabled = false
		return
	end
	if now < cooldownUntil then
		local left = cooldownUntil - now
		l.Text = string.format("BANQUETE EM DUPLA\nPróxima rodada em %d:%02d", left // 60, left % 60)
		p.Enabled = false
	elseif reservation then
		local left = math.max(0, (reservation :: Reservation).untilTime - now)
		l.Text = string.format("BANQUETE EM DUPLA  1/2\nTraga comida COMUM ou INCOMUM: %d:%02d", left // 60, left % 60)
		p.Enabled = true
		p.ActionText = "COMPLETAR BANQUETE"
	else
		l.Text = "BANQUETE EM DUPLA  0/2\nVenha com um amigo! +15% XP por 4 min"
		p.Enabled = true
		p.ActionText = "INICIAR BANQUETE"
	end
end

local function tryContribute(player: Player)
	if not on() or not stand or not Guard.withinReach(player, stand, Rules.PromptReach) then
		return
	end
	local now = os.time()
	expire(now)
	if now < cooldownUntil then
		return
	end
	local nextAt = individualCooldown[player.UserId] or 0
	if now < nextAt then
		notify(player, string.format("Você já ajudou! Próximo banquete em %d s.", nextAt - now))
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local slice = ownedSlice(profile)
	if not Rules.available(slice, now) then
		notify(player, "Você já fez 3 banquetes hoje. Pode ajudar outros jogadores amanhã.")
		return
	end
	local index, item = Rules.findFood(profile.inventory)
	if not index or not item or type(item.uid) ~= "string" then
		notify(player, "Tenha uma comida COMUM ou INCOMUM normal na mochila. Itens raros são protegidos.")
		return
	end
	local first = reservation
	if not first then
		reservation = { player = player, foodUid = item.uid, untilTime = now + Rules.WindowSeconds }
		notify(player, "Banquete iniciado! Chame alguém à praça em até 2 minutos. Sua comida ainda não foi consumida.")
		Remotes.Notify:FireAllClients({
			text = "BANQUETE EM DUPLA: 1/2 cozinheiros na praça. Venha ajudar por um bônus de XP!",
			color = Color3.fromRGB(255, 204, 110),
		})
		Analytics.event(player, "social_feast_started", 1)
		updateDisplay(now)
		return
	end
	if first.player == player then
		notify(player, "Você já iniciou o banquete. Aguarde OUTRO jogador na praça.")
		return
	end
	if not Rules.canPair(first.player.UserId, player.UserId, first.untilTime, now) then
		reservation = nil
		notify(player, "O prazo terminou. Use o pedestal para iniciar outro banquete.")
		updateDisplay(now)
		return
	end
	-- Duas pessoas PRECISAM estar presentes. O segundo não pode completar
	-- com uma inscrição distante ou uma conta que já foi embora.
	local firstPlayer = first.player
	if firstPlayer.Parent ~= Players or Guard.distanceBetween(firstPlayer, player) > Rules.PartnerReach
		or not Guard.withinReach(firstPlayer, stand, Rules.PromptReach) then
		reservation = nil
		notify(player, "O primeiro cozinheiro saiu da praça. Comece outra rodada.")
		updateDisplay(now)
		return
	end
	local firstProfile = DataService.get(firstPlayer)
	if not firstProfile or not Rules.available(ownedSlice(firstProfile), now)
		or now < (individualCooldown[firstPlayer.UserId] or 0) then
		reservation = nil
		updateDisplay(now)
		return
	end
	local firstIndex, firstFood = Rules.findFood(firstProfile.inventory, first.foodUid)
	if not firstIndex or not firstFood then
		reservation = nil
		notify(firstPlayer, "A comida reservada foi usada. Inscreva-se novamente.")
		updateDisplay(now)
		return
	end
	-- Daqui até a concessão não há yields. Checa-se ANTES de retirar ambos.
	table.remove(firstProfile.inventory, firstIndex)
	table.remove(profile.inventory, index)
	firstProfile.coins += Rules.RewardCoins
	profile.coins += Rules.RewardCoins
	(firstProfile :: any).communityFeast = Rules.completed(ownedSlice(firstProfile), now)
	(profile :: any).communityFeast = Rules.completed(slice, now)
	DataService.markDirty(firstPlayer)
	DataService.markDirty(player)
	GiantService.grantCoopBuff(firstPlayer, Rules.BuffSeconds, Rules.BuffMult)
	GiantService.grantCoopBuff(player, Rules.BuffSeconds, Rules.BuffMult)
	PlotService.pushState(firstPlayer)
	PlotService.pushState(player)
	reservation = nil
	cooldownUntil = now + Rules.GlobalResetSeconds
	individualCooldown[firstPlayer.UserId] = now + Rules.CooldownSeconds
	individualCooldown[player.UserId] = now + Rules.CooldownSeconds
	if sparks then
		sparks:Emit(28)
	end
	for _, pl in { firstPlayer, player } do
		Remotes.Callout:FireClient(pl, {
			title = "BANQUETE COMPLETO!",
			sub = string.format("+%d moedas e +15%% XP ao alimentar por 4 min!", Rules.RewardCoins),
			color = Color3.fromRGB(255, 220, 110),
		})
		Remotes.GiantReact:FireAllClients({ userId = pl.UserId, kind = "cheer" })
		Analytics.event(pl, "social_feast_completed", 1, { "two_humans" })
	end
	updateDisplay(now)
end

local function build()
	local map = Workspace:WaitForChild("Map", 60)
	if not map then
		warn("[SocialFeast] mapa não encontrado")
		return
	end
	local old = map:FindFirstChild("SocialFeastStand")
	if old then
		old:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = "SocialFeastStand"
	p.Size = Vector3.new(7, 2.1, 7)
	p.CFrame = CFrame.new(46, 3.2, 24) -- próximo ao caldeirão, fora do pedestal central
	p.Material = Enum.Material.WoodPlanks
	p.Color = Color3.fromRGB(163, 96, 51)
	p.Anchored = true
	p.CanCollide = false -- sem bloquear tráfego na praça
	p.CanTouch = false
	p.Parent = map
	local top = Instance.new("Part")
	top.Name = "ServingTray"
	top.Size = Vector3.new(5.5, 0.35, 5.5)
	top.CFrame = p.CFrame * CFrame.new(0, 1.25, 0)
	top.Material = Enum.Material.Neon
	top.Color = Color3.fromRGB(255, 176, 64)
	top.Anchored = true
	top.CanCollide = false
	top.CanTouch = false
	top.Parent = p
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "CompleteSparks"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 0
	sparkle.Speed = NumberRange.new(5, 12)
	sparkle.Lifetime = NumberRange.new(0.4, 0.8)
	sparkle.Size = NumberSequence.new(0.75, 0)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 218, 108))
	sparkle.Parent = top
	sparks = sparkle
	local txt = Util.makeBillboard(p, "", UDim2.fromOffset(430, 100), Vector3.new(0, 6, 0), Color3.fromRGB(255, 225, 160))
	local board = txt.Parent :: BillboardGui
	board.MaxDistance = 140
	label = txt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "SocialFeastPrompt"
	pp.ActionText = "INICIAR BANQUETE"
	pp.ObjectText = "BANQUETE EM DUPLA"
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.MaxActivationDistance = Rules.PromptReach
	pp.RequiresLineOfSight = false
	pp.HoldDuration = 0.4
	pp.Parent = p
	stand, prompt = p, pp
	pp.Triggered:Connect(tryContribute)
	updateDisplay(os.time())
end

function SocialFeastService.init()
	DataService.registerSlice("communityFeast", function()
		return { v = 1, day = 0, count = 0, total = 0 }
	end)
	Players.PlayerRemoving:Connect(function(player)
		if reservation and (reservation :: Reservation).player == player then
			reservation = nil -- a comida estava na mochila: nada a devolver
		end
	end)
	task.spawn(build)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			expire(now)
			updateDisplay(now)
		end
	end)
end

return SocialFeastService
