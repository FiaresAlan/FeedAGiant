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
local GiantService = require(script.Parent.GiantService)
local GameLogic = require(script.Parent.Parent.GameLogic)
local Guard = require(script.Parent.Parent.Guard)
local StarterSpecies = require(game.ReplicatedStorage.Shared.StarterSpecies)

local OnboardingService = {}

local firstFeedPending: { [Player]: boolean } = {}

local function isNewPlayer(profile: any): boolean
	return profile.onboardingAt == 0 and profile.totalFeeds == 0 and profile.totalBoxes == 0
end

-- Pode ganhar o presente? Só quem foi marcado como novato na 1ª entrada (onboardingAt == -1) e
-- ainda não ganhou. Função pura (testada em tests/V3.spec.luau).
function OnboardingService.giftEligible(onboardingAt: number, welcomeGiven: boolean, skipped: boolean): boolean
	return onboardingAt == -1 and not welcomeGiven and not skipped
end

-- Escolha da espécie inicial (Features.StarterSpecies; prompt v4 §1). Independe do OnboardingV2.
-- Conta nova (nada comido nem comprado) recebe a oferta; fica marcada "?" no perfil até escolher, então
-- quem sai sem escolher recebe de novo na próxima entrada. Sem "pode trocar depois" na tela (pedido).
local function offerStarter(player: Player)
	if not Features.on("StarterSpecies") then
		return
	end
	local profile = DataService.get(player)
	if
		not profile or not GameLogic.starterShouldOffer(profile.starterSpecies, profile.totalFeeds, profile.totalBoxes)
	then
		return
	end
	profile.starterSpecies = "?"
	DataService.markDirty(player)
	local options = {}
	for _, sp in StarterSpecies.List do
		table.insert(options, { id = sp.id, name = sp.name, desc = sp.desc, color = sp.color })
	end
	-- O menu antigo de escolha/chegada nao tem listener na HUD V3.
	-- Preservar oferta no perfil e o RequestStarter, mas nao disparar UI fantasma.
	if not Features.on("RebuildV2") then
		task.delay(5, function()
			if player.Parent and profile.starterSpecies == "?" then
				Remotes.OnboardingV2:FireClient(player, { kind = "StarterChoice", options = options })
				Analytics.event(player, "onboarding_phase_started", 4, { "starter_choice" })
			end
		end)
	end
end

-- Chamado pelo Main depois que a base e o gigante existem.
function OnboardingService.onJoin(player: Player)
	offerStarter(player)
	-- V3 tem seu proprio cartao de jornada; nao iniciar chegada de camera legada.
	if Features.on("RebuildV2") then return end
	if not Features.on("OnboardingV2") then
		return
	end
	local profile = DataService.get(player)
	if not profile or not isNewPlayer(profile) then
		return
	end
	firstFeedPending[player] = true
	-- Marca a conta como "começou como novata" (-1). Só ela pode ganhar o presente no fim do tutorial:
	-- veterano que refaz o tutorial não ganha (revisão cega 08/11). Vira os.time() ao terminar.
	profile.onboardingAt = -1
	DataService.markDirty(player)
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
	if not OnboardingService.giftEligible(profile.onboardingAt, profile.welcomeGiven, skipped) then
		if profile.onboardingAt == -1 then -- novato que pulou: encerra sem presente
			profile.onboardingAt = os.time()
			profile.welcomeGiven = true
			DataService.markDirty(player)
			Analytics.event(player, "onboarding_finished", 0, { "skipped" })
		end
		return
	end
	profile.welcomeGiven = true
	profile.onboardingAt = os.time()
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
	Remotes.RequestStarter.OnServerEvent:Connect(function(player: Player, speciesId: any)
		if not Features.on("StarterSpecies") or not Guard.allow(player, "Species") then
			return
		end
		if GiantService.grantStarterSpecies(player, speciesId) then
			PlotService.pushState(player)
			local sp = StarterSpecies.ById[speciesId]
			Remotes.OnboardingV2:FireClient(player, { kind = "StarterChosen", id = speciesId, name = sp.name })
		end
	end)
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
