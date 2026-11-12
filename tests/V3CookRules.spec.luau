--!nonstrict
-- Regras de panelas V3: testes puros sem DataStore e sem Roblox Studio Play.
local Rules = require(game:GetService("ReplicatedStorage").Shared.RebuildV2.CookRules)

return function()
	describe("V3: duas panelas e protecao de ingredientes", function()
		it("a mesma instancia nao paga dois ingredientes iguais", function()
			local one = { { id = "apple", uid = "1" } }
			expect(Rules.selectIndices(one, { "apple", "apple" })).to.equal(nil)
			local two = { { id = "apple", uid = "1" }, { id = "apple", uid = "2" } }
			local picks = Rules.selectIndices(two, { "apple", "apple" })
			expect(#picks).to.equal(2)
			expect(picks[1]).to.equal(2)
			expect(picks[2]).to.equal(1)
		end)
		it("receita invalida nao seleciona nem modifica o inventario", function()
			local inv = { { id = "bread", uid = "1" }, { id = "honey", uid = "2" } }
			expect(Rules.selectIndices(inv, { "bread", "cheese" })).to.equal(nil)
			expect(#inv).to.equal(2)
			expect(inv[1].uid).to.equal("1")
		end)
		it("dois slots possuem contagem offline independente", function()
			local slots = {
				{ state = "cooking", jobId = "A", endsAtUtc = 1012 },
				{ state = "cooking", jobId = "B", endsAtUtc = 2800 },
			}
			expect(Rules.isReady(slots[1], 1011)).to.equal(false)
			expect(Rules.isReady(slots[1], 1012)).to.equal(true)
			expect(Rules.isReady(slots[2], 1012)).to.equal(false)
			expect(Rules.isReady(slots[2], 2800)).to.equal(true)
			expect(Rules.canClaim(slots[1], "A", 1012)).to.equal(true)
			expect(Rules.canClaim(slots[2], "A", 2800)).to.equal(false)
		end)
		it("replay de claim falha depois que o slot fica vazio", function()
			local slot = { state = "cooking", jobId = "valid", endsAtUtc = 100 }
			expect(Rules.canClaim(slot, "valid", 101)).to.equal(true)
			slot.state = "empty"
			slot.jobId = nil
			for _ = 1, 100 do
				expect(Rules.canClaim(slot, "valid", 101)).to.equal(false)
			end
		end)
		it("mochila cheia preserva a panela pronta", function()
			local slot = { state = "ready", jobId = "valid" }
			expect(Rules.canClaim(slot, "valid", 150)).to.equal(true)
			expect(Rules.hasSpace(300, 300)).to.equal(false)
			expect(Rules.hasSpace(299, 300)).to.equal(true)
			expect(slot.state).to.equal("ready")
		end)
		it("timestamps invalidos nao antecipam recompensa", function()
			local slot = { state = "cooking", jobId = "valid", endsAtUtc = 0 / 0 }
			expect(Rules.isReady(slot, 9999999)).to.equal(false)
			slot.endsAtUtc = "already"
			expect(Rules.isReady(slot, 9999999)).to.equal(false)
		end)
	end)
end
