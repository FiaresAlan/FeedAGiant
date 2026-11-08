--!strict
-- OnboardingService: gerencia as 7 fases dos primeiros 4 minutos.
-- Substitui o onboarding atual (se existir). Flags em Features.lua.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ADAPTAR: caminhos de require conforme estrutura real
local Shared     = script.Parent.Parent.shared
local Config     = require(Shared.Config.Onboarding)
local Features   = require(Shared.Config.Features)
local Remotes    = require(Shared.Remotes)
local Analytics  = require(Shared.Analytics)
-- local ProfileTemplate = require(Shared.ProfileTemplate) -- não usado diretamente aqui

-- ADAPTAR: requires de serviços dependentes
local GiantService = require(script.Parent.GiantService)
local DropService  = require(script.Parent.DropService)
local RaidService  = require(script.Parent.RaidService)
local ClashService = require(script.Parent.ClashService)
-- local EggService   = require(script.Parent.EggService)   -- se existir
-- local CodexService = require(script.Parent.CodexService) -- se existir

local OnboardingService = {}

local activePhases:  { [Player]: number }  = {}
local phaseTokens:   { [Player]: any }     = {}  -- tokens para invalidar timeouts
local startedAt:     { [Player]: number }  = {}

-- ============================================================================
-- Helpers
-- ============================================================================

-- ADAPTAR: substituir pela API real do seu data manager
local function getProfile(player: Player)
    return _G.Profiles and _G.Profiles[player]
end

local function isEnabled(): boolean
    -- ADAPTAR: API real de Features
    return Features.get and Features.get("OnboardingV2", false) or false
end

local function clearPhaseTimeout(player: Player)
    phaseTokens[player] = nil -- invalida qualquer timeout pendente
end

-- ============================================================================
-- Handlers por fase
-- ============================================================================

local phaseHandlers: { [number]: { start: (Player, any) -> () } } = {}

phaseHandlers[Config.Phase.SPAWN_CINEMATIC] = {
    start = function(player, profile)
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.SPAWN_CINEMATIC)
        Analytics:emit("onboarding_phase_started", { player = player, phase = 1 })
    end,
}

phaseHandlers[Config.Phase.FIRST_FEED] = {
    start = function(player, profile)
        local basePos = GiantService:GetBasePosition(player) -- ADAPTAR: método real
        if basePos then
            DropService:SpawnTutorialFood(player, basePos + Vector3.new(0, 3, 6))
        end
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.FIRST_FEED)
        Analytics:emit("onboarding_phase_started", { player = player, phase = 2 })
    end,
}

phaseHandlers[Config.Phase.EGG_TUTORIAL] = {
    start = function(player, profile)
        -- ADAPTAR: chamada real ao serviço de ovos
        -- if EggService and EggService.GrantTutorialEgg then
        --     EggService:GrantTutorialEgg(player, Config.EggTutorialId)
        -- end
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.EGG_TUTORIAL, {
            hatchSeconds = Config.TutorialEggHatchSeconds,
        })
        Analytics:emit("onboarding_phase_started", { player = player, phase = 3 })
    end,
}

phaseHandlers[Config.Phase.SPECIES_REVEAL] = {
    start = function(player, profile)
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.SPECIES_REVEAL, {
            choices = Config.SpeciesChoices,
        })
        Analytics:emit("onboarding_phase_started", { player = player, phase = 4 })
    end,
}

phaseHandlers[Config.Phase.FIRST_PUNCH] = {
    start = function(player, profile)
        local basePos = GiantService:GetBasePosition(player)
        if basePos then
            -- ADAPTAR: método real para spawnar NPC de treino
            -- GiantService:SpawnTrainingNpc(player, basePos + Vector3.new(0, 0, 8))
        end
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.FIRST_PUNCH)
        Analytics:emit("onboarding_phase_started", { player = player, phase = 5 })
    end,
}

phaseHandlers[Config.Phase.WORLD_REVEAL] = {
    start = function(player, profile)
        -- Descobre o próximo evento mais iminente
        local raid  = RaidService and RaidService:GetNextRaid()
        local clash = ClashService and ClashService:GetNextClash()
        local payload = { raid = raid, clash = clash }

        Remotes.OnboardingBegin:FireClient(player, Config.Phase.WORLD_REVEAL, payload)
        Analytics:emit("onboarding_phase_started", { player = player, phase = 6 })
    end,
}

