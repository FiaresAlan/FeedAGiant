--!strict
-- Arena.lua — janela "GIANT CLASH": lista jogadores para desafiar, popup de desafio recebido, overlay da luta com barras de HP.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.Parent.UI)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local State = require(script.Parent.Parent.State)

local Arena = {}
local Effects = require(script.Parent.Effects)
local player = Players.LocalPlayer
local win: Frame
local listFrame: Frame
local challengePopup: Frame
local challengeText: TextLabel
local fight: Frame
local timerLabel: TextLabel
local countdownLabel: TextLabel
local realFight = false
-- Luta mostrada agora (revisão: Tick/End de outra luta e o "esconder" atrasado atrapalhavam a
-- luta seguinte do campeonato).
local fightSerial = 0
local curA, curB = 0, 0
local nameA: TextLabel
local nameB: TextLabel
local hpA: Frame
local hpB: Frame
local fightTitle: TextLabel
local pendingFrom = 0
Arena.playSound = nil :: ((string, number?) -> ())?
Arena.OnOpenGiantBattle = nil :: (() -> ())?
Arena.shake = nil :: ((number, number) -> ())?

local function sfx(k: string, v: number?)
	if Arena.playSound then
		Arena.playSound(k, v)
	end
end

local function rebuildList()
	for _, c in listFrame:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local n = 0
	for _, p in Players:GetPlayers() do
		if p == player then
			continue
		end
		n += 1
		local row = UI.frame(listFrame, { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = UI.Colors.Panel })
		UI.label(row, p.DisplayName, {
			Size = UDim2.new(1, -170, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local b = UI.button(
			row,
			"DESAFIAR ⚔",
			UI.Colors.Red,
			{ Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -158, 0.5, -20) }
		)
		b.Activated:Connect(function()
			Remotes.RequestDuel:FireServer(p.UserId)
		end)
	end
	if n == 0 then
		UI.label(
			listFrame,
			"Nenhum oponente no servidor. Convide amigos!",
			{ Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.Accent }
		)
	end
end

local function statsText(s: State.PlayerState): string
	local a = s :: any
	local cd = math.max(
		0,
		(a.lastDuel or 0)
			+ (if s.passes.ArenaVIP then Config.Arena.DuelCooldown / 2 else Config.Arena.DuelCooldown)
			- os.time()
	)
	return Locale.fmt("arena_stats", nil, {
		w = a.arenaWins or 0,
		l = a.arenaLosses or 0,
		s = if cd > 0 then Locale.fmt("cooldown_s", nil, { n = cd }) else "Pronto para lutar!",
	})
end

local function buildWindow(gui: ScreenGui)
	local body: Frame
	win, body = UI.window(gui, "GIANT CLASH — COLISEU", UDim2.fromOffset(620, 540))
	local stats = UI.label(body, "", { Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.Colors.Accent })
	-- Dois modos no mesmo coliseu (item 9): boxe entre jogadores (aqui embaixo) e a batalha de gigantes.
	local giantBtn = UI.button(body, "BATALHA DE GIGANTES  (seu gigante luta!)", UI.Colors.Green, {
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 32),
		TextScaled = false,
		TextSize = 24,
	})
	giantBtn.Activated:Connect(function()
		win.Visible = false
		if Arena.OnOpenGiantBattle then
			Arena.OnOpenGiantBattle()
		end
	end)
	UI.label(body, "BOXE: JOGADOR x JOGADOR", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 100),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Red,
	})
	UI.label(
		body,
		"Vencedor rouba as 2 comidas mais raras do PÁTIO do perdedor + 5% das moedas. Luta justa: mesma vida e força para os dois.",
		{
			Size = UDim2.new(1, 0, 0, 52),
			Position = UDim2.fromOffset(0, 130),
			TextScaled = false,
			TextSize = 20,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.2,
		}
	)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -190)
	scroll.Position = UDim2.fromOffset(0, 188)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body
	listFrame = UI.frame(
		scroll,
		{ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }
	)
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 6)
	lay.Parent = listFrame
	State.onChanged(function(s)
		stats.Text = statsText(s)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if win.Visible then
				stats.Text = statsText(State.current)
			end
		end
	end)
end

