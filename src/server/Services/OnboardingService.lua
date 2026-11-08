--!strict
-- OnboardingService (especificação v3 §3, ADAPTADO; Features.OnboardingV2).
-- O jogo já tem um tutorial de 4 passos (TutorialService: alimentar → pátio → lunchbox → crescer),
-- com funil próprio. Este serviço NÃO o substitui: acrescenta só o que a especificação tem de novo
-- e que cabe no jogo sem mudar a economia nem as decisões do briefing:
--   1. Chegada: câmera de 2,5 s diante do PRÓPRIO gigante na primeira entrada (cliente).
--   2. Primeira alimentação com efeito dobrado (tremida, FOV, zoom) — o cliente pede ao servidor
--      apenas o sinal "é a primeira", o servidor decide pelo perfil (totalFeeds).
--   3. Presente de boas-vindas no fim do tutorial: 1 Lunchbox Comum GUARDADA na base (o jogador
--      abre clicando; nunca automático). Uma vez por conta (welcomeGiven).
-- O que ficou de fora e por quê está em docs/VALIDACAO_ESPEC_V3.md (ovo, escolha de espécie
-- grátis, soco guiado, baú de 24 h).
local Players = game:GetService("Players")

local Features = require(game.ReplicatedStorage.Shared.Features)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local Hooks = require(script.Parent.Parent.Hooks)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local OnboardingService = {}

local firstFeedPending: { [Player]: boolean } = {}

local function isNewPlayer(profile: any): boolean
	return profile.onboardingAt == 0 and profile.totalFeeds == 0 and profile.totalBoxes == 0
end

-- Chamado pelo Main depois que a base e o gigante existem.
function OnboardingService.onJoin(player: Player)
	if not Features.on("OnboardingV2") then
		return
	end
	local profile = DataService.get(player)
	if not profile or not isNewPlayer(profile) then
		return
	end
	firstFeedPending[player] = true
	Analytics.event(player, "onboarding_phase_started", 1, { "arrival" })
	-- espera o personagem existir para a câmera ter onde focar
	task.delay(1.5, function()
		if player.Parent then
			Remotes.OnboardingV2:FireClient(player, { kind = "Arrival", seconds = GameRules.Onboarding.ArrivalSeconds })
		end
	end)
end

-- Fim do tutorial (TutorialService.onFinished). Pulou = veterano: não ganha presente de novato.
function OnboardingService.onTutorialFinished(player: Player, skipped: boolean)
	if not Features.on("OnboardingV2") then
		return
	end
	local profile = DataService.get(player)
	if not profile or profile.welcomeGiven then
		return
	end
	profile.welcomeGiven = true
	profile.onboardingAt = os.time()
	if skipped then
		DataService.markDirty(player)
		Analytics.event(player, "onboarding_finished", 0, { "skipped" })
		return
	end
	local pending = profile.pendingBoxes
	table.insert(pending, GameRules.Onboarding.WelcomeBox)
	DataService.markDirty(player)
	PlotService.pushState(player)
	Remotes.PendingBox:FireClient(player, { boxId = GameRules.Onboarding.WelcomeBox, count = #pending })
	Remotes.Notify:FireClient(player, {
		text = "PRESENTE DE BOAS-VINDAS! Uma Lunchbox está guardada na sua base: abra quando quiser.",
		color = Color3.fromRGB(255, 220, 80),
	})
	Remotes.OnboardingV2:FireClient(player, { kind = "Done" })
	Analytics.event(player, "onboarding_finished", 1, { "gift" })
end

function OnboardingService.init()
	-- Primeira alimentação: o servidor manda o "efeito dobrado" só para o próprio jogador.
	Hooks.on("fed", function(player: Player)
		if firstFeedPending[player] then
			firstFeedPending[player] = nil
			Remotes.OnboardingV2:FireClient(player, { kind = "FirstFeed" })
			Analytics.event(player, "onboarding_phase_started", 2, { "first_feed" })
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		firstFeedPending[p] = nil
	end)
end

return OnboardingService
