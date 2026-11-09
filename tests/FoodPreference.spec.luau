--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Preference = require(ReplicatedStorage.Shared.FoodPreference)
local Choice = require(ReplicatedStorage.Shared.FoodChoice)

return function()
	describe("Personalidade — sabor favorito", function()
		it("mesma espécie no mesmo dia recebe exatamente o mesmo alimento", function()
			local today = 86400 * 200
			expect(Preference.favorite("human", today)).to.equal(Preference.favorite("human", today + 500))
		end)
		it("só usa comidas comuns e incomuns já existentes", function()
			for _, species in { "human", "dragon", "zombie", "phoenix" } do
				for day = 200, 206 do
					local id = Preference.favorite(species, day * 86400)
					local def = Config.FoodById[id]
					expect(def ~= nil).to.equal(true)
					expect(Config.Rarities[def.rarity].order <= 2).to.equal(true)
				end
			end
		end)
		it("preferência muda no dia seguinte sem remover nenhum item", function()
			local a = Preference.favorite("human", 100 * 86400)
			local b = Preference.favorite("human", 101 * 86400)
			expect(a == b).to.equal(false)
		end)
		it("aplica bônus somente no alimento preferido", function()
			local t = 105 * 86400
			local fav = Preference.favorite("human", t)
			expect(Preference.multiplier("human", fav, t)).to.equal(1.2)
			for _, id in Preference.Pool do
				if id ~= fav then
					expect(Preference.multiplier("human", id, t)).to.equal(1)
				end
			end
		end)
		it("alimentação rápida escolhe favorito normal, mas nunca versão mutada", function()
			local t = 110 * 86400
			local fav = Preference.favorite("human", t)
			local slot, idx = Choice.choose({}, {
				{ id = "apple", mut = "golden" },
				{ id = "bread" },
				{ id = fav },
			}, fav)
			expect(slot).to.equal(nil)
			expect(idx).to.equal(3)
		end)
	end)
end
