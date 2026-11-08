--!nonstrict
-- Specs dos sistemas de 08/11/2026 (alimentação, coleção, exposição, turnos, Dragão, pendências, carne).
-- Testam o MESMO código que os serviços usam (ServerScriptService.Server.GameLogic). Lógica pura:
-- sem DataStore, sem jogadores. Rodar: require(game.ServerScriptService.FwjelaaTests.Runner)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameRules = require(ReplicatedStorage.Shared.GameRules)
local GameLogic = require(ServerScriptService.Server.GameLogic)

local function fx()
	return { stun = false, weak = 0, guard = false }
end

local function move(id)
	for _, kit in GameRules.MoveKits do
		for _, m in kit do
			if m.id == id then
				return m
			end
		end
	end
	error("golpe " .. id)
end

return function()
	describe("Regras (GameRules)", function()
		it("toda comida do jogo tem característica, e a carne também", function()
			for _, f in Config.Foods do
				expect(GameRules.traitOf(f.id)).to.be.ok()
			end
			expect(GameRules.traitOf("giantmeat")).to.be.ok()
		end)
		it("a carne gigante não entra nas caixas nem nos drops (fora de Config.Foods)", function()
			local found = false
			for _, f in Config.Foods do
				if f.id == "giantmeat" then
					found = true
				end
			end
			expect(found).to.equal(false)
			expect(Config.FoodById.giantmeat).to.be.ok()
		end)
		it("cada espécie tem 3 golpes com acerto entre 0 e 1", function()
			for _, sp in Config.Species do
				local moves = GameRules.movesFor(sp.id)
				expect(#moves).to.equal(3)
				for _, m in moves do
					expect(m.accuracy > 0 and m.accuracy <= 1).to.equal(true)
				end
			end
		end)
		it("as 3 tarefas do dia são diferentes e iguais para o mesmo dia", function()
			local a = GameRules.objectivesForDay(20400)
			local b = GameRules.objectivesForDay(20400)
			expect(#a).to.equal(3)
			expect(a[1].id).to.equal(b[1].id)
			expect(a[1].id ~= a[2].id and a[2].id ~= a[3].id and a[1].id ~= a[3].id).to.equal(true)
		end)
	end)

	describe("4.1 Sequência", function()
		it("começa em 1, sobe dentro da janela e recomeça depois dela", function()
			expect(GameLogic.nextStreak(0, nil, 100, 0)).to.equal(1)
			expect(GameLogic.nextStreak(1, 100, 120, 0)).to.equal(2)
			expect(GameLogic.nextStreak(5, 100, 100 + GameRules.Feed.StreakWindow + 1, 0)).to.equal(1)
		end)
		it("Doce soma +2 na sequência", function()
			expect(GameLogic.nextStreak(1, 100, 110, 2)).to.equal(4)
		end)
		it("multiplicador tem teto x1,5", function()
			expect(GameRules.streakMult(1)).to.be.near(1)
			expect(GameRules.streakMult(2)).to.be.near(1.1)
			expect(GameRules.streakMult(6)).to.be.near(1.5)
			expect(GameRules.streakMult(50)).to.be.near(1.5)
		end)
	end)

	describe("4.3 / 4.4 XP da alimentação", function()
		it("Maçã (Crescimento) dá 14 XP sem sequência (medido em jogo)", function()
			local xp, crit = GameLogic.feedXp("apple", "Common", 1, 0.99)
			expect(xp).to.equal(14)
			expect(crit).to.equal(false)
		end)
		it("crítica multiplica por 2,5", function()
			local xp, crit = GameLogic.feedXp("bread", "Common", 1, 0)
			expect(crit).to.equal(true)
			expect(xp).to.equal(math.floor(10 * 0.75 * GameRules.Feed.CritMult))
		end)
		it("Picante tem 3x a chance de crítica", function()
			local r = GameRules.Feed.CritChance * 2 -- acima da chance normal, abaixo da picante
			local _, critNormal = GameLogic.feedXp("apple", "Common", 1, r)
			local _, critSpicy = GameLogic.feedXp("sushi", "Uncommon", 1, r)
			expect(critNormal).to.equal(false)
			expect(critSpicy).to.equal(true)
		end)
	end)

	describe("Sistema 1: transferência de 30%", function()
		it("XP total vai e volta sem perder nada", function()
			local total = GameLogic.totalXp(11, 675)
			local lv, xp = GameLogic.fromTotalXp(total)
			expect(lv).to.equal(11)
			expect(xp).to.equal(675)
		end)
		it("humano nível 11 (675 XP) passa o jacaré para o nível 7 (medido em jogo)", function()
			local lv, xp = GameLogic.inherit(11, 675)
			expect(lv).to.equal(7)
			expect(xp).to.equal(112)
		end)
		it("nível 1 herda nível 1", function()
			local lv = GameLogic.inherit(1, 0)
			expect(lv).to.equal(1)
		end)
	end)

	describe("Sistema 2: exposição e renda offline", function()
		it("taxa = 0,5 + 0,15 x nível, no máximo 3 expostos", function()
			expect(GameLogic.displayRate({ 7 })).to.be.near(1.55, 1e-9)
			expect(GameLogic.displayRate({ 10, 10, 10, 10 })).to.be.near(3 * 2, 1e-9)
		end)
		it("3 h fora paga metade da taxa (medido: 8.370)", function()
			expect(GameLogic.offlineGain(1000, 1000 + 3 * 3600, 1.55)).to.equal(8370)
		end)
		it("teto de 8 h (medido: 22.320)", function()
			expect(GameLogic.offlineGain(1000, 1000 + 20 * 3600, 1.55)).to.equal(22320)
		end)
		it("voltar logo em seguida, sem carimbo ou sem exposição não paga", function()
			expect(GameLogic.offlineGain(1000, 1000 + 30, 5)).to.equal(0)
			expect(GameLogic.offlineGain(0, 99999, 5)).to.equal(0)
			expect(GameLogic.offlineGain(1000, 50000, 0)).to.equal(0)
			expect(GameLogic.offlineGain(5000, 1000, 5)).to.equal(0) -- relógio para trás
		end)
	end)

	describe("Sistema 3: batalha por turnos", function()
		it("acerta abaixo da chance e erra acima", function()
			local hit = GameLogic.rollMove(10, move("crush"), fx(), fx(), 0.5, 0.5, 1)
			local miss = GameLogic.rollMove(10, move("crush"), fx(), fx(), 0.6, 0.5, 1)
			expect(hit).to.equal(true)
			expect(miss).to.equal(false)
		end)
		it("dano = força x golpe x escala (meio do sorteio)", function()
			local _, dmg = GameLogic.rollMove(10, move("bite"), fx(), fx(), 0, 0.5, 1)
			expect(dmg).to.equal(math.floor(10 * 1.0 * GameRules.TurnBattle.DamageScale))
		end)
		it("Rugido baixa a defesa e o próximo golpe tira +35%", function()
			local defFx = fx()
			local _, _, eff = GameLogic.rollMove(10, move("roar"), fx(), defFx, 0, 0.5, 0)
			expect(eff).to.equal("weaken")
			expect(defFx.weak).to.equal(GameRules.TurnBattle.WeakenTurns)
			local _, dmg = GameLogic.rollMove(10, move("bite"), fx(), defFx, 0, 0.5, 1)
			expect(dmg).to.equal(math.floor(10 * GameRules.TurnBattle.DamageScale * GameRules.TurnBattle.WeakenMult))
			expect(defFx.weak).to.equal(GameRules.TurnBattle.WeakenTurns - 1)
		end)
		it("Esquiva deixa o próximo golpe do adversário com menos acerto (uma vez)", function()
			local myFx = fx()
			GameLogic.rollMove(10, move("dodge"), myFx, fx(), 0, 0.5, 1)
			expect(myFx.guard).to.equal(true)
			-- golpe de 100% de acerto vira 60%: sorteio 0,7 erra
			local hit = GameLogic.rollMove(10, move("jab"), fx(), myFx, 0.7, 0.5, 1)
			expect(hit).to.equal(false)
			expect(myFx.guard).to.equal(false)
		end)
		it("Pisão deixa tonto com sorteio favorável", function()
			local defFx = fx()
			GameLogic.rollMove(10, move("quake"), fx(), defFx, 0, 0.5, 0.1)
			expect(defFx.stun).to.equal(true)
		end)
		it("quem não escolheu nenhum golpe (AFK) nunca ganha prêmio", function()
			expect(GameLogic.battleOutcome(50, 100, 0, 100, 0)).to.equal(false)
			expect(GameLogic.battleOutcome(50, 100, 0, 100, 3)).to.equal(true)
			expect(GameLogic.battleOutcome(10, 100, 40, 100, 3)).to.equal(false)
		end)
	end)

	describe("Sistema 4: recompensas do Dragão", function()
		it("2 jogadores: confere os números medidos no teste real", function()
			-- Player1 (-1) 93,6% do dano; Player2 (-2) 6,4%; os dois nível 1
			local r = GameLogic.bossRewards({ [-1] = 936, [-2] = 64 }, { [-1] = 20, [-2] = 8 }, { [-1] = 1, [-2] = 1 }, true)
			expect(#r).to.equal(2)
			local byUid = {}
			for _, x in r do
				byUid[x.uid] = x
			end
			expect(byUid[-1].coins).to.equal(308)
			expect(byUid[-1].xp).to.equal(123)
			expect(byUid[-1].bonus).to.equal(math.floor(1800 * 0.936))
			expect(byUid[-2].coins + byUid[-2].bonus).to.equal(308 + math.floor(1800 * 0.064))
		end)
		it("a soma dos bônus nunca passa do pote", function()
			local r = GameLogic.bossRewards({ [1] = 333, [2] = 333, [3] = 334 }, {}, {}, true)
			local sum = 0
			for _, x in r do
				sum += x.bonus
			end
			expect(sum <= GameRules.BossIsland.BonusPoolPerPlayer * 3).to.equal(true)
		end)
		it("quem quase não ajudou (menos de 3% e menos de 3 golpes) não conta", function()
			local r = GameLogic.bossRewards({ [1] = 990, [2] = 10 }, { [1] = 30, [2] = 1 }, {}, true)
			expect(#r).to.equal(1)
			expect(r[1].uid).to.equal(1)
		end)
		it("3 golpes valem participação mesmo com pouco dano", function()
			local r = GameLogic.bossRewards({ [1] = 990, [2] = 10 }, { [1] = 30, [2] = 3 }, {}, true)
			expect(#r).to.equal(2)
		end)
		it("dragão fugiu: metade da participação e nenhum bônus (ninguém é punido)", function()
			local r = GameLogic.bossRewards({ [1] = 500 }, { [1] = 10 }, { [1] = 1 }, false)
			expect(r[1].coins).to.equal(math.floor(308 * GameRules.BossIsland.FailFraction))
			expect(r[1].bonus).to.equal(0)
		end)
	end)

	describe("Recompensas pendentes (idempotentes)", function()
		it("paga uma vez e ignora id repetido na mesma fila", function()
			local pay, claimed = GameLogic.pendingToPay({}, {
				{ id = "a", coins = 500, xp = 50 },
				{ id = "a", coins = 500, xp = 50 },
				{ id = "b", coins = 700, xp = 0 },
			}, 20)
			expect(#pay).to.equal(2)
			expect(pay[1].coins + pay[2].coins).to.equal(1200)
			expect(#claimed).to.equal(2)
		end)
		it("id já pago em outra entrada não paga de novo", function()
			local pay = GameLogic.pendingToPay({ "a" }, { { id = "a", coins = 500, xp = 50 } }, 20)
			expect(#pay).to.equal(0)
		end)
		it("valores estranhos viram 0 e a lista de pagos tem tamanho máximo", function()
			local pay, claimed = GameLogic.pendingToPay({ "x1", "x2" }, { { id = "c", coins = -5, xp = "zz" } }, 2)
			expect(pay[1].coins).to.equal(0)
			expect(pay[1].xp).to.equal(0)
			expect(#claimed).to.equal(2)
			expect(claimed[2]).to.equal("c")
		end)
	end)

	describe("4.5 Carne Gigante", function()
		it("porções: 4 + 2 por jogador, no máximo 14", function()
			expect(GameLogic.meatPortions(1)).to.equal(6)
			expect(GameLogic.meatPortions(2)).to.equal(8)
			expect(GameLogic.meatPortions(8)).to.equal(14)
		end)
		it("recusas: acabou, limite de 2 por jogador, já carregando", function()
			expect(GameLogic.meatRefusal(0, 0, false)).to.equal("gone")
			expect(GameLogic.meatRefusal(5, 2, false)).to.equal("limit")
			expect(GameLogic.meatRefusal(5, 1, true)).to.equal("carrying")
			expect(GameLogic.meatRefusal(5, 1, false)).to.equal(nil)
		end)
	end)
end
