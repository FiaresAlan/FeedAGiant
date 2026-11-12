--!nonstrict
local Guide = require(game.ReplicatedStorage.Shared.RebuildV2.GuideRules)

return function()
	describe("V3: onboarding adaptativo sem bloqueio", function()
		it("mostra um unico proximo objetivo", function()
			local seen = {}
			local id, message, index = Guide.next(seen)
			expect(id).to.equal("first_feed")
			expect(index).to.equal(1)
			expect(type(message)).to.equal("string")
		end)
		it("cada etapa avanca uma vez, sem recompensar repeticao", function()
			local seen = {}
			for i, entry in Guide.Steps do
				expect(Guide.mark(seen, entry.id)).to.equal(true)
				expect(Guide.mark(seen, entry.id)).to.equal(false)
				local id, _, index = Guide.next(seen)
				expect(index).to.equal(i + 1)
				if i < #Guide.Steps then
					expect(id).to.equal(Guide.Steps[i + 1].id)
				else
					expect(id).to.equal(nil)
				end
			end
		end)
		it("eventos fora de ordem podem ser lembrados sem concluir os anteriores", function()
			local seen = {}
			expect(Guide.mark(seen, "first_delivery")).to.equal(true)
			expect(Guide.next(seen)).to.equal("first_feed")
			expect(Guide.mark(seen, "first_feed")).to.equal(true)
			expect(Guide.next(seen)).to.equal("first_mount")
		end)
		it("chave inventada nao altera progresso", function()
			local seen = {}
			expect(Guide.mark(seen, "give_999999_xp")).to.equal(false)
			expect(next(seen)).to.equal(nil)
		end)
	end)
end
