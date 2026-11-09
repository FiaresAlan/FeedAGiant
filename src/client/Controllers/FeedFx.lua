--!strict
-- FeedFx — Fase 3 ("juice"): ao alimentar, a comida 3D voa em arco até a boca do gigante, girando,
-- encolhe ao chegar, estoura em faíscas da cor da raridade e sobe um "+XP".
-- Só no cliente e só perto da câmera (celular primeiro). Usa os modelos de
-- ReplicatedStorage.FoodTemplates (FoodModels, servidor) e o mesmo estilo de FoodVisuals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local FoodVisuals = require(game.ReplicatedStorage.Shared.FoodVisuals)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local UI = require(script.Parent.Parent.UI)

local FeedFx = {}

local MAX_DIST = 250
local FLIGHT = GameRules.Feed.FlightSeconds -- o mesmo tempo da mordida em GiantAnim
local FOOD_SIZE = 3.2

local function giantOf(userId: number): Model?
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == userId and m.Name:match("^Giant_") then
			return m
		end
	end
	return nil
end

local function mouthOf(giant: Model): Vector3
	local target: PVInstance = giant
	local mesh = giant:FindFirstChild("CreatureMesh")
	if mesh and mesh:IsA("Model") then
		target = mesh
	end
	local cf, size = (target :: Model):GetBoundingBox()
	-- Boca ~ 80% da altura, um pouco à frente do centro
	return (cf * CFrame.new(0, size.Y * 0.3, -size.Z * 0.25)).Position
end

local function cloneFood(foodId: string): Model?
	local visual = FoodVisuals.get(foodId)
	local folder = ReplicatedStorage:FindFirstChild("FoodTemplates")
	local template = visual and folder and folder:FindFirstChild(visual.file)
	if not visual or not template or not template:IsA("Model") then
		return nil
	end
	local m = template:Clone()
	local _, ext = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * FOOD_SIZE / math.max(ext.X, ext.Y, ext.Z, 1e-3))
	local style = visual.style and FoodVisuals.Styles[visual.style]
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if style and d:IsA("MeshPart") then
				d.TextureID = ""
				d.Color = style.color
				d.Material = style.material
				d.Transparency = style.transparency
			end
		end
	end
	return m
end

local player = game:GetService("Players").LocalPlayer

-- Tremida curta da câmera (só para o dono, só na crítica). Respeita "movimento reduzido".
local function shake(strength: number, duration: number)
	local GuiService = game:GetService("GuiService")
	if GuiService.ReducedMotionEnabled then
		return
	end
	local t0 = os.clock()
	local name = "FeedCritShake"
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local a = os.clock() - t0
		local cam = Workspace.CurrentCamera
		if a >= duration or not cam then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = strength * (1 - a / duration)
		cam.CFrame = cam.CFrame
			* CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end)
end

