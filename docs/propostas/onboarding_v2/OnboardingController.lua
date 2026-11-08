--!strict
-- OnboardingController: efeitos visuais e de áudio das fases do onboarding.
-- Toda ação do jogador avança a fase (envia OnboardingPhaseComplete pro server).

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ADAPTAR requires
local Shared  = ReplicatedStorage:WaitForChild("shared")
local Config  = require(Shared.Config.Onboarding)
local Remotes = require(Shared.Remotes)
-- local Sounds  = require(Shared.Sounds) -- se existir

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local OnboardingController = {}

local currentPhase = 0
local cameraShakeBind: RBXScriptConnection? = nil
local savedCameraType = camera.CameraType

-- ============================================================================
-- Helpers de efeito
-- ============================================================================

-- Screen shake suave: amplitude em studs, duração em segundos
local function screenShake(amplitude: number, duration: number)
    local elapsed = 0
    local start = tick()

    if cameraShakeBind then cameraShakeBind:Disconnect() end
    cameraShakeBind = RunService.RenderStepped:Connect(function(dt)
        elapsed = tick() - start
        if elapsed >= duration then
            cameraShakeBind:Disconnect()
            cameraShakeBind = nil
            return
        end
        local decay = 1 - (elapsed / duration)
        local offsetX = math.sin(elapsed * 40) * amplitude * decay
        local offsetY = math.cos(elapsed * 37) * amplitude * decay
        camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0)
    end)
end

-- FOV pulse: aumenta temporariamente e volta
local function fovPulse(delta: number, duration: number)
    local defaultFov = 70
    local tween = TweenService:Create(camera,
        TweenInfo.new(duration / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { FieldOfView = defaultFov + delta })
    tween:Play()
    task.delay(duration / 2, function()
        local back = TweenService:Create(camera,
            TweenInfo.new(duration / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            { FieldOfView = defaultFov })
        back:Play()
    end)
end

-- Zoom rápido no Gigante (ida e volta)
local function quickZoomOnGiant(focusPart: BasePart?, duration: number)
    if not focusPart then return end
    local originalCFrame = camera.CFrame
    local lookCFrame = CFrame.lookAt(
        focusPart.Position + Vector3.new(0, 5, -12),
        focusPart.Position
    )
    camera.CameraType = Enum.CameraType.Scriptable

    local go = TweenService:Create(camera,
        TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = lookCFrame })
    go:Play()
    go.Completed:Wait()

    local back = TweenService:Create(camera,
        TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { CFrame = originalCFrame })
    back:Play()
    back.Completed:Wait()

    camera.CameraType = savedCameraType
end

-- ============================================================================
-- Handlers de fase (client-side effects)
-- ============================================================================

local function completePhase(phase: number)
    Remotes.OnboardingPhaseComplete:FireServer(phase)
end

local phaseEffects: { [number]: (any) -> () } = {}

phaseEffects[Config.Phase.SPAWN_CINEMATIC] = function()
    -- Câmera cinematográfica de baixo pra cima no Gigante do jogador
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    camera.CameraType = Enum.CameraType.Scriptable
    local startCFrame = CFrame.lookAt(
        root.Position + Vector3.new(0, -8, 15),
        root.Position + Vector3.new(0, 5, 0)
    )
    local endCFrame = CFrame.lookAt(
        root.Position + Vector3.new(0, 4, 10),
        root.Position + Vector3.new(0, 6, 0)
    )
    camera.CFrame = startCFrame

    local tween = TweenService:Create(camera,
        TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = endCFrame })
    tween:Play()

    task.delay(2, function()
        camera.CameraType = savedCameraType
        completePhase(Config.Phase.SPAWN_CINEMATIC)
    end)
end

phaseEffects[Config.Phase.FIRST_FEED] = function()
    -- Aguarda o jogador alimentar 3 vezes (via RemoteEvent existente)
    -- ADAPTAR: hook no GiantService.OnFedRemote
    local feedCount = 0
    local conn
    conn = Remotes.GiantFed.OnClientEvent:Connect(function()
        feedCount += 1
        screenShake(0.4, 0.25)
        fovPulse(5, 0.3)
        -- TODO: tocar som de impacto forte
        if feedCount >= 3 then
            conn:Disconnect()
            completePhase(Config.Phase.FIRST_FEED)
        end
    end)
end

phaseEffects[Config.Phase.EGG_TUTORIAL] = function(payload)
    -- UI de ovo com cronômetro (payload.hatchSeconds)
    -- TODO: montar UI de cronômetro e chuva de comida exclusiva
    task.delay((payload and payload.hatchSeconds or 45) + 1, function()
        completePhase(Config.Phase.EGG_TUTORIAL)
    end)
end

phaseEffects[Config.Phase.SPECIES_REVEAL] = function(payload)
    -- TODO: montar modal com 3 cards de espécie
    -- Ao escolher, chamar Remotes.SetSpecies e completePhase
    -- Quando o server confirmar transformação: completePhase
    Remotes.SpeciesSelected.OnClientEvent:Once(function()
        completePhase(Config.Phase.SPECIES_REVEAL)
    end)
end

phaseEffects[Config.Phase.FIRST_PUNCH] = function()
    -- Ouve a primeira confirmação de soco
    Remotes.GiantPunched.OnClientEvent:Once(function()
        screenShake(0.6, 0.2)
        fovPulse(7, 0.25)
        task.delay(0.5, function()
            completePhase(Config.Phase.FIRST_PUNCH)
        end)
    end)
end

phaseEffects[Config.Phase.WORLD_REVEAL] = function(payload)
    -- Pan suave da câmera na direção de um Gigante DEUS (se houver)
    -- TODO: encontrar um jogador com Gigante DEUS no server; se não houver, mostrar showcase
    task.delay(3, function()
        completePhase(Config.Phase.WORLD_REVEAL)
    end)
end

phaseEffects[Config.Phase.RETURN_HOOKS] = function()
    -- TODO: mostrar UI de "presente resgatável" piscando
    -- TODO: mostrar streak "Dia 1/7"
    -- TODO: mostrar missão curta com progresso
    -- TODO: mostrar baú misterioso trancado "Volte em 24h"
    task.delay(3, function()
        completePhase(Config.Phase.RETURN_HOOKS)
    end)
end

phaseEffects[Config.Phase.DONE] = function()
    -- Reabilitar HUD normal (loja, inventário, rank)
    -- TODO: SetHudEnabled(true)
end

-- ============================================================================
-- Init
-- ============================================================================

function OnboardingController.Init()
    savedCameraType = camera.CameraType

    Remotes.OnboardingBegin.OnClientEvent:Connect(function(phase, payload)
        currentPhase = phase
        local fn = phaseEffects[phase]
        if fn then
            local ok, err = pcall(fn, payload)
            if not ok then
                warn(("[OnboardingController] Fase %d falhou: %s"):format(phase, tostring(err)))
                -- Não travar jogador: avança
                completePhase(phase)
            end
        else
            -- Fase sem efeito definido → avança
            completePhase(phase)
        end
    end)
end

return OnboardingController