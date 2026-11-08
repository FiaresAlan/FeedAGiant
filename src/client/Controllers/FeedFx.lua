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

local FeedFx = {}

local MAX_DIST = 250
local FLIGHT = 0.6
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

local function burst(at: Vector3, color: Color3, xp: number)
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
	pe:Emit(22)
	local label = Util.makeBillboard(
		anchor,
		"+" .. Util.formatNumber(xp) .. " XP",
		UDim2.fromOffset(160, 44),
		Vector3.new(0, 2, 0),
		color
	)
	local board = label.Parent :: BillboardGui
	board.AlwaysOnTop = true
	TweenService:Create(board, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.3, function()
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
		burst(mouthOf(giant), color, xp)
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
			burst(to, color, xp)
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
