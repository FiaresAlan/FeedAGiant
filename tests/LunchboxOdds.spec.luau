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
end
