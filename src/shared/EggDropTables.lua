--!strict
-- EggDropTables — que gigantes cada tamanho de ovo pode dar (resposta 2 do usuário ao prompt v4,
-- 09/11/2026). Regra do usuário: tamanho → faixa de raridade.
--   Pequeno  → Comum
--   Médio    → Comum + Raro
--   Grande   → Raro + Épico
--   Enorme   → Épico + Lendário
--   Colossal → Lendário + Mítico
--
-- TODO(usuário): preencher a tabela real. O usuário pediu "3 criaturas de exemplo por raridade";
-- isso NÃO é possível com seguranca, porque o servidor entregaria uma espécie que não existe (sem
-- modelo, sem atributos). Por isso cada raridade usa as espécies REAIS do jogo com aquela raridade
-- (Config.Species.rarityTag). Hoje: Comum = Humano (só 1); Raro = Jacaré, Zumbi; Épico = Águia,
-- Troll; Lendário = Golem, Wyvern; Mítico = Slime, Hidra. Incomum (Goblin) não está em nenhuma faixa
-- pela regra do usuário. Dragão e Fênix (Robux) e as espécies iniciais nunca entram.
-- Ver docs/VALIDACAO_ESPEC_V4.md (P2).
--
-- Pesos (decisão provisória do diretor, TODO do usuário): faixa de baixo 70%, faixa de cima 30%,
-- divididos igualmente entre as espécies de cada faixa.
local Config = require(script.Parent.Config)

local EggDropTables = {}

EggDropTables.Bands = {
	-- Revisão de 09/11 (docs/OVOS_V2_DESIGN.md §3): o Pequeno só dava o Humano (sempre repetido) e o
	-- Goblin não estava em nenhum ovo. Pequeno = Comum + Incomum; Médio = Incomum + Raro.
	small = { { tag = "Comum", share = 0.6 }, { tag = "Incomum", share = 0.4 } },
	medium = { { tag = "Incomum", share = 0.7 }, { tag = "Raro", share = 0.3 } },
	large = { { tag = "Raro", share = 0.7 }, { tag = "Épico", share = 0.3 } },
	huge = { { tag = "Épico", share = 0.7 }, { tag = "Lendário", share = 0.3 } },
	massive = { { tag = "Lendário", share = 0.7 }, { tag = "Mítico", share = 0.3 } },
} :: { [string]: { { tag: string, share: number } } }

-- Espécies elegíveis de uma raridade (nunca as de Robux; as iniciais não ficam em Config.Species).
function EggDropTables.speciesOf(tag: string): { string }
	local out = {}
	for _, sp in Config.Species do
		if sp.rarityTag == tag and not sp.robux then
			table.insert(out, sp.id)
		end
	end
	table.sort(out)
	return out
end

-- Pesos finais { [speciesId] = peso } de um tamanho. Faixa sem espécie: a parte dela vai para as outras.
function EggDropTables.weights(size: string): { [string]: number }
	local bands = EggDropTables.Bands[size]
	assert(bands, `ovo desconhecido {size}`)
	local out: { [string]: number } = {}
	local usable = 0
	for _, b in bands do
		if #EggDropTables.speciesOf(b.tag) > 0 then
			usable += b.share
		end
	end
	for _, b in bands do
		local list = EggDropTables.speciesOf(b.tag)
		for _, id in list do
			out[id] = (out[id] or 0) + 100 * (b.share / usable) / #list
		end
	end
	return out
end

return EggDropTables
