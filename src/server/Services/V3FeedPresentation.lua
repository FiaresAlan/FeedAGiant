--!strict
-- Food presentation V3. Visual-only, nunca concede XP, comida ou moedas.
-- O inventario ja foi debitado e validado pelo PlotService antes deste efeito.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Presentation = {}
local active: { [Model]: BasePart } = {}

function Presentation.play(model: Model, foodId: any)
	if type(foodId) ~= "string" or not model.Parent then return end
	local foodDef = Config.FoodById[foodId]
	if not foodDef then return end
	local hand = model:FindFirstChild("CargoCarryAnchor", true)
	local mouth = model:FindFirstChild("Jaw", true)
	if not hand or not hand:IsA("Attachment") or not hand.Parent
		or not hand.Parent:IsA("BasePart") or not mouth or not mouth:IsA("BasePart") then
		return -- o rig importado pode usar animacoes proprias com markers
	end
	local previous = active[model]
	if previous and previous.Parent then previous:Destroy() end

	local morsel = Instance.new("Part")
	morsel.Name = "V3FeedingMorsel"
	morsel.Size = Vector3.new(1.7, 1.7, 1.7)
	morsel.Shape = if foodDef.shape == "Block" then Enum.PartType.Block else Enum.PartType.Ball
	morsel.Color = foodDef.color
	morsel.Material = Enum.Material.SmoothPlastic
	morsel.CanCollide = false
	morsel.CanTouch = false
	morsel.CanQuery = false
	morsel.Massless = true
	morsel.Anchored = false
	morsel.CFrame = hand.WorldCFrame
	morsel.Parent = model
	active[model] = morsel

	local grip = Instance.new("WeldConstraint")
	grip.Name = "FoodInHand"
	grip.Part0 = hand.Parent
	grip.Part1 = morsel
	grip.Parent = morsel
	task.delay(0.62, function()
		if not model.Parent or not morsel.Parent then return end
		grip:Destroy()
		morsel.CFrame = mouth.CFrame * CFrame.new(0, -0.4, -1.55)
		local bite = Instance.new("WeldConstraint")
		bite.Name = "FoodAtMouth"
		bite.Part0 = mouth
		bite.Part1 = morsel
		bite.Parent = morsel
	end)
	task.delay(1.45, function()
		if active[model] == morsel then active[model] = nil end
		if morsel.Parent then morsel:Destroy() end
	end)
end

return Presentation
