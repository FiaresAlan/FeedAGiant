--!strict
-- AncestralService — o Gigante Ancestral (noite de 09/11/2026; Features.Ancestral).
--
-- Ideia nova (o usuário pediu "não se limite ao que temos, seja criativo"): um gigante COLOSSAL dorme no
-- pé das montanhas, visível do mapa todo. Toda vez que QUALQUER jogador alimenta o próprio gigante, o
-- Banquete do servidor enche (comida rara vale mais). Cheio: o Ancestral acorda com um rugido, faz
-- chover comida (e às vezes caixas e ovos) na praça e dá +25% de XP para todos por 5 minutos. Depois
-- volta a dormir. Meta coletiva = motivo social para alimentar mais; ninguém perde nada.
-- Reaproveita: modelo do Golem (CreatureAssets), drops do mapa (DropService.spawnAt), XP (GiantService).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Analytics = require(script.Parent.Parent.Analytics)
local GameLogic = require(script.Parent.Parent.GameLogic)
local Hooks = require(script.Parent.Parent.Hooks)
local GiantService = require(script.Parent.GiantService)
local DropService = require(script.Parent.DropService)

local A = GameRules.Ancestral
local AncestralService = {}

local points = 0
local state: "sleep" | "awake" | "cooldown" = "sleep"
local cooldownUntil = 0
local buffToken = 0
local model: Model? = nil
local sleepCf: CFrame? = nil
local label: TextLabel? = nil

local function on(): boolean
	return Features.on("Ancestral")
end

