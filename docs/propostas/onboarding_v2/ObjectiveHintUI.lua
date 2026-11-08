--!strict
-- UI da dica de objetivo: 1 cartão, canto da tela, cor por categoria.
-- Não cobre controles mobile (canto superior direito, longe do polegar).

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared  = ReplicatedStorage:WaitForChild("shared")
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ObjectiveHintUI = {}

local COLORS = {
    immediate = Color3.fromRGB(120, 200, 120),  -- verde
    imminent  = Color3.fromRGB(230, 130, 60),   -- laranja
    short     = Color3.fromRGB(230, 200, 60),   -- amarelo
    long      = Color3.fromRGB(160, 120, 230),  -- roxo
    none      = Color3.fromRGB(100, 100, 100),
}

local currentFrame: Frame? = nil
local hideToken: any = nil

local function buildHintFrame(): Frame
    local frame = Instance.new("Frame")
    frame.Name = "ObjectiveHint"
    frame.Size = UDim2.new(0, 320, 0, 56)
    frame.Position = UDim2.new(1, -340, 0, 16) -- canto superior direito
    frame.BackgroundColor3 = COLORS.immediate
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "HintText"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = ""
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = false
    label.TextSize = 16
    label.TextWrapped = true
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    return frame
end

local function showHint(text: string, category: string)
    if not currentFrame then return end

    -- Cancela hide pendente
    hideToken = nil

    local label = currentFrame:FindFirstChild("HintText") :: TextLabel?
    if not label then return end

    if text == "" then
        currentFrame.Visible = false
        return
    end

    label.Text = text
    currentFrame.BackgroundColor3 = COLORS[category] or COLORS.immediate
    currentFrame.Visible = true

    -- Animação de entrada (pop)
    currentFrame.Position = UDim2.new(1, -340, 0, 16)
    local start = currentFrame.Position
    local target = UDim2.new(1, -340, 0, 16)
    -- Pequeno deslocamento inicial
    currentFrame.Position = UDim2.new(1, -340, 0, -60)

    local tween = TweenService:Create(currentFrame,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = target })
    tween:Play()

    -- Auto-hide após 8 segundos (a menos que um novo hint chegue)
    local token = {}
    hideToken = token
    task.delay(8, function()
        if hideToken == token and currentFrame then
            local fadeOut = TweenService:Create(currentFrame,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { BackgroundTransparency = 1 })
            fadeOut:Play()
            fadeOut.Completed:Wait()
            if currentFrame then
                currentFrame.Visible = false
                currentFrame.BackgroundTransparency = 0.15
            end
        end
    end)
end

function ObjectiveHintUI.Init()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ObjectiveHintGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    currentFrame = buildHintFrame()
    currentFrame.Parent = screenGui

    Remotes.ObjectiveHintUpdate.OnClientEvent:Connect(function(text, category, _hintId)
        showHint(text, category)
    end)
end

return ObjectiveHintUI