-- Um destaque curto confirma visualmente QUAL gigante foi alimentado.
-- O efeito vive apenas no cliente, não altera status, rede ou modelo persistido.
local function pulseGiant(userId: number, color: Color3)
	local giant = giantOf(userId)
	if not giant then
		return
	end
	local old = giant:FindFirstChild("FeedPulse")
	if old then
		old:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "FeedPulse"
	h.Adornee = giant
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillColor = color
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.86
	h.OutlineTransparency = 0.1
	h.Parent = giant
	TweenService:Create(h, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	task.delay(0.7, function()
		if h.Parent then
			h:Destroy()
		end
	end)
end

local function burst(at: Vector3, color: Color3, xp: number, e: { [string]: any })
	local crit = e.crit == true
	local def = if type(e.foodId) == "string" then Config.FoodById[e.foodId] else nil
	local rarityOrder = if def then Config.Rarities[def.rarity].order else 1
	pulseGiant(e.userId, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.8, 0)
	pe.Parent = anchor
	pe:Emit(if crit then 24 elseif rarityOrder >= 4 then 22 else 14)
	if rarityOrder >= 4 then
		-- Brilho rápido só para comidas épicas+, sem efeito contínuo no celular.
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 2
		light.Range = 12
		light.Shadows = false
		light.Parent = anchor
		TweenService:Create(light, TweenInfo.new(0.55), { Brightness = 0 }):Play()
	end
	if crit then
		-- Crítica: estrelas douradas grandes + anel de faíscas (um Emit só, sem Rate contínuo).
		local star = Instance.new("ParticleEmitter")
		star.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		star.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 150, 40))
		star.LightEmission = 1
		star.LightInfluence = 0
		star.Rate = 0
		star.Lifetime = NumberRange.new(0.7, 1.2)
		star.Speed = NumberRange.new(14, 26)
		star.SpreadAngle = Vector2.new(180, 180)
		star.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		star.Rotation = NumberRange.new(0, 360)
		star.RotSpeed = NumberRange.new(-180, 180)
		star.Parent = anchor
		star:Emit(26)
	end
	local trait = if type(e.trait) == "string" then GameRules.Traits[e.trait] else nil
	local text = "+" .. Util.formatNumber(xp) .. " XP"
	if e.userId == player.UserId and e.feedNumber == 1 then
		text = "PRIMEIRA MORDIDA!\n" .. text
	elseif e.userId == player.UserId and e.leveled and type(e.level) == "number" then
		text ..= "\nNÍVEL " .. tostring(e.level)
	end
	if crit then
		text = Locale.t("CRÍTICO!") .. "  " .. text
	end
	local streak = if type(e.streak) == "number" then e.streak else 0
	if streak >= 2 and type(e.streakMult) == "number" and e.streakMult > 1 then
		text ..= "\n" .. string.format("%s %d  x%.1f", Locale.t("SEQUÊNCIA"), streak, e.streakMult)
	end
	local label = Util.makeBillboard(
		anchor,
		text,
		if crit then UDim2.fromOffset(300, 110) else UDim2.fromOffset(200, 76),
		Vector3.new(0, 2, 0),
		if crit then Color3.fromRGB(255, 220, 70) elseif trait then trait.color else color
	)
	local board = label.Parent :: BillboardGui
	board.AlwaysOnTop = true
	TweenService:Create(board, TweenInfo.new(1.3, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	if e.userId == player.UserId then
		if crit then
			shake(1.6, 0.45)
			UI.sfx("Heavy", 0.8)
			task.delay(0.08, function()
				UI.sfx("Bell", 0.7)
			end)
		else
			UI.sfx("Coin", 0.35)
		end
	end
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

local function fly(e: { [string]: any })
	local giant = giantOf(e.userId)
	local from = e.from
	if not giant or typeof(from) ~= "Vector3" or type(e.foodId) ~= "string" then
		return
	end
	local cam = Workspace.CurrentCamera
	if cam and (cam.CFrame.Position - from).Magnitude > MAX_DIST then
		return
	end
	local def = Config.FoodById[e.foodId]
	local color = if def then Config.Rarities[def.rarity].color else Color3.new(1, 1, 1)
	local food = cloneFood(e.foodId)
	local xp = if type(e.xp) == "number" then e.xp else 0
	if not food then
		task.delay(FLIGHT, burst, mouthOf(giant), color, xp, e)
		return
	end
	local model = food :: Model
	model.Parent = Workspace
	local to = mouthOf(giant)
	local dist = (to - from).Magnitude
	local peak = (from + to) / 2 + Vector3.new(0, 6 + dist * 0.25, 0)
	local baseScale = model:GetScale()
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / FLIGHT, 0, 1)
		-- Bézier quadrática (arco) + giro; encolhe nos últimos 30%
		local p = (1 - a) ^ 2 * from + 2 * (1 - a) * a * peak + a ^ 2 * to
		model:PivotTo(CFrame.new(p) * CFrame.Angles(a * 7, a * 11, 0))
		local shrink = if a > 0.7 then 1 - (a - 0.7) / 0.3 * 0.85 else 1
		model:ScaleTo(baseScale * math.max(shrink, 0.1))
		if a >= 1 then
			conn:Disconnect()
			model:Destroy()
			burst(to, color, xp, e)
		end
	end)
end

function FeedFx.init()
	Remotes.GiantFed.OnClientEvent:Connect(function(e)
		if type(e) == "table" and type(e.userId) == "number" then
			fly(e)
		end
	end)
end

return FeedFx
