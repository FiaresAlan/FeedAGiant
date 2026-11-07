--!strict
-- Config.lua — ÚNICO lugar para ajustar balanceamento, preços e IDs.
local Config = {}

Config.GameName = "FEED A GIANT"
Config.Version = "4.0.0"
Config.GroupId = 0 -- coloque o ID do seu grupo para bônus de 10%
Config.PromoCodes = { GIGANTE = 1000, LAUNCH = 2500 }

Config.MaxPlayers = 8
Config.StartingCoins = 250
Config.BaseRadius = 320
Config.BaseSize = 60
Config.PlotSlots = 12
Config.PlotSlotsVIP = 16

Config.Giant = {
	BaseScale = 1,
	ScalePerLevel = 0.35,
	MaxLevel = 250,
	HungerDecayPerSec = 0.5, -- 0..100
	HungerPerFeed = 12,
	MoodMultipliers = { Hungry = 0.8, Fine = 1.0, Happy = 1.25 },
}

function Config.xpNeeded(level: number): number
	return math.floor(50 * level ^ 1.4)
end

Config.Rebirth = {
	MinLevel = 50,
	BonusPerRebirth = 0.25,
}

Config.Steal = {
	ChannelTime = 3,
	SpawnShieldSec = 60,
	PurchaseShieldSec = 20,
	SuperShieldSec = 600,
	KnockbackForce = 60,
}

Config.Events = {
	MinInterval = 360,
	MaxInterval = 540,
	List = {
		{ id = "GoldenHour", name = "Golden Hour", duration = 90, color = Color3.fromRGB(255, 200, 40) },
		{ id = "FoodRain", name = "Chuva de Comida", duration = 60, color = Color3.fromRGB(80, 200, 255) },
		{ id = "HungryBoss", name = "Boss Faminto", duration = 120, color = Color3.fromRGB(255, 70, 70) },
		{ id = "LuckyBoxes", name = "Lucky Boxes", duration = 60, color = Color3.fromRGB(120, 255, 120) },
	},
}


----------------------------------------------------------------
-- v2: ESPÉCIES DE GIGANTE
-- Cada espécie tem stats próprios. "robux = true" = só via Game Pass (nunca encolhe).
----------------------------------------------------------------
export type SpeciesDef = {
	id: string,
	name: string,
	desc: string,
	price: number, -- moedas (0 = inicial)
	robux: boolean, -- requer Game Pass (chave em Config.GamePasses)
	passKey: string?,
	rarityTag: string,
	color: Color3,
	skin: Color3,
	xpMult: number, -- XP por alimentação
	coinMult: number, -- moedas/seg
	hungerDecayMult: number, -- fome cai mais rápido (>1) ou mais devagar (<1)
	arenaPower: number, -- força base no Giant Clash
	arenaHp: number,
	decayImmune: boolean,
	bodyShape: string, -- "Humanoid" | "Beast" | "Bird" | "Dragon" | "Robot" | "Slime"
}

