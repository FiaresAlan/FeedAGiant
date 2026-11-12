--!strict
-- Feedback V3: numero de XP aparece somente depois da sequencia visual de morder.
-- Nao altera XP, nivel ou inventario; toda transacao ja foi validada no servidor.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Feed = {}

function Feed.init(gui: ScreenGui)
	local player = Players.LocalPlayer
	local label = Instance.new("TextLabel")
	label.Name = "V3FeedFeedback"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 161)
	label.Size = UDim2.fromOffset(240, 46)
	label.BackgroundColor3 = Color3.fromRGB(32, 65, 63)
	label.BackgroundTransparency = 1
	label.TextTransparency = 1
	label.TextColor3 = Color3.fromRGB(161, 249, 197)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.ZIndex = 21
	label.Visible = false
	label.Parent = gui
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 12)
	rounded.Parent = label

	local serial = 0
	Remotes.GiantFed.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or payload.userId ~= player.UserId
			or type(payload.xp) ~= "number" or payload.xp < 0 then
			return
		end
		serial += 1
		local token = serial
		task.delay(1.5, function()
			if not label.Parent or token ~= serial then return end
			label.Text = ("+%d XP  ·  GIGANTE ALIMENTADO"):format(math.floor(payload.xp))
			label.Visible = true
			label.BackgroundTransparency = 0.16
			label.TextTransparency = 0
			task.delay(1.0, function()
				if token ~= serial then return end
				local a = TweenService:Create(label, TweenInfo.new(0.35), {
					BackgroundTransparency = 1,
					TextTransparency = 1,
				})
				a:Play()
				a.Completed:Once(function()
					if token == serial then label.Visible = false end
				end)
			end)
		end)
	end)
end

return Feed
