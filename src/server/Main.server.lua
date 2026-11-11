--!strict
-- Main.server.lua — ponto de entrada do servidor. Inicializa serviços em ordem e gerencia entrada/saída de jogadores.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local GiantService = require(Services.GiantService)
local PlotService = require(Services.PlotService)
local StealService = require(Services.StealService)
local ShopService = require(Services.ShopService)
local EventService = require(Services.EventService)
local MonetizationService = require(Services.MonetizationService)
local LeaderboardService = require(Services.LeaderboardService)
local CombatService = require(Services.CombatService)
local DropService = require(Services.DropService)
local ArenaService = require(Services.ArenaService)
local TutorialService = require(Services.TutorialService)
local BossService = require(Services.BossService)
local ShieldService = require(Services.ShieldService)
local GiantBattleService = require(Services.GiantBattleService)
local RosterService = require(Services.RosterService)
local ProgressService = require(Services.ProgressService)
local MeatService = require(Services.MeatService)
local AdminService = require(Services.AdminService)
local BotService = require(Services.BotService)
-- Especificação v3 (08/11/2026): tudo atrás de ReplicatedStorage.Shared.Features (desligado)
local ObjectiveHintService = require(Services.ObjectiveHintService)
local OnboardingService = require(Services.OnboardingService)
local EggService = require(Services.EggService)
local EggNotificationService = require(Services.EggNotificationService)
local MutationService = require(Services.MutationService)
local AncestralService = require(Services.AncestralService)
local WelcomeService = require(Services.WelcomeService)
local TravelService = require(Services.TravelService)
local V2CookingService = require(Services.V2CookingService)
local V2WorldService = require(Services.V2WorldService)
local V2MountService = require(Services.V2MountService)
local V2LaneService = require(Services.V2LaneService)
local V2MetricsService = require(Services.V2MetricsService)
local WorldFx = require(script.Parent.WorldFx)
local Speed = require(script.Parent.Speed)
local LightingRecipes = require(game.ReplicatedStorage.Shared.LightingRecipes)

print("[FeedAGiant] Iniciando servidor...")

LightingRecipes.apply("GoldenAfternoon") -- Fase 1: luz, céu e nuvens (um único dono: o servidor)
MapService.init()
V2WorldService.init() -- pista/duas panelas so com RebuildV2 ativo
DataService.init()
V2CookingService.init() -- registra v2Cook antes de DataService.start(); flag OFF por padrao
V2MountService.init()
V2LaneService.init() -- registra v2Race antes de DataService.start()
V2MetricsService.init()
GiantService.init()
PlotService.init()
StealService.init()
ShopService.init()
MonetizationService.init()
LeaderboardService.init()
EventService.init()
CombatService.init()
DropService.init()
ArenaService.init()
BossService.init()
ShieldService.init()
GiantBattleService.init()
RosterService.init()
ProgressService.init()
MeatService.init()
AdminService.init()
BotService.init()
ObjectiveHintService.init()
OnboardingService.init()
EggService.init()
EggNotificationService.init() -- só estrutura: não chama a API (bloqueada até publicar)
MutationService.init() -- noite 09/11: mutações no pátio durante os eventos (flag)
AncestralService.init() -- noite 09/11: Gigante Ancestral, banquete coletivo (flag)
WelcomeService.init() -- noite 09/11: resumo "Bem-vindo de volta" (flag)
TravelService.init() -- 09/11: blips de viagem rápida + turbo da ponte do Dragão
Speed.init() -- 09/11: dono único da velocidade (carga, ponte, Corrida Turbo)
TutorialService.FinishedHook = OnboardingService.onTutorialFinished
AdminService.Bots = BotService
-- Coliseu compartilhado: boxe e gigantes, um de cada vez (item 9.4). O Dragão mora na Ilha do
-- Dragão desde 08/11/2026 (noite) e não ocupa mais o coliseu.
GiantBattleService.IsArenaBusy = function()
	return ArenaService.isBusy()
end
ArenaService.OtherBusy = function()
	return GiantBattleService.isActive()
end
task.spawn(WorldFx.init, GiantService.template) -- água, fogo/fumaça do caldeirão, estátuas
TutorialService.init() -- registra o slice "tutorial" no perfil (antes do DataService.start)
-- Só agora começa a carregar perfis: todos os serviços já registraram o que precisam
-- (PlayerData exige isso; ver fwjelaa-systems, ordem de inicialização).
DataService.start()
TutorialService.start()

local function onPlayerAdded(player: Player)
	-- PlayerData pode levar ~7-25 s se outro servidor ainda segura a sessão (lease).
	local profile = DataService.waitFor(player, 45)
	if not profile then
		-- Load que falhou já desconecta com mensagem própria; isto cobre só o timeout.
		if player.Parent then
			player:Kick("Falha ao carregar seus dados. Nada foi alterado. Tente novamente.")
		end
		return
	end
	local base = MapService.claimBase(player)
	if not base then
		player:Kick("Servidor cheio.")
		return
	end
	GiantService.onPassesChanged(player)
	GiantService.applyDecay(player, profile)
	GiantService.spawnFor(player)
	RosterService.onJoin(player) -- renda offline da exposição (até 8 h) + estátuas da vitrine
	ProgressService.onJoin(player) -- tarefas do dia, recordes e recompensas pendentes do Dragão
	PlotService.rebuildPlot(player)
	StealService.giveShield(player, Config.Steal.SpawnShieldSec)
	PlotService.pushState(player)
	V2CookingService.onJoin(player)
	V2LaneService.pushSnapshot(player)
	V2MetricsService.onJoin(player)
	OnboardingService.onJoin(player) -- v3: câmera de chegada e 1ª alimentação mais forte (flag)
	EggService.onJoin(player) -- ovos: estado do ninho e marcos de nível (flag)
	WelcomeService.onJoin(player) -- resumo de quem volta (flag)

	-- Teleporta o jogador para sua base ao (re)nascer
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		local b = MapService.getBaseOf(player)
		if b then
			char:PivotTo(b.origin * CFrame.new(0, 6, 20))
		end
	end)
	if player.Character then
		player.Character:PivotTo(base.origin * CFrame.new(0, 6, 20))
	end

	-- Kit inicial: 2 comidas comuns para o loop começar imediatamente
	if profile.totalBoxes == 0 and #profile.inventory == 0 and next(profile.plot) == nil then
		PlotService.giveFood(player, "apple")
		PlotService.giveFood(player, "bread")
		Remotes.Notify:FireClient(player, {
			text = "Bem-vindo! Seu Gigante está com fome!",
			color = Color3.fromRGB(255, 220, 80),
		})
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	MapService.releaseBase(player)
end)

print("[FeedAGiant] Servidor pronto. Bases:", #MapService.Bases)
