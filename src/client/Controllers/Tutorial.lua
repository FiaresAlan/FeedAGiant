--!strict
-- Tutorial (cliente) — Fase 4: faixa do objetivo, dicas quando trava, trilha até a loja, botão Pular
-- com confirmação e uma pequena comemoração a cada passo. O servidor é dono do progresso e das
-- recompensas (TutorialService + módulo FwjelaaTutorial do fwjelaa).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Steps = require(game.ReplicatedStorage.Shared.TutorialSteps) :: { any }
local UI = require(script.Parent.Parent.UI)

local Tutorial = {}

function Tutorial.init()
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("TutorialRemote", 60)
		if not remote then
			return
		end
		local module = require(ReplicatedStorage:WaitForChild("fwjelaa"):WaitForChild("FwjelaaTutorial")) :: any
		local player = Players.LocalPlayer
		local ui = module.Client.DefaultUi()

		local gui = player:WaitForChild("PlayerGui"):WaitForChild("FwjelaaTutorialUI", 10)
		-- Objetivo e dica logo ABAIXO do painel do topo da HUD (teste de 08/11: ficavam por cima dele).
		-- O painel ocupa ~160 px no desenho 1080p, na escala do aparelho.
		local function placeBanners()
			if not gui then
				return
			end
			-- abaixo também do chip do escudo (6 + 122 + 36 px no desenho; teste de 08/11)
			local y = 8 + 168 * UI.deviceScale()
			-- Por baixo da HUD do jogo: janelas abertas (loja, coleção) escurecem e cobrem a faixa.
			if gui:IsA("ScreenGui") then
				gui.DisplayOrder = -1
			end
			local objective = gui:FindFirstChild("Objective")
			local hint = gui:FindFirstChild("Hint")
			if objective and objective:IsA("GuiObject") then
				objective.Position = UDim2.new(0.5, 0, 0, y)
				objective.ZIndex = 5
			end
			if hint and hint:IsA("GuiObject") then
				hint.Position = UDim2.new(0.5, 0, 0, y + 46)
				hint.ZIndex = 5
			end
		end
		placeBanners()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(placeBanners)
		end

		-- Botão Pular (46 px de toque, confirmação em 2 toques), no canto inferior esquerdo:
		-- longe da HUD, do painel de disputa (canto superior direito) e do combate (inferior direito).
		local skip: TextButton? = nil
		if gui then
			local b = UI.button(gui, "Pular tutorial", Color3.fromRGB(110, 110, 130), {
				Name = "TutorialSkip",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -12),
				Size = UDim2.fromOffset(170, 46),
				TextScaled = false,
				TextSize = 18,
				Visible = false,
			})
			skip = b
		end
		local client: any = nil
		ui.setSkipVisible = function(visible: boolean)
			if skip then
				skip.Visible = visible
			end
		end
		ui.celebrate = function(_stepId: string)
			UI.sfx("LevelUp", 0.6)
		end
		if skip then
			local confirming = false
			skip.Activated:Connect(function()
				if not confirming then
					confirming = true
					skip.Text = "Tem certeza?"
					task.delay(3, function()
						confirming = false
						skip.Text = "Pular tutorial"
					end)
					return
				end
				client:RequestSkip()
			end)
		end
		client = module.Client.new({ steps = Steps, remote = remote, ui = ui })
		client:Start()
	end)
end

return Tutorial
