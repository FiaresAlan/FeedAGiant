--!nonstrict
-- Feed a Giant spec: LunchboxOdds (Fase 0.5). Lógica pura; roda com tests/Runner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Config = require(Shared.Config)
local LunchboxOdds = require(Shared.LunchboxOdds)
local Odds = require(ReplicatedStorage:WaitForChild("fwjelaa"):WaitForChild("Odds"))

local function sumP(finals)
	local s = 0
	for _, f in finals do
		s += f.p
	end
	return s
end

local function pRarity(finals, rarity)
	local s = 0
	for _, f in finals do
		if f.tier == rarity then
			s += f.p
		end
	end
	return s
end

-- Probabilidade de raridade pela regra da v4 (Util.weightedPick + promoção à mínima).
local function v4Rarity(boxId, bonus, minRarity, rarity)
	local box = Config.LunchboxById[boxId]
	local total, adj = 0, {}
	for key, w in box.weights do
		local a = if key ~= "Common" and key ~= "Uncommon" then w * (1 + bonus) else w
		adj[key] = a
		total += a
	end
	local p = 0
	local minOrder = if minRarity then Config.Rarities[minRarity].order else 0
	for key, a in adj do
		local effective = if Config.Rarities[key].order < minOrder then minRarity else key
		if effective == rarity then
			p += a / total
		end
	end
	return p
end

return function()
	describe("LunchboxOdds.finals", function()
		it("sums to 1 for every box, with and without luck and minimum rarity", function()
			for _, box in Config.Lunchboxes do
				expect(sumP(LunchboxOdds.finals(box.id, 0, nil))).to.be.near(1, 1e-9)
				expect(sumP(LunchboxOdds.finals(box.id, 0.5, nil))).to.be.near(1, 1e-9)
				expect(sumP(LunchboxOdds.finals(box.id, 0, "Rare"))).to.be.near(1, 1e-9)
			end
		end)

		it("reproduces the v4 rarity distribution exactly (economy unchanged)", function()
			for _, box in Config.Lunchboxes do
				for _, bonus in { 0, 0.5 } do
					for _, minR in { false, "Rare", "Legendary" } do
						local m = if minR then minR else nil
						local finals = LunchboxOdds.finals(box.id, bonus, m)
						for rarity in Config.Rarities do
							expect(pRarity(finals, rarity)).to.be.near(v4Rarity(box.id, bonus, m, rarity), 1e-9)
						end
					end
				end
			end
		end)

		it("Lucky Box (rare + min Rare) never gives Common or Uncommon", function()
			local finals = LunchboxOdds.finals("rare", 0, "Rare")
			expect(pRarity(finals, "Common")).to.equal(0)
			expect(pRarity(finals, "Uncommon")).to.equal(0)
			expect(pRarity(finals, "Rare")).to.be.near(0.92, 1e-9) -- 30+40+22 de 100
		end)

		it("never shows a non-zero chance as 0%", function()
			for _, row in LunchboxOdds.rows("common", 0, nil) do
				if row.percent > 0 then
					expect(row.text ~= "0%").to.equal(true)
				end
			end
		end)
	end)

	describe("LunchboxOdds.roll", function()
		it("matches the shown odds (chi-square, 20k rolls)", function()
			local rng = Random.new(12345)
			local finals = LunchboxOdds.finals("rare", 0, nil)
			local counts = {}
			local n = 20000
			for _ = 1, n do
				local food = LunchboxOdds.roll("rare", 0, nil, rng)
				counts[food.id] = (counts[food.id] or 0) + 1
			end
			local chi, dof = Odds.ChiSquare(finals, counts, n)
			-- Valor crítico folgado (p≈0,001) para até ~15 graus de liberdade.
			expect(chi < 40 + dof).to.equal(true)
		end)
	end)

	describe("Lunchbox v5: várias comidas e garantia", function()
		it("quantidades escalam como o dono pediu (1 · 2-3 · 4-5 · 7-8 · 9-10)", function()
			local want =
				{ common = { 1, 1 }, rare = { 2, 3 }, epic = { 4, 5 }, legendary = { 7, 8 }, mythic = { 9, 10 } }
			local rng = Random.new(7)
			for boxId, mm in want do
				local seen = {}
				for _ = 1, 200 do
					local n = #LunchboxOdds.rollBox(boxId, 0, nil, nil, rng)
					expect(n >= mm[1] and n <= mm[2]).to.equal(true)
					seen[n] = true
				end
				for k = mm[1], mm[2] do
					expect(seen[k]).to.equal(true)
				end
			end
		end)
		it(
			"a 1ª comida respeita a garantia (Épica ≥ Épico, Lendária ≥ Lendário, Mítica = Mítico)",
			function()
				local rng = Random.new(99)
				for boxId, g in { epic = "Epic", legendary = "Legendary", mythic = "Mythic" } do
					for _ = 1, 300 do
						local first = LunchboxOdds.rollBox(boxId, 0, nil, nil, rng)[1]
						expect(Config.Rarities[first.rarity].order >= Config.Rarities[g].order).to.equal(true)
					end
				end
			end
		)
		it("a garantia é a mesma usada na tela (firstMin)", function()
			expect(LunchboxOdds.firstMin("common", nil, nil)).to.equal(nil)
			expect(LunchboxOdds.firstMin("epic", nil, nil)).to.equal("Epic")
			expect(LunchboxOdds.firstMin("epic", "Rare", nil)).to.equal("Epic")
			expect(LunchboxOdds.firstMin("rare", "Rare", "Epic")).to.equal("Epic")
			expect(LunchboxOdds.firstMin("mythic", nil, "Epic")).to.equal("Mythic")
		end)
		it("a mínima da compra (Lucky Box) vale para TODAS as comidas", function()
			local rng = Random.new(3)
			for _ = 1, 200 do
				for _, f in LunchboxOdds.rollBox("rare", 0, "Rare", nil, rng) do
					expect(Config.Rarities[f.rarity].order >= Config.Rarities.Rare.order).to.equal(true)
				end
			end
		end)
		it("o pity só melhora a 1ª comida", function()
			local rng = Random.new(5)
			local belowSeen = false
			for _ = 1, 300 do
				local foods = LunchboxOdds.rollBox("rare", 0, nil, "Epic", rng)
				expect(Config.Rarities[foods[1].rarity].order >= Config.Rarities.Epic.order).to.equal(true)
				for i = 2, #foods do
					if Config.Rarities[foods[i].rarity].order < Config.Rarities.Epic.order then
						belowSeen = true
					end
				end
			end
			expect(belowSeen).to.equal(true)
		end)
		it("texto da loja diz quantas e o que é garantido", function()
			expect(LunchboxOdds.contentsText("common")).to.equal("Traz 1 comida")
			expect(LunchboxOdds.contentsText("rare")).to.equal("Traz 2 a 3 comidas")
			expect(LunchboxOdds.contentsText("legendary")).to.equal(
				"Traz 7 a 8 comidas · 1 garantida: Legendary ou melhor"
			)
		end)
		it("toda caixa da Config tem conteúdo definido", function()
			for _, b in Config.Lunchboxes do
				expect(LunchboxOdds.Contents[b.id]).to.be.ok()
			end
		end)
	end)
end
