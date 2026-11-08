--!strict
-- GiantBattle.lua — janela "BATALHA DE GIGANTES" e o painel da luta POR TURNOS (08/11/2026, noite).
--   * lista as espécies que o jogador POSSUI com o nível de CADA uma (coleção com progresso próprio);
--   * LEVAR manda o gigante escolhido ao coliseu (o servidor confere a posse e se a arena está livre);
--   * na luta: barras de vida, 3 botões de golpe (nome, % de acerto, força e o efeito em 1 linha),
--     cronômetro do turno e uma linha que narra o que aconteceu ("Mordida acertou! -23", "ERROU!").
--     Teclas 1/2/3 e botões X/Y/B do controle também escolhem. Sem escolha, o servidor usa o golpe 1.
--   * no fim: resultado com as moedas e o XP ganhos.
-- O cliente só manda o ÍNDICE do golpe; acerto, dano e efeitos são sorteados no servidor.
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)

local GiantBattle = {}
local G = Config.GiantBattle

local win: Frame
local list: Frame
local hud: Frame
local movesBar: Frame
local meName: TextLabel
local foeName: TextLabel
local meFill: Frame
local foeFill: Frame
local meHpText: TextLabel
local foeHpText: TextLabel
local logLine: TextLabel
local turnFill: Frame
local result: TextLabel
local moveButtons: { TextButton } = {}
local moveLabels: { { name: TextLabel, info: TextLabel, desc: TextLabel } } = {}
local meMax, foeMax = 1, 1
local fighting = false
local myTurn = false

local EFFECT_TEXT = {
	stun = "deixou TONTO!",
	weaken = "baixou a DEFESA!",
	guard = "preparou a ESQUIVA!",
}

local function stats(speciesId: string, level: number, rebirths: number): (number, number)
	local sp = Config.SpeciesById[speciesId]
	if not sp then
		return 100, 10
	end
	local hp = math.floor(sp.arenaHp * (1 + level * G.HpPerLevel) * (1 + rebirths * G.PerRebirth))
	local power = sp.arenaPower * (1 + level * G.PowerPerLevel) * (1 + rebirths * G.PerRebirth)
	return hp, math.floor(power * 10) / 10
end

