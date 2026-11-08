--!strict
-- ObjectiveHintService: mostra 1 dica de "próximo objetivo" por vez, priorizada.
-- Regra de ouro: nunca mais de 1 hint visível.

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")

local Shared     = script.Parent.Parent.shared
local Config     = require(Shared.Config.ObjectiveHints)
local Features   = require(Shared.Config.Features)
local Remotes    = require(Shared.Remotes)
local Analytics  = require(Shared.Analytics)

-- ADAPTAR: requires reais dos serviços
local GiantService = require(script.Parent.GiantService)
local DropService  = require(script.Parent.DropService)
local RaidService  = require(script.Parent.RaidService)
local ClashService = require(script.Parent.ClashService)
-- local CodexService = require(script.Parent.CodexService)
-- local EggService   = require(script.Parent.EggService)

local ObjectiveHintService = {}

local lastShownId: { [Player]: string? } = {}

local function getProfile(player: Player)
    return _G.Profiles and _G.Profiles[player]
end

local function isEnabled(): boolean
    return Features.get and Features.get("ObjectiveHints", false) or false
end

-- ============================================================================
-- Providers de candidatos
-- Cada provider retorna { id, text, category } ou nil.
-- Menor priority = mais importante.
-- ============================================================================

type Hint = { id: string, text: string, category: string }
type Provider = { id: string, priority: number, build: (Player, any) -> Hint? }

local providers: { Provider } = {

    -- P10: comida perto (imediato)
    {
        id = "food_nearby",
        priority = 10,
        build = function(player, profile)
            -- ADAPTAR: método real de consulta
            local hasNearby = GiantService and GiantService.HasNearbyFood
                and GiantService:HasNearbyFood(player, Config.NearbyFoodRadius)
            if hasNearby then
                return {
                    id = "food_nearby",
                    text = "🍖 Há comida perto de você — pegue antes!",
                    category = "immediate",
                }
            end
            return nil
        end,
    },

    -- P20: raid iminente
    {
        id = "raid_imminent",
        priority = 20,
        build = function(player, profile)
            if not RaidService or not RaidService.GetNextRaid then return nil end
            local raid = RaidService:GetNextRaid()
            if raid and raid.startsInSeconds and raid.startsInSeconds <= Config.ImminentEventSeconds then
                return {
                    id = "raid_imminent",
                    text = ("🐉 Boss Raid em %d:%02d — junte-se ao time!"):format(
                        math.floor(raid.startsInSeconds / 60),
                        raid.startsInSeconds % 60
                    ),
                    category = "imminent",
                }
            end
            return nil
        end,
    },

    -- P25: clash iminente
    {
        id = "clash_imminent",
        priority = 25,
        build = function(player, profile)
            if not ClashService or not ClashService.GetNextClash then return nil end
            local clash = ClashService:GetNextClash()
            if clash and clash.startsInSeconds and clash.startsInSeconds <= Config.ImminentEventSeconds then
                return {
                    id = "clash_imminent",
                    text = ("⚔️ Giant Clash em %d:%02d — entre na arena!"):format(
                        math.floor(clash.startsInSeconds / 60),
                        clash.startsInSeconds % 60
                    ),
                    category = "imminent",
                }
            end
            return nil
        end,
    },

    -- P40: ovo chocando
    {
        id = "egg_soon",
        priority = 40,
        build = function(player, profile)
            if not profile or not profile.eggs then return nil end
            local egg = profile.eggs.incubating
            if egg and egg.hatchAt and egg.hatchAt > os.time() then
                local remaining = egg.hatchAt - os.time()
                if remaining < 3600 then
                    return {
                        id = "egg_soon",
                        text = ("🥚 Seu ovo choca em %d min!"):format(math.ceil(remaining / 60)),
                        category = "short",
                    }
                end
            end
            return nil
        end,
    },

    -- P50: missão semanal (resgate pendente ou progresso)
    {
        id = "quest_claim",
        priority = 50,
        build = function(player, profile)
            if not profile or not profile.weeklyQuest then return nil end
            local quest = profile.weeklyQuest
            if not quest.chosenId then return nil end

            local progress = (quest.progressById and quest.progressById[quest.chosenId]) or 0
            local target   = Config.WeeklyQuestTargets[quest.chosenId] or 10

            if progress >= target and not quest.claimed then
                return {
                    id = "quest_claim",
                    text = "🎁 Sua missão semanal está completa — resgate a recompensa!",
                    category = "short",
                }
            end
            if progress > 0 and progress < target then
                return {
                    id = "quest_progress",
                    text = ("📋 Missão semanal: %d/%d"):format(progress, target),
                    category = "short",
                }
            end
            return nil
        end,
    },

    -- P70: coleção incompleta
    {
        id = "codex_gap",
        priority = 70,
        build = function(player, profile)
            if not profile or not profile.codex then return nil end
            -- ADAPTAR: método real
            -- local missing = CodexService:GetMissingCount(player)
            -- if missing > 0 then
            --     return {
            --         id = "codex_gap",
            --         text = ("📖 Faltam %d criaturas para completar sua coleção"):format(missing),
            --         category = "long",
            --     }
            -- end
            return nil
        end,
    },
}

