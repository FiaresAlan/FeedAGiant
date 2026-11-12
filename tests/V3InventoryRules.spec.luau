--!nonstrict
local Rules = require(game.ReplicatedStorage.Shared.RebuildV2.InventoryRules)

return function()
	describe("V3: alimento identificado pelo UID imutavel", function()
		it("encontra o item certo depois que a mochila troca de ordem", function()
			local inv = { { uid = "a", id = "apple" }, { uid = "b", id = "bread" } }
			expect(Rules.findUid(inv, "b")).to.equal(2)
			table.remove(inv, 1)
			expect(Rules.findUid(inv, "b")).to.equal(1)
		end)
		it("nunca resolve UID de outro inventario nem vazio", function()
			local mine = { { uid = "my-1", id = "apple" } }
			expect(Rules.findUid(mine, "other-1")).to.equal(nil)
			expect(Rules.findUid(mine, "")).to.equal(nil)
			expect(Rules.findUid(mine, string.rep("x", 81))).to.equal(nil)
			expect(Rules.findUid({}, "my-1")).to.equal(nil)
		end)
	end)
end
