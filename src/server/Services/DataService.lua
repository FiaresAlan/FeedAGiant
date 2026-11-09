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
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
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
	-- Fase 4: índice de coleção (comidas que já passaram pela mochila ou pelo pátio)
	discovered: { [string]: boolean },
	-- Dragão Faminto: vitórias contadas por dia (dia = os.time() // 86400)
	bossDay: number,
	bossWins: number,
	-- Lunchboxes trazidas do mapa até a base, esperando o jogador abrir (DropService)
	pendingBoxes: { string },
	-- Arena dos gigantes (GiantBattleService)
	giantWins: number,
	giantLosses: number,
	giantDay: number,
	giantRewardsToday: number,
	-- Missão 08/11/2026 (noite). Todos aditivos: perfis antigos recebem o padrão no reconcile.
	-- Coleção de gigantes: progresso POR espécie. profile.level/xp continuam sendo os do gigante
	-- ATIVO (todo o código antigo segue funcionando); os outros ficam aqui.
	giants: { [string]: { level: number, xp: number, inherited: boolean? } },
	display: { string }, -- espécies expostas na base (no máximo GameRules.Roster.DisplaySlots)
	displaySettledAt: number, -- os.time() até onde a renda da exposição já foi paga
	records: { [string]: number }, -- recordes pessoais (GameRules.Records)
	objDay: number,
	objProgress: { [string]: number },
	objClaimed: { [string]: boolean },
	objBonusClaimed: boolean,
	bossClaimed: { string }, -- ids de lutas do Dragão já pagas (anti-duplicação de pendentes)
	-- Especificação v3 (08/11/2026), atrás de Features. Aditivos: perfis antigos ganham o padrão.
	pityCount: number, -- caixas pagas seguidas sem Épica ou melhor (GameRules.Pity)
	streakBackups: number, -- proteções da sequência diária (GameRules.StreakBackup)
	stealDay: number, -- dia UTC do contador de roubos
	stealsToday: number, -- roubos bem-sucedidos nesse dia (GameRules.StealLimits)
	onboardingAt: number, -- 0 = nunca marcado; -1 = entrou como novato (v3); >0 = os.time() do fim
	welcomeGiven: boolean, -- presente de boas-vindas já entregue (fica guardado até abrir)
	-- Sistema de Ovos (08/11/2026, Features.EggSystem). Chaves de texto: nada de tabela numérica esparsa.
	eggs: { string }, -- ovos guardados (tamanho), fora do ninho
	nest: { [string]: { size: string, hatchAt: number, fed: boolean, warmed: boolean, species: string?, bond: number? } },
	eggsHatched: number,
	eggBossDay: number, -- dia UTC do último Ovo Grande ganho no Dragão
	eggMilestones: { [string]: boolean }, -- marcos de nível já premiados
	starterSpecies: string, -- "" = nunca ofertada; "?" = ofertada, sem escolha; id = escolhida (StarterSpecies)
	-- Prompt v4 (09/11/2026). Aditivos (slices): perfis antigos ganham o padrão sem perder nada.
	mysteryChest: { unlockAt: number }, -- baú de 24 h (ainda sem código: espera a cópia de teste)
	revangeTarget: number, -- UserId do ladrão para a revanche (0 = nenhum; ainda sem código)
	eggNotifyHatchAt: number, -- hatchAt do último ovo já avisado por notificação (nunca 2 vezes)
	weeklyQuest: {
		week: number, -- semana (segunda a domingo, UTC) a que a escolha pertence
		chosenId: string, -- "" = ainda não escolheu
		chosenAt: number,
		swappedThisWeek: boolean,
		progress: number,
		claimed: boolean,
	},
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
		discovered = {},
		bossDay = 0,
		bossWins = 0,
		pendingBoxes = {},
		giantWins = 0,
		giantLosses = 0,
		giantDay = 0,
		giantRewardsToday = 0,
		giants = {},
		display = {},
		displaySettledAt = 0,
		records = {},
		objDay = 0,
		objProgress = {},
		objClaimed = {},
		objBonusClaimed = false,
		bossClaimed = {},
		pityCount = 0,
		streakBackups = 0,
		stealDay = 0,
		stealsToday = 0,
		onboardingAt = 0,
		welcomeGiven = false,
		eggs = {},
		nest = {},
		eggsHatched = 0,
		eggBossDay = 0,
		eggMilestones = {},
		starterSpecies = "",
		mysteryChest = { unlockAt = 0 },
		revangeTarget = 0,
		eggNotifyHatchAt = 0,
		weeklyQuest = { week = 0, chosenId = "", chosenAt = 0, swappedThisWeek = false, progress = 0, claimed = false },
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
	-- Migração da coleção (08/11/2026): antes o nível era um só para todas as espécies. Para
	-- ninguém perder nada, cada espécie já possuída começa com o nível ATUAL do jogador.
	-- Idempotente: só preenche espécies possuídas que ainda não têm registro.
	for id, owned in profile.ownedSpecies do
		if owned and Config.SpeciesById[id] and profile.giants[id] == nil then
			profile.giants[id] = {
				level = profile.level,
				xp = if id == profile.species then profile.xp else 0,
				inherited = true,
			}
		end
	end
	-- Valores impossíveis nos campos novos (save corrompido/antigo): corrige sem apagar nada útil.
	local function num(v: any, lo: number, hi: number, default: number): number
		if type(v) ~= "number" or v ~= v then
			return default
		end
		return math.clamp(math.floor(v), lo, hi)
	end
	for id, rec in profile.giants do
		if type(rec) ~= "table" or not Config.SpeciesById[id] then
			profile.giants[id] = nil
		else
			rec.level = num(rec.level, 1, Config.Giant.MaxLevel, 1)
			rec.xp = num(rec.xp, 0, math.huge, 0)
		end
	end
	for k, v in profile.records do
		profile.records[k] = num(v, 0, math.huge, 0)
	end
	for k, v in profile.objProgress do
		profile.objProgress[k] = num(v, 0, 1e6, 0)
	end
	profile.displaySettledAt = num(profile.displaySettledAt, 0, os.time(), 0)
	profile.pityCount = num(profile.pityCount, 0, GameRules.Pity.Hard, 0)
	profile.streakBackups = num(profile.streakBackups, 0, GameRules.StreakBackup.Max, 0)
	profile.stealsToday = num(profile.stealsToday, 0, 1e6, 0)
	-- Ovos: só tamanhos conhecidos; lugares do ninho "1".."3" com dados válidos.
	local Sizes = GameRules.Eggs.Sizes
	local eggs = {}
	for _, size in profile.eggs do
		if type(size) == "string" and Sizes[size] and #eggs < GameRules.Eggs.MaxStoredHard then
			table.insert(eggs, size)
		end
	end
	profile.eggs = eggs
	for key, slot in profile.nest do
		local okKey = key == "1" or key == "2" or key == "3"
		if not okKey or type(slot) ~= "table" or not Sizes[slot.size] or type(slot.hatchAt) ~= "number" then
			profile.nest[key] = nil
		end
	end
	-- Exposição: só espécies possuídas, sem a ativa, sem repetição, até o limite.
	local seen: { [string]: boolean } = {}
	local clean = {}
	for _, id in profile.display do
		if
			type(id) == "string"
			and profile.ownedSpecies[id]
			and id ~= profile.species
			and not seen[id]
			and #clean < GameRules.Roster.DisplaySlots
		then
			seen[id] = true
			table.insert(clean, id)
		end
	end
	profile.display = clean
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

-- Registra uma parte extra do perfil (ex.: "tutorial"). Só antes de DataService.start().
function DataService.registerSlice(name: string, makeDefault: () -> any)
	PlayerData.RegisterSlice(name, makeDefault)
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
