--!strict
-- LightingRecipes — receitas de iluminação guardadas como dados (Fase 1, estilo cartoon pintado).
-- Um único dono: só o servidor chama apply() (Lighting replica para os clientes).
-- Este módulo só mexe nos objetos que ele mesmo cria (nomes "Recipe*"); efeitos de outros
-- sistemas (ex.: blur do KO no cliente) ficam intocados.
--
-- Valores: vault "Stylized Lighting Recipes" §3.1 Bright cartoon (simuladores e hubs).
-- LightingStyle/PrioritizeLightingQuality ficam no default.project.json (Technology é
-- obsoleto e não é scriptável: vault "Lighting Technologies and Settings").
-- Nuvens: só renderizam sob Workspace.Terrain (vault "Atmosphere Sky Clouds and Post-Processing").
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local SkyAssets = require(script.Parent.SkyAssets)

export type Recipe = {
	lighting: { [string]: any },
	atmosphere: { [string]: any },
	bloom: { [string]: any },
	grade: { [string]: any },
	sky: { [string]: any },
	clouds: { [string]: any },
	sunRays: { [string]: any },
	-- Fase 1, item A: céu de 6 faces (SkyAssets). Só vale se as 6 faces tiverem ID;
	-- sem IDs, fica o céu padrão do Roblox (nada quebra).
	skybox: string?,
	-- Ajustes aplicados SÓ quando o skybox está ativo.
	skyboxSky: { [string]: any }?,
	skyboxClouds: { [string]: any }?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local LightingRecipes = {}

LightingRecipes.Recipes = {
	-- Inspiração: screenshot de jogo Roblox com studs claros, sombras limpas e céu azul.
	-- Sem PBR pago nem skybox de terceiros. A direção é centralizada/reversível.
	ToyboxDaylight = {
		lighting = {
			Ambient = rgb(154, 169, 184),
			OutdoorAmbient = rgb(183, 194, 207),
			Brightness = 2.8,
			ColorShift_Top = rgb(245, 245, 247),
			ColorShift_Bottom = rgb(20, 35, 55),
			EnvironmentDiffuseScale = 0.55,
			EnvironmentSpecularScale = 0.25,
			ClockTime = 13.7,
			GeographicLatitude = 25,
			GlobalShadows = true,
		},
		atmosphere = {
			Density = 0.18,
			Offset = 0.15,
			Color = rgb(191, 225, 255),
			Decay = rgb(121, 169, 219),
			Glare = 0.05,
			Haze = 0.45,
		},
		bloom = { Intensity = 0.2, Size = 22, Threshold = 1.6 },
		grade = { Brightness = 0.02, Contrast = 0.16, Saturation = 0.13, TintColor = rgb(255, 255, 255) },
		sunRays = { Intensity = 0.035, Spread = 0.65 },
		sky = { SunAngularSize = 13, MoonAngularSize = 11, CelestialBodiesShown = true },
		clouds = { Cover = 0.3, Density = 0.35, Color = rgb(255, 255, 255) },
	} :: Recipe,
	-- Fim de tarde (decisão do usuário, 07/11/2026). Base: vault "Stylized Lighting Recipes" §3.3
	-- Golden hour (ClockTime 17,6; ambiente 90/70/70 e 130/100/90). Ajustes deste jogo (regra prática):
	-- ClockTime 16,8 em vez de 17,6 e ambiente ~20% mais alto, para o estilo cartoon nunca ficar escuro e
	-- quem olha contra o sol não ver tudo em contraluz (o "Breaks when" da própria receita).
	GoldenAfternoon = {
		lighting = {
			Ambient = rgb(121, 112, 112),
			OutdoorAmbient = rgb(158, 139, 132),
			Brightness = 2.1,
			ColorShift_Top = rgb(255, 212, 165),
			ColorShift_Bottom = rgb(60, 40, 80),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0,
			ClockTime = 16.8,
			GeographicLatitude = 30,
			GlobalShadows = true,
		},
		atmosphere = {
			Density = 0.27,
			Offset = 0.2,
			Color = rgb(239, 212, 194),
			Decay = rgb(184, 144, 143),
			Glare = 0.18,
			Haze = 0.85,
		},
		bloom = { Intensity = 0.5, Size = 28, Threshold = 1.15 },
		grade = { Brightness = 0, Contrast = 0.15, Saturation = 0.05, TintColor = rgb(251, 247, 242) },
		sunRays = { Intensity = 0.06, Spread = 0.6 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, CelestialBodiesShown = true },
		clouds = { Cover = 0.5, Density = 0.5, Color = rgb(255, 236, 220) },
		-- Céu pintado "dourado" (assets/sky/dourado): HDRI CC0 qwantani_sunset_puresky recolorido
		-- (horizonte dourado → coral → lilás). O sol do céu foi girado para o azimute do sol da luz
		-- (−96,8°, medido no Studio com ClockTime 16,8 e latitude 30). O disco do sol do Roblox fica
		-- desligado: ele ficaria a 18° de altura, longe do sol pintado (2,7°), e apareceriam dois sóis.
		skybox = "dourado",
		skyboxSky = { CelestialBodiesShown = false },
		-- Nuvens 3D mais ralas para não esconder o degradê pintado (regra prática).
		skyboxClouds = { Cover = 0.32, Density = 0.4 },
	} :: Recipe,
	BrightCartoon = {
		lighting = {
			Ambient = rgb(110, 110, 125),
			OutdoorAmbient = rgb(150, 150, 160),
			Brightness = 2.5,
			ColorShift_Top = rgb(255, 228, 190), -- revisão Fase 1: mais quente
			ColorShift_Bottom = rgb(0, 0, 0),
			EnvironmentDiffuseScale = 0.3,
			EnvironmentSpecularScale = 0,
			ClockTime = 15, -- revisão Fase 1: sol mais baixo = sombras mais longas e luz de tarde
			GlobalShadows = true,
		},
		atmosphere = {
			-- Ajuste da revisão da Fase 1 (profundidade): Density 0,25→0,3 e Haze 0,5→1,2
			-- (vault Atmosphere: Haze tinge o horizonte; a ilha e o mar ganham degradê de distância).
			Density = 0.3,
			Offset = 0.1,
			Color = rgb(200, 225, 255),
			Decay = rgb(120, 160, 210),
			Glare = 0,
			Haze = 1.2,
		},
		bloom = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		grade = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.12, TintColor = rgb(255, 247, 235) },
		-- Raios de sol bem sutis (vault: só aparecem com o sol na tela; custo baixo)
		sunRays = { Intensity = 0.04, Spread = 0.5 },
		-- Céu padrão do Roblox (texturas internas; nenhum upload). Sol um pouco menor que o padrão (21).
		sky = { SunAngularSize = 14, MoonAngularSize = 11, CelestialBodiesShown = true },
		-- Nuvens leves de dia bonito (regra prática: abaixo do padrão 0,5/0,7 para não escurecer).
		clouds = { Cover = 0.45, Density = 0.45, Color = rgb(255, 255, 255) },
	} :: Recipe,
}

