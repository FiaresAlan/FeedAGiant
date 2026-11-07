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

print("[FeedAGiant] Iniciando servidor...")

MapService.init()
DataService.init()
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

local function onPlayerAdded(player: Player)
	local profile = DataService.waitFor(player, 20)
	if not profile then
		player:Kick("Falha ao carregar seus dados. Tente novamente.")
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
	PlotService.rebuildPlot(player)
	StealService.giveShield(player, Config.Steal.SpawnShieldSec)
	PlotService.pushState(player)

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
		Remotes.Notify:FireClient(player, { text = "Bem-vindo! Coloque comida no pátio e alimente seu Gigante.", color = Color3.fromRGB(255, 220, 80) })
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
