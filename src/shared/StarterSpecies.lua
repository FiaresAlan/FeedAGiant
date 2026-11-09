--!strict
-- StarterSpecies — as 3 espécies INICIAIS (prompt v4 §1; temas confirmados pelo usuário em 09/11/2026:
-- fire_starter, ice_starter, stone_starter). Features.StarterSpecies.
--
-- Pool FECHADO: nunca entram na loja, em Lunchbox, em ovo, em evento nem em sorteio. Por isso ficam FORA
-- da lista Config.Species (que a loja, as estátuas, os ovos e os bots percorrem); o Config só as registra
-- no índice Config.SpeciesById, para o resto do jogo (gigante, coleção, perfil) reconhecê-las.
-- O servidor só aceita estes 3 ids em GiantService.grantStarterSpecies, uma vez por conta.
--
-- Arte: "variação de cor do modelo existente" (pedido do usuário). Os gigantes são uma malha só, sem
-- esqueleto; a malha do Humano é reaproveitada e TINGIDA pela cor da MeshPart (a cor multiplica a
-- textura), mais uma aura de partículas própria. Nenhum modelo novo, nenhum upload.
-- Atributos = os do Humano (grátis) + 1 bônus pequeno de identidade, para nunca ficarem melhores que as
-- espécies pagas.
local StarterSpecies = {}

StarterSpecies.Ids = { "fire_starter", "ice_starter", "stone_starter" }

StarterSpecies.List = {
	{
		id = "fire_starter",
		name = "Gigante de Fogo",
		desc = "Coração quente: +5% de moedas.",
		price = 0,
		robux = false,
		rarityTag = "Inicial",
		color = Color3.fromRGB(255, 110, 50),
		skin = Color3.fromRGB(255, 150, 100),
		xpMult = 1,
		coinMult = 1.05,
		hungerDecayMult = 1,
		arenaPower = 10,
		arenaHp = 100,
		decayImmune = false,
		bodyShape = "Humanoid",
		starter = true,
		tint = Color3.fromRGB(255, 165, 120),
		aura = "fire",
	},
	{
		id = "ice_starter",
		name = "Gigante de Gelo",
		desc = "Calma gelada: a fome cai 10% mais devagar.",
		price = 0,
		robux = false,
		rarityTag = "Inicial",
		color = Color3.fromRGB(90, 180, 255),
		skin = Color3.fromRGB(170, 215, 255),
		xpMult = 1,
		coinMult = 1,
		hungerDecayMult = 0.9,
		arenaPower = 10,
		arenaHp = 100,
		decayImmune = false,
		bodyShape = "Humanoid",
		starter = true,
		tint = Color3.fromRGB(165, 210, 255),
		aura = "ice",
	},
	{
		id = "stone_starter",
		name = "Gigante de Pedra",
		desc = "Pele de rocha: +10% de vida fora da arena justa.",
		price = 0,
		robux = false,
		rarityTag = "Inicial",
		color = Color3.fromRGB(140, 130, 120),
		skin = Color3.fromRGB(175, 165, 150),
		xpMult = 1,
		coinMult = 1,
		hungerDecayMult = 1,
		arenaPower = 10,
		arenaHp = 110,
		decayImmune = false,
		bodyShape = "Humanoid",
		starter = true,
		tint = Color3.fromRGB(175, 168, 158),
		aura = "stone",
	},
}

StarterSpecies.ById = {} :: { [string]: any }
for _, sp in StarterSpecies.List do
	StarterSpecies.ById[sp.id] = sp
end

function StarterSpecies.isStarter(id: any): boolean
	return type(id) == "string" and StarterSpecies.ById[id] ~= nil
end

return StarterSpecies
