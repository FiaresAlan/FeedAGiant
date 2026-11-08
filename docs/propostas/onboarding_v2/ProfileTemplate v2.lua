function ProfileTemplate:migrate(old)
    old = old or {}
    -- ... migrações existentes ...

    -- v2: onboarding v2
    if not old.onboarding then
        old.onboarding = { phase = 1, completedAt = 0 }
    end
    if not old.objectiveHint then
        old.objectiveHint = { lastShownId = nil, lastShownAt = 0, dismissedToday = {} }
    end
    if not old.mysteryChest then
        old.mysteryChest = { unlockAt = 0 }
    end
    if old.welcomeGiftClaimed == nil then
        old.welcomeGiftClaimed = false
    end

    old.version = 2
    return old
end