Config.Species = {
	{ id = "human", name = "Gigante Humano", desc = "Equilibrado. Come de tudo, cresce rápido.", price = 0, robux = false, rarityTag = "Comum",
		color = Color3.fromRGB(240, 240, 240), skin = Color3.fromRGB(255, 205, 150), xpMult = 1, coinMult = 1, hungerDecayMult = 1, arenaPower = 10, arenaHp = 100, decayImmune = false, bodyShape = "Humanoid" },
	{ id = "gator", name = "Gigante Jacaré", desc = "Mandíbula de aço. +40% força na arena, cresce mais devagar.", price = 15000, robux = false, rarityTag = "Raro",
		color = Color3.fromRGB(60, 140, 70), skin = Color3.fromRGB(80, 170, 90), xpMult = 0.85, coinMult = 1.1, hungerDecayMult = 1.2, arenaPower = 14, arenaHp = 140, decayImmune = false, bodyShape = "Beast" },
	{ id = "eagle", name = "Gigante Águia", desc = "Visão de caçador. +50% XP por comida, mas fome cai 1.5x.", price = 40000, robux = false, rarityTag = "Épico",
		color = Color3.fromRGB(150, 90, 40), skin = Color3.fromRGB(230, 200, 150), xpMult = 1.5, coinMult = 1, hungerDecayMult = 1.5, arenaPower = 12, arenaHp = 90, decayImmune = false, bodyShape = "Bird" },
	{ id = "golem", name = "Gigante Golem", desc = "Tanque de pedra. 2x HP na arena, +25% moedas, come devagar.", price = 120000, robux = false, rarityTag = "Lendário",
		color = Color3.fromRGB(110, 110, 120), skin = Color3.fromRGB(140, 140, 150), xpMult = 0.75, coinMult = 1.25, hungerDecayMult = 0.7, arenaPower = 11, arenaHp = 220, decayImmune = false, bodyShape = "Robot" },
	{ id = "slime", name = "Gigante Slime", desc = "Absorve tudo. +100% moedas, cresce muito devagar.", price = 350000, robux = false, rarityTag = "Mítico",
		color = Color3.fromRGB(80, 255, 160), skin = Color3.fromRGB(120, 255, 190), xpMult = 0.6, coinMult = 2, hungerDecayMult = 0.8, arenaPower = 9, arenaHp = 160, decayImmune = false, bodyShape = "Slime" },
	{ id = "dragon", name = "Gigante Dragão", desc = "O ápice. +100% XP, +50% moedas, arena dominante. NUNCA encolhe.", price = 0, robux = true, passKey = "DragonGiant", rarityTag = "SECRETO",
		color = Color3.fromRGB(255, 60, 40), skin = Color3.fromRGB(200, 30, 30), xpMult = 2, coinMult = 1.5, hungerDecayMult = 0.5, arenaPower = 20, arenaHp = 250, decayImmune = true, bodyShape = "Dragon" },
	{ id = "phoenix", name = "Gigante Fênix", desc = "Renasce das cinzas: Rebirth dá +50% em vez de +25%. NUNCA encolhe.", price = 0, robux = true, passKey = "PhoenixGiant", rarityTag = "SECRETO",
		color = Color3.fromRGB(255, 150, 30), skin = Color3.fromRGB(255, 200, 60), xpMult = 1.5, coinMult = 1.5, hungerDecayMult = 0.6, arenaPower = 16, arenaHp = 180, decayImmune = true, bodyShape = "Bird" },
} :: { SpeciesDef }

Config.SpeciesById = {} :: { [string]: SpeciesDef }
for _, sp in Config.Species do
	Config.SpeciesById[sp.id] = sp
end
Config.DefaultSpecies = "human"

----------------------------------------------------------------
-- v2: ESTÁGIOS VISUAIS — o Gigante fica mais BRAVO conforme sobe de nível
----------------------------------------------------------------
export type StageDef = { minLevel: number, name: string, eyeColor: Color3, browAngle: number, teeth: boolean, horns: boolean, aura: Color3?, mouthWidth: number }
Config.GiantStages = {
	{ minLevel = 1, name = "Bebê", eyeColor = Color3.fromRGB(20, 20, 20), browAngle = 0, teeth = false, horns = false, aura = nil, mouthWidth = 0.5 },
	{ minLevel = 10, name = "Criança", eyeColor = Color3.fromRGB(20, 20, 20), browAngle = 5, teeth = false, horns = false, aura = nil, mouthWidth = 0.6 },
	{ minLevel = 25, name = "Adolescente", eyeColor = Color3.fromRGB(255, 200, 40), browAngle = 12, teeth = true, horns = false, aura = nil, mouthWidth = 0.75 },
	{ minLevel = 50, name = "Guerreiro", eyeColor = Color3.fromRGB(255, 120, 20), browAngle = 20, teeth = true, horns = true, aura = Color3.fromRGB(255, 150, 40), mouthWidth = 0.9 },
	{ minLevel = 100, name = "Titã", eyeColor = Color3.fromRGB(255, 40, 40), browAngle = 28, teeth = true, horns = true, aura = Color3.fromRGB(255, 60, 60), mouthWidth = 1.0 },
	{ minLevel = 150, name = "Colosso", eyeColor = Color3.fromRGB(255, 0, 120), browAngle = 32, teeth = true, horns = true, aura = Color3.fromRGB(200, 40, 255), mouthWidth = 1.1 },
	{ minLevel = 200, name = "DEUS", eyeColor = Color3.fromRGB(255, 255, 255), browAngle = 35, teeth = true, horns = true, aura = Color3.fromRGB(255, 255, 255), mouthWidth = 1.2 },
} :: { StageDef }

