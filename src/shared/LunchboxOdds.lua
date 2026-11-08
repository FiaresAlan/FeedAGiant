--!strict
-- LunchboxOdds — FONTE ÚNICA das chances das Lunchboxes (Fase 0.5).
-- O servidor sorteia e o cliente mostra a partir da MESMA função `finals`, então a
-- tela nunca diverge do sorteio (vault: Paid Random Items and Odds Disclosure in Practice).
--
-- Regras (idênticas à v4, para não mudar a economia):
--   * peso de cada raridade vem de Config.Lunchboxes[...].weights;
--   * bônus de sorte (evento Lucky Boxes) multiplica Rare ou melhor por (1 + bônus);
--   * raridade mínima (Lucky Box): o que cairia abaixo dela vira a própria mínima;
--   * dentro de uma raridade, cada comida tem a mesma chance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Odds = require(ReplicatedStorage:WaitForChild("fwjelaa"):WaitForChild("Odds"))

local LunchboxOdds = {}

-- Atributo em ReplicatedStorage com o bônus de sorte ativo (servidor escreve, cliente lê).
LunchboxOdds.LUCK_ATTRIBUTE = "LunchboxLuckBonus"
LunchboxOdds.LUCKY_FROM_ORDER = 3 -- Rare

local function rarityOrder(): { string }
	local list: { string } = {}
	for name in Config.Rarities do
		table.insert(list, name :: string)
	end
	table.sort(list, function(a, b)
		return Config.Rarities[a].order < Config.Rarities[b].order
	end)
	return list
end

local function foodsOf(rarity: string): { Odds.Item }
	local items = {}
	for _, f in Config.Foods do
		if f.rarity == rarity then
			table.insert(items, { id = f.id, weight = 1 })
		end
	end
	return items
end

-- Monta as faixas (tiers) com os pesos já ajustados pela sorte e pela raridade mínima.
function LunchboxOdds.tiers(boxId: string, luckBonus: number?, minRarity: string?): { Odds.Tier }
	local box = Config.LunchboxById[boxId]
	assert(box, `LunchboxOdds: caixa desconhecida {boxId}`)
	local bonus = math.max(0, luckBonus or 0)
	local minOrder = if minRarity then Config.Rarities[minRarity].order else 0

	local carried = 0 -- peso das raridades abaixo da mínima, somado à mínima
	local tiers: { Odds.Tier } = {}
	for _, rarity in rarityOrder() do
		local base = box.weights[rarity] or 0
		local order = Config.Rarities[rarity].order
		local w = if order >= LunchboxOdds.LUCKY_FROM_ORDER then base * (1 + bonus) else base
		if order < minOrder then
			carried += w
		else
			if order == minOrder then
				w += carried
				carried = 0
			end
			local items = foodsOf(rarity)
			if w > 0 and #items > 0 then
				table.insert(tiers, { name = rarity, weight = w, items = items })
			end
		end
	end
	return tiers
end

-- Probabilidade final de cada comida (p de 0 a 1, soma 1).
function LunchboxOdds.finals(boxId: string, luckBonus: number?, minRarity: string?): { Odds.Final }
	local finals = Odds.Flatten(LunchboxOdds.tiers(boxId, luckBonus, minRarity))
	return finals
end

-- Sorteia uma comida usando exatamente as chances mostradas.
function LunchboxOdds.roll(boxId: string, luckBonus: number?, minRarity: string?, rng: Random): Config.FoodDef
	local pick = Odds.Pick(LunchboxOdds.finals(boxId, luckBonus, minRarity), rng)
	return Config.FoodById[pick.id]
end

export type Row = { foodId: string, name: string, rarity: string, percent: number, text: string }

-- Linhas prontas para a tela (ordenadas da raridade mais comum para a mais rara).
function LunchboxOdds.rows(boxId: string, luckBonus: number?, minRarity: string?): { Row }
	local rows: { Row } = {}
	for _, shown in Odds.Shown(LunchboxOdds.finals(boxId, luckBonus, minRarity)) do
		local food = Config.FoodById[shown.id]
		table.insert(rows, {
			foodId = shown.id,
			name = food.name,
			rarity = shown.tier,
			percent = shown.percent,
			text = shown.text,
		})
	end
	table.sort(rows, function(a, b)
		local oa, ob = Config.Rarities[a.rarity].order, Config.Rarities[b.rarity].order
		if oa ~= ob then
			return oa < ob
		end
		return a.name < b.name
	end)
	return rows
end

-- Pity (GameRules.Pity): raridade mínima efetiva da PRÓXIMA abertura paga, dado o contador salvo.
-- Usada pelo servidor no sorteio e pela loja na tela de chances (mesma função = mesma chance).
function LunchboxOdds.pityMin(pityCount: number, minRarity: string?, hard: number, pityRarity: string): string?
	if pityCount + 1 < hard then
		return minRarity
	end
	if minRarity and Config.Rarities[minRarity].order >= Config.Rarities[pityRarity].order then
		return minRarity
	end
	return pityRarity
end

-- Novo valor do contador depois de uma abertura paga que saiu com a raridade `rarity`.
function LunchboxOdds.pityAfter(pityCount: number, rarity: string, pityRarity: string): number
	if Config.Rarities[rarity].order >= Config.Rarities[pityRarity].order then
		return 0
	end
	return pityCount + 1
end

LunchboxOdds.Disclaimer = "As chances são arredondadas para exibição e podem não somar exatamente 100%."

return LunchboxOdds
