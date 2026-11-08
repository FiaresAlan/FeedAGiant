--!strict
-- Config do sistema de dicas de objetivo (1 por vez, priorizadas).

local ObjectiveHintsConfig = {}

-- Intervalo entre atualizações (segundos)
ObjectiveHintsConfig.UpdateIntervalSeconds = 60

-- Distância (studs) para considerar "comida perto"
ObjectiveHintsConfig.NearbyFoodRadius = 30

-- Janela de "iminente" para eventos (segundos)
ObjectiveHintsConfig.ImminentEventSeconds = 180

-- Alvos das missões semanais por ID (usado para a dica de progresso)
-- ADAPTAR: alinhar com WeeklyQuests config
ObjectiveHintsConfig.WeeklyQuestTargets = {
    ["feed_10"]     = 10,
    ["win_5_duels"] = 5,
    ["feed_20"]     = 20,
}

return ObjectiveHintsConfig