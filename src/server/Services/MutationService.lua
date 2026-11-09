--!strict
-- MutationService — Mutações na comida do pátio (noite de 09/11/2026; Features.Mutations).
-- Ideia de "clima + mutação" dos simuladores de jardim, adaptada ao Feed a Giant: durante os eventos que
-- JÁ existem (EventService), a cada GameRules.MutationTick segundos cada comida EXPOSTA no pátio, ainda
-- sem mutação, tem uma chance de ganhar a mutação do evento:
--   Hora Dourada → Dourada · Chuva de Comida → Suculenta · Lucky Boxes → Arco-íris (rara)
-- A mutação é permanente na comida (mochila, pátio, roubo) e multiplica a renda no pátio e o XP ao
-- alimentar (PlotService). Nada pago: não sai de caixa, a tabela de chances paga não muda.
local Players = game:GetService("Players")

local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local GameLogic = require(script.Parent.Parent.GameLogic)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local EventService = require(script.Parent.EventService)

local MutationService = {}

local rng = Random.new()

-- Uma rodada para todos os jogadores (exposta para o teste no Studio).
function MutationService.tick(eventId: string?): number
	local mutId = GameRules.mutationForEvent(eventId)
	if not mutId then
		return 0
	end
	local m = GameRules.Mutations[mutId]
	local total = 0
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			local changed = GameLogic.rollMutations(profile.plot :: any, mutId, m.chance, function()
				return rng:NextNumber()
			end)
			if #changed > 0 then
				total += #changed
				DataService.markDirty(player)
				PlotService.rebuildPlot(player)
				PlotService.pushState(player)
				local first = profile.plot[changed[1]]
				local def = first and Config.FoodById[first.id]
				Remotes.Notify:FireClient(player, {
					text = string.format(
						"MUTAÇÃO! %s%s ficou %s no seu pátio (renda x%s, XP x%s).",
						if def then def.name else "Sua comida",
						if #changed > 1 then string.format(" e mais %d", #changed - 1) else "",
						string.upper(m.name),
						tostring(m.income),
						tostring(m.xp)
					),
					color = m.color,
				})
				Analytics.event(player, "food_mutated", #changed, { mutId })
			end
		end
	end
	return total
end

function MutationService.init()
	task.spawn(function()
		while true do
			task.wait(GameRules.MutationTick)
			if Features.on("Mutations") then
				local ok, err = pcall(MutationService.tick, EventService.activeId())
				if not ok then
					warn("[MutationService]", err)
				end
			end
		end
	end)
end

return MutationService
