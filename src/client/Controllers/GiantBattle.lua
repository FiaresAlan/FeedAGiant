--!strict
-- GiantBattle.lua — janela "BATALHA DE GIGANTES" (item 9.2) e o painel durante a luta.
--   * lista as espécies que o jogador POSSUI com vida, força e nível reais (mesma fórmula do servidor);
--   * LEVAR manda o gigante escolhido ao coliseu (o servidor confere a posse e se a arena está livre);
--   * durante a luta: barras de vida dos dois e o botão GOLPE FORTE (recarga), também na tecla G e no
--     botão Y do controle;
--   * no fim: resultado com as moedas e o XP ganhos.
local UserInputService = game:GetService("UserInputService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)

local GiantBattle = {}
local G = Config.GiantBattle

local win: Frame
local list: Frame
local hud: Frame
local meName: TextLabel
local foeName: TextLabel
local meFill: Frame
local foeFill: Frame
local special: TextButton
local result: TextLabel
local meMax, foeMax = 1, 1
local fighting = false
local specialReadyAt = 0

local function stats(speciesId: string, level: number, rebirths: number): (number, number)
	local sp = Config.SpeciesById[speciesId]
	if not sp then
		return 100, 10
	end
	local hp = math.floor(sp.arenaHp * (1 + level * G.HpPerLevel) * (1 + rebirths * G.PerRebirth))
	local power = sp.arenaPower * (1 + level * G.PowerPerLevel) * (1 + rebirths * G.PerRebirth)
	return hp, math.floor(power * 10) / 10
end

local function rebuild()
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local s = State.current :: any
	local owned = s.ownedSpecies or {}
	local order = 0
	for _, sp in Config.Species do
		if not owned[sp.id] then
			continue
		end
		order += 1
		local hp, power = stats(sp.id, s.level or 1, s.rebirths or 0)
		local row = UI.frame(list, {
			Size = UDim2.new(1, -8, 0, 84),
			LayoutOrder = order,
			BackgroundColor3 = UI.Colors.Panel2,
		})
		UI.stroke(row, sp.color, 2)
		UI.label(row, sp.name .. (if s.species == sp.id then "  (equipado)" else ""), {
			Size = UDim2.new(1, -190, 0, 34),
			Position = UDim2.fromOffset(12, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = sp.color,
		})
		UI.label(row, string.format("Nv. %d  •  Vida %d  •  Força %.1f", s.level or 1, hp, power), {
			Size = UDim2.new(1, -190, 0, 30),
			Position = UDim2.fromOffset(12, 44),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			TextColor3 = UI.Colors.Accent,
		})
		local go = UI.button(row, "LEVAR", UI.Colors.Red, {
			Size = UDim2.fromOffset(150, 54),
			Position = UDim2.new(1, -164, 0.5, -27),
			TextScaled = false,
			TextSize = 24,
		})
		go.Activated:Connect(function()
			Remotes.RequestGiantBattle:FireServer(sp.id)
			win.Visible = false
		end)
	end
	if order == 0 then
		UI.label(list, "Você ainda não tem gigantes. Compre na LOJA DE GIGANTES ou nas estátuas da praça.", {
			Size = UDim2.new(1, -8, 0, 60),
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
		})
	end
end

function GiantBattle.open()
	rebuild()
	if not win.Visible then
		UI.pop(win)
	end
end

local function doSpecial()
	if not fighting or os.clock() < specialReadyAt then
		return
	end
	specialReadyAt = os.clock() + G.SpecialCooldown
	Remotes.RequestGiantSpecial:FireServer()
	UI.sfx("Heavy", 0.7)
end

function GiantBattle.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "BATALHA DE GIGANTES", UDim2.fromOffset(620, 520))
	UI.label(
		body,
		string.format(
			"Escolha um gigante seu para lutar contra um gigante selvagem. Vitória: moedas e XP (até %d vitórias premiadas por dia). Derrota não tira nada.",
			G.RewardedWinsPerDay
		),
		{
			Size = UDim2.new(1, 0, 0, 78),
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}
	)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -86)
	scroll.Position = UDim2.fromOffset(0, 84)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body
	list = UI.frame(
		scroll,
		{ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }
	)
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = list

	-- Painel da luta (topo, no meio)
	hud = UI.panel(gui, {
		Name = "GiantBattleHud",
		Size = UDim2.fromOffset(640, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Visible = false,
	})
	UI.autoScale(hud)
	meName = UI.label(hud, "", {
		Size = UDim2.new(0.5, -20, 0, 30),
		Position = UDim2.fromOffset(14, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Green,
	})
	foeName = UI.label(hud, "", {
		Size = UDim2.new(0.5, -20, 0, 30),
		Position = UDim2.new(0.5, 6, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Red,
	})
	local _a
	_a, meFill =
		UI.bar(hud, UI.Colors.Green, { Size = UDim2.new(0.5, -20, 0, 24), Position = UDim2.fromOffset(14, 42) })
	local _b
	_b, foeFill = UI.bar(hud, UI.Colors.Red, {
		Size = UDim2.new(0.5, -20, 0, 24),
		Position = UDim2.new(0.5, 6, 0, 42),
	})
	special = UI.button(hud, "GOLPE FORTE (G)", UI.Colors.Orange, {
		Size = UDim2.fromOffset(300, 56),
		Position = UDim2.new(0.5, -150, 0, 80),
		TextScaled = false,
		TextSize = 24,
	})
	special.Activated:Connect(doSpecial)
	result = UI.title(gui, "", {
		Size = UDim2.fromOffset(700, 70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Visible = false,
		ZIndex = 30,
	})
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.G or (fighting and input.KeyCode == Enum.KeyCode.ButtonY) then
			doSpecial()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if fighting then
				local left = specialReadyAt - os.clock()
				special.Text = if left > 0
					then string.format("GOLPE FORTE  %.0fs", math.ceil(left))
					else "GOLPE FORTE (G)"
				special.BackgroundColor3 = if left > 0 then Color3.fromRGB(96, 102, 118) else UI.Colors.Orange
			end
		end
	end)

	Remotes.GiantBattle.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Start" then
			fighting = true
			meMax = math.max(1, tonumber(e.me.hp) or 1)
			foeMax = math.max(1, tonumber(e.foe.hp) or 1)
			meName.Text = tostring(e.me.name)
			foeName.Text = string.format("%s Nv.%d", tostring(e.foe.name), tonumber(e.foe.level) or 1)
			UI.setBar(meFill, 1, true)
			UI.setBar(foeFill, 1, true)
			specialReadyAt = 0
			hud.Visible = true
			UI.pop(hud)
			if GiantBattle.OnFight then
				GiantBattle.OnFight(true)
			end
			UI.sfx("Bell", 0.8)
			UI.sfx("VO_Fight", 1)
		elseif e.kind == "Tick" then
			UI.setBar(meFill, (tonumber(e.meHp) or 0) / meMax)
			UI.setBar(foeFill, (tonumber(e.foeHp) or 0) / foeMax)
		elseif e.kind == "End" then
			fighting = false
			hud.Visible = false
			if GiantBattle.OnFight then
				GiantBattle.OnFight(false)
			end
			if e.won then
				result.Text = if (e.coins or 0) > 0
					then string.format("VITÓRIA! +%s moedas  +%d XP", Util.formatNumber(e.coins), e.xp or 0)
					else "VITÓRIA! (prêmio do dia já recebido)"
				UI.sfx("Win", 0.9)
				if GiantBattle.OnVictory then
					GiantBattle.OnVictory()
				end
			else
				result.Text = "DERROTA... treine e tente de novo!"
			end
			result.Visible = true
			UI.pop(result)
			task.delay(3.5, function()
				result.Visible = false
			end)
		end
	end)
	State.onChanged(function()
		if win.Visible then
			rebuild()
		end
	end)
end

GiantBattle.OnVictory = nil :: (() -> ())?
GiantBattle.OnFight = nil :: ((started: boolean) -> ())?

return GiantBattle