function Config.stageForLevel(level: number): StageDef
	local s = Config.GiantStages[1]
	for _, st in Config.GiantStages do
		if level >= st.minLevel then
			s = st
		end
	end
	return s
end

----------------------------------------------------------------
-- v2: DECAY — ficou 3 dias sem alimentar? O Gigante começa a ENCOLHER.
-- Gigantes de Robux (Dragão/Fênix) e quem tem o pass Guardian / produto Freeze não encolhem.
----------------------------------------------------------------
Config.Decay = {
	GraceSeconds = 3 * 24 * 3600, -- 3 dias reais
	LevelsLostPerDay = 2, -- após a carência, perde 2 níveis por dia ausente
	MaxLevelsLost = 30, -- nunca perde mais que isso de uma vez (perdão parcial para quem volta)
	WarnAtSeconds = 2 * 24 * 3600, -- aviso "seu gigante está com fome" (para push notification externa / UI)
	FreezeProductSeconds = 7 * 24 * 3600, -- produto Robux: congela decay por 7 dias
	ReturnBonusCoins = 2000, -- recompensa por VOLTAR após 1+ dia (gancho de retorno)
	ReturnBonusBox = "rare",
}

----------------------------------------------------------------
-- v2: BOXE — combate corpo-a-corpo para disputar comida
----------------------------------------------------------------
Config.Combat = {
	PunchDamage = 12,
	HeavyDamage = 24,
	PunchCooldown = 0.45,
	HeavyCooldown = 1.6,
	PunchRange = 7,
	HeavyRange = 8,
	Knockback = 45,
	HeavyKnockback = 95,
	BlockDamageMult = 0.25,
	BlockBreakHeavy = true, -- heavy quebra a guarda
	MaxStamina = 100,
	StaminaPunch = 12,
	StaminaHeavy = 30,
	StaminaBlockPerSec = 15,
	StaminaRegenPerSec = 22,
	ComboWindow = 1.2,
	ComboDamageBonus = 0.15, -- +15% por hit no combo (máx 5)
	KOSeconds = 3.5, -- tempo caído após KO (vida chega a 0 → não morre, fica tonto)
	KOHealth = 100, -- HP base do lutador
	-- Força e HP crescem com o Gigante: lutador de alto nível defende melhor o seu objetivo
	HpPerLevel = 1.5, -- +1.5 HP por nível do Gigante (Lv100 = 250 HP)
	HpPerRebirth = 25,
	StrengthPerLevel = 0.01, -- +1% dano por nível (Lv100 = 2x)
	StrengthPerRebirth = 0.15,
	StrengthMoodHappy = 1.15, -- gigante feliz = dono mais forte
	KOBlurSeconds = 3.5, -- visão embaçada/escura durante o KO
	SafeZoneRadius = 45, -- em volta do próprio pátio ninguém pode ser socado (anti-grief total)
	ArenaAnyone = true,
}

----------------------------------------------------------------
-- v2: DROPS CONTESTADOS — comida cai do céu e precisa ser DEFENDIDA
-- Quem está em pé dentro do círculo quando o timer zera ganha. Soco empurra para fora.
----------------------------------------------------------------
Config.Drops = {
	MinInterval = 35,
	MaxInterval = 70,
	MaxActive = 3,
	ZoneRadius = 14,
	FallHeight = 160,
	FallTime = 3.5,
	WarnBeforeFall = 4, -- marcador no chão antes de cair
	ExpireIfNobody = 45,
	-- tempo de disputa por raridade: quanto mais rara, mais tempo precisa segurar o círculo
	HoldTimeByRarity = { Common = 6, Uncommon = 9, Rare = 14, Epic = 20, Legendary = 30, Mythic = 45, Secret = 60 },
	Weights = { Common = 38, Uncommon = 30, Rare = 18, Epic = 9, Legendary = 3.5, Mythic = 1.2, Secret = 0.3 },
	MinPlayersForRare = 2, -- com 1 jogador, Legendary+ não cai (evita farm solo)
	ProgressLossWhenOut = 0.5, -- perde 50% do progresso ao ser empurrado para fora
}