-- Classes que só podem ter um ativo em Lighting -> nome do objeto deste módulo.
local SINGLETONS: { [string]: string } = { Sky = "RecipeSky", Atmosphere = "RecipeAtmosphere" }

-- Encontra ou cria um objeto deste módulo; nunca reutiliza objetos de outros sistemas.
local function owned(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function assign(inst: Instance, props: { [string]: any })
	for key, value in props do
		(inst :: any)[key] = value
	end
end

function LightingRecipes.apply(name: string)
	local recipe = (LightingRecipes.Recipes :: { [string]: Recipe })[name]
	assert(recipe, `LightingRecipes: receita desconhecida {name}`)
	assign(Lighting, recipe.lighting)
	-- Só pode haver um Sky e um Atmosphere ativos: remove os que não são deste módulo.
	for _, child in Lighting:GetChildren() do
		local keep = SINGLETONS[child.ClassName]
		if keep and child.Name ~= keep then
			child:Destroy()
		end
	end
	assign(owned(Lighting, "Atmosphere", "RecipeAtmosphere"), recipe.atmosphere)
	local sky = owned(Lighting, "Sky", "RecipeSky")
	assign(sky, recipe.sky)
	assign(owned(Lighting, "BloomEffect", "RecipeBloom"), recipe.bloom)
	assign(owned(Lighting, "ColorCorrectionEffect", "RecipeGrade"), recipe.grade)
	assign(owned(Lighting, "SunRaysEffect", "RecipeSunRays"), recipe.sunRays)
	local clouds = owned(Workspace.Terrain, "Clouds", "RecipeClouds")
	assign(clouds, recipe.clouds)

	local faces = if recipe.skybox then SkyAssets[recipe.skybox] else nil
	if faces then
		local s = sky :: Sky
		s.SkyboxBk = faces.Bk
		s.SkyboxDn = faces.Dn
		s.SkyboxFt = faces.Ft
		s.SkyboxLf = faces.Lf
		s.SkyboxRt = faces.Rt
		s.SkyboxUp = faces.Up
		assign(sky, recipe.skyboxSky or {})
		assign(clouds, recipe.skyboxClouds or {})
	end
	sky:SetAttribute("Skybox", if faces then recipe.skybox else "padrão")
end

-- O céu de 6 faces desta receita está disponível (IDs enviados)?
function LightingRecipes.hasSkybox(name: string): boolean
	local recipe = (LightingRecipes.Recipes :: { [string]: Recipe })[name]
	return recipe ~= nil and recipe.skybox ~= nil and SkyAssets[recipe.skybox :: string] ~= nil
end

return LightingRecipes
