--!nonstrict
-- Regressão: dois cozinheiros reais, prazo, teto diário e item protegido.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.SocialFeastRules)
local FoodChoice = require(ReplicatedStorage.Shared.FoodChoice)

return function()
	describe("Banquete em Dupla — regras puras", function()
		it("aceita apenas duas contas distintas e antes de expirar", function()
			expect(Rules.canPair(1, 2, 100, 99)).to.equal(true)
			expect(Rules.canPair(1, 1, 100, 99)).to.equal(false)
			expect(Rules.canPair(1, 2, 100, 100)).to.equal(false)
		end)
		it("prefere comida comum e não oferece mutadas, gigantescas ou raras", function()
			local inv = {
				{ uid = "r", id = "diamonddonut" },
				{ uid = "m", id = "apple", mut = "golden" },
				{ uid = "b", id = "bread", big = true },
				{ uid = "u", id = "burger" },
				{ uid = "a", id = "apple" },
			}
			local i, food = Rules.findFood(inv)
			expect(i).to.equal(5)
			expect(food.uid).to.equal("a")
			expect((Rules.findFood(inv, "r")) == nil).to.equal(true)
			expect((Rules.findFood(inv, "a"))).to.equal(5)
		end)
		it("não encontra inscrição antiga se o item foi consumido", function()
			local idx = Rules.findFood({ { uid = "NEW", id = "apple" } }, "OLD")
			expect(idx).to.equal(nil)
		end)
		it("limita três sucessos por dia, reiniciando apenas após virar o UTC", function()
			local now = 86400 * 5 + 100
			local s = { day = 5, count = 2, total = 12 }
			expect(Rules.available(s, now)).to.equal(true)
			local updated = Rules.completed(s, now)
			expect(updated.count).to.equal(3)
			expect(updated.total).to.equal(13)
			expect(updated.buffUntil).to.equal(now + Rules.BuffSeconds)
			expect(Rules.available(updated, now)).to.equal(false)
			expect(Rules.available(updated, now + 86400)).to.equal(true)
			local nextDay = Rules.completed(updated, now + 86400)
			expect(nextDay.count).to.equal(1)
		end)
		it("inscrição não consume um item nem gera prêmio ao expirar", function()
			local inventory = { { uid = "a", id = "apple" } }
			local idx = Rules.findFood(inventory, "a")
			expect(idx).to.equal(1)
			expect(Rules.canPair(1, 2, 200, 201)).to.equal(false)
			expect(#inventory).to.equal(1)
		end)
	end)
	describe("Preparo da Cozinha Colossal", function()
		it("somente cozinheiro A pode cortar e B pode mexer", function()
			local data = {
				player = { UserId = 42 },
				partner = { UserId = 81 },
				untilTime = 500,
				preparedA = false,
				preparedB = false,
			}
			expect(Rules.canPrepare(data, "A", 42, 100)).to.equal(true)
			expect(Rules.canPrepare(data, "B", 81, 100)).to.equal(true)
			expect(Rules.canPrepare(data, "B", 42, 100)).to.equal(false)
			expect(Rules.canPrepare(data, "A", 81, 100)).to.equal(false)
		end)
		it("não permite repetir estação, nem preparar após tempo acabar", function()
			local data = {
				player = { UserId = 1 },
				partner = { UserId = 2 },
				untilTime = 500,
				preparedA = true,
				preparedB = false,
			}
			expect(Rules.canPrepare(data, "A", 1, 250)).to.equal(false)
			expect(Rules.canPrepare(data, "B", 2, 499)).to.equal(true)
			expect(Rules.canPrepare(data, "B", 2, 500)).to.equal(false)
		end)
	end)

		describe("Alimentação segura", function()
		it("prefere comida comum da mochila e preserva a renda exposta", function()
			local slot, index = FoodChoice.choose({ ["1"] = { id = "apple" } }, {
				{ id = "pizza" },
				{ id = "bread" },
			})
			expect(slot).to.equal(nil)
			expect(index).to.equal(2)
		end)
		it("protege raras, lendárias, mutações e fusões", function()
			local plot = { ["1"] = { id = "goldpizza" }, ["2"] = { id = "apple", mut = "golden" } }
			local slot, index = FoodChoice.choose(plot, { { id = "bread", big = true } })
			expect(slot).to.equal(nil)
			expect(index).to.equal(nil)
		end)
		it("pode escolher comida normal do pátio quando a mochila só tem itens especiais", function()
			local slot, index = FoodChoice.choose({
				["5"] = { id = "pizza" },
				["2"] = { id = "bread" },
			}, { { id = "universelasagna" } })
			expect(slot).to.equal(2)
			expect(index).to.equal(nil)
		end)
	end)
end