----------------------------------------------------------------
-- v2: GIANT CLASH — arena de gigantes (duelo 1v1 e campeonato)
----------------------------------------------------------------
Config.Arena = {
	DuelCooldown = 90,
	MinLevelToFight = 5,
	RoundSeconds = 20, -- duração da luta encenada
	-- força = (arenaPower * (1 + level*0.04) * (1 + rebirths*0.1) * moodMult) + sorte de 0..15%
	LevelFactor = 0.04,
	RebirthFactor = 0.1,
	LuckRange = 0.15,
	-- recompensas
	WinStealFoodCount = 2, -- vencedor rouba até 2 comidas do PÁTIO do perdedor (as mais raras primeiro)
	WinCoinsPct = 0.05, -- + 5% das moedas do perdedor
	WinCoinsCap = 25000,
	LoserProtectionSec = 300, -- perdedor não pode ser desafiado de novo por 5 min
	WagerOptional = true,
	-- campeonato
	TournamentEvery = 900, -- a cada 15 min
	TournamentMinPlayers = 3,
	TournamentPrizeBox = "legendary",
	TournamentPrizeCoins = 15000,
	ChampionTrophyDays = 1,
}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

Config.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(200, 200, 200), xp = 10, cps = 1 },
	Uncommon = { order = 2, color = Color3.fromRGB(80, 220, 100), xp = 30, cps = 3 },
	Rare = { order = 3, color = Color3.fromRGB(60, 140, 255), xp = 100, cps = 10 },
	Epic = { order = 4, color = Color3.fromRGB(170, 60, 255), xp = 350, cps = 35 },
	Legendary = { order = 5, color = Color3.fromRGB(255, 180, 20), xp = 1200, cps = 120 },
	Mythic = { order = 6, color = Color3.fromRGB(255, 60, 200), xp = 5000, cps = 500 },
	Secret = { order = 7, color = Color3.fromRGB(20, 20, 20), xp = 20000, cps = 2000 },
}

export type FoodDef = { id: string, name: string, rarity: Rarity, shape: string, color: Color3 }

Config.Foods = {
	{ id = "apple", name = "Maçã", rarity = "Common", shape = "Ball", color = Color3.fromRGB(230, 50, 50) },
	{ id = "bread", name = "Pão", rarity = "Common", shape = "Block", color = Color3.fromRGB(220, 170, 90) },
	{ id = "banana", name = "Banana", rarity = "Common", shape = "Cylinder", color = Color3.fromRGB(250, 230, 60) },
	{ id = "pizza", name = "Pizza", rarity = "Uncommon", shape = "Cylinder", color = Color3.fromRGB(240, 120, 40) },
	{ id = "burger", name = "Hambúrguer", rarity = "Uncommon", shape = "Cylinder", color = Color3.fromRGB(150, 90, 40) },
	{ id = "sushi", name = "Sushi", rarity = "Uncommon", shape = "Block", color = Color3.fromRGB(250, 250, 250) },
	{ id = "lavacake", name = "Bolo de Lava", rarity = "Rare", shape = "Cylinder", color = Color3.fromRGB(255, 90, 20) },
	{ id = "goldtaco", name = "Taco Dourado", rarity = "Rare", shape = "Wedge", color = Color3.fromRGB(255, 210, 60) },
	{ id = "ramen", name = "Ramen Épico", rarity = "Rare", shape = "Cylinder", color = Color3.fromRGB(255, 240, 180) },
	{ id = "diamonddonut", name = "Donut de Diamante", rarity = "Epic", shape = "Cylinder", color = Color3.fromRGB(120, 230, 255) },
	{ id = "galaxyicecream", name = "Sorvete Galáctico", rarity = "Epic", shape = "Ball", color = Color3.fromRGB(140, 60, 255) },
	{ id = "infinitebbq", name = "Churrasco Infinito", rarity = "Epic", shape = "Block", color = Color3.fromRGB(120, 40, 20) },
	{ id = "goldpizza", name = "Pizza Dourada", rarity = "Legendary", shape = "Cylinder", color = Color3.fromRGB(255, 200, 0) },
	{ id = "legendburger", name = "Hambúrguer Lendário", rarity = "Legendary", shape = "Cylinder", color = Color3.fromRGB(255, 150, 0) },
	{ id = "universelasagna", name = "Lasanha do Universo", rarity = "Mythic", shape = "Block", color = Color3.fromRGB(255, 40, 180) },
	{ id = "cosmiccoxinha", name = "Coxinha Cósmica", rarity = "Mythic", shape = "Wedge", color = Color3.fromRGB(255, 90, 220) },
	{ id = "infinitebrigadeiro", name = "Brigadeiro Infinito", rarity = "Secret", shape = "Ball", color = Color3.fromRGB(30, 15, 10) },
} :: { FoodDef }

