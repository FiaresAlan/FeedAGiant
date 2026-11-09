--!strict
-- Diary.lua — o DIÁRIO (P5 da missão de 08/11/2026): UM painel para tudo que é "volte e faça":
--   1) recompensa diária (a sequência de 7 dias que já existia; o botão continua no mesmo lugar);
--   2) 3 TAREFAS DO DIA (alimentar, sequência, crítica, entregar, batalhar, Dragão, Carne Gigante...)
--      com barra de progresso e RESGATAR; fazer as 3 dá 1 Lunchbox Rara grátis;
--   3) RECORDES pessoais (maior gigante, maior sequência, maior alimentação...).
-- Tudo vem pronto do servidor (DiaryState); aqui só desenha e manda o índice do resgate.
local Config = require(game.ReplicatedStorage.Shared.Config)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local UI = require(script.Parent.Parent.UI)

local Diary = {}

local win: Frame
local body: Frame
local content: Frame
local lastState: { [string]: any }? = nil
Diary.OnClaimable = nil :: ((boolean) -> ())?

local function hms(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h = sec // 3600
	local m = (sec % 3600) // 60
	return if h > 0 then string.format("%dh%02d", h, m) else string.format("%d min", math.max(m, 1))
end

local function section(text: string, order: number)
	UI.label(content, text, {
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Accent,
		ZIndex = 13,
	})
end

local function row(order: number, h: number): Frame
	local r = UI.frame(content, {
		Size = UDim2.new(1, -6, 0, h),
		LayoutOrder = order,
		BackgroundColor3 = UI.Colors.Panel2,
		ZIndex = 13,
	})
	UI.corner(r, 12)
	return r
end

local function render(st: { [string]: any })
	for _, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local anyClaim = false
	-- 1) Recompensa diária
	section(Locale.t("RECOMPENSA DIÁRIA"), 1)
	local d = st.daily or {}
	local streak = tonumber(d.streak) or 0
	local nextDay = math.min(streak + 1, #Config.DailyRewards)
	local dr = row(2, 70)
	UI.label(
		dr,
		string.format(
			"%s %d/%d  ·  +%s",
			Locale.t("Dia"),
			nextDay,
			#Config.DailyRewards,
			Util.formatNumber(Config.DailyRewards[nextDay])
		)
			.. (
				if type(d.backups) == "number"
					then string.format("  ·  %s %d", Locale.t("Proteções"), d.backups)
					else ""
			),
		{
			Size = UDim2.new(1, -200, 1, -10),
			Position = UDim2.fromOffset(12, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 24,
			ZIndex = 14,
		}
	)
	local ready = d.ready == true
	anyClaim = anyClaim or ready
	local db = UI.button(
		dr,
		if ready then Locale.t("RESGATAR") else hms(tonumber(d.nextIn) or 0),
		if ready then UI.Colors.Green else Color3.fromRGB(96, 102, 118),
		{
			Size = UDim2.fromOffset(176, 52),
			Position = UDim2.new(1, -186, 0.5, -26),
			TextScaled = false,
			TextSize = 22,
			ZIndex = 15,
		}
	)
	db.Activated:Connect(function()
		if ready then
			Remotes.RequestClaimDaily:FireServer()
		end
	end)

	-- 2) Tarefas do dia
	section(
		string.format("%s  (%s %s)", Locale.t("TAREFAS DE HOJE"), Locale.t("novas em"), hms(tonumber(st.resetIn) or 0)),
		3
	)
	local allClaimed = true
	for i, o in (st.objectives or {}) :: { any } do
		local r = row(3 + i, 84)
		local text = string.gsub(Locale.t(tostring(o.text)), "{n}", tostring(o.goal))
		UI.label(r, text, {
			Size = UDim2.new(1, -210, 0, 30),
			Position = UDim2.fromOffset(12, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 22,
			ZIndex = 14,
		})
		local _bg, fill = UI.bar(r, UI.Colors.Green, {
			Size = UDim2.new(1, -330, 0, 18),
			Position = UDim2.fromOffset(12, 50),
			ZIndex = 14,
		})
		UI.setBar(fill, (tonumber(o.progress) or 0) / math.max(tonumber(o.goal) or 1, 1), true)
		UI.label(r, string.format("%d/%d", tonumber(o.progress) or 0, tonumber(o.goal) or 1), {
			Size = UDim2.fromOffset(100, 24),
			Position = UDim2.new(1, -310, 0, 47),
			TextScaled = false,
			TextSize = 20,
			ZIndex = 14,
		})
		local reward = "+" .. Util.formatNumber(tonumber(o.coins) or 0)
		if (tonumber(o.xp) or 0) > 0 then
			reward ..= "  +" .. tostring(o.xp) .. " XP"
		end
		local done = (tonumber(o.progress) or 0) >= (tonumber(o.goal) or 1)
		local claimed = o.claimed == true
		allClaimed = allClaimed and claimed
		local canClaim = done and not claimed
		anyClaim = anyClaim or canClaim
		local b = UI.button(
			r,
			if claimed then "✔" elseif canClaim then Locale.t("RESGATAR") else reward,
			if canClaim then UI.Colors.Green elseif claimed then UI.Colors.Blue else Color3.fromRGB(96, 102, 118),
			{
				Size = UDim2.fromOffset(176, 56),
				Position = UDim2.new(1, -186, 0.5, -28),
				TextScaled = false,
				TextSize = if canClaim or claimed then 22 else 17,
				ZIndex = 15,
			}
		)
		local idx = i
		b.Activated:Connect(function()
			if canClaim then
				Remotes.RequestClaimObjective:FireServer(idx)
			end
		end)
	end
	local br = row(7, 64)
	UI.label(br, Locale.t("Complete as 3 tarefas: 1 Lunchbox Rara grátis"), {
		Size = UDim2.new(1, -210, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		ZIndex = 14,
	})
	local bonusReady = allClaimed and st.bonusClaimed ~= true
	anyClaim = anyClaim or bonusReady
	local bb = UI.button(
		br,
		if st.bonusClaimed then "✔" elseif bonusReady then Locale.t("ABRIR") else "🔒",
		if bonusReady then UI.Colors.Orange else Color3.fromRGB(96, 102, 118),
		{
			Size = UDim2.fromOffset(176, 50),
			Position = UDim2.new(1, -186, 0.5, -25),
			TextScaled = false,
			TextSize = 22,
			ZIndex = 15,
		}
	)
	bb.Activated:Connect(function()
		if bonusReady then
			Remotes.RequestClaimObjective:FireServer(0)
		end
	end)

	-- 2b) Missão semanal (Features.WeeklyQuest; o servidor só manda `weekly` com a função ligada)
	local wk = st.weekly
	if type(wk) == "table" then
		section(
			string.format(
				"%s  (%s %s)",
				Locale.t("MISSÃO DA SEMANA"),
				Locale.t("novas em"),
				hms(tonumber(wk.resetIn) or 0)
			),
			10
		)
		local function questText(q: { [string]: any }): string
			return (string.gsub(Locale.t(tostring(q.text)), "{n}", tostring(q.goal)))
		end
		local function rewardText(q: { [string]: any }): string
			local s = "+" .. Util.formatNumber(tonumber(q.coins) or 0)
			if (tonumber(q.xp) or 0) > 0 then
				s ..= "  +" .. tostring(q.xp) .. " XP"
			end
			return s .. "  + Lunchbox Épica"
		end
		local chosen = wk.chosen
		if type(chosen) == "table" then
			-- missão escolhida: progresso, RESGATAR ou TROCAR (1 vez por semana)
			local r = row(11, 96)
			UI.label(r, questText(chosen) .. (if wk.status == "carry" then "  (semana passada)" else ""), {
				Size = UDim2.new(1, -210, 0, 30),
				Position = UDim2.fromOffset(12, 6),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 22,
				ZIndex = 14,
			})
			local goal = math.max(tonumber(chosen.goal) or 1, 1)
			local prog = tonumber(wk.progress) or 0
			local _bg, fill = UI.bar(r, UI.Colors.Orange, {
				Size = UDim2.new(1, -330, 0, 18),
				Position = UDim2.fromOffset(12, 46),
				ZIndex = 14,
			})
			UI.setBar(fill, prog / goal, true)
			UI.label(r, string.format("%d/%d  ·  %s", prog, goal, rewardText(chosen)), {
				Size = UDim2.new(1, -210, 0, 24),
				Position = UDim2.fromOffset(12, 68),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = false,
				TextSize = 17,
				TextTransparency = 0.2,
				ZIndex = 14,
			})
			local canClaim = wk.claimable == true
			anyClaim = anyClaim or canClaim
			local b = UI.button(
				r,
				if wk.claimed then "✔" elseif canClaim then Locale.t("RESGATAR") else Locale.t("EM ANDAMENTO"),
				if canClaim then UI.Colors.Green elseif wk.claimed then UI.Colors.Blue else Color3.fromRGB(96, 102, 118),
				{
					Size = UDim2.fromOffset(176, 56),
					Position = UDim2.new(1, -186, 0.5, -28),
					TextScaled = false,
					TextSize = if canClaim or wk.claimed then 22 else 16,
					ZIndex = 15,
				}
			)
			b.Activated:Connect(function()
				if canClaim then
					Remotes.RequestWeekly:FireServer("claim")
				end
			end)
			-- troca: as outras 2 opções, se ainda não trocou nesta semana
			if wk.status == "current" and not wk.swapped and not wk.claimed then
				for i, q in (wk.options or {}) :: { any } do
					if q.id ~= chosen.id then
						local tr = row(11 + i, 52)
						UI.label(tr, Locale.t("Trocar por:") .. " " .. questText(q), {
							Size = UDim2.new(1, -210, 1, 0),
							Position = UDim2.fromOffset(12, 0),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextScaled = false,
							TextSize = 18,
							TextTransparency = 0.25,
							ZIndex = 14,
						})
						local sb = UI.button(tr, Locale.t("TROCAR"), UI.Colors.Blue, {
							Size = UDim2.fromOffset(176, 44),
							Position = UDim2.new(1, -186, 0.5, -22),
							TextScaled = false,
							TextSize = 18,
							ZIndex = 15,
						})
						local qid = q.id
						sb.Activated:Connect(function()
							Remotes.RequestWeekly:FireServer("swap", qid)
						end)
					end
				end
			end
		else
			-- ainda não escolheu: as 3 opções da semana
			for i, q in (wk.options or {}) :: { any } do
				local r = row(10 + i, 84)
				UI.label(r, questText(q), {
					Size = UDim2.new(1, -210, 0, 30),
					Position = UDim2.fromOffset(12, 6),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = false,
					TextSize = 22,
					ZIndex = 14,
				})
				UI.label(r, rewardText(q), {
					Size = UDim2.new(1, -210, 0, 26),
					Position = UDim2.fromOffset(12, 46),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = false,
					TextSize = 18,
					TextColor3 = UI.Colors.Accent,
					ZIndex = 14,
				})
				local b = UI.button(r, Locale.t("ESCOLHER"), UI.Colors.Orange, {
					Size = UDim2.fromOffset(176, 56),
					Position = UDim2.new(1, -186, 0.5, -28),
					TextScaled = false,
					TextSize = 22,
					ZIndex = 15,
				})
				local qid = q.id
				b.Activated:Connect(function()
					Remotes.RequestWeekly:FireServer("choose", qid)
				end)
			end
		end
	end

	-- 3) Recordes pessoais (salvos para sempre)
	section(Locale.t("RECORDES"), 20)
	local recs = st.records or {}
	for i, r in GameRules.Records do
		local rr = row(20 + i, 44)
		UI.label(rr, Locale.t(r.name), {
			Size = UDim2.new(1, -160, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 20,
			ZIndex = 14,
		})
		UI.label(rr, Util.formatNumber(tonumber(recs[r.id]) or 0), {
			Size = UDim2.fromOffset(140, 44),
			Position = UDim2.new(1, -150, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = UI.Colors.Accent,
			ZIndex = 14,
		})
	end
	if Diary.OnClaimable then
		(Diary.OnClaimable :: (boolean) -> ())(anyClaim)
	end
end

function Diary.open()
	Remotes.RequestDiary:FireServer()
	if not win.Visible then
		UI.pop(win)
	end
	if lastState then
		render(lastState)
	end
end

function Diary.init(gui: ScreenGui)
	win, body = UI.window(gui, "DIÁRIO", UDim2.fromOffset(720, 600))
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 12
	scroll.Parent = body
	content = UI.frame(scroll, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 12,
	})
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = content
	Remotes.DiaryState.OnClientEvent:Connect(function(st)
		if type(st) ~= "table" then
			return
		end
		lastState = st
		render(st)
	end)
	-- Estado inicial para o selo "!" do botão (sem abrir a janela).
	task.delay(4, function()
		Remotes.RequestDiary:FireServer()
	end)
end

return Diary
