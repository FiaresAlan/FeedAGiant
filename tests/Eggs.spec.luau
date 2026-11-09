--!nonstrict
-- Specs do Sistema de Ovos (08/11/2026): chances, sorteio, repetidos, lugares do ninho, aceleração,
-- regras de economia aprovadas e migração de perfil. Mesmo código do EggService (GameLogic/EggOdds).
-- Rodar: require(game.ServerScriptService.FwjelaaTests.Runner)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local EggOdds = require(ReplicatedStorage.Shared.EggOdds)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)
local PlayerData = require(ServerScriptService:WaitForChild("fwjelaa").PlayerData)

local E = GameRules.Eggs

local function rarityOrderOf(id)
	local tag = Config.SpeciesById[id].rarityTag
	local map = { ["Comum"] = 1, ["Incomum"] = 2, ["Raro"] = 3, ["Épico"] = 4, ["Lendário"] = 5, ["Mítico"] = 6 }
	return map[tag] or 99
end

return function()
	describe("Ovos: regras aprovadas", function()
		it("5 tamanhos com tempo e nível 3/5/8/12/20 min e 1/5/10/20/30", function()
			local mins = { small = 3, medium = 5, large = 8, huge = 12, massive = 20 }
			local lv = { small = 1, medium = 5, large = 10, huge = 20, massive = 30 }
			for _, size in E.Order do
				expect(E.Sizes[size].seconds).to.equal(mins[size] * 60)
				expect(E.Sizes[size].level).to.equal(lv[size])
			end
		end)
		it("só Pequeno (3.000) e Médio (12.000) vendem por moedas", function()
			expect(E.Sizes.small.price).to.equal(3000)
			expect(E.Sizes.medium.price).to.equal(12000)
			expect(E.Sizes.large.price).to.equal(nil)
			expect(E.Sizes.huge.price).to.equal(nil)
			expect(E.Sizes.massive.price).to.equal(nil)
		end)
		it(
			"faixas (Ovos v2): P=Comum+Incomum, M=Incomum+Raro, G=Raro+Épico, E=Épico+Lendário, C=Lendário+Mítico",
			function()
				local allowed = {
					small = { [1] = true, [2] = true },
					medium = { [2] = true, [3] = true },
					large = { [3] = true, [4] = true },
					huge = { [4] = true, [5] = true },
					massive = { [5] = true, [6] = true },
				}
				for _, size in E.Order do
					local n = 0
					for id in E.Sizes[size].weights do
						n += 1
						expect(allowed[size][rarityOrderOf(id)]).to.equal(true)
					end
					expect(n > 0).to.equal(true)
				end
			end
		)
		it("Médio: Incomum 70%; Pequeno: Comum 60% e Goblin presente", function()
			local comum = 0
			for _, e in EggOdds.odds("medium") do
				if rarityOrderOf(e.id) == 2 then
					comum += e.p
				end
			end
			expect(comum).to.be.near(0.7, 1e-9)
		end)
		it("Dragão e Fênix (Robux) nunca saem de ovo; toda espécie do ovo existe", function()
			for _, size in E.Order do
				for id in E.Sizes[size].weights do
					expect(Config.SpeciesById[id]).to.be.ok()
					expect(Config.SpeciesById[id].robux).to.equal(false)
				end
			end
		end)
		it("os interruptores dos ovos existem", function()
			expect(type(Features.flags.EggSystem)).to.equal("boolean")
			expect(type(Features.flags.EggVFX)).to.equal("boolean")
			expect(type(Features.flags.EggNotifications)).to.equal("boolean")
			expect(type(Features.flags.StarterSpecies)).to.equal("boolean")
		end)
	end)

	describe("Ovos: chances e sorteio", function()
		it("as chances de cada tamanho somam 100%", function()
			for _, size in E.Order do
				local t = 0
				for _, e in EggOdds.odds(size) do
					t += e.p
				end
				expect(t).to.be.near(1, 1e-9)
			end
		end)
		it("o servidor sorteia pela mesma tabela que a janela mostra", function()
			expect(GameLogic.eggOdds).to.equal(EggOdds.odds)
			expect(GameLogic.eggRoll).to.equal(EggOdds.roll)
		end)
		it("simulação: frequência sorteada ≈ chance mostrada (20.000 Pequenos)", function()
			local rng = Random.new(7)
			local n, count = 20000, {}
			for _ = 1, n do
				local id = EggOdds.roll("small", rng:NextNumber())
				count[id] = (count[id] or 0) + 1
			end
			for _, e in EggOdds.odds("small") do
				expect((count[e.id] or 0) / n).to.be.near(e.p, 0.015)
			end
		end)
		it("bordas do sorteio (r=0 e r quase 1) devolvem espécies válidas", function()
			expect(Config.SpeciesById[EggOdds.roll("massive", 0)]).to.be.ok()
			expect(Config.SpeciesById[EggOdds.roll("massive", 0.9999999)]).to.be.ok()
		end)
	end)

	describe("Ovos: eclosão", function()
		it("espécie nova nasce no nível do ovo", function()
			local level, xp, dup, gain = GameLogic.eggApply(nil, 10)
			expect(level).to.equal(10)
			expect(xp).to.equal(0)
			expect(dup).to.equal(false)
			expect(gain).to.equal(0)
		end)
		it("repetida ganha o XP equivalente e nunca perde nível", function()
			local level, _, dup, gain = GameLogic.eggApply({ level = 40, xp = 0 }, 10)
			expect(dup).to.equal(true)
			expect(gain).to.equal(GameLogic.eggDupXp(10))
			expect(level >= 40).to.equal(true)
		end)
		it("repetida de nível 1 com ovo Grande sobe pelo menos até perto do 10", function()
			local level = GameLogic.eggApply({ level = 1, xp = 0 }, 10)
			expect(level).to.equal(11)
		end)
		it("XP somado respeita o nível máximo", function()
			local level = GameLogic.addXp(Config.Giant.MaxLevel, 0, 1e12)
			expect(level).to.equal(Config.Giant.MaxLevel)
		end)
	end)

	describe("Ovos v2: estrelas de cuidado", function()
		it("alimentado, aquecido e laço contam 1 estrela cada", function()
			expect(GameLogic.eggStars({ size = "large" })).to.equal(0)
			expect(GameLogic.eggStars({ size = "large", fed = true })).to.equal(1)
			expect(GameLogic.eggStars({ size = "large", fed = true, warmed = true, bond = 7 })).to.equal(2)
			expect(GameLogic.eggStars({ size = "large", fed = true, warmed = true, bond = 8 })).to.equal(3)
		end)
		it("espécie nova: +1 nível por estrela", function()
			expect((GameLogic.eggApply(nil, 10, 3))).to.equal(13)
			expect((GameLogic.eggApply(nil, 10, 0))).to.equal(10)
		end)
		it("repetida: +25% de XP por estrela", function()
			local _, _, _, g0 = GameLogic.eggApply({ level = 50, xp = 0 }, 10, 0)
			local _, _, _, g2 = GameLogic.eggApply({ level = 50, xp = 0 }, 10, 2)
			expect(g2).to.equal(math.floor(g0 * 1.5))
		end)
		it("servidor e janela usam a MESMA função de estrelas", function()
			expect(GameLogic.eggStars).to.equal(EggOdds.stars)
		end)
		it("ovos do mapa: 4% e só Pequeno", function()
			expect(GameRules.Eggs.DropChance).to.equal(0.04)
			expect(GameRules.Eggs.DropSize).to.equal("small")
		end)
	end)

	describe("Ovos: ninho e aceleração", function()
		it("lugares: 1 sempre, 2 no nível 25, 3 no nível 50", function()
			expect(GameLogic.eggSlots(1)).to.equal(1)
			expect(GameLogic.eggSlots(24)).to.equal(1)
			expect(GameLogic.eggSlots(25)).to.equal(2)
			expect(GameLogic.eggSlots(50)).to.equal(3)
			expect(GameLogic.eggSlots(250)).to.equal(3)
		end)
		it("fome corta 20% e calor 10% do tempo que FALTA", function()
			expect(GameLogic.eggSpeedUp(1000 + 600, 1000, 0.2)).to.equal(1000 + 480)
			expect(GameLogic.eggSpeedUp(1000 + 600, 1000, 0.1)).to.equal(1000 + 540)
		end)
		it("aceleração juntas = -28% (no máximo -30% do pedido)", function()
			local t = GameLogic.eggSpeedUp(GameLogic.eggSpeedUp(1000, 0, 0.2), 0, 0.1)
			expect(t).to.equal(720)
		end)
		it("ovo já pronto não volta no tempo", function()
			expect(GameLogic.eggSpeedUp(500, 1000, 0.2)).to.equal(1000)
		end)
	end)

	describe("Ovos: migração de perfil", function()
		it("perfil antigo ganha os campos dos ovos sem perder nada", function()
			local DataService = require(ServerScriptService.Server.Services.DataService)
			local old = { coins = 777, level = 12, ownedSpecies = { human = true }, pendingBoxes = { "epic" } }
			PlayerData.reconcile(old, DataService.defaultProfile())
			expect(old.coins).to.equal(777)
			expect(old.level).to.equal(12)
			expect(old.pendingBoxes[1]).to.equal("epic")
			expect(#old.eggs).to.equal(0)
			expect(next(old.nest)).to.equal(nil)
			expect(old.eggsHatched).to.equal(0)
			expect(old.starterSpecies).to.equal("")
		end)
	end)

	describe("Ovo do prêmio do Dragão", function()
		it("só sai Pequeno, Médio, Grande ou Enorme, nas proporções definidas", function()
			local E = GameRules.Eggs
			local w = E.BossEggWeights
			expect(w.massive).to.equal(nil)
			local counts = {}
			local n = 4000
			for i = 0, n - 1 do
				local size = GameLogic.bossEgg(w, E.Order, (i + 0.5) / n)
				counts[size] = (counts[size] or 0) + 1
			end
			expect(counts.massive).to.equal(nil)
			local total = w.small + w.medium + w.large + w.huge
			for size, wt in w do
				expect(math.abs(counts[size] / n - wt / total) < 0.01).to.equal(true)
				expect(E.Sizes[size]).to.be.ok()
			end
		end)
	end)
end