Config.FoodById = {} :: { [string]: FoodDef }
for _, f in Config.Foods do
	Config.FoodById[f.id] = f
end

export type LunchboxDef = { id: string, name: string, price: number, color: Color3, weights: { [string]: number } }

Config.Lunchboxes = {
	{ id = "common", name = "Lunchbox Comum", price = 100, color = Color3.fromRGB(180, 180, 180),
		weights = { Common = 70, Uncommon = 20, Rare = 7, Epic = 2.5, Legendary = 0.45, Mythic = 0.05 } },
	{ id = "rare", name = "Lunchbox Rara", price = 750, color = Color3.fromRGB(60, 140, 255),
		weights = { Common = 30, Uncommon = 40, Rare = 22, Epic = 6, Legendary = 1.7, Mythic = 0.3 } },
	{ id = "epic", name = "Lunchbox Épica", price = 4000, color = Color3.fromRGB(170, 60, 255),
		weights = { Uncommon = 35, Rare = 40, Epic = 19, Legendary = 5, Mythic = 1 } },
	{ id = "legendary", name = "Lunchbox Lendária", price = 25000, color = Color3.fromRGB(255, 180, 20),
		weights = { Rare = 40, Epic = 40, Legendary = 16, Mythic = 4 } },
	{ id = "mythic", name = "Lunchbox Mítica", price = 150000, color = Color3.fromRGB(255, 60, 200),
		weights = { Epic = 50, Legendary = 38, Mythic = 12 } },
} :: { LunchboxDef }

Config.LunchboxById = {} :: { [string]: LunchboxDef }
for _, b in Config.Lunchboxes do
	Config.LunchboxById[b.id] = b
end

-- Preencha os IDs reais criados no Creator Hub.
Config.GamePasses = {
	DoubleCoins = 0,
	VIP = 0,
	AutoFeed = 0,
	DragonGiant = 0, -- espécie Dragão (nunca encolhe)
	PhoenixGiant = 0, -- espécie Fênix (nunca encolhe)
	Guardian = 0, -- TODOS os seus gigantes nunca encolhem + aura dourada
	BoxerPro = 0, -- +25% dano, +30% stamina, luvas douradas
	ArenaVIP = 0, -- cooldown de duelo pela metade, rouba 3 comidas em vez de 2
}
Config.GamePassInfo = {
	DoubleCoins = { name = "2x Moedas", desc = "Dobra TODA a renda passiva. Para sempre.", price = 299 },
	VIP = { name = "VIP", desc = "Nametag dourada, 1.5x XP e +4 slots no pátio.", price = 499 },
	AutoFeed = { name = "Auto-Feed", desc = "Seu Gigante come sozinho do pátio a cada 30s.", price = 399 },
	DragonGiant = { name = "Gigante DRAGÃO", desc = "Espécie secreta: 2x XP, 1.5x moedas, domina a arena e NUNCA encolhe.", price = 899 },
	PhoenixGiant = { name = "Gigante FÊNIX", desc = "Espécie secreta: Rebirth dá +50%, 1.5x moedas e NUNCA encolhe.", price = 799 },
	Guardian = { name = "Guardião", desc = "Seu Gigante NUNCA encolhe por inatividade, qualquer espécie. Aura dourada.", price = 349 },
	BoxerPro = { name = "Boxeador Pro", desc = "+25% dano nos socos, +30% stamina e luvas douradas.", price = 449 },
	ArenaVIP = { name = "Arena VIP", desc = "Metade do cooldown de duelo e rouba 3 comidas por vitória.", price = 399 },
}
Config.DevProducts = {
	Coins10k = { id = 0, coins = 10000 },
	Coins100k = { id = 0, coins = 100000 },
	SuperShield = { id = 0 },
	LuckyBox = { id = 0 },
	FreezeDecay7d = { id = 0 }, -- congela o encolhimento por 7 dias
	RestoreLevels = { id = 0 }, -- recupera TODOS os níveis perdidos por decay
	StaminaRefill = { id = 0 }, -- stamina cheia + 60s de stamina infinita
	ArenaRematch = { id = 0 }, -- zera o cooldown de duelo agora
	SpeciesReroll = { id = 0 }, -- troca de espécie grátis mantendo o nível
}
Config.DevProductInfo = {
	Coins10k = { name = "10.000 Moedas", desc = "Pacote inicial de moedas.", price = 99 },
	Coins100k = { name = "100.000 Moedas", desc = "Pacote grande de moedas.", price = 799 },
	SuperShield = { name = "Super Escudo (10 min)", desc = "Ninguém rouba do seu pátio por 10 minutos.", price = 49 },
	LuckyBox = { name = "Lucky Lunchbox", desc = "Uma Lunchbox com raridade mínima Rare garantida.", price = 149 },
	FreezeDecay7d = { name = "Congelar Gigante (7 dias)", desc = "Seu Gigante não encolhe por 7 dias, mesmo sem jogar.", price = 79 },
	RestoreLevels = { name = "Restaurar Níveis", desc = "Recupera todos os níveis perdidos por inatividade.", price = 199 },
	StaminaRefill = { name = "Energético", desc = "Stamina cheia agora + 60s de stamina infinita.", price = 29 },
	ArenaRematch = { name = "Revanche Imediata", desc = "Zera o cooldown de duelo da arena.", price = 39 },
	SpeciesReroll = { name = "Trocar Espécie", desc = "Troca para qualquer espécie comprável mantendo o nível.", price = 99 },
}

