--!strict
-- Dragon.lua — o DRAGÃO FAMINTO vivo e o CONVITE do servidor (pedido do usuário, 09/11/2026, itens 11 e 15).
--
-- Animação (a malha não tem ossos: medido em 08/11, 0 Bones): igual ao GiantAnim, o cliente move a
-- malha só localmente (nada replica). O servidor diz para onde o dragão olha (atributo FaceYaw) e
-- quando ele ataca (BossState Telegraph). Movimentos:
--   chegada  desce do céu batendo as asas (balanço) e aterrissa com tremor;
--   parado   respira (sobe/desce e inclina), balança a cabeça, gira suave para o alvo;
--   ataque   EMPINA durante o aviso do círculo vermelho e BATE no chão quando ele explode;
--   apanha   tranco curto a cada soco que acerta;
--   fúria    respiração rápida e contorno vermelho pulsando (fase 2+);
--   fim      vitória: tomba de lado e afunda; fuga: sobe e vai embora voando.
-- Convite: cartão pequeno no canto esquerdo (não tampa a luta nem a HUD) com "O DRAGÃO NASCEU! VAMOS
-- JOGAR!", o time (1 de 4 ... 4 de 4), o prêmio e um botão azul JOGAR que pulsa. Some quando o
-- jogador já está na ilha, quando fecha no X ou quando o Dragão acaba.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)

local Dragon = {}

local player = Players.LocalPlayer

type Rig = {
	model: Model,
	parts: { { part: BasePart, rel: CFrame } },
	ground: Vector3,
	height: number,
	yaw: number,
	born: number,
	attackAt: number,
	attackDur: number,
	hitAt: number,
	over: string?,
	overAt: number,
	fury: boolean,
	hl: Highlight?,
}

local rig: Rig? = nil
local phase = 1

-- Captura a pose de repouso (relativa ao pivô no chão, como o servidor deixou).
local function capture(model: Model): Rig?
	local pivot = model:GetPivot()
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "BossHitbox" then
			table.insert(parts, { part = d, rel = pivot:ToObjectSpace(d.CFrame) })
		end
	end
	if #parts == 0 then
		return nil
	end
	local _, size = model:GetBoundingBox()
	return {
		model = model,
		parts = parts,
		ground = pivot.Position,
		height = math.max(size.Y, 8),
		yaw = (model:GetAttribute("FaceYaw") :: number?) or 0,
		born = os.clock(),
		attackAt = -1,
		attackDur = 1.4,
		hitAt = -1,
		over = nil,
		overAt = 0,
		fury = false,
		hl = model:FindFirstChildOfClass("Highlight"),
	}
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

local function angleLerp(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

local function step(dt: number)
	local r = rig
	if not r then
		return
	end
	if not r.model.Parent then
		rig = nil
		return
	end
	local now = os.clock()
	local H = r.height
	local target = (r.model:GetAttribute("FaceYaw") :: number?) or r.yaw
	r.yaw = angleLerp(r.yaw, target, math.clamp(dt * 3, 0, 1))

	local up, pitch, roll, yawAdd = 0, 0, 0, 0
	-- respiração e cabeça (mais rápido na fúria)
	local rate = if r.fury then 2.2 else 1.1
	up += math.sin(now * rate * 2) * H * 0.012
	pitch += math.sin(now * rate * 2 + 0.6) * math.rad(1.6)
	yawAdd += math.sin(now * 0.7) * math.rad(4)

	-- chegada: desce do céu balançando (asas) e aterrissa
	local age = now - r.born
	if age < 2.6 then
		local k = easeOut(age / 2.6)
		up += (1 - k) * H * 2.4
		roll += math.sin(age * 9) * math.rad(6) * (1 - k)
		pitch += math.sin(age * 9 + 1) * math.rad(4) * (1 - k)
	elseif age < 3.0 then
		local k = (age - 2.6) / 0.4
		up -= math.sin(k * math.pi) * H * 0.05 -- amassa ao tocar o chão
	end

	-- ataque: empina durante o aviso e bate no chão no fim
	if r.attackAt > 0 then
		local t = now - r.attackAt
		local d = r.attackDur
		if t < d then
			local k = easeOut(t / d)
			pitch -= math.rad(16) * k
			up += H * 0.08 * k
		elseif t < d + 0.18 then
			local k = (t - d) / 0.18
			pitch += math.rad(-16 + 26 * k)
			up += H * 0.08 * (1 - k)
		elseif t < d + 0.8 then
			local k = (t - d - 0.18) / 0.62
			pitch += math.rad(10) * (1 - easeOut(k))
		else
			r.attackAt = -1
		end
	end

	-- apanhou: tranco curto
	if r.hitAt > 0 then
		local t = now - r.hitAt
		if t < 0.22 then
			local k = math.sin(t / 0.22 * math.pi)
			pitch -= math.rad(2.5) * k
			roll += math.rad(1.5) * k * (if math.floor(r.hitAt * 10) % 2 == 0 then 1 else -1)
		else
			r.hitAt = -1
		end
	end

	-- fim
	if r.over == "won" then
		local k = easeOut((now - r.overAt) / 2)
		roll += math.rad(75) * k
		up -= H * 0.25 * k
	elseif r.over == "fled" then
		local k = math.clamp((now - r.overAt) / 2.5, 0, 1)
		up += H * 3 * k * k
		roll += math.sin(now * 9) * math.rad(5)
		pitch -= math.rad(10) * k
	end

	-- fúria: contorno pulsando
	local hl = r.hl
	if hl then
		if r.fury then
			hl.OutlineColor = Color3.fromRGB(255, 40, 40)
			hl.OutlineTransparency = 0.25 + 0.35 * (0.5 + 0.5 * math.sin(now * 6))
		else
			hl.OutlineColor = Color3.fromRGB(60, 10, 20)
			hl.OutlineTransparency = 0.2
		end
	end

	local base = CFrame.new(r.ground + Vector3.new(0, up, 0))
		* CFrame.Angles(0, r.yaw + yawAdd, 0)
		* CFrame.Angles(pitch, 0, roll)
	for _, p in r.parts do
		p.part.CFrame = base * p.rel
	end
end

---------------------------------------------------------------------------
-- Convite
---------------------------------------------------------------------------
local card: Frame
local teamLabel: TextLabel
local prizeLabel: TextLabel
local playBtn: TextButton
local dismissed = false
local active = false
local pulse: Tween? = nil

local function onIsland(): boolean
	local m = rig
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not m or not root or not root:IsA("BasePart") then
		return false
	end
	local d = root.Position - m.ground
	return Vector3.new(d.X, 0, d.Z).Magnitude < 70 and math.abs(d.Y) < 30
end

local function setCard(visible: boolean)
	if visible == card.Visible then
		return
	end
	card.Visible = visible
	if visible then
		UI.pop(card)
		if not pulse then
			pulse = TweenService:Create(
				playBtn,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundColor3 = Color3.fromRGB(120, 200, 255) }
			)
		end
		if not UI.reducedMotion() then
			(pulse :: Tween):Play()
		end
	elseif pulse then
		pulse:Cancel()
		playBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 255)
	end
