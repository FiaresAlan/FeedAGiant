--!strict
-- FoodView — miniatura 3D de uma comida num ViewportFrame (Fase 3/4: abertura de caixa, coleção,
-- azulejo da HUD). Usa os modelos que o servidor deixa em ReplicatedStorage.FoodTemplates
-- (FoodModels.preload) com o mesmo estilo do mundo (ouro, cristal, galáxia, cósmico).
-- Sem modelo (ainda carregando ou falhou): devolve nil e quem chamou mostra o quadrado colorido.
-- Celular primeiro: ViewportFrame não tem luz dinâmica nem sombra; a rotação lenta é opcional e
-- para sozinha quando o quadro some (e nunca roda com "Movimento reduzido").
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FoodVisuals = require(game.ReplicatedStorage.Shared.FoodVisuals)

local FoodView = {}

local function template(foodId: string): Model?
	local visual = FoodVisuals.get(foodId)
	local folder = ReplicatedStorage:FindFirstChild("FoodTemplates")
	if not visual or not folder then
		return nil
	end
	local t = folder:FindFirstChild(visual.file)
	if t and t:IsA("Model") then
		return t
	end
	return nil
end

function FoodView.has(foodId: string): boolean
	return template(foodId) ~= nil
end

-- Espera os modelos chegarem (até `timeout` s). Útil antes de montar listas.
function FoodView.waitReady(timeout: number?): boolean
	return ReplicatedStorage:WaitForChild("FoodTemplates", timeout or 10) ~= nil
end

export type Options = {
	spin: boolean?, -- gira devagar (só enquanto visível)
	silhouette: boolean?, -- comida ainda não descoberta: sombra escura, sem textura
	yaw: number?, -- ângulo inicial em graus
	zIndex: number?,
}

-- Cria o ViewportFrame dentro de `parent`, ocupando todo o espaço dele. Retorna nil sem modelo.
function FoodView.create(parent: GuiObject, foodId: string, opts: Options?): ViewportFrame?
	local t = template(foodId)
	if not t then
		return nil
	end
	local o: Options = opts or {}
	local vf = Instance.new("ViewportFrame")
	vf.Name = "FoodView"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.ZIndex = o.zIndex or ((parent :: GuiObject).ZIndex + 1)
	vf.Ambient = Color3.fromRGB(205, 205, 215)
	vf.LightColor = Color3.fromRGB(255, 244, 225)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.5)

	local model = t:Clone()
	local visual = FoodVisuals.get(foodId)
	local style = visual and visual.style and FoodVisuals.Styles[visual.style]
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			if o.silhouette then
				d.TextureID = ""
				d.Color = Color3.fromRGB(28, 30, 48)
				d.Material = Enum.Material.SmoothPlastic
			elseif style then
				d.TextureID = ""
				d.Color = style.color
				d.Material = style.material
				d.Transparency = style.transparency
			end
		end
	end
	-- Centro da caixa na origem; câmera enquadra a maior dimensão com folga.
	local boxCf, ext = model:GetBoundingBox()
	model:PivotTo(boxCf:ToObjectSpace(model:GetPivot()))
	model.Parent = vf

	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local radius = math.max(ext.X, ext.Y, ext.Z) * 0.5
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.25
	-- -32°: comidas chatas (pizza, donut, prato) aparecem por cima, não de lado (teste de 08/11)
	local pitch = math.rad(-32)
	local yaw = math.rad(o.yaw or 25)
	local function place(a: number)
		local dir = CFrame.Angles(0, a, 0) * CFrame.Angles(pitch, 0, 0)
		cam.CFrame = CFrame.new((dir.LookVector * -dist), Vector3.zero)
	end
	place(yaw)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent

	if o.spin and not GuiService.ReducedMotionEnabled then
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function(dt: number)
			if not vf.Parent then
				if conn then
					conn:Disconnect()
				end
				return
			end
			if vf.Visible then
				yaw += dt * 0.9
				place(yaw)
			end
		end)
		vf.Destroying:Connect(function()
			if conn then
				conn:Disconnect()
			end
		end)
	end
	return vf
end

return FoodView
