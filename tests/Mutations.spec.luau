--!nonstrict
-- Specs das Mutações (noite de 09/11/2026): evento → mutação, sorteio, multiplicadores, nunca troca.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)

return function()
	describe("Mutações", function()
		it("cada evento existente dá a sua mutação; fora de evento, nenhuma", function()
			expect(GameRules.mutationForEvent("GoldenHour")).to.equal("gold")
			expect(GameRules.mutationForEvent("FoodRain")).to.equal("juicy")
			expect(GameRules.mutationForEvent("LuckyBoxes")).to.equal("rainbow")
			expect(GameRules.mutationForEvent(nil)).to.equal(nil)
			expect(GameRules.mutationForEvent("Desconhecido")).to.equal(nil)
		end)
		it("multiplicadores: sem mutação = 1; Arco-íris é a mais forte", function()
			expect(GameRules.mutationIncome(nil)).to.equal(1)
			expect(GameRules.mutationXp(nil)).to.equal(1)
			expect(GameRules.mutationIncome("rainbow") > GameRules.mutationIncome("gold")).to.equal(true)
			expect(GameRules.mutationIncome("lixo")).to.equal(1)
		end)
		it("sorteio: só comida sem mutação muda, e uma Arco-íris nunca vira Dourada", function()
			local plot = { ["1"] = { id = "apple" }, ["2"] = { id = "bread", mut = "rainbow" } }
			local changed = GameLogic.rollMutations(plot, "gold", 1, function()
				return 0
			end)
			expect(#changed).to.equal(1)
			expect(plot["1"].mut).to.equal("gold")
			expect(plot["2"].mut).to.equal("rainbow")
		end)
		it("sorteio respeita a chance", function()
			local plot = { ["1"] = { id = "apple" } }
			local changed = GameLogic.rollMutations(plot, "gold", 0.04, function()
				return 0.5
			end)
			expect(#changed).to.equal(0)
			expect(plot["1"].mut).to.equal(nil)
		end)
		it("simulação: Hora Dourada (6 rodadas) muda ~22% das comidas expostas", function()
			local rng = Random.new(3)
			local mutated, n = 0, 4000
			for _ = 1, n do
				local plot = { ["1"] = { id = "apple" } }
				for _ = 1, 6 do
					GameLogic.rollMutations(plot, "gold", GameRules.Mutations.gold.chance, function()
						return rng:NextNumber()
					end)
				end
				if plot["1"].mut then
					mutated += 1
				end
			end
			expect(mutated / n).to.be.near(1 - (1 - 0.04) ^ 6, 0.03)
		end)
		it("nasce desligada", function()
			expect(Features.flags.Mutations).to.equal(false)
		end)
	end)
end