Config.DailyRewards = { 500, 1000, 2000, 3500, 5000, 8000, 15000 }

-- v2: SONS (IDs clássicos da biblioteca Roblox; troque à vontade, 0 = mudo)
-- IDs de assets. Após fazer upload (Creator Dashboard → Development Items → Audio/Decals), cole o ID no lugar do 0.
-- Os arquivos fonte estão em assets/ui e assets/audio. 0 = o jogo usa fallback procedural (UI vetorial / som da biblioteca Roblox).
-- Idiomas suportados pela tradução automática (Localization Table em assets/localization/FeedAGiant_Localization.csv)
Config.Locales = { "pt-br", "es", "en" }
Config.DefaultLocale = "pt-br"

Config.Assets = {
	Logo = 139277283937723, -- assets/ui/logo.png
	IconsSheet = 110810450318375, -- assets/ui/icons_sheet.png (grade 4x2: coin, glove, lunchbox, backpack / trophy, shield, crown, gear)
	Panel = 88757291686340, -- assets/ui/panel_9slice.png
}
Config.Sounds = {
	-- SFX: assets/audio/sfx_*.wav (gerados para este projeto). Fallback = biblioteca Roblox.
	Punch = "rbxassetid://12222216",
	Heavy = "rbxassetid://12222242",
	Block = "rbxassetid://12222225",
	KO = "rbxassetid://12222030",
	Impact = "rbxassetid://12222124",
	LevelUp = "rbxassetid://12222253",
	Evolve = "rbxassetid://12222005",
	Bell = "rbxassetid://12222152",
	Win = "rbxassetid://12222084",
	Coin = "rbxassetid://12222005",
	Whoosh = "rbxassetid://12222216",
	Click = "rbxassetid://12221967",
	-- Narrador (ElevenLabs, voz "Tyler – Arena Announcer"). Arquivos: assets/audio/vo_<nome>.<idioma>.mp3
	-- Suba os 15 arquivos e cole os IDs abaixo. 0 = mudo. O cliente escolhe o idioma pelo LocaleId do jogador.
	VO = {
		["pt-br"] = { Fight = 0, KO = 0, Evolved = 0, Drop = 0, Champion = 0 }, -- vo_fight.pt-BR.mp3 ...
		["es"] = { Fight = 0, KO = 0, Evolved = 0, Drop = 0, Champion = 0 }, -- vo_fight.es.mp3 ...
		["en"] = { Fight = 0, KO = 0, Evolved = 0, Drop = 0, Champion = 0 }, -- vo_fight.en.mp3 ...
	},
}

return Config
