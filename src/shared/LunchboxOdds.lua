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

-- Conteúdo v5 (pedido do usuário, 09/11, item 17: "compensa mais comprar comida"). Cada caixa traz
-- VÁRIAS comidas, escalando; nas caixas grandes, a 1ª comida tem raridade mínima garantida. As outras
-- seguem a tabela normal da caixa. A tela mostra as duas tabelas (garantida e demais), da MESMA função.
export type Contents = { min: number, max: number, guarantee: string? }
LunchboxOdds.Contents = {
	common = { min = 1, max = 1 },
	rare = { min = 2, max = 3 },
	epic = { min = 4, max = 5, guarantee = "Epic" },
	legendary = { min = 7, max = 8, guarantee = "Legendary" },
	mythic = { min = 9, max = 10, guarantee = "Mythic" },
} :: { [string]: Contents }

-- A maior de duas raridades mínimas (nil = sem mínima).
function LunchboxOdds.higher(a: string?, b: string?): string?
	if not a then
		return b
	end
	if not b then
		return a
	end
	return if Config.Rarities[a].order >= Config.Rarities[b].order then a else b
end

function LunchboxOdds.contents(boxId: string): Contents
	return LunchboxOdds.Contents[boxId] or { min = 1, max = 1 }
end

-- Raridade mínima da comida garantida (1ª), dada a mínima da compra e a do pity.
function LunchboxOdds.firstMin(boxId: string, minAll: string?, minPity: string?): string?
	return LunchboxOdds.higher(LunchboxOdds.higher(LunchboxOdds.contents(boxId).guarantee, minAll), minPity)
end

-- Sorteia o conteúdo inteiro: a 1ª com `firstMin`, as outras com a mínima da compra (`minAll`).
-- O pity (`minPity`) só melhora a 1ª. Devolve a lista na ordem (1ª = garantida).
function LunchboxOdds.rollBox(
	boxId: string,
	luckBonus: number?,
	minAll: string?,
	minPity: string?,
	rng: Random
): { Config.FoodDef }
	local c = LunchboxOdds.contents(boxId)
	local n = rng:NextInteger(c.min, c.max)
	local out = { LunchboxOdds.roll(boxId, luckBonus, LunchboxOdds.firstMin(boxId, minAll, minPity), rng) }
	for _ = 2, n do
		table.insert(out, LunchboxOdds.roll(boxId, luckBonus, minAll, rng))
	end
	return out
end

-- "Traz 4 a 5 comidas · 1 garantida: Épico ou melhor" (texto da loja).
function LunchboxOdds.contentsText(boxId: string, rarityName: ((string) -> string)?): string
	local c = LunchboxOdds.contents(boxId)
	local qty = if c.min == c.max
		then (if c.min == 1 then "Traz 1 comida" else string.format("Traz %d comidas", c.min))
		else string.format("Traz %d a %d comidas", c.min, c.max)
	if c.guarantee then
		local r = if rarityName then rarityName(c.guarantee) else c.guarantee
		return string.format("%s · 1 garantida: %s ou melhor", qty, r)
	end
	return qty
end

LunchboxOdds.Disclaimer = "As chances são arredondadas para exibição e podem não somar exatamente 100%."

return LunchboxOdds
