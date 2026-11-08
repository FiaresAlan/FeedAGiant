--!strict
-- RosterService — Sistema 2 (missão de 08/11/2026): EXPOR gigantes da coleção na base.
--
-- O jogador escolhe até GameRules.Roster.DisplaySlots espécies que possui (menos a ativa) para
-- ficarem em pedestais no canto da base. Duas funções:
--   1) vitrine: quem passa vê a coleção (estátua 3D da espécie + "Nv. N");
--   2) renda complementar em MOEDAS normais: Base + PerLevel × nível de cada exposto.
-- Offline: continua rendendo à metade (OfflineRate), no máximo OfflineCapSeconds (8 h). O valor é
-- pago UMA vez ao voltar e mostrado claramente.
--
-- Anti-duplicação: o pagamento é "liquidado" por tempo (profile.displaySettledAt). As moedas e o
-- carimbo de tempo moram no MESMO documento do save (PlayerData), então ou os dois são salvos
-- juntos ou nenhum: reconectar, trocar de servidor ou o save falhar nunca paga o mesmo período 2x.
-- A renda é pequena de propósito (exemplo nível 20: 3,5 moedas/s; uma comida Incomum no pátio dá 3):
-- alimentar e jogar continuam rendendo bem mais. Nada disso se compra com Robux.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)
local Guard = require(script.Parent.Parent.Guard)
local Hooks = require(script.Parent.Parent.Hooks)
local GameLogic = require(script.Parent.Parent.GameLogic)

local RosterService = {}
local R = GameRules.Roster

local STATUE_HEIGHT = 7
-- Faixa livre do lado esquerdo da base (o escudo fica à direita, o pátio no meio).
local PEDESTAL_SPOTS = {
	CFrame.new(-24, 2, -20),
	CFrame.new(-24, 2, -9),
	CFrame.new(-24, 2, 2),
}

local remainder: { [Player]: number } = {}
local built: { [Player]: Folder } = {}

-- Moedas por segundo da exposição (online).
function RosterService.rate(profile: DataService.Profile): number
	local levels = {}
	for _, id in profile.display do
		if id ~= profile.species and profile.ownedSpecies[id] then
			table.insert(levels, GiantService.levelOf(profile, id))
		end
	end
	return GameLogic.displayRate(levels)
end

-- Paga o tempo desde a última liquidação (online). Frações ficam para a próxima.
local function settle(player: Player, profile: DataService.Profile)
	local now = os.time()
	local last = profile.displaySettledAt
	profile.displaySettledAt = now
	if last <= 0 or now <= last then
		return
	end
	local gain = (now - last) * RosterService.rate(profile) + (remainder[player] or 0)
	local whole = math.floor(gain)
	remainder[player] = gain - whole
	if whole > 0 then
		profile.coins += whole
		DataService.markDirty(player)
	end
end

local function clearBuilt(player: Player)
	local f = built[player]
	if f then
		f:Destroy()
		built[player] = nil
	end
end

-- Estátuas nos pedestais da base do jogador.
local function rebuild(player: Player)
	clearBuilt(player)
	local profile = DataService.get(player)
	local base = MapService.getBaseOf(player)
	if not profile or not base then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Displays"
	for i, spot in PEDESTAL_SPOTS do
		local cf = base.origin * spot
		local ped = Util.makePart({
			Name = "DisplayPedestal" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 7, 7),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(205, 196, 178),
			Material = Enum.Material.Slate,
			Parent = folder,
		})
		local id = profile.display[i]
		local sp = id and Config.SpeciesById[id]
		if sp then
			local file = CreatureModels.resolve(sp.id, GiantService.levelOf(profile, sp.id) < 10)
			local tpl = file and GiantService.template(file)
			local top = cf * CFrame.new(0, 0.6, 0)
			if tpl then
				local m = tpl:Clone()
				m.Name = "Display_" .. sp.id
				local _, ext = m:GetBoundingBox()
				m:ScaleTo(m:GetScale() * STATUE_HEIGHT / math.max(ext.Y, 0.1))
				local bb, size = m:GetBoundingBox()
				local bottom = bb * CFrame.new(0, -size.Y / 2, 0)
				local offset = m:GetPivot():ToObjectSpace(bottom)
				-- de frente para o meio da base
				m:PivotTo(top * CFrame.Angles(0, math.rad(-90), 0) * offset:Inverse())
				m.Parent = folder
			end
			local label = Util.makeBillboard(
				ped,
				string.format("%s\nNv. %d", sp.name, GiantService.levelOf(profile, sp.id)),
				UDim2.fromOffset(170, 52),
				Vector3.new(0, STATUE_HEIGHT + 2.5, 0),
				sp.color
			)
			local board = label.Parent :: BillboardGui
			board.MaxDistance = 70
		else
			ped.Transparency = 0.35
		end
	end
	folder.Parent = base.model
	built[player] = folder
