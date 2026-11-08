--!strict
-- Config das 7 fases do onboarding e timeouts.
-- Usar os assets/efeitos reais do projeto onde marcado.

local OnboardingConfig = {}

OnboardingConfig.Phase = {
    SPAWN_CINEMATIC = 1,
    FIRST_FEED      = 2,
    EGG_TUTORIAL    = 3,
    SPECIES_REVEAL  = 4,
    FIRST_PUNCH     = 5,
    WORLD_REVEAL    = 6,
    RETURN_HOOKS    = 7,
    DONE            = 8,
}

-- Timeout em segundos por fase (avança mesmo sem ação do jogador)
OnboardingConfig.PhaseTimeouts = {
    [1] = 15,   -- spawn cinematic
    [2] = 45,   -- first feed
    [3] = 90,   -- egg tutorial (eclosão)
    [4] = 45,   -- species reveal
    [5] = 60,   -- first punch
    [6] = 45,   -- world reveal
    [7] = 30,   -- return hooks
}

-- Configurações específicas
OnboardingConfig.EggTutorialId = "egg_tutorial_human" -- ADAPTAR: ID do ovo garantido
OnboardingConfig.SpeciesChoices = { -- 3 opções apresentadas na fase 4
    "fire",
    "ice",
    "stone",
}

-- Duração da incubação do ovo tutorial (segundos)
OnboardingConfig.TutorialEggHatchSeconds = 45

-- Presente de boas-vindas (fase 7)
OnboardingConfig.WelcomeGift = {
    rewardId = "lunchbox_basic", -- ADAPTAR: item real do projeto
    quantity = 1,
}

return OnboardingConfig