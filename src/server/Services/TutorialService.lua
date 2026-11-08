--!strict
-- TutorialService — liga o módulo FwjelaaTutorial (vendorizado) ao jogo (Fase 4: primeiro minuto).
-- O servidor é dono do progresso e das recompensas; o progresso fica no perfil (slice "tutorial",
-- por ID de passo), então quem sai no meio continua de onde parou. Funil de analytics no servidor
-- (AnalyticsService, feito pelo módulo). Os serviços do jogo só chamam TutorialService.signal(...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Steps = require(game.ReplicatedStorage.Shared.TutorialSteps) :: { any }
local Tutorial = require(ReplicatedStorage:WaitForChild("fwjelaa"):WaitForChild("FwjelaaTutorial")) :: any
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local tutorial: any = nil
local FIRST_BOX_PRICE = (Config.LunchboxById["common"] :: any).price
local GROW_LEVEL = 3

-- Recompensas (pagas uma vez, também ao pular). Nunca dão mais que o necessário para o próximo passo.
local REWARDS: { [string]: (Player) -> () } = {
	SpareFood = function(player: Player)
		local profile = DataService.get(player)
		if profile and #profile.inventory == 0 then
			table.insert(profile.inventory, { id = "bread", uid = DataService.newUid() })
			DataService.markDirty(player)
		end
	end,
	BoxMoney = function(player: Player)
		local profile = DataService.get(player)
		if profile and profile.coins < FIRST_BOX_PRICE then
			profile.coins = FIRST_BOX_PRICE
			DataService.markDirty(player)
		end
	end,
	FirstGrowth = function(player: Player)
		local profile = DataService.get(player)
		if profile then
			profile.coins += 500
			DataService.markDirty(player)
		end
	end,
}

-- Chamado pelos serviços do jogo quando algo acontece (sinais fora do passo atual são ignorados).
function TutorialService.signal(player: Player, name: string, amount: number?)
	if tutorial then
		tutorial:Signal(player, name, amount or 1)
	end
end

function TutorialService.refresh(player: Player)
	if tutorial then
		tutorial:Refresh(player)
	end
end

-- Fase 1: registrar o slice no perfil (antes de DataService.start).
function TutorialService.init()
	DataService.registerSlice("tutorial", function()
		return { v = 1, done = {}, rewarded = {}, progress = {}, skipped = false, finished = false }
	end)
	for _, step in Steps do
		if step.id == "grow" then
			step.isComplete = function(player: Player): boolean
				local profile = DataService.get(player)
				return profile ~= nil and (profile.level >= GROW_LEVEL or profile.rebirths > 0)
			end
		elseif step.id == "feed" then
			step.isComplete = function(player: Player): boolean
				local profile = DataService.get(player)
				return profile ~= nil and profile.totalFeeds > 0
			end
		end
	end
end

-- Fase 2: depois que o DataService começou a carregar perfis.
function TutorialService.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "TutorialRemote"
	remote.Parent = ReplicatedStorage
	tutorial = Tutorial.Server.new({
		steps = Steps,
		remote = remote,
		funnelName = "Tutorial_v1",
		load = function(player: Player)
			local profile = DataService.waitFor(player, 60)
			if profile == nil then
				error("perfil não carregou") -- o módulo pausa em vez de tratar como jogador novo
			end
			return (profile :: any).tutorial
		end,
		save = function(player: Player, saved: any)
			local profile = DataService.get(player)
			if profile then
				(profile :: any).tutorial = saved
				DataService.markDirty(player)
			end
		end,
		reward = function(player: Player, rewardId: string, _stepId: string)
			local grant = REWARDS[rewardId]
			if grant then
				grant(player)
			end
		end,
		-- Quem já jogou antes do tutorial existir pode pular na hora.
		isReturning = function(player: Player): boolean
			local profile = DataService.get(player)
			return profile ~= nil and (profile.totalBoxes > 3 or profile.level >= 10 or profile.rebirths > 0)
		end,
		onFinished = function(player: Player, skipped: boolean)
			-- Nunca termina num beco sem saída: a próxima meta aparece na HUD.
			player:SetAttribute("NextGoal", if skipped then "rebirth" else "level10")
		end,
	})
	tutorial:Start()
end

return TutorialService
