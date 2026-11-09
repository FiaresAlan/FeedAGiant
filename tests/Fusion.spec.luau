--!nonstrict
-- Specs da Fusão (noite de 09/11/2026): 3 iguais → 1 Gigantesca, determinística.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)

return function()
	describe("Fusão", function()
		it("precisa de 3 iguais e ignora as já fundidas", function()
			local inv = { { id = "apple" }, { id = "apple", big = true }, { id = "apple" }, { id = "bread" } }
			expect(GameLogic.fusionPick(inv, "apple")).to.equal(nil)
			table.insert(inv, { id = "apple" })
			local picks = GameLogic.fusionPick(inv, "apple")
			expect(#picks).to.equal(3)
			for _, i in picks do
				expect(inv[i].big).to.equal(nil)
			end
		end)
		it("gasta primeiro as SEM mutação (guarda as mutadas)", function()
			local inv = {
				{ id = "apple" },
				{ id = "apple" },
				{ id = "apple", mut = "gold" },
				{ id = "apple" },
				{ id = "apple", mut = "rainbow" },
			}
			local picks = GameLogic.fusionPick(inv, "apple")
			expect(GameLogic.fusionMutation(inv, picks)).to.equal(nil)
			-- com só 3 (uma Dourada), a Gigantesca herda a Dourada
			local inv2 = { { id = "apple" }, { id = "apple", mut = "gold" }, { id = "apple" } }
			expect(GameLogic.fusionMutation(inv2, GameLogic.fusionPick(inv2, "apple"))).to.equal("gold")
		end)
		it("renda no pátio: mutação x fusão (Gigantesca Dourada = 1,5 x 3,2)", function()
			expect(GameLogic.foodIncomeMult({ big = true, mut = "gold" })).to.be.near(1.5 * 3.2, 1e-9)
			expect(GameLogic.foodIncomeMult({})).to.equal(1)
		end)
		it("a Gigantesca vale x3,2 (um pouco mais que as 3 juntas)", function()
			expect(GameLogic.fusionMult({ big = true })).to.equal(GameRules.Fusion.Mult)
			expect(GameLogic.fusionMult({})).to.equal(1)
			expect(GameRules.Fusion.Mult > GameRules.Fusion.Count).to.equal(true)
		end)
		it("o interruptor existe (o dono decide em Features.lua)", function()
			expect(type(Features.flags.Fusion)).to.equal("boolean")
		end)
	end)
end
