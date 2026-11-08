--!strict
-- Tutorial (cliente) — Fase 4: faixa do objetivo, dicas quando trava, trilha até a loja, botão Pular
-- com confirmação e uma pequena comemoração a cada passo. O servidor é dono do progresso e das
-- recompensas (TutorialService + módulo FwjelaaTutorial do fwjelaa).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Steps = require(game.ReplicatedStorage.Shared.TutorialSteps) :: { any }
local UI = require(script.Parent.Parent.UI)
local HUD = require(script.Parent.HUD)

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
		-- HUD nova (08/11): o objetivo e a dica aparecem DENTRO do cartão de META (embaixo à esquerda),
		-- como na referência do usuário. As faixas próprias do módulo ficam desligadas; o texto delas é
		-- espelhado no cartão (o módulo continua dono do progresso, das trilhas e dos destaques no mundo).
		local card = HUD.goalCard
		local function mirror(src: Instance?, dst: TextLabel?)
			if not src or not src:IsA("TextLabel") or not dst then
				return
			end
			local srcLabel: TextLabel = src
			local function sync()
				dst.Text = srcLabel.Text
				dst.Visible = srcLabel.Visible and srcLabel.Text ~= ""
			end
			srcLabel:GetPropertyChangedSignal("Text"):Connect(sync)
			srcLabel:GetPropertyChangedSignal("Visible"):Connect(sync)
			sync()
		end
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = false
			-- Medido no celular (08/11/2026): o módulo religava a própria faixa no topo, duplicando o texto do
			-- cartão de META e tampando o selo de evento. Ela fica sempre desligada.
			local tutorialGui: ScreenGui = gui
			tutorialGui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if tutorialGui.Enabled then
					tutorialGui.Enabled = false
				end
			end)
			mirror(gui:FindFirstChild("Objective", true), HUD.goalObjective)
			mirror(gui:FindFirstChild("Hint", true), HUD.goalHint)
		end

		-- Botão Pular (46 px de toque, confirmação em 2 toques), dentro do cartão de META.
		local skip: TextButton? = nil
		if card then
			local b = UI.button(card, "Pular tutorial", Color3.fromRGB(96, 102, 118), {
				Name = "TutorialSkip",
				Size = UDim2.fromOffset(240, 46),
				TextScaled = false,
				TextSize = 20,
				LayoutOrder = 4,
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
