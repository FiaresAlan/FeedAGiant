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

export type Recipe = {
	lighting: { [string]: any },
	atmosphere: { [string]: any },
	bloom: { [string]: any },
	grade: { [string]: any },
	sky: { [string]: any },
	clouds: { [string]: any },
	sunRays: { [string]: any },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local LightingRecipes = {}

LightingRecipes.Recipes = {
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
	assign(owned(Lighting, "Sky", "RecipeSky"), recipe.sky)
	assign(owned(Lighting, "BloomEffect", "RecipeBloom"), recipe.bloom)
	assign(owned(Lighting, "ColorCorrectionEffect", "RecipeGrade"), recipe.grade)
	assign(owned(Lighting, "SunRaysEffect", "RecipeSunRays"), recipe.sunRays)
	assign(owned(Workspace.Terrain, "Clouds", "RecipeClouds"), recipe.clouds)
end

return LightingRecipes