-- ============================================================================
-- Núcleo
-- ============================================================================

local function selectBestHint(player: Player, profile)
    local candidates: { { priority: number, hint: Hint } } = {}

    for _, provider in ipairs(providers) do
        local ok, result = pcall(provider.build, player, profile)
        if ok and result then
            table.insert(candidates, { priority = provider.priority, hint = result })
        end
    end

    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b) return a.priority < b.priority end)

    local best = candidates[1].hint
    -- Evitar repetir a mesma dica se houver outra disponível
    if best.id == lastShownId[player] and #candidates > 1 then
        best = candidates[2].hint
    end

    return best
end

function ObjectiveHintService:_update(player: Player)
    if not isEnabled() then return end
    local profile = getProfile(player)
    if not profile then return end

    -- Durante onboarding, não mostra hints (evita competir com tutorial)
    if profile.onboarding
       and profile.onboarding.completedAt
       and profile.onboarding.completedAt == 0 then
        return
    end

    local hint = selectBestHint(player, profile)

    if hint then
        Remotes.ObjectiveHintUpdate:FireClient(player, hint.text, hint.category, hint.id)
        lastShownId[player] = hint.id
        Analytics:emit("objective_shown", {
            player = player,
            hint_id = hint.id,
            category = hint.category,
        })
    else
        Remotes.ObjectiveHintUpdate:FireClient(player, "", "none", nil)
        lastShownId[player] = nil
    end
end

function ObjectiveHintService:OnPlayerAdded(player: Player)
    lastShownId[player] = nil
    task.delay(6, function()
        self:_update(player)
    end)
end

function ObjectiveHintService:OnPlayerRemoving(player: Player)
    lastShownId[player] = nil
end

-- ============================================================================
-- Init
-- ============================================================================

function ObjectiveHintService.Init()
    if not isEnabled() then
        warn("[ObjectiveHintService] Desativado por Features flag")
        return
    end

    Players.PlayerAdded:Connect(function(p) ObjectiveHintService:OnPlayerAdded(p) end)
    Players.PlayerRemoving:Connect(function(p) ObjectiveHintService:OnPlayerRemoving(p) end)

    -- Loop de atualização
    task.spawn(function()
        while true do
            task.wait(Config.UpdateIntervalSeconds)
            for _, player in ipairs(Players:GetPlayers()) do
                ObjectiveHintService:_update(player)
            end
        end
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        task.spawn(function() ObjectiveHintService:OnPlayerAdded(p) end)
    end
end

-- API pública: outros serviços podem forçar atualização
-- (ex: quando jogador completa missão, pega comida, etc.)
function ObjectiveHintService:RequestUpdate(player: Player)
    self:_update(player)
end

-- API pública: jogador clicou na dica (para analytics)
function ObjectiveHintService:ReportHintActed(player: Player, hintId: string)
    Analytics:emit("objective_acted_on", {
        player = player,
        hint_id = hintId,
    })
end

return ObjectiveHintService