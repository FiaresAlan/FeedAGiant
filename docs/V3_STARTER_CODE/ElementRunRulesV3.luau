--!strict
-- Snippet V3: regra pura para o Claude adaptar à arquitetura existente.
-- NÃO conectar aos Remotes sem validações, cooldowns, stamina e QA.
local Rules = {}

Rules.BASE_SPEED = 20
Rules.HARD_SPEED_CAP = 31
Rules.SPRINT_MULTIPLIER = 1.35
Rules.MAX_PROGRESSION = 1.08
Rules.PENALTIES = table.freeze({
    light = 0,
    medium = 0.10,
    heavy = 0.25,
})
Rules.ELEMENT = table.freeze({
    stone = table.freeze({ cooldown = 25, duration = 4, weightRelief = 0.40, speedBoost = 1 }),
    fire = table.freeze({ cooldown = 25, duration = 3, weightRelief = 0, speedBoost = 1.12 }),
    ice = table.freeze({ cooldown = 30, duration = 2, weightRelief = 0, speedBoost = 1 }),
})

export type SpeedParams = {
    element: string,
    weightClass: string,
    progressionMultiplier: number,
    sprinting: boolean,
    boostActive: boolean,
}

function Rules.validElement(element: string): boolean
    return Rules.ELEMENT[element] ~= nil
end

function Rules.validWeight(weightClass: string): boolean
    return Rules.PENALTIES[weightClass] ~= nil
end

function Rules.speed(params: SpeedParams): number?
    local elemental = Rules.ELEMENT[params.element]
    local rawPenalty = Rules.PENALTIES[params.weightClass]
    if elemental == nil or rawPenalty == nil then
        return nil -- O chamador deve rejeitar categorias de cliente inválidas.
    end

    local progression = math.clamp(params.progressionMultiplier, 1, Rules.MAX_PROGRESSION)
    local relief = params.boostActive and elemental.weightRelief or 0
    local minimumPenalty = if params.weightClass == "heavy" then 0.08 else 0
    local effectivePenalty = math.max(minimumPenalty, rawPenalty * (1 - relief))
    local sprintMultiplier = if params.sprinting then Rules.SPRINT_MULTIPLIER else 1
    local boostMultiplier = if params.boostActive then elemental.speedBoost else 1
    local result = Rules.BASE_SPEED * progression * (1 - effectivePenalty) * sprintMultiplier * boostMultiplier
    return math.min(Rules.HARD_SPEED_CAP, result)
end

function Rules.countersInterrupt(element: string, boostActive: boolean, alreadyConsumed: boolean): boolean
    return element == "ice" and boostActive and not alreadyConsumed
end

return Rules
