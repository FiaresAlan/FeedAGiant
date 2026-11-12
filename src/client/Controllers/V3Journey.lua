--!strict
-- Cartao discreto de proximo passo. Nao escurece a tela nem bloqueia input.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Layout = require(ReplicatedStorage.Shared.RebuildV2.GuideLayoutRules)

local UI = {}

function UI.init(gui: ScreenGui)
	local card = Instance.new("Frame")
	card.Name = "V3JourneyCard"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -16, 0, 12)
	card.Size = UDim2.fromOffset(255, 87)
	card.BackgroundColor3 = Color3.fromRGB(28, 42, 52)
	card.BackgroundTransparency = 0.16
	card.BorderSizePixel = 0
	card.ZIndex = 16
	card.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(290, 100)
	limit.Parent = card
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 12)
	round.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(127, 211, 194)
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = card
	local title = Instance.new("TextLabel")
	title.Name = "JourneyHeader"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(11, 6)
	title.Size = UDim2.new(1, -49, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 211, 117)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.Text = "SEU PROXIMO PASSO"
	title.ZIndex = 17
	title.Parent = card
	local message = Instance.new("TextLabel")
	message.Name = "JourneyBody"
	message.BackgroundTransparency = 1
	message.Position = UDim2.fromOffset(11, 29)
	message.Size = UDim2.new(1, -24, 0, 51)
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextYAlignment = Enum.TextYAlignment.Top
	message.TextWrapped = true
	message.TextColor3 = Color3.fromRGB(242, 240, 222)
	message.Font = Enum.Font.Gotham
	message.TextSize = 13
	message.Text = "Buscando proxima atividade..."
	message.ZIndex = 17
	message.Parent = card
	local dismiss = Instance.new("TextButton")
	dismiss.Name = "DismissHint"
	dismiss.BackgroundTransparency = 1
	dismiss.Position = UDim2.new(1, -37, 0, 5)
	dismiss.Size = UDim2.fromOffset(30, 29)
	dismiss.Text = "×"
	dismiss.TextSize = 21
	dismiss.TextColor3 = Color3.fromRGB(207, 217, 221)
	dismiss.ZIndex = 18
	dismiss.Parent = card
	-- HUD do gigante ocupa o canto superior esquerdo. Em tela estreita,
	-- deslocar o guia para baixo da escolha inicial; apos escolher, compactar.
	local starter = gui:FindFirstChild("V2ChooseStone")
	local cameraConnection: RBXScriptConnection? = nil
	local function reposition()
		local camera = workspace.CurrentCamera
		if not camera or not card.Parent then return end
		local chooseVisible = starter ~= nil and starter:IsA("GuiObject") and starter.Visible
		local side, width, y = Layout.place(camera.ViewportSize.X, camera.ViewportSize.Y,
			chooseVisible, RunService:IsStudio())
		card.AnchorPoint = if side == "right" then Vector2.new(1, 0) else Vector2.new(0, 0)
		card.Position = if side == "right" then UDim2.new(1, -16, 0, y)
			else UDim2.fromOffset(14, y)
		card.Size = UDim2.fromOffset(width, 87)
	end
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(reposition)
		end
		reposition()
	end
	if starter and starter:IsA("GuiObject") then
		starter:GetPropertyChangedSignal("Visible"):Connect(reposition)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
	local dismissed = false
	dismiss.MouseButton1Click:Connect(function()
		dismissed = true
		card.Visible = false
	end)
	Remotes.V3GuideState.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.message) ~= "string" then return end
		title.Text = if payload.finished then "JORNADA CONCLUIDA" else
			("PROXIMO PASSO · %d/7"):format(tonumber(payload.step) or 1)
		message.Text = payload.message
		card.Visible = not dismissed
	end)
	Remotes.V3GuideRequest:FireServer("snapshot")
end

return UI