local function levelOf(s: any, speciesId: string): number
	if s.species == speciesId then
		return s.level or 1
	end
	local g = s.giants and s.giants[speciesId]
	return if g then g.level else 1
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
		local lv = levelOf(s, sp.id)
		local hp, power = stats(sp.id, lv, s.rebirths or 0)
		local row = UI.frame(list, {
			Size = UDim2.new(1, -8, 0, 84),
			LayoutOrder = order,
			BackgroundColor3 = UI.Colors.Panel2,
		})
		UI.stroke(row, sp.color, 2)
		UI.label(row, sp.name .. (if s.species == sp.id then "  (" .. Locale.t("equipado") .. ")" else ""), {
			Size = UDim2.new(1, -190, 0, 34),
			Position = UDim2.fromOffset(12, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = sp.color,
		})
		UI.label(
			row,
			string.format("Nv. %d  •  %s %d  •  %s %.1f", lv, Locale.t("Vida"), hp, Locale.t("Força"), power),
			{
				Size = UDim2.new(1, -190, 0, 30),
				Position = UDim2.fromOffset(12, 44),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 20,
				TextColor3 = UI.Colors.Accent,
			}
		)
		local go = UI.button(row, Locale.t("LEVAR"), UI.Colors.Red, {
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

local function setTurn(on: boolean, seconds: number?)
	myTurn = on
	for _, b in moveButtons do
		b.AutoButtonColor = on
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if on then 0 else 0.6
		end
	end
	movesBar.BackgroundTransparency = if on then 0.1 else 0.45
	if on and seconds then
		turnFill.Size = UDim2.fromScale(1, 1)
		TweenService:Create(turnFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(0, 1),
		}):Play()
	else
		turnFill.Size = UDim2.fromScale(0, 1)
	end
end

local function choose(i: number)
	if not fighting or not myTurn then
		return
	end
	setTurn(false)
	Remotes.RequestGiantMove:FireServer(i)
	UI.sfx("Click", 0.6)
end

local function say(text: string, color: Color3)
	logLine.Text = text
	logLine.TextColor3 = color
	UI.pop(logLine)
end

function GiantBattle.init(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "BATALHA DE GIGANTES", UDim2.fromOffset(620, 520))
	UI.label(
		body,
		string.format(
			"Batalha por turnos: escolha um golpe a cada rodada. Golpes fortes erram mais! Vitória: moedas e XP (até %d por dia). Derrota não tira nada.",
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

	-- Placar da luta (topo)
	hud = UI.panel(gui, {
		Name = "GiantBattleHud",
		Size = UDim2.fromOffset(700, 136),
		AnchorPoint = Vector2.new(0.5, 0),
		-- abaixo das faixas do tutorial e do selo de evento (revisão das fotos de 08/11 noite)
		Position = UDim2.new(0.5, 0, 0, 200),
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
	local meBar
	meBar, meFill =
		UI.bar(hud, UI.Colors.Green, { Size = UDim2.new(0.5, -20, 0, 26), Position = UDim2.fromOffset(14, 42) })
	local foeBar
	foeBar, foeFill = UI.bar(hud, UI.Colors.Red, {
		Size = UDim2.new(0.5, -20, 0, 26),
		Position = UDim2.new(0.5, 6, 0, 42),
	})
	meHpText = UI.label(meBar, "", { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 20, ZIndex = 20 })
	foeHpText = UI.label(foeBar, "", { Size = UDim2.fromScale(1, 1), TextScaled = false, TextSize = 20, ZIndex = 20 })
	logLine = UI.label(hud, "", {
		Size = UDim2.new(1, -28, 0, 40),
		Position = UDim2.fromOffset(14, 80),
		TextScaled = false,
		TextSize = 26,
	})

	-- Golpes (embaixo, grandes para o polegar)
	movesBar = UI.panel(gui, {
		Name = "GiantBattleMoves",
		Size = UDim2.fromOffset(820, 184),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Visible = false,
	})
	UI.autoScale(movesBar)
	-- Celular (medido no iPhone emulado, tela útil de 323 px de altura): o placar ficava em y = 200,
	-- em cima dos golpes. Agora fica sempre logo acima dos golpes, e os dois ficam por cima do
	-- botão LUTAR e do cartão de disputa durante a luta.
	hud.ZIndex = 25
	movesBar.ZIndex = 25
	local function layoutBattle()
		local area = gui.AbsoluteSize
		if area.Y <= 0 then
			return
		end
		local k = UI.deviceScale()
		local movesTop = area.Y - 16 - 184 * k
		local hudH = 136 * k
		local y = math.max(8, math.min(200, movesTop - 8 - hudH))
		hud.Position = UDim2.new(0.5, 0, 0, math.floor(y))
	end
	layoutBattle()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBattle)
	local turnBg = UI.frame(movesBar, {
		Size = UDim2.new(1, -28, 0, 8),
		Position = UDim2.fromOffset(14, 8),
		BackgroundColor3 = Color3.fromRGB(30, 30, 36),
	})
	UI.corner(turnBg, 4)
	turnFill = UI.frame(turnBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Accent })
	UI.corner(turnFill, 4)
	local colors = { UI.Colors.Green, UI.Colors.Blue, UI.Colors.Orange }
	for i = 1, 3 do
		local b = UI.button(movesBar, "", colors[i], {
			Size = UDim2.fromOffset(256, 148),
			Position = UDim2.fromOffset(14 + (i - 1) * 268, 26),
		})
		local name = UI.label(b, "", {
			Name = "MoveName",
			Size = UDim2.new(1, -12, 0, 40),
			Position = UDim2.fromOffset(6, 4),
			ZIndex = b.ZIndex + 1,
		})
		local info = UI.label(b, "", {
			Name = "MoveInfo",
			Size = UDim2.new(1, -12, 0, 30),
			Position = UDim2.fromOffset(6, 46),
			TextScaled = true,
			ZIndex = b.ZIndex + 1,
		})
		local desc = UI.label(b, "", {
			Name = "MoveDesc",
			Size = UDim2.new(1, -12, 0, 62),
			Position = UDim2.fromOffset(6, 80),
			TextScaled = true,
			TextWrapped = true,
			Font = UI.FontBody,
			ZIndex = b.ZIndex + 1,
		})
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 24
		cap.Parent = desc
		local cap2 = Instance.new("UITextSizeConstraint")
		cap2.MaxTextSize = 26
		cap2.Parent = info
		moveLabels[i] = { name = name, info = info, desc = desc }
		b.Activated:Connect(function()
			choose(i)
		end)
		moveButtons[i] = b
	end

	result = UI.title(gui, "", {
		Size = UDim2.fromOffset(700, 70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Visible = false,
		ZIndex = 30,
	})
	local keys = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.ButtonX] = 1,
		[Enum.KeyCode.ButtonY] = 2,
		[Enum.KeyCode.ButtonB] = 3,
	}
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or not fighting then
			return
		end
		local i = keys[input.KeyCode]
		if i then
			choose(i)
		end
	end)

	local function hpTexts(meHp: number, foeHp: number)
		UI.setBar(meFill, meHp / meMax)
		UI.setBar(foeFill, foeHp / foeMax)
		meHpText.Text = string.format("%d / %d", math.ceil(meHp), meMax)
		foeHpText.Text = string.format("%d / %d", math.ceil(foeHp), foeMax)
	end

	Remotes.GiantBattle.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Start" then
			fighting = true
			meMax = math.max(1, tonumber(e.me.hp) or 1)
			foeMax = math.max(1, tonumber(e.foe.hp) or 1)
			meName.Text = string.format("%s Nv.%d", tostring(e.me.name), tonumber(e.me.level) or 1)
			foeName.Text = string.format("%s Nv.%d", tostring(e.foe.name), tonumber(e.foe.level) or 1)
			hpTexts(meMax, foeMax)
			if type(e.moves) == "table" then
				for i, lbl in moveLabels do
					local m = e.moves[i]
					if type(m) == "table" then
						lbl.name.Text = Locale.t(tostring(m.name))
						lbl.info.Text = string.format(
							"%s %d%%  ·  %s x%.1f",
							Locale.t("Acerto"),
							math.floor((tonumber(m.accuracy) or 0) * 100 + 0.5),
							Locale.t("Dano"),
							tonumber(m.power) or 1
						)
						lbl.desc.Text = Locale.t(tostring(m.desc))
					end
				end
			end
			say(Locale.t("Prepare-se..."), Color3.new(1, 1, 1))
			setTurn(false)
			hud.Visible = true
			movesBar.Visible = true
			UI.pop(hud)
			UI.pop(movesBar)
			if GiantBattle.OnFight then
				GiantBattle.OnFight(true)
			end
			UI.sfx("Bell", 0.8)
			UI.sfx("VO_Fight", 1)
		elseif e.kind == "Turn" then
			say(Locale.t("SUA VEZ! Escolha um golpe"), UI.Colors.Accent)
			setTurn(true, tonumber(e.seconds) or 12)
		elseif e.kind == "Result" then
			setTurn(false)
			local mine = e.side == "me"
			local who = if mine then Locale.t("Seu") else Locale.t("Selvagem:")
			local text
			if e.effect == "stunned" then
				text = if mine
					then Locale.t("Seu gigante está TONTO e perdeu a vez!")
					else Locale.t("O selvagem está TONTO e perdeu a vez!")
			elseif e.hit then
				text = string.format(
					"%s %s %s! -%d",
					who,
					Locale.t(tostring(e.move)),
					Locale.t("acertou"),
					tonumber(e.dmg) or 0
				)
				local fx = type(e.effect) == "string" and EFFECT_TEXT[e.effect]
				if fx then
					text ..= "  " .. Locale.t(fx)
				end
				UI.sfx(if mine then "Punch" else "Impact", 0.7)
			else
				text = string.format("%s %s %s", who, Locale.t(tostring(e.move)), Locale.t("ERROU!"))
				if e.effect == "guard" then
					text ..= "  " .. Locale.t(EFFECT_TEXT.guard)
				end
				UI.sfx("Whoosh", 0.6)
			end
			say(text, if mine then UI.Colors.Green else UI.Colors.Red)
			hpTexts(tonumber(e.meHp) or 0, tonumber(e.foeHp) or 0)
		elseif e.kind == "End" then
			fighting = false
			setTurn(false)
			hud.Visible = false
			movesBar.Visible = false
			if GiantBattle.OnFight then
				GiantBattle.OnFight(false)
			end
			if e.won then
				result.Text = if (e.coins or 0) > 0
					then string.format(
						"%s +%s %s  +%d XP",
						Locale.t("VITÓRIA!"),
						Util.formatNumber(e.coins),
						Locale.t("moedas"),
						e.xp or 0
					)
					else Locale.t("VITÓRIA! (prêmio do dia já recebido)")
				UI.sfx("Win", 0.9)
				if GiantBattle.OnVictory then
					GiantBattle.OnVictory()
				end
			else
				result.Text = Locale.t("DERROTA... treine e tente de novo!")
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