end

local function buildCard(gui: ScreenGui)
	card = UI.panel(gui, {
		Name = "DragonInvite",
		Size = UDim2.fromOffset(300, 186),
		-- lado direito, abaixo da faixa de evento e acima do LUTAR: não cobre os botões da esquerda
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.45, 0),
		Visible = false,
	})
	UI.stroke(card, Color3.fromRGB(255, 90, 60), 3)
	UI.autoScale(card)
	UI.label(card, "O DRAGÃO NASCEU!\nVAMOS JOGAR?", {
		Size = UDim2.new(1, -40, 0, 52),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 120, 80),
	})
	local close = UI.button(card, "X", Color3.fromRGB(90, 90, 110), {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -36, 0, 6),
	})
	close.Activated:Connect(function()
		dismissed = true
		setCard(false)
	end)
	teamLabel = UI.label(card, "", {
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextColor3 = UI.Colors.Accent,
	})
	prizeLabel = UI.label(card, "", {
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 84),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
	})
	playBtn = UI.button(card, "JOGAR", Color3.fromRGB(40, 120, 255), {
		Size = UDim2.new(1, -20, 0, 48),
		Position = UDim2.new(0, 10, 1, -56),
		TextScaled = false,
		TextSize = 26,
	})
	playBtn.Activated:Connect(function()
		Remotes.RequestBossJoin:FireServer()
		setCard(false)
		dismissed = true
	end)
end

local function teamText(n: number, goal: number): string
	local dots = ""
	for i = 1, goal do
		dots ..= if i <= n then "●" else "○"
	end
	return string.format("Time: %d de %d  %s", math.min(n, 99), goal, dots)
end

function Dragon.init(gui: ScreenGui)
	buildCard(gui)
	-- O modelo aparece no Workspace: começa a animar.
	local function consider(inst: Instance)
		if inst:IsA("Model") and inst:GetAttribute("BossDragon") then
			task.defer(function()
				local r = capture(inst)
				if r then
					rig = r
					phase = 1
				end
			end)
		end
	end
	Workspace.ChildAdded:Connect(consider)
	for _, c in Workspace:GetChildren() do
		consider(c)
	end
	RunService.RenderStepped:Connect(step)

	Remotes.BossState.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		local r = rig
		if e.kind == "Telegraph" and r then
			r.attackAt = os.clock()
			r.attackDur = tonumber(e.dur) or 1.4
		elseif e.kind == "Phase" then
			phase = tonumber(e.phase) or phase
			if r then
				r.fury = phase >= 2
			end
		elseif e.kind == "Over" then
			if r then
				r.over = if e.won then "won" else "fled"
				r.overAt = os.clock()
			end
			active = false
			dismissed = false
			setCard(false)
		elseif e.kind == "Team" then
			active = true
			local n = tonumber(e.n) or 0
			local goal = tonumber(e.goal) or 4
			teamLabel.Text = teamText(n, goal)
			prizeLabel.Text = "Prêmio: " .. tostring(e.prize or "")
			setCard(not dismissed and not onIsland())
		end
	end)
	Remotes.CombatEvent.OnClientEvent:Connect(function(e)
		local r = rig
		if type(e) ~= "table" or e.kind ~= "NpcHit" or not r then
			return
		end
		-- só treme se quem socou está perto do dragão (soco em bot na praça também é "NpcHit")
		local who = Players:GetPlayerByUserId(tonumber(e.attacker) or 0)
		local char = who and who.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - r.ground).Magnitude < 70 then
			r.hitAt = os.clock()
		end
	end)
	-- quem chega na ilha não precisa mais do cartão
	task.spawn(function()
		while true do
			task.wait(1)
			if active and card.Visible and onIsland() then
				setCard(false)
			end
		end
	end)
end

return Dragon
