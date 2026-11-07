--!strict
-- Drops.lua — painel lateral "DISPUTA" com os contendores de cada drop ativo + seta até o drop mais próximo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)

local Drops = {}
local player = Players.LocalPlayer
local panel: Frame
local list: Frame
local cards: { [number]: Frame } = {}
local drops: { [number]: any } = {}
local arrow: TextLabel

local function rebuildCard(d: any)
	local existing = cards[d.id]
	local card: Frame
	if existing then
		card = existing
	else
		card = UI.frame(list, { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = UI.Colors.Panel })
		UI.stroke(card, Config.Rarities[d.rarity].color, 2)
		local title = UI.label(card, "", {
			Name = "Title",
			Size = UDim2.new(1, -12, 0, 20),
			Position = UDim2.fromOffset(6, 2),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Config.Rarities[d.rarity].color,
		})
		title.Text = Locale.fmt("drop_card", nil, { f = d.name, r = d.rarity, n = d.holdTime })
		local rows = UI.frame(card, {
			Name = "Rows",
			Size = UDim2.new(1, -12, 1, -26),
			Position = UDim2.fromOffset(6, 24),
			BackgroundTransparency = 1,
		})
		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 2)
		lay.Parent = rows
		cards[d.id] = card
	end
	local rows = card:FindFirstChild("Rows")
	if not rows or not rows:IsA("Frame") then
		return
	end
	for _, c in rows:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local n = 0
	for i, c in d.contenders or {} do
		if i > 4 then
			break
		end
		n += 1
		local row = UI.frame(rows, { Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = Color3.fromRGB(20, 20, 30) })
		UI.corner(row, 6)
		local fill = UI.frame(row, {
			Size = UDim2.fromScale(math.clamp(c.progress, 0, 1), 1),
			BackgroundColor3 = if c.userId == player.UserId
				then UI.Colors.Green
				else (if c.inside then UI.Colors.Accent else Color3.fromRGB(110, 110, 130)),
		})
		UI.corner(fill, 6)
		UI.label(
			row,
			string.format("%s %d%%", c.name, math.floor(c.progress * 100)),
			{ Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 11 }
		)
	end
	if n == 0 then
		UI.label(
			rows,
			"Ninguém no círculo — CORRA!",
			{ Size = UDim2.new(1, 0, 0, 16), TextScaled = false, TextSize = 11, TextColor3 = UI.Colors.Accent }
		)
		n = 1
	end
	card.Size = UDim2.new(1, 0, 0, 30 + n * 18)
end

local function refreshPanel()
	local any = next(drops) ~= nil
	panel.Visible = any
	arrow.Visible = any
end

function Drops.init(gui: ScreenGui)
	panel = UI.panel(gui, {
		Name = "DropsPanel",
		Size = UDim2.fromOffset(280, 220),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UI.Colors.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	UI.stroke(panel, Color3.new(0, 0, 0), 3)
	UI.title(panel, "⚔ DISPUTA DE COMIDA", {
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
	})
	list = UI.frame(
		panel,
		{ Size = UDim2.new(1, -16, 1, -36), Position = UDim2.fromOffset(8, 32), BackgroundTransparency = 1 }
	)
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 6)
	lay.Parent = list
	arrow = UI.title(gui, "▼ COMIDA CAINDO NO CENTRO ▼", {
		Size = UDim2.fromOffset(360, 30),
		Position = UDim2.new(0.5, 0, 0, 100),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = UI.Colors.Accent,
		Visible = false,
	})

	Remotes.DropState.OnClientEvent:Connect(function(d)
		if type(d) ~= "table" or type(d.id) ~= "number" then
			return
		end
		if d.removed then
			drops[d.id] = nil
			if cards[d.id] then
				cards[d.id]:Destroy()
				cards[d.id] = nil
			end
		else
			if not drops[d.id] then
				UI.sfx("VO_Drop", 0.9)
				UI.sfx("Bell", 0.4)
			end
			drops[d.id] = d
			rebuildCard(d)
		end
		refreshPanel()
	end)

	-- Seta aponta para o drop mais próximo
	RunService.Heartbeat:Connect(function()
		if not arrow.Visible then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local best, bd = nil, math.huge
		for _, d in drops do
			if typeof(d.pos) == "Vector3" then
				local dist = (d.pos - root.Position).Magnitude
				if dist < bd then
					bd, best = dist, d
				end
			end
		end
		if best then
			local cam = Workspace.CurrentCamera
			local rel = cam.CFrame:PointToObjectSpace(best.pos)
			local ang = math.deg(math.atan2(rel.X, -rel.Z))
			arrow.Text = string.format(
				"%s  %dm  %s",
				if ang < -20 then "◄" else (if ang > 20 then "►" else "▲"),
				math.floor(bd),
				best.name
			)
		end
	end)
end

return Drops
