--!strict
-- MeatService — 4.5 "Disputa por alimentos maiores": a CARNE GIGANTE (missão de 08/11/2026).
--
-- Um pedaço enorme de carne cai na praça com aviso para o servidor inteiro (20 s antes) e um
-- cronômetro. Os jogadores correm até ele e SEGURAM o botão (1,2 s) para cortar uma PORÇÃO.
-- A porção vai para a cabeça de quem cortou e daí em diante é um drop normal (DropService):
-- deixa o jogador mais lento, um soco derruba e outro jogador pode pegar, entrega só na própria base.
-- Regras para vários ganharem (não só o primeiro):
--   * porções = 4 + 2 por jogador no servidor (no máximo 14);
--   * cada jogador corta no máximo 2 por evento;
--   * enquanto carrega uma porção não corta outra (precisa entregar ou perder antes).
-- Tudo validado no servidor (distância, limite por jogador, carga, ProximityPrompt + Guard).
-- A porção ("giantmeat", Rara, traço Crescimento) fica fora das caixas e da tabela de chances.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DropService = require(script.Parent.DropService)
local Guard = require(script.Parent.Parent.Guard)
local Hooks = require(script.Parent.Parent.Hooks)

local MeatService = {}
local M = GameRules.Meat

type Feast = {
	model: Model,
	core: Part,
	pos: Vector3,
	portions: number,
	maxPortions: number,
	cuts: { [number]: number }, -- por UserId: sair e voltar não zera o limite
	endsAt: number,
	label: TextLabel,
	over: boolean,
}

local current: Feast? = nil
MeatService.nextAt = 0

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Peça de carne cartoon: pernil grande (elipse marrom-avermelhada, camada de gordura clara, osso).
local function buildMeat(pos: Vector3): (Model, Part)
	local m = Instance.new("Model")
	m.Name = "GiantMeat"
	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		Color = Color3.fromRGB(176, 72, 52),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CanQuery = true,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.35, 0.8, 1)
	mesh.Parent = core
	core.Parent = m
	local fat = part({
		Name = "Fat",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14.4, 14.4, 14.4),
		Color = Color3.fromRGB(240, 196, 160),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.25,
	})
	local fm = Instance.new("SpecialMesh")
	fm.MeshType = Enum.MeshType.Sphere
	fm.Scale = Vector3.new(1.2, 0.5, 0.92)
	fm.Offset = Vector3.new(0, 1.6, 0)
	fm.Parent = fat
	fat.Parent = m
	local bone = part({
		Name = "Bone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 2.4, 2.4),
		Color = Color3.fromRGB(250, 244, 228),
		Material = Enum.Material.SmoothPlastic,
	})
	bone.Parent = m
	local knob = part({
		Name = "BoneKnob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Color = Color3.fromRGB(250, 244, 228),
		Material = Enum.Material.SmoothPlastic,
	})
	knob.Parent = m
	m.PrimaryPart = core
	local function place(at: Vector3)
		core.CFrame = CFrame.new(at)
		fat.CFrame = CFrame.new(at)
		bone.CFrame = CFrame.new(at + Vector3.new(11, 1, 0))
		knob.CFrame = CFrame.new(at + Vector3.new(15.5, 1, 0))
	end
	place(pos)
	-- vapor quente saindo (1 emissor, taxa baixa: celular)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 5, 0)
	att.Parent = core
	local steam = Instance.new("ParticleEmitter")
	steam.Rate = 6
	steam.Lifetime = NumberRange.new(1.2, 2)
	steam.Speed = NumberRange.new(3, 6)
	steam.Size = NumberSequence.new(2, 5)
	steam.Transparency = NumberSequence.new(0.5, 1)
	steam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	steam.LightInfluence = 0.5
	steam.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 110)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = core
	return m, core
end

local function mmss(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function refresh(f: Feast)
	f.label.Text =
		string.format("CARNE GIGANTE\n%d/%d porções  ·  %s", f.portions, f.maxPortions, mmss(f.endsAt - os.clock()))
	-- a carne "diminui" conforme é cortada
	local k = 0.45 + 0.55 * (f.portions / math.max(f.maxPortions, 1))
	local mesh = f.core:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.Scale = Vector3.new(1.35, 0.8, 1) * k
	end
	Remotes.MeatState:FireAllClients({
		kind = "Update",
		pos = f.pos,
		portions = f.portions,
		max = f.maxPortions,
		left = f.endsAt - os.clock(),
	})
end

local function finish(f: Feast)
	if f.over then
		return
	end
	f.over = true
	current = nil
	Remotes.MeatState:FireAllClients({ kind = "End" })
	for _, d in f.model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.9, function()
		f.model:Destroy()
	end)
