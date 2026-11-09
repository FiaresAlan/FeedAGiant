--!nonstrict
-- Specs da missão semanal 1-de-3 (prompt v4, 09/11/2026), da estrutura da notificação de ovo e dos
-- campos novos do perfil. Mesmo código do ProgressService/EggNotificationService.
-- Rodar: require(game.ServerScriptService.FwjelaaTests.Runner)()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameRules = require(ReplicatedStorage.Shared.GameRules)
local Features = require(ReplicatedStorage.Shared.Features)
local GameLogic = require(ServerScriptService.Server.GameLogic)
local PlayerData = require(ServerScriptService:WaitForChild("fwjelaa").PlayerData)

local function fresh()
	return { week = 0, chosenId = "", chosenAt = 0, swappedThisWeek = false, progress = 0, claimed = false }
end

local WEEK = 2900
local function opts(week)
	local ids = {}
	for _, q in GameRules.weeklyOptions(week) do
		table.insert(ids, q.id)
	end
	return ids
end

return function()
	describe("Missão semanal: semana e opções", function()
		it("a semana vira na segunda 00:00 UTC", function()
			-- 2026-11-08 (domingo) e 2026-11-09 (segunda)
			local monday = 1794182400 -- 09/11/2026 00:00 UTC (segunda, conferido)
			local sunday = monday - 1
			expect(GameRules.weekIndex(monday)).to.equal(GameRules.weekIndex(sunday) + 1)
			expect(GameRules.weekIndex(monday + 6 * 86400 + 86399)).to.equal(GameRules.weekIndex(monday))
		end)
		it("3 opções diferentes, iguais para todos na mesma semana", function()
			local a, b = opts(WEEK), opts(WEEK)
			expect(#a).to.equal(3)
			expect(a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3]).to.equal(true)
			for i = 1, 3 do
				expect(a[i]).to.equal(b[i])
			end
		end)
		it("recompensa semanal é maior que qualquer diária", function()
			local maxDaily = 0
			for _, o in GameRules.Objectives do
				maxDaily = math.max(maxDaily, o.coins)
			end
			for _, q in GameRules.WeeklyQuests do
				expect(q.coins > maxDaily).to.equal(true)
			end
		end)
		it("nasce desligada", function()
			expect(Features.flags.WeeklyQuest).to.equal(false)
		end)
	end)

	describe("Missão semanal: escolher, trocar, progredir, resgatar", function()
		it("só escolhe uma das 3 opções e só uma vez", function()
			local wq = fresh()
			local o = opts(WEEK)
			local bad = nil
			for _, q in GameRules.WeeklyQuests do
				if not table.find(o, q.id) then
					bad = q.id
				end
			end
			if bad then
				expect((GameLogic.weeklyChoose(wq, WEEK, bad, 1))).to.equal(false)
			end
			expect((GameLogic.weeklyChoose(wq, WEEK, o[1], 1))).to.equal(true)
			local ok, why = GameLogic.weeklyChoose(wq, WEEK, o[2], 2)
			expect(ok).to.equal(false)
			expect(why).to.equal("chosen")
		end)
		it("troca 1 vez por semana e zera o progresso", function()
			local wq = fresh()
			local o = opts(WEEK)
			GameLogic.weeklyChoose(wq, WEEK, o[1], 1)
			GameLogic.weeklyBump(wq, WEEK, o[1], 3)
			expect((GameLogic.weeklySwap(wq, WEEK, o[2], 2))).to.equal(true)
			expect(wq.progress).to.equal(0)
			local ok, why = GameLogic.weeklySwap(wq, WEEK, o[3], 3)
			expect(ok).to.equal(false)
			expect(why).to.equal("swapped")
		end)
		it("progresso só conta para a missão escolhida e para no alvo", function()
			local wq = fresh()
			local o = opts(WEEK)
			GameLogic.weeklyChoose(wq, WEEK, o[1], 1)
			GameLogic.weeklyBump(wq, WEEK, o[2], 5)
			expect(wq.progress).to.equal(0)
			local goal = GameRules.weeklyById(o[1]).goal
			local done = GameLogic.weeklyBump(wq, WEEK, o[1], goal + 50)
			expect(done).to.equal(true)
			expect(wq.progress).to.equal(goal)
			expect(GameLogic.weeklyBump(wq, WEEK, o[1], 1)).to.equal(false)
		end)
		it("resgate só depois de completar, uma vez só", function()
			local wq = fresh()
			local o = opts(WEEK)
			GameLogic.weeklyChoose(wq, WEEK, o[1], 1)
			expect(GameLogic.weeklyClaim(wq, WEEK)).to.equal(nil)
			GameLogic.weeklyBump(wq, WEEK, o[1], 1e6)
			expect(GameLogic.weeklyClaim(wq, WEEK)).to.be.ok()
			expect(GameLogic.weeklyClaim(wq, WEEK)).to.equal(nil)
		end)
		it("completa e não resgatada continua resgatável na semana seguinte; depois abre a nova", function()
			local wq = fresh()
			local o = opts(WEEK)
			GameLogic.weeklyChoose(wq, WEEK, o[1], 1)
			GameLogic.weeklyBump(wq, WEEK, o[1], 1e6)
			expect(GameLogic.weeklyNormalize(wq, WEEK + 1)).to.equal("carry")
			expect((GameLogic.weeklyChoose(wq, WEEK + 1, opts(WEEK + 1)[1], 9))).to.equal(false)
			expect(GameLogic.weeklyClaim(wq, WEEK + 1)).to.be.ok()
			expect(wq.week).to.equal(WEEK + 1)
			expect(wq.chosenId).to.equal("")
		end)
		it("incompleta é descartada na virada (sem prêmio)", function()
			local wq = fresh()
			local o = opts(WEEK)
			GameLogic.weeklyChoose(wq, WEEK, o[1], 1)
			GameLogic.weeklyBump(wq, WEEK, o[1], 1)
			expect(GameLogic.weeklyNormalize(wq, WEEK + 1)).to.equal("current")
			expect(wq.chosenId).to.equal("")
			expect(wq.progress).to.equal(0)
		end)
	end)

	describe("Notificação de ovo (estrutura, sem API)", function()
		it("avisa só o ovo que choca primeiro, no futuro, e não repete", function()
			local N = require(ServerScriptService.Server.Services.EggNotificationService)
			local nest = { ["1"] = { size = "large", hatchAt = 500 }, ["2"] = { size = "small", hatchAt = 300 } }
			local job = N.planJob(9, nest, 100, nil)
			expect(job.dueAt).to.equal(300)
			expect(job.size).to.equal("small")
			expect(N.planJob(9, nest, 100, 300)).to.equal(nil)
			expect(N.planJob(9, nest, 600, nil)).to.equal(nil)
			expect(N.send(job)).to.equal(false) -- sem API até publicar
		end)
	end)

	describe("Campos novos do perfil (v4)", function()
		it("perfil antigo ganha mysteryChest, revangeTarget e weeklyQuest sem perder nada", function()
			local DataService = require(ServerScriptService.Server.Services.DataService)
			local old = { coins = 5, level = 3, eggs = { "small" } }
			PlayerData.reconcile(old, DataService.defaultProfile())
			expect(old.coins).to.equal(5)
			expect(old.eggs[1]).to.equal("small")
			expect(old.mysteryChest.unlockAt).to.equal(0)
			expect(old.revangeTarget).to.equal(0)
			expect(old.weeklyQuest.chosenId).to.equal("")
			expect(old.weeklyQuest.claimed).to.equal(false)
		end)
	end)
end
