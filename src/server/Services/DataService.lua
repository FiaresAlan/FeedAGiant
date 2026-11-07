--!strict
-- DataService — carrega/salva perfis com DataStore, com retry e autosave.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local STORE_NAME = "FeedAGiant_v1"
local store
local leaderLevel
local leaderRebirth
local leaderArena
local dataStoreAvailable = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
	leaderLevel = DataStoreService:GetOrderedDataStore("FAG_TopLevel_v1")
	leaderRebirth = DataStoreService:GetOrderedDataStore("FAG_TopRebirth_v1")
end)

if not dataStoreAvailable then
	if RunService:IsStudio() then
		warn("[DataService] DataStore indisponível neste place não publicado; usando perfis em memória.")
	else
		warn("[DataService] Não foi possível inicializar o DataStore.")
	end
end

export type FoodInstance = { id: string, uid: string }
export type Profile = {
	coins: number,
	level: number,
	xp: number,
	rebirths: number,
	hunger: number,
	inventory: { FoodInstance },
	plot: { [string]: FoodInstance }, -- key = tostring(slotIndex)
	totalFeeds: number,
	totalSteals: number,
	totalBoxes: number,
	dailyStreak: number,
	lastDaily: number,
	redeemedCodes: { [string]: boolean },
	passes: { [string]: boolean },
	shieldUntil: number,
	-- v2
	species: string,
	ownedSpecies: { [string]: boolean },
	lastFed: number, -- os.time() da última alimentação (base do decay)
	lastSeen: number,
	freezeUntil: number, -- decay congelado até
	levelsLostToDecay: number,
	peakLevel: number,
	dropsWon: number,
	punchesLanded: number,
	knockouts: number,
	arenaWins: number,
	arenaLosses: number,
	arenaStreak: number,
	championships: number,
	championUntil: number,
	lastDuel: number,
	duelProtectionUntil: number,
}

local DataService = {}
local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local uidCounter = 0

function DataService.newUid(): string
	uidCounter += 1
	return string.format("%d_%d", os.time(), uidCounter)
end

local function defaultProfile(): Profile
	return {
		coins = Config.StartingCoins,
		level = 1,
		xp = 0,
		rebirths = 0,
		hunger = 60,
		inventory = {},
		plot = {},
		totalFeeds = 0,
		totalSteals = 0,
		totalBoxes = 0,
		dailyStreak = 0,
		lastDaily = 0,
		redeemedCodes = {},
		passes = {},
		shieldUntil = 0,
		species = Config.DefaultSpecies,
		ownedSpecies = { [Config.DefaultSpecies] = true },
		lastFed = os.time(),
		lastSeen = os.time(),
		freezeUntil = 0,
		levelsLostToDecay = 0,
		peakLevel = 1,
		dropsWon = 0,
		punchesLanded = 0,
		knockouts = 0,
		arenaWins = 0,
		arenaLosses = 0,
		arenaStreak = 0,
		championships = 0,
		championUntil = 0,
		lastDuel = 0,
		duelProtectionUntil = 0,
	}
end

local function withRetry<T>(fn: () -> T, attempts: number): (boolean, T?)
	local ok, result
	for i = 1, attempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn("[DataService] tentativa " .. i .. " falhou:", result)
		task.wait(1.5 * i)
	end
	return false, nil
end

local function load(player: Player)
	local key = "u_" .. player.UserId
	local ok, data = false, nil
	if dataStoreAvailable and store then
		ok, data = withRetry(function()
			return store:GetAsync(key)
		end, 3)
	end
	local profile = defaultProfile()
	if ok and type(data) == "table" then
		for k, v in data :: any do
			(profile :: any)[k] = v
		end
		-- Migração v1 -> v2: perfis antigos não têm os campos novos; defaultProfile já os preencheu.
		if not Config.SpeciesById[profile.species] then
			profile.species = Config.DefaultSpecies
		end
		profile.ownedSpecies[profile.species] = true
		if profile.peakLevel < profile.level then
			profile.peakLevel = profile.level
		end
	end
	if not ok and not RunService:IsStudio() then
		warn("[DataService] Falha ao carregar " .. player.Name .. ". Jogando com perfil temporário.")
	end
	profiles[player] = profile
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if not dataStoreAvailable or not store then
		dirty[player] = nil
		return
	end
	local key = "u_" .. player.UserId
	profile.lastSeen = os.time()
	withRetry(function()
		store:SetAsync(key, profile, { player.UserId })
		return true
	end, 3)
	pcall(function()
		leaderLevel:SetAsync(tostring(player.UserId), profile.level + profile.rebirths * 1000)
		leaderRebirth:SetAsync(tostring(player.UserId), profile.rebirths)
		leaderArena:SetAsync(tostring(player.UserId), profile.arenaWins + profile.championships * 10)
	end)
	dirty[player] = nil
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.waitFor(player: Player, timeout: number?): Profile?
	local t0 = os.clock()
	while not profiles[player] do
		if os.clock() - t0 > (timeout or 15) then
			return nil
		end
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.getLeaderboard(kind: "Level" | "Rebirth" | "Arena", n: number): { { userId: number, value: number } }
	local ds = if kind == "Level" then leaderLevel elseif kind == "Arena" then leaderArena else leaderRebirth
	if not ds then
		return {}
	end
	local ok, pages = pcall(function()
		return ds:GetSortedAsync(false, n)
	end)
	local out = {}
	if ok and pages then
		for _, entry in pages:GetCurrentPage() do
			table.insert(out, { userId = tonumber(entry.key) or 0, value = entry.value })
		end
	end
	return out
end

function DataService.init()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local jobs = {}
		for player in profiles do
			table.insert(jobs, task.spawn(save, player))
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in dirty do
				if player.Parent then
					task.spawn(save, player)
				end
			end
		end
	end)
end

return DataService