end

local function tryCut(player: Player, f: Feast)
	if f.over or f.portions <= 0 then
		return
	end
	if not Guard.withinReach(player, f.core, M.Reach) then
		return
	end
	local done = f.cuts[player.UserId] or 0
	if done >= M.PerPlayer then
		Remotes.Notify:FireClient(player, Locale.msg("meat_limit", { n = M.PerPlayer }, Color3.fromRGB(255, 170, 60)))
		return
	end
	local root = Guard.rootOf(player)
	local at = if root then root.Position + Vector3.new(0, 3, 0) else f.pos
	if not DropService.giveCarried(player, M.FoodId, at) then
		return -- já carregando algo (o DropService avisa)
	end
	f.cuts[player.UserId] = done + 1
	f.portions -= 1
	Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = f.pos })
	Hooks.fire("meatCut", player)
	refresh(f)
	if f.portions <= 0 then
		Remotes.Notify:FireAllClients(Locale.msg("meat_gone", nil, Color3.fromRGB(255, 200, 120)))
		finish(f)
	end
end

function MeatService.run()
	if current then
		return
	end
	-- Ponto na praça longe do caldeirão (mesma faixa dos drops).
	local a = math.random() * math.pi * 2
	local r = 62 + math.random() * 18
	local pos = Vector3.new(math.cos(a) * r, 7, math.sin(a) * r)
	Remotes.Notify:FireAllClients(Locale.msg("meat_warn", { n = M.WarnSeconds }, Color3.fromRGB(255, 170, 110)))
	Remotes.MeatState:FireAllClients({ kind = "Warn", pos = pos, left = M.WarnSeconds })
	task.wait(M.WarnSeconds)
	local n = #Players:GetPlayers()
	local portions = math.min(M.PortionsMax, M.PortionsBase + M.PortionsPerPlayer * n)
	local model, core = buildMeat(pos + Vector3.new(0, 160, 0))
	model.Parent = Workspace
	-- queda de 2,5 s (acelerando) e impacto
	local t0 = os.clock()
	while os.clock() - t0 < 2.5 do
		local k = ((os.clock() - t0) / 2.5) ^ 2
		model:PivotTo(CFrame.new(pos + Vector3.new(0, 160 * (1 - k), 0)) * CFrame.Angles(0, k * 6, 0))
		task.wait()
	end
	model:PivotTo(CFrame.new(pos))
	Remotes.CombatEvent:FireAllClients({ kind = "Impact", pos = pos })
	Remotes.Fireworks:FireAllClients({ pos = pos, big = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 80)
	bb.StudsOffset = Vector3.new(0, 10, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.Parent = core
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 150)
	label.TextStrokeTransparency = 0
	label.Parent = bb
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Cut"
	prompt.ActionText = "CORTAR PORÇÃO"
	prompt.ObjectText = "Carne Gigante"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = M.CutSeconds
	prompt.MaxActivationDistance = M.Reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	local f: Feast = {
		model = model,
		core = core,
		pos = pos,
		portions = portions,
		maxPortions = portions,
		cuts = {},
		endsAt = os.clock() + M.Lifetime,
		label = label,
		over = false,
	}
	current = f
	prompt.Triggered:Connect(function(player)
		if Guard.allow(player, "Meat") then
			tryCut(player, f)
		end
	end)
	Remotes.MeatState:FireAllClients({
		kind = "Land",
		pos = pos,
		portions = portions,
		max = portions,
		left = M.Lifetime,
	})
	refresh(f)
	while not f.over and os.clock() < f.endsAt do
		task.wait(1)
		if not f.over then
			refresh(f)
		end
	end
	finish(f)
end

function MeatService.isActive(): boolean
	return current ~= nil
end

function MeatService.init()
	MeatService.nextAt = os.time() + M.FirstDelay
	task.spawn(function()
		while true do
			task.wait(1)
			if os.time() >= MeatService.nextAt and not current then
				local ok, err = pcall(MeatService.run :: any)
				if not ok then
					warn("[MeatService]", err)
				end
				MeatService.nextAt = os.time() + math.random(M.Every[1], M.Every[2])
			end
		end
	end)
end

return MeatService
