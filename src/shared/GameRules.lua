--!strict
-- GameRules — regras e números das novidades de 08/11/2026 (missão "evolução integrada").
-- Tudo aqui é configurável e compartilhado entre servidor (que decide) e cliente (que só MOSTRA).
-- O servidor nunca confia no cliente para nenhum destes cálculos.
--
-- Decisões registradas em docs/GAME_BRIEF.md ("Decisões do diretor técnico", 08/11/2026 noite).
local EggDropTables = require(script.Parent.EggDropTables)

local GameRules = {}

---------------------------------------------------------------------------
-- 4.1 Sequência de alimentação, 4.3 traços das comidas, 4.4 alimentação crítica
---------------------------------------------------------------------------
GameRules.Feed = {
	-- A sequência sobe a cada alimentação VÁLIDA feita até StreakWindow segundos depois da anterior.
	-- 40 s é folgado: dá tempo de ir ao pátio/mochila sem "ficar clicando sem parar".
	StreakWindow = 40,
	StreakStep = 0.1, -- +10% de XP por passo
	StreakMaxSteps = 5, -- teto: x1,5 a partir da 6ª alimentação seguida
	-- Crítica: chance pequena, multiplicador de crescimento. Nada disso se compra com Robux.
	CritChance = 0.06,
	CritMult = 2.5,
	-- Tempo do voo da comida até a boca (FeedFx) = momento da mordida (GiantAnim).
	FlightSeconds = 0.6,
}

export type Trait = "grow" | "coin" | "spicy" | "sweet"
export type TraitDef = {
	id: Trait,
	name: string, -- nome curto mostrado ao jogador (traduzível pelo Locale)
	hint: string, -- frase curta do benefício
	color: Color3,
	icon: string, -- símbolo curto (sem imagem nova: texto)
	xpMult: number, -- ao alimentar
	incomeMult: number, -- exposta no pátio
	critMult: number, -- multiplica a chance de crítica
	streakBonus: number, -- passos extras de sequência
	fillHunger: boolean, -- enche a fome até 100
}

-- Quatro características só (pedido: "poucas, bem compreensíveis").
GameRules.Traits = {
	grow = {
		id = "grow",
		name = "Crescimento",
		hint = "+40% XP ao alimentar",
		color = Color3.fromRGB(110, 230, 110),
		icon = "▲",
		xpMult = 1.4,
		incomeMult = 0.75,
		critMult = 1,
		streakBonus = 0,
		fillHunger = false,
	},
	coin = {
		id = "coin",
		name = "Renda",
		hint = "+50% moedas exposta no pátio",
		color = Color3.fromRGB(255, 205, 60),
		icon = "$",
		xpMult = 0.75,
		incomeMult = 1.5,
		critMult = 1,
		streakBonus = 0,
		fillHunger = false,
	},
	spicy = {
		id = "spicy",
		name = "Picante",
		hint = "3x chance de alimentação CRÍTICA",
		color = Color3.fromRGB(255, 100, 60),
		icon = "✦",
		xpMult = 1,
		incomeMult = 1,
		critMult = 3,
		streakBonus = 0,
		fillHunger = false,
	},
	sweet = {
		id = "sweet",
		name = "Doce",
		hint = "Enche a fome e sobe +2 na sequência",
		color = Color3.fromRGB(255, 130, 210),
		icon = "♥",
		xpMult = 1,
		incomeMult = 1,
		critMult = 1,
		streakBonus = 2,
		fillHunger = true,
	},
} :: { [string]: TraitDef }

-- Uma característica por comida (os 3D já existentes). Cada raridade mistura os tipos.
GameRules.FoodTraits = {
	apple = "grow",
	bread = "coin",
	banana = "sweet",
	pizza = "coin",
	burger = "grow",
	sushi = "spicy",
	lavacake = "spicy",
	goldtaco = "coin",
	ramen = "grow",
	diamonddonut = "coin",
	galaxyicecream = "sweet",
	infinitebbq = "grow",
	goldpizza = "coin",
	legendburger = "grow",
	universelasagna = "grow",
	cosmiccoxinha = "spicy",
	infinitebrigadeiro = "sweet",
	-- Porção da Carne Gigante (evento 4.5): muito crescimento, nenhuma renda especial.
	giantmeat = "grow",
} :: { [string]: Trait }

function GameRules.traitOf(foodId: string): TraitDef?
	local t = GameRules.FoodTraits[foodId]
	return if t then GameRules.Traits[t] else nil
end