local function buildPopup(gui: ScreenGui)
	challengePopup = UI.panel(gui, {
		Size = UDim2.fromOffset(420, 150),
		Position = UDim2.fromScale(0.5, 0.25),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Colors.Bg,
		Visible = false,
	})
	UI.stroke(challengePopup, UI.Colors.Red, 3)
	challengeText = UI.label(
		challengePopup,
		"",
		{ Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 8), TextWrapped = true }
	)
	local acc = UI.button(
		challengePopup,
		"ACEITAR ⚔",
		UI.Colors.Green,
		{ Size = UDim2.fromOffset(180, 48), Position = UDim2.fromOffset(20, 90) }
	)
	local dec = UI.button(
		challengePopup,
		"RECUSAR",
		Color3.fromRGB(110, 110, 130),
		{ Size = UDim2.fromOffset(180, 48), Position = UDim2.fromOffset(220, 90) }
	)
	acc.Activated:Connect(function()
		Remotes.RequestDuelAnswer:FireServer(pendingFrom, true)
		challengePopup.Visible = false
	end)
	dec.Activated:Connect(function()
		Remotes.RequestDuelAnswer:FireServer(pendingFrom, false)
		challengePopup.Visible = false
	end)
end

local function buildFight(gui: ScreenGui)
	-- Fase 3: abaixo do painel do topo da HUD (que ocupa ~0..160 no desenho 1080p) e na mesma escala.
	fight = UI.panel(gui, {
		Name = "FightOverlay",
		Size = UDim2.fromOffset(620, 110),
		Position = UDim2.new(0.5, 0, 0, 104),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UI.Colors.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	UI.autoScale(fight)
	UI.stroke(fight, UI.Colors.Accent, 3)
	timerLabel = UI.label(fight, "", {
		Size = UDim2.fromOffset(80, 26),
		Position = UDim2.new(0.5, -40, 1, -28),
		TextColor3 = UI.Colors.Text,
		TextScaled = false,
		TextSize = 22,
	})
	countdownLabel = UI.title(gui, "", {
		Size = UDim2.fromOffset(520, 130),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 40,
	})
	fightTitle = UI.title(
		fight,
		"⚔ GIANT CLASH ⚔",
		{ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 4), TextColor3 = UI.Colors.Accent }
	)
	nameA = UI.label(fight, "", {
		Size = UDim2.fromOffset(280, 24),
		Position = UDim2.fromOffset(12, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	nameB = UI.label(fight, "", {
		Size = UDim2.fromOffset(280, 24),
		Position = UDim2.new(1, -292, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local bgA = UI.frame(fight, {
		Size = UDim2.fromOffset(280, 22),
		Position = UDim2.fromOffset(12, 68),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	})
	UI.corner(bgA, 11)
	hpA = UI.frame(bgA, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Colors.Green })
	UI.corner(hpA, 11)
	local bgB = UI.frame(fight, {
		Size = UDim2.fromOffset(280, 22),
		Position = UDim2.new(1, -292, 0, 68),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
	})
	UI.corner(bgB, 11)
	hpB = UI.frame(bgB, {
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundColor3 = UI.Colors.Red,
	})
	UI.corner(hpB, 11)
	UI.label(
		fight,
		"VS",
		{ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, -20, 0, 50), TextColor3 = UI.Colors.Accent }
	)
end

function Arena.open()
	rebuildList()
	UI.pop(win)
end

function Arena.init(gui: ScreenGui)
	buildWindow(gui)
	buildPopup(gui)
	buildFight(gui)
	Players.PlayerAdded:Connect(function()
		if win.Visible then
			rebuildList()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if win.Visible then
			rebuildList()
		end
	end)

	Remotes.ArenaState.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Challenge" then
			pendingFrom = e.from
			challengeText.Text = Locale.fmt("challenge_popup", nil, { p = e.fromName, n = math.floor(e.power) })
			UI.pop(challengePopup)
			sfx("Bell", 0.8)
			task.delay(20, function()
				if pendingFrom == e.from then
					challengePopup.Visible = false
				end
			end)
		elseif e.kind == "Sent" then
			win.Visible = false
		elseif e.kind == "Start" then
			local involved = e.a == player.UserId or e.b == player.UserId
			fight.Visible = true
			fightTitle.Text = Locale.fmt("fight_title", nil, {
				t = if e.tournament then "🏆 " .. Locale.t("CAMPEONATO") .. ": " else "⚔ GIANT CLASH: ",
				a = e.aName,
				b = e.bName,
			})
			nameA.Text = string.format("%s  (⚡%d)", e.aName, e.powerA)
			nameB.Text = string.format("(⚡%d)  %s", e.powerB, e.bName)
			hpA.Size = UDim2.fromScale(1, 1)
			hpB.Size = UDim2.fromScale(1, 1)
			fightSerial += 1
			curA, curB = e.a, e.b
			realFight = e.real == true
			timerLabel.Text = if realFight then tostring(e.seconds or "") else ""
			sfx("Bell", if involved then 1 else 0.5)
			if involved then
				win.Visible = false
			end
			if realFight and involved then
				-- Contagem regressiva (o servidor segura os lutadores parados nesse tempo)
				local n = math.max(1, math.floor(tonumber(e.countdown) or 3))
				task.spawn(function()
					countdownLabel.Visible = true
					for i = n, 1, -1 do
						countdownLabel.Text = tostring(i)
						UI.pop(countdownLabel)
						task.wait(1)
					end
					countdownLabel.Text = Locale.t("LUTEM!")
					UI.pop(countdownLabel)
					UI.sfx("VO_Fight", 1)
					task.wait(0.8)
					countdownLabel.Visible = false
				end)
			else
				UI.sfx("VO_Fight", if involved then 1 else 0.6)
			end
		elseif e.kind == "Tick" then
			if e.a ~= curA or e.b ~= curB then
				return
			end
			TweenService:Create(hpA, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(e.hpA / 100, 0, 1), 1) })
				:Play()
			TweenService:Create(hpB, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(e.hpB / 100, 0, 1), 1) })
				:Play()
			if type(e.left) == "number" then
				timerLabel.Text = tostring(e.left)
			end
			if not realFight then
				-- luta encenada antiga: sons e tremor simulados (na real, os socos já têm som próprio)
				sfx(if math.random() < 0.3 then "Heavy" else "Punch", 0.4)
				if (e.a == player.UserId or e.b == player.UserId) and Arena.shake then
					Arena.shake(0.6, 0.2)
				end
			end
		elseif e.kind == "End" then
			if e.a ~= curA or e.b ~= curB then
				return
			end
			local serial = fightSerial
			if e.aborted and (e.winner == 0 or e.winner == nil) then
				fightTitle.Text = Locale.t("Luta cancelada.")
				timerLabel.Text = ""
				task.delay(3, function()
					if fightSerial == serial then
						fight.Visible = false
					end
				end)
				return
			end
			if e.winner == player.UserId then
				fightTitle.Text = Locale.fmt("fight_won", nil, {
					x = if e.stolen and #e.stolen > 0
						then Locale.fmt("fight_stole", nil, { s = table.concat(e.stolen, ", ") })
						else "",
				})
				sfx("Win", 1)
				Effects.confetti(80)
				Effects.flash(UI.Colors.Accent, 0.4)
			elseif e.a == player.UserId or e.b == player.UserId then
				fightTitle.Text = Locale.fmt("fight_lost", nil, { p = e.winnerName or "" })
				sfx("KO", 0.9)
			else
				fightTitle.Text = Locale.fmt("fight_other", nil, { p = e.winnerName or "?" })
			end
			local why = if e.reason == "ko"
				then Locale.t("por NOCAUTE!")
				elseif e.reason == "ring" then Locale.t("fora do RINGUE!")
				elseif e.reason == "time" then Locale.t("no TEMPO!")
				else ""
			if why ~= "" then
				timerLabel.Text = ""
				fightTitle.Text ..= "  " .. why
			end
			task.delay(4, function()
				if fightSerial == serial then
					fight.Visible = false
				end
			end)
		elseif e.kind == "Tournament" then
			sfx("Bell", 1)
		elseif e.kind == "Champion" then
			UI.sfx("VO_Champion", 1)
			Effects.confetti(120)
		end
	end)
end

return Arena
