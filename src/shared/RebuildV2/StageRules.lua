--!strict
-- V3: evolucao visual NA BASE em tres marcos, sem mexer no nivel/XP persistidos.
-- Na pista, todos os rigs montados mantem dimensoes iguais, independentemente do nivel.
local Rules = {}
Rules.YOUNG_LEVEL = 10
Rules.COLOSSUS_LEVEL = 30

function Rules.stage(level: number): (string, string, number)
	local n = if type(level) == "number" and level == level then math.max(1, level) else 1
	if n >= Rules.COLOSSUS_LEVEL then
		return "colossus", "Colosso", 2.2
	elseif n >= Rules.YOUNG_LEVEL then
		return "young", "Jovem", 1.75
	end
	return "baby", "Bebê", 1.35
end

function Rules.style(level: number, baseStage: any): any
	local key, name = Rules.stage(level)
	local result = table.clone(baseStage)
	result.name = name
	if key == "colossus" then
		result.minLevel = Rules.COLOSSUS_LEVEL
		result.teeth = true
		result.horns = true
		result.mouthWidth = 0.9
	elseif key == "young" then
		result.minLevel = Rules.YOUNG_LEVEL
		result.teeth = true
		result.horns = false
		result.mouthWidth = 0.7
	else
		result.minLevel = 1
		result.teeth = false
		result.horns = false
		result.mouthWidth = 0.5
	end
	return result
end

return Rules