function GameRules.streakMult(streak: number): number
	local F = GameRules.Feed
	local steps = math.clamp(streak - 1, 0, F.StreakMaxSteps)
	return 1 + steps * F.StreakStep
end

---------------------------------------------------------------------------
-- Sistema 1 e 2: coleção de gigantes (progresso por espécie, transferência, exposição, offline)
---------------------------------------------------------------------------
GameRules.Roster = {
	-- Ao ganhar uma espécie NOVA, ela herda esta fração do XP TOTAL do gigante ativo naquele
	-- momento. Uma vez só por espécie (profile.giants[id].inherited). O antigo não perde nada.
	TransferFraction = 0.3,
	-- Vagas de exposição na base (criaturas que não são o gigante ativo).
	DisplaySlots = 3,
	-- Renda da exposição (moedas/s) = Base + PerLevel × nível do gigante exposto. Exemplo: nível 20
	-- = 0,5 + 0,15×20 = 3,5 moedas/s (uma comida Incomum no pátio rende 3). É complementar.
	DisplayBase = 0.5,
	DisplayPerLevel = 0.15,
	-- Offline: a exposição continua rendendo, a metade da velocidade, até 8 h (configurável).
	OfflineCapSeconds = 8 * 3600,
	OfflineRate = 0.5,
	OfflineMinSeconds = 120, -- menos que isso não vale a mensagem
}

---------------------------------------------------------------------------
-- 4.6 Recordes pessoais e Objetivos do Diário (P5)
---------------------------------------------------------------------------
export type RecordDef = { id: string, name: string }
GameRules.Records = {
	{ id = "maxLevel", name = "Maior gigante (nível)" },
	{ id = "sessionLevels", name = "Mais níveis numa sessão" },
	{ id = "bestStreak", name = "Maior sequência" },
	{ id = "delivered", name = "Comidas entregues na base" },
	{ id = "bestFeedXp", name = "Maior alimentação (XP)" },
} :: { RecordDef }

export type ObjectiveDef = {
	id: string,
	text: string, -- "{n}" vira o alvo
	goal: number,
	coins: number,
	xp: number,
}
-- Três tarefas por dia, sorteadas desta lista por dia (mesma para todos no mesmo dia).
-- Recompensas em moedas e XP (sem moeda nova, sem item aleatório pago).
GameRules.Objectives = {
	{ id = "feed", text = "Alimente seu gigante {n} vezes", goal = 15, coins = 800, xp = 200 },
	{ id = "streak", text = "Faça uma sequência de {n}", goal = 5, coins = 1000, xp = 250 },
	{ id = "crit", text = "Consiga {n} alimentação crítica", goal = 1, coins = 900, xp = 250 },
	{ id = "deliver", text = "Entregue {n} comidas do mapa na base", goal = 3, coins = 1200, xp = 300 },
	{ id = "battle", text = "Vença {n} batalhas de gigantes", goal = 2, coins = 1200, xp = 300 },
	{ id = "boss", text = "Ajude a derrotar o Dragão {n} vez", goal = 1, coins = 1500, xp = 400 },
	{ id = "meat", text = "Leve {n} porção de Carne Gigante para a base", goal = 1, coins = 1000, xp = 300 },
	{ id = "levels", text = "Suba {n} níveis com qualquer gigante", goal = 3, coins = 1000, xp = 0 },
} :: { ObjectiveDef }
GameRules.ObjectivesPerDay = 3
-- Bônus por completar as 3 do dia: 1 caixa Rara grátis (não paga, só jogando).
GameRules.ObjectivesAllDoneBox = "rare"

-- Missão semanal (prompt v4, 09/11/2026; Features.WeeklyQuest). Toda semana aparecem 3 opções (as
-- mesmas para todos) e o jogador ESCOLHE 1. Troca permitida 1 vez por semana (o progresso recomeça).
-- Recompensa maior que as diárias: moedas + XP + 1 Lunchbox Épica grátis (não paga). Missão completa
-- e não resgatada continua resgatável depois da virada da semana (nunca se perde).
GameRules.WeeklyQuests = {
	{ id = "feed", text = "Alimente seu gigante {n} vezes", goal = 120, coins = 9000, xp = 2500 },
	{ id = "deliver", text = "Entregue {n} comidas do mapa na base", goal = 20, coins = 10000, xp = 2500 },
	{ id = "battle", text = "Vença {n} batalhas de gigantes", goal = 15, coins = 10000, xp = 3000 },
	{ id = "boss", text = "Ajude a derrotar o Dragão {n} vezes", goal = 4, coins = 12000, xp = 3500 },
	{ id = "meat", text = "Leve {n} porções de Carne Gigante para a base", goal = 6, coins = 9000, xp = 2500 },
	{ id = "levels", text = "Suba {n} níveis com qualquer gigante", goal = 20, coins = 10000, xp = 0 },
} :: { ObjectiveDef }
GameRules.WeeklyOptions = 3
GameRules.WeeklyBox = "epic"

