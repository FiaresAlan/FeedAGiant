--!nonstrict
-- Specs da especificação v3 (08/11/2026): pity das Lunchboxes, proteção da sequência diária,
-- limites do roubo, migração de perfil antigo (v1 -> campos novos) e interruptores desligados.
-- Testam o MESMO código usado pelos serviços (LunchboxOdds, GameLogic, DataService.defaultProfile,
-- PlayerData.reconcile). Rodar: require(game.ServerScriptService.FwjelaaTests.Runner)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local LunchboxOdds = require(ReplicatedStorage.Shared.LunchboxOdds)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)
local PlayerData = require(ServerScriptService:WaitForChild("fwjelaa").PlayerData)

local P = GameRules.Pity

return function()
	describe("Interruptores (Features)", function()
		it("todos os interruptores são sim/não", function()
			for name, value in Features.flags do
				expect(type(value)).to.equal("boolean")
			end
		end)
	end)

	describe("Pity das Lunchboxes", function()
		it("antes do limite não mexe na raridade mínima", function()
			expect(LunchboxOdds.pityMin(0, nil, P.Hard, P.MinRarity)).to.equal(nil)
			expect(LunchboxOdds.pityMin(P.Hard - 2, nil, P.Hard, P.MinRarity)).to.equal(nil)
			expect(LunchboxOdds.pityMin(10, "Rare", P.Hard, P.MinRarity)).to.equal("Rare")
		end)
		it("na caixa número Hard a mínima vira Épica", function()
			expect(LunchboxOdds.pityMin(P.Hard - 1, nil, P.Hard, P.MinRarity)).to.equal("Epic")
			expect(LunchboxOdds.pityMin(P.Hard - 1, "Rare", P.Hard, P.MinRarity)).to.equal("Epic")
		end)
		it("não rebaixa uma mínima que já é maior que Épica", function()
			expect(LunchboxOdds.pityMin(P.Hard - 1, "Legendary", P.Hard, P.MinRarity)).to.equal("Legendary")
		end)
		it("Épica ou melhor zera; abaixo disso soma 1", function()
			expect(LunchboxOdds.pityAfter(7, "Epic", P.MinRarity)).to.equal(0)
			expect(LunchboxOdds.pityAfter(7, "Mythic", P.MinRarity)).to.equal(0)
			expect(LunchboxOdds.pityAfter(7, "Rare", P.MinRarity)).to.equal(8)
		end)
		it("a tela de chances com pity soma 100% e não lista nada abaixo de Épica", function()
			local total = 0
			for _, row in LunchboxOdds.rows("common", 0, "Epic") do
				expect(Config.Rarities[row.rarity].order >= Config.Rarities.Epic.order).to.equal(true)
				total += row.percent
			end
			expect(total).to.be.near(100, 0.5)
		end)
		it("simulação: 2.000 jogadores abrindo 200 caixas comuns nunca passam de Hard sem Épica", function()
			local rng = Random.new(42)
			local worst = 0
			for _ = 1, 2000 do
				local count, gap = 0, 0
				for _ = 1, 200 do
					local minR = LunchboxOdds.pityMin(count, nil, P.Hard, P.MinRarity)
					local food = LunchboxOdds.roll("common", 0, minR, rng)
					gap += 1
					if Config.Rarities[food.rarity].order >= Config.Rarities.Epic.order then
						worst = math.max(worst, gap)
						gap = 0
					end
					count = LunchboxOdds.pityAfter(count, food.rarity, P.MinRarity)
				end
			end
			expect(worst <= P.Hard).to.equal(true)
		end)
	end)

	describe("Proteção da sequência diária", function()
		local H = 3600
		it("dentro de 48 h a sequência segue e nada é gasto", function()
			local s, b, used = GameLogic.dailyStreakBase(4, 30 * H, 1, true)
			expect(s).to.equal(4)
			expect(b).to.equal(1)
			expect(used).to.equal(false)
		end)
		it("passou de 48 h com proteção: gasta 1 e mantém a sequência", function()
			local s, b, used = GameLogic.dailyStreakBase(4, 60 * H, 1, true)
			expect(s).to.equal(4)
			expect(b).to.equal(0)
			expect(used).to.equal(true)
		end)
		it("passou de 48 h sem proteção: zera", function()
			local s, b, used = GameLogic.dailyStreakBase(4, 60 * H, 0, true)
			expect(s).to.equal(0)
			expect(b).to.equal(0)
			expect(used).to.equal(false)
		end)
		it("com a função desligada a proteção não é usada (comportamento antigo)", function()
			local s, b, used = GameLogic.dailyStreakBase(4, 60 * H, 2, false)
			expect(s).to.equal(0)
			expect(b).to.equal(2)
			expect(used).to.equal(false)
		end)
		it("sequência zerada não gasta proteção", function()
			local _, b, used = GameLogic.dailyStreakBase(0, 90 * H, 1, true)
			expect(b).to.equal(1)
			expect(used).to.equal(false)
		end)
	end)

	describe("Limites do roubo", function()
		local L = GameRules.StealLimits
		it("vítima abaixo do nível mínimo não pode ser roubada", function()
			local ok, why = GameLogic.stealAllowed(0, 0, L.MinVictimLevel - 1, 100)
			expect(ok).to.equal(false)
			expect(why).to.equal("newbie")
		end)
		it("ladrão com o máximo do dia é recusado; no dia seguinte pode de novo", function()
			local ok, why = GameLogic.stealAllowed(100, L.MaxPerDay, 20, 100)
			expect(ok).to.equal(false)
			expect(why).to.equal("daily")
			expect((GameLogic.stealAllowed(100, L.MaxPerDay, 20, 101))).to.equal(true)
		end)
		it("quem já renasceu nunca é novato, e vale o maior nível já alcançado", function()
			expect(GameLogic.victimProgress(1, 1, 1) >= L.MinVictimLevel).to.equal(true)
			expect(GameLogic.victimProgress(2, 30, 0)).to.equal(30)
			expect(GameLogic.victimProgress(3, 3, 0) < L.MinVictimLevel).to.equal(true)
		end)
		it("contador reinicia na virada do dia", function()
			local d, n = GameLogic.countSteal(100, 2, 100)
			expect(d).to.equal(100)
			expect(n).to.equal(3)
			d, n = GameLogic.countSteal(100, 3, 101)
			expect(d).to.equal(101)
			expect(n).to.equal(1)
		end)
	end)

	describe("Presente de boas-vindas", function()
		it("só para conta marcada como novata, uma vez, e nunca para quem pulou", function()
			local OB = require(ServerScriptService.Server.Services.OnboardingService)
			expect(OB.giftEligible(-1, false, false)).to.equal(true)
			expect(OB.giftEligible(0, false, false)).to.equal(false) -- veterano que refaz o tutorial
			expect(OB.giftEligible(-1, true, false)).to.equal(false)
			expect(OB.giftEligible(-1, false, true)).to.equal(false)
		end)
	end)

	describe("Migração de perfil antigo", function()
		it("perfil v1 ganha os campos novos sem perder nada", function()
			local DataService = require(ServerScriptService.Server.Services.DataService)
			local old = {
				coins = 123456,
				level = 42,
				xp = 77,
				dailyStreak = 5,
				inventory = { { id = "apple", uid = "u1" } },
				pendingBoxes = { "rare" },
				ownedSpecies = { human = true, goblin = true },
			}
			PlayerData.reconcile(old, DataService.defaultProfile())
			expect(old.coins).to.equal(123456)
			expect(old.level).to.equal(42)
			expect(old.dailyStreak).to.equal(5)
			expect(#old.inventory).to.equal(1)
			expect(old.pendingBoxes[1]).to.equal("rare")
			expect(old.ownedSpecies.goblin).to.equal(true)
			expect(old.pityCount).to.equal(0)
			expect(old.streakBackups).to.equal(0)
			expect(old.stealsToday).to.equal(0)
			expect(old.onboardingAt).to.equal(0)
			expect(old.welcomeGiven).to.equal(false)
		end)
	end)
end