phaseHandlers[Config.Phase.RETURN_HOOKS] = {
    start = function(player, profile)
        if profile then
            -- Inicia streak no dia 1
            profile.streak.count      = 1
            profile.streak.lastFedDay = os.time()
            -- Baú misterioso 24h
            profile.mysteryChest.unlockAt = os.time() + 24 * 60 * 60
            -- Presente de boas-vindas fica PENDENTE (o jogador precisa clicar)
            profile.welcomeGiftClaimed = false
        end
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.RETURN_HOOKS)
        Analytics:emit("onboarding_phase_started", { player = player, phase = 7 })
    end,
}

phaseHandlers[Config.Phase.DONE] = {
    start = function(player, profile)
        if profile then
            profile.onboarding.phase       = Config.Phase.DONE
            profile.onboarding.completedAt = os.time()
        end
        local elapsed = os.time() - (startedAt[player] or os.time())
        Remotes.OnboardingBegin:FireClient(player, Config.Phase.DONE)
        Analytics:emit("onboarding_finished", {
            player = player,
            duration_seconds = elapsed,
        })
        startedAt[player] = nil
    end,
}

-- ============================================================================
-- Núcleo da máquina de estados
-- ============================================================================

function OnboardingService:_setPhase(player: Player, newPhase: number)
    if not isEnabled() then return end
    local profile = getProfile(player)
    if not profile then return end

    -- Já completou? Não mexe.
    if profile.onboarding.completedAt and profile.onboarding.completedAt > 0 then
        return
    end

    profile.onboarding.phase = newPhase
    activePhases[player]    = newPhase

    local handler = phaseHandlers[newPhase]
    if handler then
        local ok, err = pcall(handler.start, player, profile)
        if not ok then
            warn(("[OnboardingService] Fase %d falhou para %s: %s"):format(
                newPhase, player.Name, tostring(err)))
        end
    end

    -- Configura timeout para a próxima fase
    clearPhaseTimeout(player)
    if newPhase ~= Config.Phase.DONE then
        local timeoutSec = Config.PhaseTimeouts[newPhase] or 60
        local token = {}
        phaseTokens[player] = token

        task.delay(timeoutSec, function()
            -- Se o token ainda for o atual, avança por timeout
            if phaseTokens[player] == token and activePhases[player] == newPhase then
                warn(("[OnboardingService] Timeout na fase %d para %s"):format(newPhase, player.Name))
                Analytics:emit("onboarding_phase_timeout", {
                    player = player, phase = newPhase,
                })
                self:_setPhase(player, newPhase + 1)
            end
        end)
    end
end

function OnboardingService:OnPlayerAdded(player: Player)
    if not isEnabled() then return end
    local profile = getProfile(player)
    if not profile then return end

    -- Já completou → não faz nada
    if profile.onboarding.completedAt and profile.onboarding.completedAt > 0 then
        return
    end

    startedAt[player] = os.time()

    local current = math.max(
        profile.onboarding.phase or 1,
        Config.Phase.SPAWN_CINEMATIC
    )
    self:_setPhase(player, current)
end

function OnboardingService:OnPlayerRemoving(player: Player)
    clearPhaseTimeout(player)
    activePhases[player] = nil
    startedAt[player]    = nil
end

-- ============================================================================
-- Remote handlers
-- ============================================================================

local function handlePhaseComplete(player: Player, reportedPhase: number)
    if not isEnabled() then return end
    local profile = getProfile(player)
    if not profile then return end
    if profile.onboarding.completedAt and profile.onboarding.completedAt > 0 then
        return
    end

    local current = activePhases[player] or profile.onboarding.phase
    if reportedPhase ~= current then
        -- Race condition ou client desatualizado — ignorar
        return
    end

    Analytics:emit("onboarding_phase_completed", {
        player = player,
        phase = current,
        duration_seconds = os.time() - (startedAt[player] or os.time()),
    })

    self:_setPhase(player, current + 1)
end

-- ============================================================================
-- Init
-- ============================================================================

function OnboardingService.Init()
    if not isEnabled() then
        warn("[OnboardingService] Desativado por Features flag")
        return
    end

    Players.PlayerAdded:Connect(function(p) OnboardingService:OnPlayerAdded(p) end)
    Players.PlayerRemoving:Connect(function(p) OnboardingService:OnPlayerRemoving(p) end)

    Remotes.OnboardingPhaseComplete.OnServerEvent:Connect(handlePhaseComplete)

    for _, p in ipairs(Players:GetPlayers()) do
        task.spawn(function() OnboardingService:OnPlayerAdded(p) end)
    end
end

-- Debug: forçar fase no Studio
function OnboardingService:DebugSetPhase(player: Player, phase: number)
    if RunService:IsStudio() then
        self:_setPhase(player, phase)
    end
end

return OnboardingService