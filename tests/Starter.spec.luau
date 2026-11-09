--!nonstrict
-- Specs das 3 espécies iniciais (prompt v4 §1, 09/11/2026): pool fechado, fora da loja/ovos/sorteios,
-- só 3 ids, oferta 1 vez, atributos parecidos com o Humano. Mesmo código do jogo.
-- Rodar: require(game.ServerScriptService.FwjelaaTests.Runner)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local StarterSpecies = require(ReplicatedStorage.Shared.StarterSpecies)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)

return function()
	describe("Espécies iniciais: pool fechado", function()
		it("são exatamente fire_starter, ice_starter e stone_starter", function()
			expect(#StarterSpecies.Ids).to.equal(3)
			for _, id in { "fire_starter", "ice_starter", "stone_starter" } do
				expect(StarterSpecies.isStarter(id)).to.equal(true)
			end
			expect(StarterSpecies.isStarter("human")).to.equal(false)
			expect(StarterSpecies.isStarter("dragon")).to.equal(false)
			expect(StarterSpecies.isStarter(nil)).to.equal(false)
			expect(StarterSpecies.isStarter(5)).to.equal(false)
		end)
		it("nunca estão na lista da loja (Config.Species), mas o jogo as reconhece pelo índice", function()
			for _, sp in Config.Species do
				expect(StarterSpecies.isStarter(sp.id)).to.equal(false)
			end
			for _, id in StarterSpecies.Ids do
				expect(Config.SpeciesById[id]).to.be.ok()
			end
		end)
		it("nunca saem de ovo", function()
			for _, size in GameRules.Eggs.Order do
				for id in GameRules.Eggs.Sizes[size].weights do
					expect(StarterSpecies.isStarter(id)).to.equal(false)
				end
			end
		end)
		it("usam a malha do Humano (variação de cor) e têm tinta e aura", function()
			for _, sp in StarterSpecies.List do
				expect(CreatureModels.BySpecies[sp.id].file).to.equal(CreatureModels.BySpecies.human.file)
				expect(typeof(sp.tint)).to.equal("Color3")
				expect(type(sp.aura)).to.equal("string")
			end
		end)
		it("atributos iguais aos do Humano, com no máximo 1 bônus pequeno", function()
			local h = Config.SpeciesById.human
			for _, sp in StarterSpecies.List do
				local diffs = 0
				for _, k in { "xpMult", "coinMult", "hungerDecayMult", "arenaPower", "arenaHp" } do
					if sp[k] ~= h[k] then
						diffs += 1
						expect(math.abs(sp[k] - h[k]) / h[k] <= 0.1 + 1e-9).to.equal(true)
					end
				end
				expect(diffs <= 1).to.equal(true)
				expect(sp.robux).to.equal(false)
				expect(sp.decayImmune).to.equal(false)
			end
		end)
		it("o interruptor existe (o dono decide em Features.lua)", function()
			expect(type(Features.flags.StarterSpecies)).to.equal("boolean")
		end)
	end)

	describe("Espécies iniciais: oferta e escolha", function()
		it("oferece só para conta nova ou já ofertada", function()
			expect(GameLogic.starterShouldOffer("", 0, 0)).to.equal(true)
			expect(GameLogic.starterShouldOffer("?", 50, 9)).to.equal(true)
			expect(GameLogic.starterShouldOffer("", 1, 0)).to.equal(false)
			expect(GameLogic.starterShouldOffer("", 0, 1)).to.equal(false)
			expect(GameLogic.starterShouldOffer("fire_starter", 0, 0)).to.equal(false)
		end)
		it("só pode escolher quem está com a oferta aberta, e só uma vez", function()
			expect(GameLogic.starterEligible("?")).to.equal(true)
			expect(GameLogic.starterEligible("")).to.equal(false)
			expect(GameLogic.starterEligible("ice_starter")).to.equal(false)
		end)
	end)
end
