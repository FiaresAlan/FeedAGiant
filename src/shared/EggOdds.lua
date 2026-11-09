--!strict
-- EggOdds — chances dos ovos, num lugar só. O servidor sorteia com EggOdds.roll e a janela do
-- ninho mostra EggOdds.odds: a MESMA tabela (vault: "Paid Random Items and Odds Disclosure in
-- Practice" — chance exibida = chance sorteada).
local GameRules = require(script.Parent.GameRules)

local EggOdds = {}

export type Entry = { id: string, p: number }

-- Chances finais de um tamanho, da maior para a menor (soma 1).
function EggOdds.odds(size: string): { Entry }
	local def = GameRules.Eggs.Sizes[size]
	assert(def, `ovo desconhecido {size}`)
	local total = 0
	for _, w in def.weights do
		total += w
	end
	local out: { Entry } = {}
	for id, w in def.weights do
		table.insert(out, { id = id :: string, p = (w :: number) / total })
	end
	table.sort(out, function(a, b)
		return a.p > b.p or (a.p == b.p and a.id < b.id)
	end)
	return out
end

-- Sorteia com r em [0,1).
function EggOdds.roll(size: string, r: number): string
	local acc = 0
	local odds = EggOdds.odds(size)
	for _, e in odds do
		acc += e.p
		if r < acc then
			return e.id
		end
	end
	return odds[#odds].id
end

-- Estrelas de cuidado de um ovo no ninho (Ovos v2): alimentado, aquecido e laço com o gigante.
-- Uma função só: o servidor (GameLogic.eggStars) e a janela do cliente usam esta.
function EggOdds.stars(slot: { [string]: any }): number
	local need = GameRules.Eggs.BondFeeds[slot.size] or math.huge
	return (if slot.fed then 1 else 0) + (if slot.warmed then 1 else 0) + (if (slot.bond or 0) >= need then 1 else 0)
end

-- "12,5%" (arredondado para exibição).
function EggOdds.format(p: number): string
	local pct = p * 100
	local s = if pct >= 10
		then string.format("%.0f%%", pct)
		elseif pct >= 1 then string.format("%.1f%%", pct)
		else string.format("%.2f%%", pct)
	return (string.gsub(s, "%.", ","))
end

return EggOdds
