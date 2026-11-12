--!strict
-- HUD da pista V2, legivel em mobile. Nenhuma concessao economica no cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Features = require(ReplicatedStorage.Shared.Features)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local LaneUI = {}
local state: { any } = {}
local deliveryCount = 0
local homePosition: Vector3? = nil
local status: TextLabel?
local mounted = false

local function ownGiantRoot(): BasePart?
	local model = workspace:FindFirstChild("V2Mounted_" .. tostring(player.UserId))
	if not model or not model:IsA("Model") then return nil end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function carriedCargo(): any
	for _, cargo in state do
		if cargo.ownerUserId == player.UserId and cargo.state == "carried" then
			return cargo
		end
	end
	return nil
end

local function closestCargo(): any
	local root = ownGiantRoot()
	if not root then return nil end
	local best, bestDistance = nil, 18.5
	for _, cargo in state do
		if (cargo.state == "world" or cargo.state == "dropped") and typeof(cargo.position) == "Vector3" then
			local d = (root.Position - cargo.position).Magnitude
			if d < bestDistance then best, bestDistance = cargo, d end
		end
	end
	return best
end

local function closestRival(): Player?
	local root = ownGiantRoot()
	if not root then return nil end
	local nearest, distance = nil, 15.5
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local model = workspace:FindFirstChild("V2Mounted_" .. tostring(other.UserId))
			local theirs = model and model:FindFirstChild("HumanoidRootPart")
			if theirs and theirs:IsA("BasePart") then
				local d = (theirs.Position - root.Position).Magnitude
				if d < distance then nearest, distance = other, d end
			end
		end
	end
	return nearest
end

local function actionPickup(_: string, input: Enum.UserInputState)
	if input ~= Enum.UserInputState.Begin or not mounted then return Enum.ContextActionResult.Pass end
	local mine = carriedCargo()
	if mine then
		Remotes.V2LaneRequest:FireServer("deposit")
	else
		local near = closestCargo()
		if near then Remotes.V2LaneRequest:FireServer("pickup", near.uid) end
	end
	return Enum.ContextActionResult.Sink
end

local function actionIntercept(_: string, input: Enum.UserInputState)
	if input ~= Enum.UserInputState.Begin or not mounted then return Enum.ContextActionResult.Pass end
	local rival = closestRival()
	if rival then Remotes.V2LaneRequest:FireServer("intercept", rival.UserId) end
	return Enum.ContextActionResult.Sink
end

local function refresh()
	if not status then return end
	local root = ownGiantRoot()
	mounted = root ~= nil
	status.Visible = mounted
	if not mounted then return end
	local mine = carriedCargo()
	if mine then
		local def = Config.FoodById[mine.itemId]
		local name = if mine.kind == "recipe_scroll" then "PERGAMINHO" else (if def then def.name else mine.itemId)
		local weight = if mine.weight == "heavy" then "PESADA" elseif mine.weight == "medium" then "MEDIA" else "LEVE"
		local distanceHome = if homePosition then (Vector3.new(root.Position.X, 0, root.Position.Z)
			- Vector3.new(homePosition.X, 0, homePosition.Z)).Magnitude else nil
		local route = if distanceHome then ("BASE A %d STUDS"):format(math.floor(distanceHome)) else "VOLTE A SUA BASE"
		status.Text = ("CARGA %s: %s  •  %s\nE / X · ENTREGAR NA ZONA   |   R / B · DISPUTAR"):format(weight, name, route)
	else
		local nearest = closestCargo()
		local def = nearest and Config.FoodById[nearest.itemId]
		local name = if nearest then (if nearest.kind == "recipe_scroll" then "PERGAMINHO" else (if def then def.name else nearest.itemId)) else nil
		status.Text = if name then ("PROXIMO: %s  •  E / X · PEGAR\nENTREGAS: %d"):format(name, deliveryCount)
			else ("PROCURE COMIDAS NA PISTA  •  E / X · PEGAR\nENTREGAS: %d"):format(deliveryCount)
	end
end

function LaneUI.init(gui: ScreenGui)
	if not Features.on("RebuildV2") then return end
	status = Instance.new("TextLabel")
	status.Name = "V2LaneHUD"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 1, -80)
	status.Size = UDim2.new(0.78, 0, 0, 58)
	status.TextColor3 = Color3.fromRGB(255, 246, 220)
	status.BackgroundColor3 = Color3.fromRGB(27, 47, 56)
	status.BackgroundTransparency = 0.1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 12
	status.TextWrapped = true
	status.Visible = false
	status.ZIndex = 19
	status.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(535, 100)
	limit.Parent = status
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 12)
	rounded.Parent = status
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(241, 198, 110)
	stroke.Thickness = 1.4
	stroke.Parent = status
	ContextActionService:BindAction("V2CargoInteract", actionPickup, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("V2CargoInteract", "PEGAR")
	ContextActionService:SetPosition("V2CargoInteract", UDim2.new(1, -260, 1, -110))
	ContextActionService:BindAction("V2CargoIntercept", actionIntercept, true, Enum.KeyCode.R, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("V2CargoIntercept", "DISPUTAR")
	ContextActionService:SetPosition("V2CargoIntercept", UDim2.new(1, -265, 1, -195))
	Remotes.V2LaneState.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end
		if type(payload.cargo) == "table" then state = payload.cargo end
		if type(payload.deliveries) == "number" then deliveryCount = payload.deliveries end
		if typeof(payload.homePosition) == "Vector3" then homePosition = payload.homePosition end
		refresh()
	end)
	Remotes.V2MountState.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			mounted = payload.mounted == true
			refresh()
		end
	end)
	task.spawn(function()
		while gui.Parent do
			task.wait(0.3)
			refresh()
		end
	end)
	Remotes.V2LaneRequest:FireServer("snapshot")
end

return LaneUI
