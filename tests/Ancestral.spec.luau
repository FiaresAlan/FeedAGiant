--!nonstrict
-- Specs do Gigante Ancestral (noite de 09/11/2026): meta coletiva e pontos por raridade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)

return function()
	describe("Gigante Ancestral", function()
		it("a meta cresce com os jogadores (1 = 100, 8 = 380)", function()
			expect(GameLogic.ancestralGoal(1)).to.equal(100)
			expect(GameLogic.ancestralGoal(8)).to.equal(380)
			expect(GameLogic.ancestralGoal(0)).to.equal(100)
		end)
		it("comida mais rara vale mais pontos", function()
			expect(GameLogic.ancestralPoints("Common")).to.equal(1)
			expect(GameLogic.ancestralPoints("Mythic") > GameLogic.ancestralPoints("Epic")).to.equal(true)
			expect(GameLogic.ancestralPoints(nil)).to.equal(1)
		end)
		it("o bônus é de +25% de XP por 5 minutos e o interruptor existe", function()
			expect(GameRules.Ancestral.XpBuff).to.equal(1.25)
			expect(GameRules.Ancestral.BuffSeconds).to.equal(300)
			expect(type(Features.flags.Ancestral)).to.equal("boolean")
		end)
	end)
end
