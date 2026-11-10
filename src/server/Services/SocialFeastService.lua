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

type Reservation = {
	player: Player,
	foodUid: string,
	untilTime: number,
	partner: Player?,
	partnerUid: string?,
	preparedA: boolean?,
	preparedB: boolean?,
}
local reservation: Reservation? = nil
local cooldownUntil = 0
local individualCooldown: { [number]: number } = {}
local stand: BasePart? = nil
local label: TextLabel? = nil
local prompt: ProximityPrompt? = nil
local prepPrompts: { ProximityPrompt } = {}
local sparks: ParticleEmitter? = nil
local lastInviteAt = -math.huge

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
	if current and (
		now >= current.untilTime
		or current.player.Parent ~= Players
		or (current.partner ~= nil and current.partner.Parent ~= Players)
	) then
		reservation = nil
		if current.player.Parent then
			notify(current.player, "O Banquete em Dupla expirou. Sua comida continua guardada!")
		end
	end
end

local function updateDisplay(now: number)
	local l, p = label, prompt
	local active = reservation
	local ready = on() and Features.on("ColossalKitchenSteps") and active ~= nil
		and active.partner ~= nil and now < active.untilTime and now >= cooldownUntil
	for _, chefPrompt in prepPrompts do
		chefPrompt.Enabled = ready
	end
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
		local current = reservation :: Reservation
		local left = math.max(0, current.untilTime - now)
		if current.partner then
			local cut = if current.preparedA then "PRONTO" else "CORTAR"
			local stir = if current.preparedB then "PRONTO" else "MEXER"
			l.Text = string.format("COZINHA 2/2 · %d:%02d\nA: %s | B: %s", left // 60, left % 60, cut, stir)
			p.Enabled = false
		else
			l.Text = string.format("COZINHA COLOSSAL  1/2\nConvide outro cozinheiro: %d:%02d", left // 60, left % 60)
			p.Enabled = true
			p.ActionText = "ENTRAR NO BANQUETE"
		end
	else
		l.Text = "BANQUETE EM DUPLA  0/2\nVenha com um amigo! +15% XP por 4 min"
		p.Enabled = true
		p.ActionText = "INICIAR BANQUETE"
	end
end


-- Só completa depois de dois participantes e duas tarefas ativas.
-- Todos os dados são revalidados no servidor; se alguém for embora, nada é debitado.
local function completeCooking(now: number)
	local current = reservation
	local center = stand
	if not current or not current.partner or not current.partnerUid or not current.preparedA
		or not current.preparedB or not center or now >= current.untilTime then
		return
	end
	local firstPlayer = current.player
	local secondPlayer = current.partner
	local firstRoot, secondRoot = Guard.rootOf(firstPlayer), Guard.rootOf(secondPlayer)
	if firstPlayer.Parent ~= Players or secondPlayer.Parent ~= Players
		or not firstRoot or not secondRoot or (firstRoot.Position - center.Position).Magnitude > 27
		or (secondRoot.Position - center.Position).Magnitude > 27 then
		reservation = nil
		updateDisplay(now)
		return
	end
	if not Rules.canPair(firstPlayer.UserId, secondPlayer.UserId, current.untilTime, now) then
		reservation = nil
		updateDisplay(now)
		return
	end
	local firstProfile = DataService.get(firstPlayer)
	local profile = DataService.get(secondPlayer)
	if not firstProfile or not profile or not Rules.available(ownedSlice(firstProfile), now)
		or not Rules.available(ownedSlice(profile), now) then
		reservation = nil
		updateDisplay(now)
		return
	end
	local firstIndex, firstFood = Rules.findFood(firstProfile.inventory, current.foodUid)
	local index, item = Rules.findFood(profile.inventory, current.partnerUid)
	if not firstIndex or not firstFood or not index or not item then
		reservation = nil
		notify(firstPlayer, "Uma comida foi usada antes do preparo. Inscrevam-se novamente; nada foi debitado pelo banquete.")
		notify(secondPlayer, "Faltou ingrediente na mochila. Inscrevam-se de novo.")
		updateDisplay(now)
		return
	end
	-- Ponto de commit: nenhum yield até remover ambos os ingredientes e conceder os prêmios.
	table.remove(firstProfile.inventory, firstIndex)
	table.remove(profile.inventory, index)
	firstProfile.coins += Rules.RewardCoins
	profile.coins += Rules.RewardCoins
	local firstData: any = firstProfile
	local secondData: any = profile
	firstData.communityFeast = Rules.completed(ownedSlice(firstProfile), now)
	secondData.communityFeast = Rules.completed(ownedSlice(profile), now)
	DataService.markDirty(firstPlayer)
	DataService.markDirty(secondPlayer)
	GiantService.grantCoopBuff(firstPlayer, Rules.BuffSeconds, Rules.BuffMult)
	GiantService.grantCoopBuff(secondPlayer, Rules.BuffSeconds, Rules.BuffMult)
	PlotService.pushState(firstPlayer)
	PlotService.pushState(secondPlayer)
	reservation = nil
	cooldownUntil = now + Rules.GlobalResetSeconds
	individualCooldown[firstPlayer.UserId] = now + Rules.CooldownSeconds
	individualCooldown[secondPlayer.UserId] = now + Rules.CooldownSeconds
	if sparks then
		sparks:Emit(28)
	end
	for _, pl in { firstPlayer, secondPlayer } do
		Remotes.Callout:FireClient(pl, {
			title = "PRATO COLOSSAL PRONTO!",
			sub = string.format("+%d moedas e +15%% XP por 4 min!", Rules.RewardCoins),
			color = Color3.fromRGB(255, 220, 110),
		})
		Remotes.GiantReact:FireAllClients({ userId = pl.UserId, kind = "cheer" })
		Analytics.event(pl, "social_feast_completed", 1, { "two_humans", "cooked" })
	end
	updateDisplay(now)
end

local function tryContribute(player: Player)
	if not on() or not stand or not Guard.allow(player, "SocialFeast")
		or not Guard.withinReach(player, stand, Rules.PromptReach) then
		return
	end
	local now = os.time()
	expire(now)
	if now < cooldownUntil then
		return
	end
	if #Players:GetPlayers() < 2 then
		notify(player, "O banquete precisa de 2 jogadores reais. Convide um amigo!")
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
	if first and first.partner then
		notify(player, "A dupla está preparando o prato. Aguarde a próxima rodada.")
		return
	end
	if not first then
		reservation = { player = player, foodUid = item.uid, untilTime = now + Rules.WindowSeconds }
		notify(player, "Banquete iniciado! Chame alguém à praça em até 2 minutos. Sua comida ainda não foi consumida.")
		-- Não transformar uma atividade social em spam de mensagens para toda a sala.
		if now - lastInviteAt >= 60 then
			lastInviteAt = now
			Remotes.Notify:FireAllClients({
				text = "BANQUETE EM DUPLA: 1/2 cozinheiros na praça. Venha ajudar por um bônus de XP!",
				color = Color3.fromRGB(255, 204, 110),
			})
		end
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
	-- Os dois estão inscritos, mas ainda precisam PREPARAR o prato em estações diferentes.
	first.partner = player
	first.partnerUid = item.uid
	first.preparedA = false
	first.preparedB = false
	notify(firstPlayer, "Dupla formada! Vá à TÁBUA e segure E para CORTAR.")
	notify(player, "Dupla formada! Vá à PANELA e segure E para MEXER.")
	Analytics.event(firstPlayer, "social_feast_paired", 1)
	Analytics.event(player, "social_feast_paired", 1)
	if not Features.on("ColossalKitchenSteps") then
		-- Reserva para regressão caso as estações apresentem problemas no Studio.
		first.preparedA, first.preparedB = true, true
		completeCooking(now)
	else
		updateDisplay(now)
	end
end

local function prepare(player: Player, role: "A" | "B", station: BasePart)
	if not on() or not Features.on("ColossalKitchenSteps")
		or not Guard.allow(player, "SocialFeast")
		or not Guard.withinReach(player, station, Rules.PromptReach) then
		return
	end
	local current = reservation
	local now = os.time()
	expire(now)
	if not current or reservation ~= current or not current.partner then
		notify(player, "Primeiro formem uma dupla no balcão da Cozinha Colossal.")
		return
	end
	if not Rules.canPrepare(current, role, player.UserId, now) then
		notify(player, if role == "A" then "A TÁBUA é do primeiro cozinheiro." else "A PANELA é do segundo cozinheiro.")
		return
	end
	if role == "A" then
		current.preparedA = true
	else
		current.preparedB = true
	end
	Analytics.event(player, "social_feast_prepared", 1, { role })
	notify(player, if role == "A" then "INGREDIENTES CORTADOS! Aguarde a panela." else "PANELA PRONTA! Aguarde a tábua.")
	updateDisplay(now)
	completeCooking(now)
end

local function build()
	local map = Workspace:WaitForChild("Map", 60)
	local district = map and map:FindFirstChild("LivingPlazaDistrict")
	local kitchen = district and district:FindFirstChild("ColossalKitchen")
	if not kitchen then
		warn("[SocialFeast] cozinha não encontrada — PlazaDistrict deve iniciar antes dos serviços")
		return
	end
	local p = kitchen:FindFirstChild("ServeSpot")
	local a = kitchen:FindFirstChild("PrepA")
	local b = kitchen:FindFirstChild("PrepB")
	if not p or not p:IsA("BasePart") or not a or not a:IsA("BasePart")
		or not b or not b:IsA("BasePart") then
		warn("[SocialFeast] cozinha sem balcão ou estações")
		return
	end
	stand = p
	local top = kitchen:FindFirstChild("BandejaDaEquipe")
	if top and top:IsA("BasePart") then
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
	end
	local txt = Util.makeBillboard(p, "", UDim2.fromOffset(340, 78), Vector3.new(0, 5, 0), Color3.fromRGB(255, 225, 160))
	local board = txt.Parent :: BillboardGui
	board.MaxDistance = 90
	label = txt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "SocialFeastPrompt"
	pp.ActionText = "INICIAR BANQUETE"
	pp.ObjectText = "COZINHA COLOSSAL"
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.MaxActivationDistance = Rules.PromptReach
	pp.RequiresLineOfSight = false
	pp.HoldDuration = 0.4
	pp.Parent = p
	prompt = pp
	pp.Triggered:Connect(tryContribute)
	for _, entry in { { a, "A", "CORTAR INGREDIENTES" }, { b, "B", "MEXER PANELÃO" } } do
		local station = entry[1] :: BasePart
		local role = entry[2] :: "A" | "B"
		local action = entry[3] :: string
		local actionPrompt = Instance.new("ProximityPrompt")
		actionPrompt.Name = "Cook" .. role
		actionPrompt.ActionText = action
		actionPrompt.ObjectText = "PREPARO COOPERATIVO"
		actionPrompt.HoldDuration = 1.7
		actionPrompt.KeyboardKeyCode = Enum.KeyCode.E
		actionPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		actionPrompt.MaxActivationDistance = Rules.PromptReach
		actionPrompt.RequiresLineOfSight = false
		actionPrompt.Parent = station
		actionPrompt.Enabled = false
		table.insert(prepPrompts, actionPrompt)
		actionPrompt.Triggered:Connect(function(player: Player)
			prepare(player, role, station)
		end)
	end
	updateDisplay(os.time())
end

-- Reentrada após queda/conexão ruim: restaura os minutos RESTANTES do buff.
-- Nenhum bônus é congelado enquanto o jogador está offline.
function SocialFeastService.onJoin(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local slice = ownedSlice(profile)
	local remaining = (tonumber(slice.buffUntil) or 0) - os.time()
	if remaining > 0 then
		GiantService.grantCoopBuff(player, remaining, Rules.BuffMult)
	end
end

function SocialFeastService.init()
	DataService.registerSlice("communityFeast", function()
		return { v = 1, day = 0, count = 0, total = 0, buffUntil = 0 }
	end)
	Players.PlayerRemoving:Connect(function(player)
		if reservation and ((reservation :: Reservation).player == player
			or (reservation :: Reservation).partner == player) then
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