-- Semana UTC começando na segunda (o dia 0 de 1970 foi uma quinta: +3 alinha a virada na segunda).
function GameRules.weekIndex(now: number): number
	return (now // 86400 + 3) // 7
end

-- As 3 opções da semana (determinístico: iguais para todos os servidores).
function GameRules.weeklyOptions(week: number): { ObjectiveDef }
	local list = GameRules.WeeklyQuests
	local rng = Random.new(week * 104729 + 31)
	local idx = {}
	for i = 1, #list do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(GameRules.WeeklyOptions, #list) do
		table.insert(out, list[idx[i]])
	end
	return out
end

function GameRules.weeklyById(id: string): ObjectiveDef?
	for _, q in GameRules.WeeklyQuests do
		if q.id == id then
			return q
		end
	end
	return nil
end

-- Escolha determinística das tarefas do dia (dia = os.time() // 86400).
function GameRules.objectivesForDay(day: number): { ObjectiveDef }
	local list = GameRules.Objectives
	local rng = Random.new(day * 7919 + 17)
	local idx = {}
	for i = 1, #list do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(GameRules.ObjectivesPerDay, #list) do
		table.insert(out, list[idx[i]])
	end
	return out
end

---------------------------------------------------------------------------
-- 4.5 Carne Gigante (evento de disputa)
---------------------------------------------------------------------------
GameRules.Meat = {
	Every = { 420, 600 }, -- entre 7 e 10 min (horário próprio, com aviso)
	FirstDelay = 240,
	WarnSeconds = 20, -- aviso para o servidor antes de cair
	PortionsBase = 4,
	PortionsPerPlayer = 2,
	PortionsMax = 14,
	PerPlayer = 2, -- cada jogador corta no máximo 2 porções por evento: vários ganham
	CutSeconds = 1.2, -- segurar perto da carne para cortar
	Reach = 18,
	Lifetime = 90, -- a carne some depois disso
	FoodId = "giantmeat",
}

---------------------------------------------------------------------------
-- Sistema 3: batalhas por turnos (arena dos gigantes, PvE)
---------------------------------------------------------------------------
export type MoveDef = {
	id: string,
	name: string,
	power: number, -- multiplicador da força
	accuracy: number, -- 0..1
	effect: string?, -- "stun" | "weaken" | "guard"
	effectChance: number?,
	desc: string,
}
-- Quatro estilos, três golpes cada. Sem elementos, sem fraquezas: chance de acerto e dano.
GameRules.MoveKits = {
	brute = {
		{ id = "smash", name = "Pancada", power = 1.0, accuracy = 0.95, desc = "Seguro: 95% de acerto." },
		{
			id = "quake",
			name = "Pisão Sísmico",
			power = 0.7,
			accuracy = 0.8,
			effect = "stun",
			effectChance = 0.5,
			desc = "50% de deixar tonto (perde a vez).",
		},
		{ id = "crush", name = "Esmagar", power = 1.9, accuracy = 0.55, desc = "Muito forte, mas erra muito." },
	},
	striker = {
		{ id = "bite", name = "Mordida", power = 1.0, accuracy = 0.95, desc = "Seguro: 95% de acerto." },
		{
			id = "roar",
			name = "Rugido",
			power = 0.4,
			accuracy = 0.9,
			effect = "weaken",
			effectChance = 1,
			desc = "Baixa a defesa: +35% de dano nele por 2 turnos.",
		},
		{ id = "blast", name = "Sopro", power = 1.7, accuracy = 0.65, desc = "Forte, 65% de acerto." },
	},
	agile = {
		{ id = "jab", name = "Golpe Rápido", power = 0.9, accuracy = 1.0, desc = "Nunca erra." },
		{
			id = "dodge",
			name = "Esquiva",
			power = 0.5,
			accuracy = 0.95,
			effect = "guard",
			effectChance = 1,
			desc = "Ataca leve e o próximo golpe dele erra mais.",
		},
		{ id = "dive", name = "Rasante", power = 1.6, accuracy = 0.7, desc = "Forte, 70% de acerto." },
	},
	tricky = {
		{ id = "slap", name = "Tapa Gosmento", power = 0.9, accuracy = 0.95, desc = "Seguro: 95% de acerto." },
		{
			id = "goo",
			name = "Gosma",
			power = 0.5,
			accuracy = 0.85,
			effect = "stun",
			effectChance = 0.6,
			desc = "60% de deixar tonto (perde a vez).",
		},
		{
			id = "bounce",
			name = "Quique",
			power = 1.5,
			accuracy = 0.75,
			effect = "weaken",
			effectChance = 0.3,
			desc = "Forte; 30% de baixar a defesa.",
		},
	},
} :: { [string]: { MoveDef } }

GameRules.KitBySpecies = {
	human = "agile",
	goblin = "agile",
	eagle = "agile",
	phoenix = "agile",
	gator = "striker",
	dragon = "striker",
	wyvern = "striker",
	hydra = "striker",
	golem = "brute",
	troll = "brute",
	zombie = "brute",
	slime = "tricky",
} :: { [string]: string }

function GameRules.movesFor(speciesId: string): { MoveDef }
	return GameRules.MoveKits[GameRules.KitBySpecies[speciesId] or "striker"]
end

GameRules.TurnBattle = {
	TurnSeconds = 12, -- tempo para escolher; sem escolha, usa o golpe 1 (seguro)
	WeakenMult = 1.35,
	WeakenTurns = 2,
	GuardAccuracy = 0.6, -- multiplica a chance de acerto do próximo golpe do adversário
	MaxRounds = 14, -- passou disso, vence quem tem mais vida (%)
	DamageScale = 2.2, -- dano = força × golpe × isto (±10%): luta de 5 a 8 rodadas
	FoeLevelSpread = 2,
}

---------------------------------------------------------------------------
-- Sistema 4: ilha do Dragão (boss coletivo)
---------------------------------------------------------------------------
GameRules.BossIsland = {
	Phase2At = 0.5, -- "Fúria": pisões mais rápidos, 2 alvos
	Phase3At = 0.2, -- "Chuva de fogo": 3 círculos espalhados
	Phase2StompMult = 0.65,
	MinShare = 0.03, -- 3% do dano total = participação válida
	MinHits = 3, -- ou pelo menos 3 golpes acertados
	-- Recompensa de participação (vitória ou não, ninguém é punido pelo resultado do grupo):
	JoinCoinsBase = 300,
	JoinCoinsPerLevel = 8,
	JoinXpBase = 120,
	JoinXpPerLevel = 3,
	FailFraction = 0.5, -- se o dragão fugir, metade da participação
	-- Bônus proporcional ao dano (só na vitória): pool dividido pela fatia de dano de cada um.
	BonusPoolPerPlayer = 900,
	-- Prêmio de conclusão: a caixa épica grátis já existente (Config.Boss, 2 por dia).
	PendingKeep = 20, -- quantos ids de luta já resgatados guardar no perfil (anti-duplicação)
}

---------------------------------------------------------------------------
-- Especificação v3 (08/11/2026). Tudo atrás de Features (desligado por padrão).
---------------------------------------------------------------------------
-- Pity das Lunchboxes: a cada caixa ABERTA COM MOEDAS OU ROBUX sem comida Épica ou melhor, o
-- contador sobe; na caixa número Hard a raridade mínima passa a ser Épica (garantida). Qualquer
-- Épica ou melhor zera. Caixas grátis (drops, diário, Dragão) não contam nem zeram. Sem "soft
-- pity": a chance mostrada antes da compra é sempre a chance real daquela abertura (vault: "Pity
-- not reflected in next-roll odds" é erro comum). O contador fica salvo no perfil (pityCount).
GameRules.Pity = {
	Hard = 50,
	MinRarity = "Epic",
}

-- Proteção da sequência diária ("backup"): completar o ciclo de 7 dias dá 1 proteção (máx. 2).
-- Se o jogador perder a janela de 48 h e tiver proteção, ela é gasta e a sequência continua.
-- Só ganha jogando (produto pago de proteção NÃO foi criado: monetização nova pede o dono).
GameRules.StreakBackup = {
	PerCycle = 1,
	Max = 2,
}

-- Roubo ético (§5.4 adaptado): base de quem tem nível abaixo de MinVictimLevel não pode ser
-- roubada; cada ladrão tem até MaxPerDay roubos bem-sucedidos por dia (dia UTC).
GameRules.StealLimits = {
	MinVictimLevel = 5,
	MaxPerDay = 3,
}

-- Primeiro acesso (§3 adaptado): presente de boas-vindas = 1 Lunchbox Comum guardada (o jogador
-- abre clicando, nunca automático). Primeira alimentação com efeito 2x.
GameRules.Onboarding = {
	WelcomeBox = "common",
	ArrivalSeconds = 2.5,
}

---------------------------------------------------------------------------
-- Sistema de Ovos (aprovado 08/11/2026; docs/VALIDACAO_OVOS_V1.md). Atrás de Features.EggSystem.
---------------------------------------------------------------------------
-- Ovos dão GIGANTES (espécies). O tamanho decide raridade, tempo, nível inicial e de onde vem.
-- Chances por espécie (pesos): a MESMA tabela é sorteada no servidor e mostrada na janela.
-- Espécies iniciais (Fogo/Gelo/Pedra), Dragão e Fênix nunca entram aqui.
GameRules.Eggs = {
	Order = { "small", "medium", "large", "huge", "massive" },
	Sizes = {
		small = {
			name = "Ovo Pequeno",
			rarity = "Common",
			seconds = 180,
			level = 1,
			price = 3000, -- loja de moedas
			scale = 2.6, -- altura em studs no ninho
			model = "egg-small",
			weights = EggDropTables.weights("small"), -- faixas do usuário (09/11), src/shared/EggDropTables.lua
		},
		medium = {
			name = "Ovo Médio",
			rarity = "Rare",
			seconds = 300,
			level = 5,
			price = 12000,
			scale = 3.2,
			model = "egg-medium",
			weights = EggDropTables.weights("medium"), -- faixas do usuário (09/11), src/shared/EggDropTables.lua
		},
		large = {
			name = "Ovo Grande",
			rarity = "Epic",
			seconds = 480,
			level = 10,
			scale = 3.8,
			model = "egg-large",
			weights = EggDropTables.weights("large"), -- faixas do usuário (09/11), src/shared/EggDropTables.lua
		},
		huge = {
			name = "Ovo Enorme",
			rarity = "Legendary",
			seconds = 720,
			level = 20,
			scale = 4.4,
			model = "egg-huge",
			weights = EggDropTables.weights("huge"), -- faixas do usuário (09/11), src/shared/EggDropTables.lua
		},
		massive = {
			name = "Ovo Colossal",
			rarity = "Mythic",
			seconds = 1200,
			level = 30,
			scale = 5.2,
			model = "egg-massive",
			weights = EggDropTables.weights("massive"), -- faixas do usuário (09/11), src/shared/EggDropTables.lua
		},
	} :: { [string]: any },
	MaxStored = 3, -- ovos guardados comprados na loja
	MaxStoredHard = 6, -- prêmios (Dragão, marcos) passam do limite até aqui, nunca somem em silêncio
	SlotLevels = { 1, 25, 50 }, -- maior nível já alcançado para abrir o 1º, 2º e 3º lugar do ninho
	FeedCut = 0.20, -- alimentar com comida Comum: -20% do tempo que falta (1 vez por ovo)
	WarmCut = 0.10, -- ficar perto por WarmSeconds: -10% do tempo que falta (1 vez por ovo)
	WarmSeconds = 30,
	WarmRadius = 10, -- studs do centro do ninho (conferido no servidor)
	NestReach = 32, -- distância máxima para usar o ninho (servidor)
	BossEggSize = "large", -- vitória sobre o Dragão: 1 Ovo Grande por dia
	Milestones = { { level = 100, size = "huge" }, { level = 200, size = "massive" } },
	TutorialSeconds = 75, -- ovo do primeiro acesso (Médio, 60-90 s)
	-- Ovos v2 (09/11/2026, docs/OVOS_V2_DESIGN.md): estrelas de cuidado e ovos no mapa.
	-- Laço: alimentar o SEU gigante enquanto o ovo choca (quantas vezes, por tamanho).
	BondFeeds = { small = 3, medium = 5, large = 8, huge = 12, massive = 20 },
	StarLevels = 1, -- cada estrela: +1 nível na espécie nova
	StarDupBonus = 0.25, -- cada estrela: +25% de XP no repetido
	DropChance = 0.04, -- 4% dos drops do mapa viram um ovo (com o sistema ligado)
	DropSize = "small",
	DropSpeed = 0.88, -- quem carrega o ovo anda a 88%
	DropUnlock = 10, -- segundos até poder pegar depois de cair
	RareAnnounceOrder = 4, -- espécie nova Épica ou melhor: aviso para o servidor (1 a cada 10 s)
	-- Prêmio de vitória contra o Dragão (pedido do usuário, 09/11, item 16): 1 ovo aleatório GRÁTIS
	-- junto da Lunchbox, dentro do mesmo limite diário da caixa. O texto do prêmio lista os tamanhos.
	BossEggWeights = { small = 40, medium = 32, large = 20, huge = 8 },
}

---------------------------------------------------------------------------
-- Mutações (noite de 09/11/2026; ideia de "clima + mutação" dos simuladores de jardim, adaptada).
-- Durante os eventos que JÁ existem, a comida EXPOSTA no pátio pode ganhar uma mutação permanente
-- (vai junto para a mochila e até num roubo). Grátis: nunca sai de caixa (chances pagas intactas).
-- Escolha do jogador: deixar no pátio (mais renda) ou alimentar o gigante (mais XP). Features.Mutations.
---------------------------------------------------------------------------
GameRules.Mutations =
	{
		gold = {
			name = "Dourada",
			income = 1.5,
			xp = 1.5,
			color = Color3.fromRGB(255, 205, 60),
			event = "GoldenHour",
			chance = 0.04,
		},
		juicy = {
			name = "Suculenta",
			income = 1.25,
			xp = 2,
			color = Color3.fromRGB(90, 200, 255),
			event = "FoodRain",
			chance = 0.04,
		},
		rainbow = {
			name = "Arco-íris",
			income = 2,
			xp = 2.5,
			color = Color3.fromRGB(255, 120, 230),
			event = "LuckyBoxes",
			chance = 0.015,
		},
	} :: { [string]: { name: string, income: number, xp: number, color: Color3, event: string, chance: number } }
---------------------------------------------------------------------------
-- Gigante Ancestral (noite de 09/11/2026; Features.Ancestral). Meta COLETIVA do servidor: cada
-- alimentação de qualquer jogador enche o Banquete; cheio, o Ancestral acorda, faz chover comida na
-- praça e dá +XP para todos por alguns minutos. Nada pago, ninguém perde nada.
---------------------------------------------------------------------------
GameRules.Ancestral = {
	GoalBase = 60,
	GoalPerPlayer = 40, -- 1 jogador: 100 pontos; 8 jogadores: 380
	PointsByOrder = { 1, 2, 3, 5, 8, 12, 20 }, -- Comum ... Secreto
	XpBuff = 1.25, -- +25% de XP para todos no servidor
	BuffSeconds = 300,
	FeastDrops = 10, -- itens que caem na praça (comida/caixa/ovo, mesmas chances dos drops normais)
	FeastSeconds = 30,
	SleepCooldown = 480, -- depois de acordar, dorme 8 min antes de voltar a contar
	Angle = 112.5, -- posição no pé das montanhas (entre duas bases, longe da ponte do Dragão)
	Radius = 505,
	Height = 110, -- altura em studs
}

---------------------------------------------------------------------------
-- Fusão (noite de 09/11/2026; Features.Fusion). 3 comidas IGUAIS (mesmo id, nenhuma já fundida) da
-- mochila viram 1 "Gigantesca": ocupa 1 vaga e vale um pouco mais que as 3 juntas. Determinístico
-- (sem sorteio). Mutação: a Gigantesca fica com a MELHOR das três (maior renda).
---------------------------------------------------------------------------
GameRules.Fusion = {
	Count = 3,
	Mult = 3.2, -- renda e XP da Gigantesca (3 comidas = 3,0; +0,2 de prêmio por juntar)
	Scale = 1.45, -- tamanho no pátio
}

GameRules.MutationTick = 15 -- segundos entre sorteios durante o evento (chance acima é por sorteio e por comida)

-- Mutação que um evento pode dar (nil se nenhum).
function GameRules.mutationForEvent(eventId: string?): string?
	if not eventId then
		return nil
	end
	for id, m in GameRules.Mutations do
		if m.event == eventId then
			return id
		end
	end
	return nil
end

-- Multiplicadores de uma comida (sem mutação = 1).
function GameRules.mutationIncome(mut: string?): number
	local m = mut and GameRules.Mutations[mut]
	return if m then m.income else 1
end
function GameRules.mutationXp(mut: string?): number
	local m = mut and GameRules.Mutations[mut]
	return if m then m.xp else 1
end

return GameRules