end

local function setDisplay(player: Player, speciesId: string, on: boolean)
	local profile = DataService.get(player)
	if not profile or not Config.SpeciesById[speciesId] or not profile.ownedSpecies[speciesId] then
		return
	end
	settle(player, profile) -- fecha a conta com a taxa antiga antes de mudar
	local list = profile.display
	local idx = table.find(list, speciesId)
	if on then
		if speciesId == profile.species then
			Remotes.Notify:FireClient(player, Locale.msg("display_active", nil, Color3.fromRGB(255, 170, 60)))
			return
		end
		if idx then
			return
		end
		if #list >= R.DisplaySlots then
			Remotes.Notify:FireClient(
				player,
				Locale.msg("display_full", { n = R.DisplaySlots }, Color3.fromRGB(255, 170, 60))
			)
			return
		end
		table.insert(list, speciesId)
	elseif idx then
		table.remove(list, idx)
	end
	DataService.markDirty(player)
	rebuild(player)
	PlotService.pushState(player)
end

-- Ao entrar: paga o tempo offline (metade da taxa, até 8 h) e mostra quanto foi.
function RosterService.onJoin(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	local last = profile.displaySettledAt
	local rate = RosterService.rate(profile)
	if last > 0 and now > last and rate > 0 then
		local away = math.min(now - last, R.OfflineCapSeconds)
		do
			local gain = GameLogic.offlineGain(last, now, rate)
			if gain > 0 then
				profile.coins += gain
				Remotes.Notify:FireClient(
					player,
					Locale.msg(
						"offline_income",
						{ n = Util.formatNumber(gain), h = string.format("%.1f", away / 3600) },
						Color3.fromRGB(120, 255, 160)
					)
				)
				Hooks.fire("offlineIncome", player, gain, away)
			end
		end
	end
	profile.displaySettledAt = now
	DataService.markDirty(player)
	rebuild(player)
end

function RosterService.init()
	PlotService.DisplayIncome = function(player: Player): number
		local profile = DataService.get(player)
		return if profile then RosterService.rate(profile) else 0
	end
	Remotes.RequestDisplay.OnServerEvent:Connect(function(player, speciesId, on)
		if type(speciesId) ~= "string" or #speciesId > 32 or type(on) ~= "boolean" then
			return
		end
		if Guard.allow(player, "Display") then
			setDisplay(player, speciesId, on)
		end
	end)
	-- Trocar de gigante ativo tira ele da vitrine (GiantService) e muda níveis: remonta.
	Hooks.on("speciesChanged", function(player: Player)
		local profile = DataService.get(player)
		if profile then
			settle(player, profile)
		end
		rebuild(player)
	end)
	-- Liquidação periódica (online) e ao sair (o carimbo vai no snapshot final do save).
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile and #profile.display > 0 then
					settle(player, profile)
				end
			end
		end
	end)
	DataService.onReleasing(function(player: Player, profile: DataService.Profile)
		-- paga até agora e marca o início do período offline
		local now = os.time()
		if profile.displaySettledAt > 0 and now > profile.displaySettledAt then
			profile.coins += math.floor((now - profile.displaySettledAt) * RosterService.rate(profile))
		end
		profile.displaySettledAt = now
		remainder[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		clearBuilt(player)
	end)
end

return RosterService
