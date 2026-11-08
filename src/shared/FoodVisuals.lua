--!strict
-- FoodVisuals — como cada comida aparece em 3D (Fase 2, item 3).
-- Modelos: Grab3D (CC0 1.0), otimizados em assets/foods/optimized (1.200 tris, textura 512 px).
-- Variações por nome e raridade (decisão do diretor técnico, autonomia dada pelo usuário em 08/11/2026):
--   style  muda o material da malha (a textura não aceita tinta, então o estilo troca a textura por
--          material sólido): gold = ouro maciço, crystal = cristal, galaxy/cosmic = cor cósmica;
--   fx     efeito extra do nome (lava, fumaça, vapor, estrelas);
--   o brilho (luz + faíscas) vem da RARIDADE (Rare ou melhor), igual em todo o jogo.
local FoodVisuals = {}

export type Style = "gold" | "crystal" | "galaxy" | "cosmic"
export type Fx = "lava" | "smoke" | "steam" | "stars" | "aura"
export type Visual = { file: string, style: Style?, fx: Fx? }

FoodVisuals.ByFood = {
	apple = { file = "food-apple" },
	bread = { file = "food-bread-loaf" },
	banana = { file = "food-banana" },
	pizza = { file = "food-pizza" },
	burger = { file = "food-burger" },
	sushi = { file = "food-sushi-set" },
	lavacake = { file = "food-cake-slice", fx = "lava" },
	goldtaco = { file = "food-taco", style = "gold" },
	ramen = { file = "food-ramen-bowl", fx = "steam" },
	diamonddonut = { file = "food-donut", style = "crystal" },
	galaxyicecream = { file = "food-ice-cream-cone", style = "galaxy", fx = "stars" },
	infinitebbq = { file = "food-steak-plate", fx = "smoke" },
	goldpizza = { file = "food-pizza", style = "gold" },
	legendburger = { file = "food-burger", style = "gold" },
	universelasagna = { file = "food-pasta-plate", fx = "aura" },
	cosmiccoxinha = { file = "food-fried-chicken", style = "cosmic", fx = "stars" },
	infinitebrigadeiro = { file = "food-chocolate-truffle-box", fx = "aura" },
} :: { [string]: Visual }

-- Material de cada estilo (só usado quando o estilo troca a textura).
FoodVisuals.Styles = {
	gold = { color = Color3.fromRGB(255, 196, 60), material = Enum.Material.Foil, transparency = 0 },
	crystal = { color = Color3.fromRGB(150, 232, 255), material = Enum.Material.Glass, transparency = 0.12 },
	galaxy = { color = Color3.fromRGB(150, 90, 255), material = Enum.Material.SmoothPlastic, transparency = 0 },
	cosmic = { color = Color3.fromRGB(255, 120, 215), material = Enum.Material.SmoothPlastic, transparency = 0 },
} :: { [string]: { color: Color3, material: Enum.Material, transparency: number } }

-- Brilho por raridade (order em Config.Rarities). Celular primeiro: poucas partículas por comida
-- (vault "Juice on a Budget": até 100 partículas/s por emissor no celular; aqui no máximo 8/s).
FoodVisuals.Glow = {
	[3] = { sparkles = 2, light = 0 },
	[4] = { sparkles = 4, light = 1.2 },
	[5] = { sparkles = 6, light = 1.6 },
	[6] = { sparkles = 8, light = 2.2 },
	[7] = { sparkles = 8, light = 2.6 },
} :: { [number]: { sparkles: number, light: number } }

function FoodVisuals.get(foodId: string): Visual?
	return FoodVisuals.ByFood[foodId]
end

return FoodVisuals