local function goal(): number
	return GameLogic.ancestralGoal(#Players:GetPlayers())
end

local function refreshLabel()
	local l = label
	if not l then
		return
	end
	if not on() then
		l.Text = ""
		return
	end
	if state == "awake" then
		l.Text = "O GIGANTE ANCESTRAL ACORDOU!"
	elseif state == "cooldown" then
		l.Text = string.format(
			"GIGANTE ANCESTRAL · dormindo (%d:%02d)",
			math.max(0, cooldownUntil - os.time()) // 60,
			math.max(0, cooldownUntil - os.time()) % 60
		)
	else
		l.Text = string.format("GIGANTE ANCESTRAL · Banquete %d/%d", math.floor(points), goal())
	end
end

-- Estado para outros sistemas (dica de META).
function AncestralService.progress(): (number, number, string)
	return points, goal(), state
end

local function build()
	local template = GiantService.template("stone-golem")
	local rad = math.rad(A.Angle)
	local pos = Vector3.new(math.cos(rad) * A.Radius, 0, math.sin(rad) * A.Radius)
	local params = RaycastParams.new()
	local hit = Workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	local groundY = if hit then hit.Position.Y else 0
	local m: Model
	if template then
		m = template:Clone()
		local _, size = m:GetBoundingBox()
		m:ScaleTo(A.Height / math.max(size.Y, 1))
	else
		m = Instance.new("Model")
		local body = Util.makePart({ Size = Vector3.new(40, A.Height, 30), Color = Color3.fromRGB(120, 110, 100) })
		body.Parent = m
		m.PrimaryPart = body
	end
	m.Name = "AncestralGiant"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	-- olhando para o centro do mapa; dormindo = afundado e inclinado para a frente
	local look = CFrame.lookAt(Vector3.new(pos.X, 0, pos.Z), Vector3.new(0, 0, 0))
	local cf, size = m:GetBoundingBox()
	local standCf = CFrame.new(pos.X, groundY + size.Y / 2, pos.Z) * (look - look.Position)
	local sCf = standCf * CFrame.new(0, -size.Y * 0.28, 0) * CFrame.Angles(math.rad(-18), 0, 0)
	m:PivotTo(m:GetPivot() * cf:Inverse() * sCf)
	m:SetAttribute("StandOffset", size.Y * 0.28)
	m.Parent = Workspace
	-- etiqueta grande, visível de longe
	local anchor = Util.makePart({
		Name = "AncestralLabel",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(pos.X, groundY + size.Y * 0.95, pos.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	anchor.Parent = m
	label =
		Util.makeBillboard(anchor, "", UDim2.fromOffset(520, 70), Vector3.new(0, 8, 0), Color3.fromRGB(255, 210, 120))
	local bb = (label :: TextLabel).Parent :: BillboardGui
	bb.MaxDistance = 2000
	bb.AlwaysOnTop = false
	-- "Zzz" do sono
	local zz = Instance.new("ParticleEmitter")
	zz.Name = "Sleep"
	zz.Texture = "rbxasset://textures/particles/smoke_main.dds"
	zz.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
	zz.Size = NumberSequence.new(6, 14)
	zz.Transparency = NumberSequence.new(0.6, 1)
	zz.Rate = 1.5
	zz.Lifetime = NumberRange.new(4, 6)
	zz.Speed = NumberRange.new(4, 8)
	zz.Parent = anchor
	model = m
	sleepCf = m:GetPivot()
	refreshLabel()
end

local function tweenPivot(m: Model, target: CFrame, seconds: number)
	local v = Instance.new("CFrameValue")
	v.Value = m:GetPivot()
	v.Changed:Connect(function(cf: CFrame)
		m:PivotTo(cf)
	end)
	local t = TweenService:Create(
		v,
		TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = target }
	)
	t:Play()
	t.Completed:Wait()
	v:Destroy()
end

local function feast()
	local center = Vector3.new(0, 0, 0)
	for i = 1, A.FeastDrops do
		local ang = math.random() * math.pi * 2
		local r = 25 + math.random() * 70
		local ok, err = pcall(
			DropService.spawnAt :: any,
			center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r),
			nil,
			nil,
			i > 1
		)
		if not ok then
			warn("[Ancestral] drop", err)
		end
		task.wait(A.FeastSeconds / A.FeastDrops)
	end
end

local function wake()
	state = "awake"
	refreshLabel()
	for _, pl in Players:GetPlayers() do
		Analytics.event(pl, "ancestral_awake", #Players:GetPlayers())
	end
	Remotes.Notify:FireAllClients({
		text = "O GIGANTE ANCESTRAL ACORDOU! Comida chovendo na praça e +25% de XP para todos por 5 minutos!",
		color = Color3.fromRGB(255, 200, 80),
	})
	Remotes.Callout:FireAllClients({
		title = "O GIGANTE ANCESTRAL ACORDOU!",
		sub = "Comida chovendo na praça e +25% de XP por 5 min",
		color = Color3.fromRGB(255, 200, 80),
	})
	-- buff de XP para o servidor inteiro
	-- ficha: só o ÚLTIMO despertar desliga o bônus (revisão cega: comparar horários era frágil)
	buffToken += 1
	local token = buffToken
	GiantService.globalXpMult = A.XpBuff
	task.delay(A.BuffSeconds, function()
		if buffToken == token then
			GiantService.globalXpMult = 1
		end
	end)
	local m = model
	local base = sleepCf
	if m and base then
		local up = m:GetAttribute("StandOffset")
		local stand = base
			* CFrame.Angles(math.rad(18), 0, 0)
			* CFrame.new(0, if type(up) == "number" then up else 0, 0)
		local sleepFx = m:FindFirstChild("Sleep", true)
		if sleepFx and sleepFx:IsA("ParticleEmitter") then
			sleepFx.Enabled = false
		end
		pcall(tweenPivot, m, stand, 2.5)
		Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = m:GetPivot().Position })
	end
	feast()
	-- volta a dormir
	if m and base then
		pcall(tweenPivot, m, base, 3)
		local sleepFx = m:FindFirstChild("Sleep", true)
		if sleepFx and sleepFx:IsA("ParticleEmitter") then
			sleepFx.Enabled = true
		end
	end
	points = 0
	state = "cooldown"
	cooldownUntil = os.time() + A.SleepCooldown
end

-- Soma pontos (chamado a cada alimentação). Exposto para teste.
function AncestralService.add(amount: number)
	if not on() or state ~= "sleep" then
		return
	end
	points += amount
	if points >= goal() then
		task.spawn(wake)
	end
	refreshLabel()
end

function AncestralService.init()
	Hooks.on("fed", function(_player: Player, info: { [string]: any }?)
		local def = info and info.foodId and Config.FoodById[info.foodId]
		AncestralService.add(GameLogic.ancestralPoints(if def then def.rarity else nil))
	end)
	task.spawn(function()
		local map = Workspace:WaitForChild("Map", 60)
		if map then
			task.wait(2)
		end
		while true do
			task.wait(1)
			-- só aparece com a função ligada (desligada, o mapa fica exatamente como antes)
			if on() and not model then
				local ok, err = pcall(build :: any)
				if not ok then
					warn("[Ancestral] não montou", err)
					break
				end
			end
			if state == "cooldown" and os.time() >= cooldownUntil then
				state = "sleep"
			end
			refreshLabel()
		end
	end)
end

return AncestralService
