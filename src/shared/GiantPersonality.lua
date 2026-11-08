--!strict
-- GiantPersonality — o "jeito de se mexer" de cada espécie (animação procedural, GiantAnim).
--
-- Os modelos 3D não têm esqueleto no Roblox (medido em 08/11/2026: goblin, troll, dragão e hidra
-- chegam como 1 MeshPart com 0 Bones; o rig do FBX do goblin/troll não sobreviveu ao upload).
-- Por isso a animação é procedural: pose (inclinação, giro, pulo) + "squash & stretch" da malha.
-- Números baseados no método de animação do fwjelaa (make-anim, "LEVEL 4/5"): criaturas grandes
-- usam o preset PESADO — antecipação:recuperação ≈ 1:2, overshoot 3-6%, respiração lenta.
export type Cheer = "hop" | "spin" | "flap" | "stomp" | "wobble"
export type Personality = {
	breathe: number, -- squash da respiração (fração da altura)
	breatheHz: number, -- ciclos por segundo
	sway: number, -- graus de giro (olhar em volta)
	roll: number, -- graus de balanço lateral
	hover: number, -- sobe e desce (voadores), fração da altura
	lean: number, -- inclinação parada (zumbi curvado), graus
	chompPitch: number, -- graus da mordida
	chompSpeed: number, -- 1 = normal; > 1 morde mais rápido
	squash: number, -- força do squash no impacto (0..0.2)
	cheer: Cheer,
	weight: number, -- 0 leve .. 1 pesado (antecipação maior, recuperação mais lenta)
	twitch: number, -- espasmos curtos aleatórios (zumbi), graus
}

local function p(t: { [string]: any }): Personality
	local base: { [string]: any } = {
		breathe = 0.02,
		breatheHz = 0.25,
		sway = 2.5,
		roll = 0,
		hover = 0,
		lean = 0,
		chompPitch = 15,
		chompSpeed = 1,
		squash = 0.1,
		cheer = "hop",
		weight = 0.5,
		twitch = 0,
	}
	for k, v in t do
		base[k] = v
	end
	return base :: any
end

local GiantPersonality = {}

GiantPersonality.BySpecies = {
	-- Humano: equilibrado, pulinho com giro.
	human = p({ cheer = "spin", weight = 0.4 }),
	-- Goblin: nervoso e rápido, mordidas curtas e várias.
	goblin = p({ breatheHz = 0.4, sway = 6, chompSpeed = 1.5, chompPitch = 12, cheer = "hop", weight = 0.2 }),
	-- Zumbi: curvado, balança de lado, espasmos.
	zombie = p({ lean = 6, roll = 4, breatheHz = 0.18, twitch = 5, chompPitch = 20, cheer = "wobble", weight = 0.6 }),
	-- Troll: pesadão, quase não balança, comemora batendo os pés.
	troll = p({
		breathe = 0.015,
		breatheHz = 0.16,
		sway = 1.5,
		chompPitch = 18,
		squash = 0.14,
		cheer = "stomp",
		weight = 0.9,
	}),
	-- Golem: pedra; respiração mínima, mordida curta e dura, comemora pisando.
	golem = p({
		breathe = 0.008,
		breatheHz = 0.12,
		sway = 1,
		chompPitch = 10,
		squash = 0.05,
		cheer = "stomp",
		weight = 1,
	}),
	-- Jacaré: baixo, o "rabo" balança (giro), bote grande.
	gator = p({
		sway = 6,
		breatheHz = 0.2,
		chompPitch = 24,
		chompSpeed = 1.3,
		squash = 0.08,
		cheer = "wobble",
		weight = 0.6,
	}),
	-- Slime: gelatina — squash enorme, tudo exagerado.
	slime = p({ breathe = 0.06, breatheHz = 0.45, sway = 3, chompPitch = 6, squash = 0.2, cheer = "hop", weight = 0.1 }),
	-- Voadores: flutuam, balanço de asa.
	eagle = p({
		hover = 0.035,
		roll = 4,
		breatheHz = 0.3,
		chompPitch = 22,
		chompSpeed = 1.4,
		cheer = "flap",
		weight = 0.2,
	}),
	phoenix = p({ hover = 0.04, roll = 5, breatheHz = 0.28, chompPitch = 18, cheer = "flap", weight = 0.2 }),
	wyvern = p({ hover = 0.025, roll = 3, sway = 4, chompPitch = 20, cheer = "flap", weight = 0.5 }),
	-- Dragão: orgulhoso, respiração ampla, mordida com o peito.
	dragon = p({
		breathe = 0.025,
		breatheHz = 0.2,
		sway = 3,
		chompPitch = 18,
		squash = 0.1,
		cheer = "spin",
		weight = 0.7,
	}),
	-- Hidra: várias cabeças — balanço lateral contínuo ("ondula").
	hydra = p({
		roll = 5,
		sway = 5,
		breatheHz = 0.22,
		chompPitch = 16,
		chompSpeed = 1.2,
		cheer = "wobble",
		weight = 0.7,
	}),
} :: { [string]: Personality }

GiantPersonality.Default = p({})

function GiantPersonality.get(speciesId: string?): Personality
	return if speciesId
		then GiantPersonality.BySpecies[speciesId] or GiantPersonality.Default
		else GiantPersonality.Default
end

return GiantPersonality
