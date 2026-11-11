--!strict
-- Regras deterministicas da corrida; cliente somente visualiza, servidor e autoridade.
local Rules = {}

Rules.BASE_SPEED = 20
Rules.MAX_LEVEL_FACTOR = 1.08
Rules.SPRINT_MULT = 1.35
Rules.STAMINA_MAX = 100
Rules.SPRINT_DRAIN_PER_SEC = 20
Rules.STAMINA_RECOVER_PER_SEC = 14
Rules.WEIGHT_PENALTIES = { light = 0, medium = 0.10, heavy = 0.25 }
Rules.BOOSTS = {
	stone_starter = { seconds = 4, cooldown = 25, relief = 0.40 },
	fire_starter = { seconds = 3, cooldown = 25, multiplier = 1.12 },
	ice_starter = { seconds = 2, cooldown = 30, shield = true },
}

function Rules.isWeightClass(weight: any): boolean
	return weight == "light" or weight == "medium" or weight == "heavy"
end

function Rules.progressionFactor(level: number): number
	-- Retornos decrescentes: nivel e XP importam sem tornar veteranos inalcançaveis.
	return 1 + math.min(math.max(level - 1, 0) / 60, 1) * 0.08
end

function Rules.speed(level: number, weight: string, sprinting: boolean, species: string, boostActive: boolean): number
	if not Rules.isWeightClass(weight) then
		weight = "light"
	end
	local penalty = Rules.WEIGHT_PENALTIES[weight]
	if species == "stone_starter" and boostActive then
		penalty = math.max(if weight == "heavy" then 0.08 else 0, penalty * 0.60)
	end
	local multiplier = if species == "fire_starter" and boostActive then 1.12 else 1
	local sprint = if sprinting then Rules.SPRINT_MULT else 1
	return math.min(31, Rules.BASE_SPEED * Rules.progressionFactor(level) * (1 - penalty) * sprint * multiplier)
end

function Rules.stamina(previous: number, dt: number, sprinting: boolean): number
	if sprinting then
		return math.max(0, previous - Rules.SPRINT_DRAIN_PER_SEC * math.clamp(dt, 0, 1))
	end
	return math.min(Rules.STAMINA_MAX, previous + Rules.STAMINA_RECOVER_PER_SEC * math.clamp(dt, 0, 1))
end

return Rules
