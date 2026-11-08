--!strict
-- DataService — fachada do jogo sobre o PlayerData do fwjelaa (Fase 0.3).
--
-- O que mudou em relação à v4 (ver docs/DIAGNOSTICO_E_PLANO.md, C1/C2/H2/H3):
--   * Trava de sessão: carregar e salvar usam UpdateAsync com lease + token (PlayerData).
--     Outro servidor nunca sobrescreve o save, e trocar de servidor não volta no tempo.
--   * Carregamento que falha NUNCA vira perfil padrão: o jogador é desconectado com uma
--     mensagem clara e o save verdadeiro fica intacto.
--   * Autosave escalonado (30 s, só se mudou), save + liberação ao sair, BindToClose que
--     espera os saves de verdade (até 26 s). Save que falha continua pendente.
--   * Compras: PurchaseId gravado no mesmo documento da entrega (ver MonetizationService).
--   * Placares (OrderedDataStore) saem do caminho do save: a cada 120 s se mudou e ao sair.
--
-- A interface pública continua a mesma da v4 (get, waitFor, markDirty, newUid,
-- getLeaderboard), então os outros serviços não precisam mudar.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Vendor = ServerScriptService:WaitForChild("fwjelaa")
local PlayerData = require(Vendor:WaitForChild("PlayerData"))
local StudioMemoryStore = require(Vendor:WaitForChild("StudioMemoryStore"))

-- Nunca renomear depois do lançamento. O place nunca foi publicado, então não há
-- dados antigos ("FeedAGiant_v1") para migrar.
local STORE_NAME = "FeedAGiant_Profiles_v1"
local SCHEMA_VERSION = 1
local LEADERBOARD_INTERVAL = 120

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
	-- Fase 0
	speciesTokens: number, -- fichas do produto "Trocar Espécie" (jogador escolhe a espécie)
}

local DataService = {}

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
		speciesTokens = 0,
	}
end
DataService.defaultProfile = defaultProfile

-- Corrige valores impossíveis vindos do save (idempotente; roda uma vez por carga).
local sanitized: { [Player]: boolean } = {}
local function sanitize(player: Player, profile: Profile)
	if sanitized[player] then
		return
	end
	sanitized[player] = true
	if not Config.SpeciesById[profile.species] then
		profile.species = Config.DefaultSpecies
	end
	profile.ownedSpecies[profile.species] = true
	if profile.peakLevel < profile.level then
		profile.peakLevel = profile.level
	end
	-- Nunca apaga itens na carga (podem ter sido comprados com Robux). Só avisa.
	if #profile.inventory > Config.MaxInventoryHard then
		warn(`[DataService] inventário de {player.UserId} acima do teto: {#profile.inventory}`)
	end
end

function DataService.newUid(): string
	return HttpService:GenerateGUID(false)
end

-- Perfil ativo (tabela do jogo) ou nil enquanto carrega / depois de sair / se o load falhou.
function DataService.get(player: Player): Profile?
	local p = PlayerData.Get(player)
	if not p then
		return nil
	end
	local profile = p.Data :: any
	sanitize(player, profile)
	return profile
end

function DataService.waitFor(player: Player, timeout: number?): Profile?
	local p = PlayerData.WaitForProfile(player, timeout or 15)
	if not p then
		return nil
	end
	return DataService.get(player)
end

function DataService.markDirty(player: Player)
	local p = PlayerData.Get(player)
	if p then
		PlayerData.MarkDirty(p)
	end
end

-- Roda `fn(player, data)` quando o jogador sai, ANTES do save final (o snapshot é tirado logo
-- depois). Mudanças em `data` feitas sem yield entram no save. Usado pela arena: sair no meio
-- da luta conta como derrota (revisão independente da Fase 3).
function DataService.onReleasing(fn: (Player, Profile) -> ())
	PlayerData.Releasing:Connect(function(player: Player, p: PlayerData.Profile)
		fn(player, p.Data :: any)
	end)
end

function DataService.saveNow(player: Player): boolean
	return PlayerData.SaveNowAsync(player)
end

---------------------------------------------------------------------------
-- Placares globais (índices; o perfil é a verdade)
---------------------------------------------------------------------------
type BoardKind = "Level" | "Rebirth" | "Arena"
-- Chave string: o Luau não aceita atribuir campos num mapa de chaves literais.
local boards: { [string]: OrderedDataStore } = {}
local lastWritten: { [number]: { [string]: number } } = {}

local function boardValues(profile: Profile): { [BoardKind]: number }
	return {
		Level = profile.level + profile.rebirths * 1000,
		Rebirth = profile.rebirths,
		Arena = profile.arenaWins + profile.championships * 10,
	}
end

local function writeBoards(userId: number, values: { [BoardKind]: number })
	local previous = lastWritten[userId] or {}
	for kind, value in values do
		local ds = boards[kind]
		if ds and previous[kind] ~= value then
			if
				DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementSortedAsync) < 1
			then
				return -- sem orçamento agora; tenta no próximo ciclo
			end
			local ok = pcall(function()
				ds:SetAsync(tostring(userId), math.floor(value))
			end)
			if ok then
				previous[kind] = value
			end
		end
	end
	lastWritten[userId] = previous
end

function DataService.getLeaderboard(kind: BoardKind, n: number): { { userId: number, value: number } }
	local ds = boards[kind]
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

---------------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------------

-- Fase 1: configura o PlayerData e registra o perfil. Chamar antes de qualquer
-- RegisterSlice de outros módulos (ex.: Receipts) e antes de DataService.start().
function DataService.init()
	PlayerData.Configure({
		storeName = STORE_NAME,
		schemaVersion = SCHEMA_VERSION,
		studioFallbackStore = if RunService:IsStudio() then StudioMemoryStore.new() else nil,
	})
	-- Uma "slice" por campo: profile.Data fica com o mesmo formato plano da v4.
	local template = defaultProfile()
	for key in template do
		PlayerData.RegisterSlice(key :: string, function()
			return (defaultProfile() :: any)[key]
		end)
	end

	local okBoards = pcall(function()
		boards.Level = DataStoreService:GetOrderedDataStore("FAG_TopLevel_v1")
		boards.Rebirth = DataStoreService:GetOrderedDataStore("FAG_TopRebirth_v1")
		boards.Arena = DataStoreService:GetOrderedDataStore("FAG_TopArena_v1")
	end)
	if not okBoards then
		warn("[DataService] Placares indisponíveis (place não publicado?).")
	end

	-- Ao sair: grava lastSeen no snapshot final e atualiza os placares uma vez.
	PlayerData.Releasing:Connect(function(_player: Player, p: PlayerData.Profile)
		(p.Data :: any).lastSeen = os.time()
	end)
	PlayerData.OnRelease(function(player: Player, p: PlayerData.Profile)
		local values = boardValues(p.Data :: any) -- lê antes de qualquer yield
		writeBoards(p.UserId, values)
		lastWritten[p.UserId] = nil
		sanitized[player] = nil
	end)
end

-- Fase 2: começa a carregar jogadores. Chamar depois de todos os init().
function DataService.start()
	PlayerData.Start()
	task.spawn(function()
		while true do
			task.wait(LEADERBOARD_INTERVAL)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile then
					writeBoards(player.UserId, boardValues(profile))
				end
				task.wait(0.5) -- espalha as escritas
			end
		end
	end)
end

return DataService
