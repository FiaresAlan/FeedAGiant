--!strict
-- WelcomeService — "Bem-vindo de volta" (noite de 09/11/2026; Features.WelcomeBack).
-- Quem volta depois de um tempo fora vê UM resumo do que aconteceu e do que está pronto, com 1 botão
-- por coisa (vault "Retention and Return Hooks": pelo menos uma coisa pronta a cada entrada, nunca mais de
-- um pop-up automático por vez). Só leitura do perfil: não dá nada novo, só mostra.
local Players = game:GetService("Players")

local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Analytics = require(script.Parent.Parent.Analytics)
local GameLogic = require(script.Parent.Parent.GameLogic)
local Hooks = require(script.Parent.Parent.Hooks)
local DataService = require(script.Parent.DataService)

local WelcomeService = {}

WelcomeService.MinAway = 600 -- só para quem ficou fora pelo menos 10 min

local offlineGain: { [Player]: number } = {}
local awayOf: { [Player]: number } = {}

-- Monta as linhas (puro sobre o perfil; exposto para o teste no Studio).
function WelcomeService.summary(profile: any, away: number, gain: number, now: number): { { [string]: any } }
	local lines = {}
	if gain > 0 then
		table.insert(lines, {
			id = "offline",
			text = string.format(
				"Seus gigantes expostos renderam %s moedas enquanto você estava fora.",
				Util.formatNumber(gain)
			),
		})
	end
	if now - profile.lastDaily >= 20 * 3600 then
		table.insert(lines, { id = "daily", text = "O prêmio diário está pronto.", action = "diary" })
	end
	if Features.on("WeeklyQuest") and profile.weeklyQuest and GameLogic.weeklyClaimable(profile.weeklyQuest) then
		table.insert(lines, { id = "weekly", text = "Sua missão semanal está completa: resgate!", action = "diary" })
	end
	if Features.on("EggSystem") then
		local ready = 0
		for _, slot in profile.nest or {} do
			if now >= slot.hatchAt then
				ready += 1
			end
		end
		if ready > 0 then
			table.insert(lines, {
				id = "eggs",
				text = string.format("%d ovo(s) prontos para chocar no NINHO.", ready),
				action = "nest",
			})
		elseif #(profile.eggs or {}) > 0 then
			table.insert(lines, {
				id = "eggs_stored",
				text = string.format("Você tem %d ovo(s) guardados: leve ao NINHO.", #profile.eggs),
				action = "nest",
			})
		end
	end
	local boxes = #(profile.pendingBoxes or {})
	if boxes > 0 then
		table.insert(lines, {
			id = "boxes",
			text = string.format("%d Lunchbox(es) guardadas esperando para abrir.", boxes),
		})
	end
	if (profile.hunger or 100) < 30 then
		table.insert(
			lines,
			{ id = "hungry", text = "Seu gigante está com fome: alimente para voltar à renda cheia." }
		)
	end
	local _ = away -- reservado (texto "fora há X dias" fica no cliente)
	return lines
end

-- Chamado pelo Main logo no começo da entrada (antes de qualquer coisa mudar o lastSeen).
function WelcomeService.onJoin(player: Player)
	if not Features.on("WelcomeBack") then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	awayOf[player] = os.time() - profile.lastSeen
	-- espera a renda offline ser paga (RosterService) e a tela carregar
	task.delay(6, function()
		local p = DataService.get(player)
		local away = awayOf[player] or 0
		if not p or not player.Parent or away < WelcomeService.MinAway then
			return
		end
		-- conta nova (primeira entrada) não recebe: ela tem o primeiro acesso
		if p.starterSpecies == "?" or (p.totalFeeds == 0 and p.totalBoxes == 0) then
			return
		end
		local lines = WelcomeService.summary(p, away, offlineGain[player] or 0, os.time())
		if #lines == 0 then
			return
		end
		Remotes.WelcomeBack:FireClient(player, { away = away, lines = lines })
		Analytics.event(player, "welcome_back_shown", #lines, { tostring(math.min(7, away // 86400)) })
	end)
end

function WelcomeService.init()
	Hooks.on("offlineIncome", function(player: Player, gain: number)
		offlineGain[player] = gain
	end)
	Players.PlayerRemoving:Connect(function(p)
		offlineGain[p] = nil
		awayOf[p] = nil
	end)
end

return WelcomeService
