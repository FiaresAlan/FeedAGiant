--!strict
-- ToyBrickTheme — identidade visual inspirada nos studs clássicos do Roblox.
-- Não altera gameplay, collision ou Terrain; só materiais/cores e overlays visuais.
-- Funciona com MapService v4 assado e com mapa gerado; rollback pelo feature flag.
-- Não usa asset remoto, textura PBR, scripts externos, clones de criaturas ou HTTP.
local ToyBrickTheme = {}

ToyBrickTheme.Palette = {
	Ivory = Color3.fromRGB(235, 241, 245),      -- baseplates claras da referência
	IvoryAlt = Color3.fromRGB(226, 234, 239),
	Grass = Color3.fromRGB(113, 186, 100),       -- baseplates verdes, sem apagar a natureza
	GrassAlt = Color3.fromRGB(102, 176, 92),
	Arena = Color3.fromRGB(222, 210, 239),
	ArenaAlt = Color3.fromRGB(210, 194, 226),
	Navy = Color3.fromRGB(65, 108, 141),
	NavyLight = Color3.fromRGB(117, 161, 196),
	Cream = Color3.fromRGB(253, 236, 202),
	Gold = Color3.fromRGB(243, 188, 73),
}

ToyBrickTheme.Layout = {
	IslandRadius = 470,
	MeadowGrid = 56,
	MeadowRadius = 450,
	PlazaGrid = 12,
	PlazaRadius = 117,
	PlazaClearRadius = 33, -- não esconder o Caldeirão
	MeadowLimit = 210, -- orçamento aproximado de peças para o chão
	PlazaLimit = 390,
	ArenaLimit = 90,
	DragonLimit = 84,
	DistrictLimit = 90,
}
local P = ToyBrickTheme.Palette
local L = ToyBrickTheme.Layout

local ORIGINAL_PREFIX = "ToyBrickOriginal_"
local OVERLAY_NAME = "ToyBrickSurfaceOverlay"

local function ancestorNamed(inst: Instance, name: string): boolean
	local node: Instance? = inst.Parent
	while node do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Só blocos de cenário. Evita comida, NPCs, criaturas e MeshParts com UV/PBR.
function ToyBrickTheme.category(part: Part): string?
	if part.Transparency > 0.05 or part:GetAttribute("ToyBrickExclude") == true then
		return nil
	end
	local n = part.Name
	if n == "Floor" and part.Parent and string.match(part.Parent.Name, "^Base%d+$") then
		return "base"
	elseif n == "Path" and part.Size.Y <= 3 then
		return "path"
	elseif n == "PathEdge" then
		return "edge"
	elseif string.match(n, "^Slot%d+$") or n == "GiantAnchor" then
		return "baseaccent"
	elseif n == "Deck" and ancestorNamed(part, "DragonIsland") then
		return "bridge"
	elseif n == "Bench" or n == "BanquetTable" then
		return "furniture"
	elseif ancestorNamed(part, "ColossalKitchen")
		and (n == "ServeSpot" or n == "PrepA" or n == "PrepB" or n == "Tábua") then
		return "kitchen"
	elseif ancestorNamed(part, "ColossusLookout") and n == "PhotoSpot" then
		return "lookout"
	elseif ancestorNamed(part, "Arena") and part.Shape == Enum.PartType.Block
		and part.Size.X >= 3 and part.Size.Z >= 2 and part.Size.Y <= 3
		and n ~= "Emblem" then
		return "arena"
	end
	return nil
end

local function saveOriginal(part: Part)
	if part:GetAttribute(ORIGINAL_PREFIX .. "Material") ~= nil then
		return
	end
	part:SetAttribute(ORIGINAL_PREFIX .. "Material", part.Material.Name)
	part:SetAttribute(ORIGINAL_PREFIX .. "Variant", part.MaterialVariant)
	part:SetAttribute(ORIGINAL_PREFIX .. "Color", part.Color)
	part:SetAttribute(ORIGINAL_PREFIX .. "Top", part.TopSurface.Name)
	part:SetAttribute(ORIGINAL_PREFIX .. "Reflectance", part.Reflectance)
end

local function restoreOriginal(part: Part)
	local oldMaterial = part:GetAttribute(ORIGINAL_PREFIX .. "Material")
	if type(oldMaterial) ~= "string" then
		return
	end
	local oldVariant = part:GetAttribute(ORIGINAL_PREFIX .. "Variant")
	local oldColor = part:GetAttribute(ORIGINAL_PREFIX .. "Color")
	local oldTop = part:GetAttribute(ORIGINAL_PREFIX .. "Top")
	local oldReflectance = part:GetAttribute(ORIGINAL_PREFIX .. "Reflectance")
	local material = Enum.Material[oldMaterial]
	if material then
		part.Material = material
	end
	if type(oldVariant) == "string" then
		part.MaterialVariant = oldVariant
	end
	if typeof(oldColor) == "Color3" then
		part.Color = oldColor
	end
	if type(oldTop) == "string" then
		local surface = Enum.SurfaceType[oldTop]
		if surface then
			part.TopSurface = surface
		end
	end
	if type(oldReflectance) == "number" then
		part.Reflectance = oldReflectance
	end
	for _, key in { "Material", "Variant", "Color", "Top", "Reflectance" } do
		part:SetAttribute(ORIGINAL_PREFIX .. key, nil)
	end
end

local function stylePart(part: Part, category: string)
	saveOriginal(part)
	part.Material = Enum.Material.Plastic
	part.MaterialVariant = "" -- PBR anterior não pode encobrir os studs clássicos
	part.TopSurface = Enum.SurfaceType.Studs
	part.Reflectance = 0.025
	if category == "base" then
		-- Preserva identidade das oito cores, com acabamento pastel da referência.
		local oldColor = part:GetAttribute(ORIGINAL_PREFIX .. "Color")
		if typeof(oldColor) == "Color3" then
			part.Color = oldColor:Lerp(P.Ivory, 0.55)
		end
	elseif category == "path" then
		part.Color = P.Ivory
	elseif category == "edge" then
		part.Color = P.Navy
	elseif category == "bridge" then
		part.Color = P.Cream
	elseif category == "furniture" then
		part.Color = P.Gold
	elseif category == "arena" then
		part.Color = P.Arena
	elseif category == "kitchen" then
		part.Color = P.IvoryAlt
	elseif category == "lookout" then
		part.Color = P.Cream
	end
end

local function tile(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Reflectance = 0.025
	part.Parent = parent
	return part
end

local function polar(phiDegrees: number, radius: number): Vector2
	local radians = math.rad(phiDegrees)
	return Vector2.new(math.sin(radians) * radius, -math.cos(radians) * radius)
end

local function nearPond(x: number, z: number): boolean
	for _, pond in {
		{ 67.5, 235, 30 },
		{ 202.5, 240, 34 },
		{ 292.5, 230, 26 },
	} do
		local center = polar(pond[1], pond[2])
		if (Vector2.new(x, z) - center).Magnitude < pond[3] + 43 then
			return true
		end
	end
	return false
end

-- A ilha natural inteira ganha leitura de baseplate verde, exceto lagos e bordas.
-- Apenas ~170 placas GRANDES: studs vêm do próprio renderer, não de centenas
-- de MeshParts ou de milhares de studs individuais. Colisão segue no Terrain.
local function buildMeadow(root: Instance): number
	local count = 0
	local grid = L.MeadowGrid
	for x = -392, 392, grid do
		for z = -392, 392, grid do
			local outer = math.sqrt((math.abs(x) + grid / 2)^2 + (math.abs(z) + grid / 2)^2)
			if outer <= L.MeadowRadius and not nearPond(x, z) then
				count += 1
				local color = if (math.floor(x / grid) + math.floor(z / grid)) % 3 == 0
					then P.GrassAlt else P.Grass
				tile(root, "MeadowPlate", Vector3.new(grid - 0.65, 0.12, grid - 0.65),
					CFrame.new(x, 0.015, z), color)
			end
		end
	end
	return count
end

-- Placa clara contínua entre os caminhos da praça, preservando o relevo,
-- o caldeirão e as faixas-guia existentes. Sem collider/raycast: drops intocados.
local function buildPlaza(root: Instance): number
	local count = 0
	local grid = L.PlazaGrid
	for x = -114, 114, grid do
		for z = -114, 114, grid do
			local r = math.sqrt(x * x + z * z)
			if r > L.PlazaClearRadius and r + grid * 0.72 < L.PlazaRadius then
				count += 1
				local stripe = r >= 93 and r <= 107
				local color = if stripe then P.IvoryAlt
					elseif (math.floor(x / grid) + math.floor(z / grid)) % 5 == 0 then P.Cream
					else P.Ivory
				tile(root, "PlazaPlate", Vector3.new(grid - 0.2, 0.1, grid - 0.2),
					CFrame.new(x, 2.15, z), color)
			end
		end
	end
	return count
end

-- O piso circular da arena usa peças cilíndricas: studs clássicos não aparecem
-- na face superior delas. Tampas de quadriculado leves deixam o centro da coroa
-- e os limites de arena visíveis, sem alterar a superfície de luta.
local function buildArena(root: Instance, map: Instance): number
	local arena = map:FindFirstChild("Arena")
	local floor = arena and arena:FindFirstChild("ArenaFloor")
	if not floor or not floor:IsA("BasePart") then
		return 0
	end
	local center = floor.Position
	local count = 0
	for x = -18, 18, 6 do
		for z = -18, 18, 6 do
			local r = math.sqrt(x * x + z * z)
			if r > 9 and r < 20 then
				count += 1
				tile(root, "ArenaPlate", Vector3.new(5.65, 0.07, 5.65),
					CFrame.new(center.X + x, 0.70, center.Z + z),
					if (math.floor(x / 6) + math.floor(z / 6)) % 2 == 0 then P.Arena else P.ArenaAlt)
			end
		end
	end
	return count
end

-- A Ilha do Dragão também recebe studs, mantendo o centro do combate livre
-- para leitura das marcas de arena e dos telegráficos do chefe.
local function buildDragon(root: Instance, map: Instance): number
	local dragon = map:FindFirstChild("DragonIsland")
	local floor = dragon and dragon:FindFirstChild("FightFloor")
	if not floor or not floor:IsA("Part") then
		return 0
	end
	local center = floor.Position
	local y = center.Y + floor.Size.X / 2 + 0.055
	local count = 0
	for x = -36, 36, 8 do
		for z = -36, 36, 8 do
			local distance = math.sqrt(x * x + z * z)
			if distance > 25 and distance < 39 then
				count += 1
				tile(root, "DragonPlate", Vector3.new(7.6, 0.075, 7.6),
					CFrame.new(center.X + x, y, center.Z + z),
					if count % 3 == 0 then P.ArenaAlt else P.Arena)
			end
		end
	end
	return count
end

-- Cozinha, Mirante e totens da trilha são discos. Placas menores dão a mesma
-- linguagem da praça sem retangularizar visualmente cada ilha circular.
local function buildDistrict(root: Instance, map: Instance): number
	local district = map:FindFirstChild("LivingPlazaDistrict")
	if not district then
		return 0
	end
	local count = 0
	local regions = {
		{ "ColossalKitchen", "PisoInterno", 13, 4.5, P.Cream },
		{ "ColossusLookout", "Centro", 10, 4.5, P.Ivory },
	}
	for _, region in regions do
		local model = district:FindFirstChild(region[1])
		local discPart = model and model:FindFirstChild(region[2])
		if discPart and discPart:IsA("Part") then
			local r = region[3] :: number
			local grid = region[4] :: number
			local color = region[5] :: Color3
			local y = discPart.Position.Y + discPart.Size.X / 2 + 0.065
			for x = -r, r, grid do
				for z = -r, r, grid do
					if math.sqrt(x * x + z * z) + grid * 0.71 < r then
						count += 1
						tile(root, "DistrictPlate", Vector3.new(grid - 0.2, 0.08, grid - 0.2),
							CFrame.new(discPart.Position.X + x, y, discPart.Position.Z + z),
							color)
					end
				end
			end
		end
	end
	local trail = district:FindFirstChild("IngredientTrail")
	if trail then
		for _, part in trail:GetChildren() do
			if part:IsA("Part") and part.Name == "Tampa" then
				for x = -3, 3, 3 do
					for z = -3, 3, 3 do
						if x * x + z * z < 11 then
							count += 1
							tile(root, "TrailPlate", Vector3.new(2.8, 0.07, 2.8),
								CFrame.new(part.Position.X + x, part.Position.Y + part.Size.X / 2 + 0.06, part.Position.Z + z),
								P.Cream)
						end
					end
				end
			end
		end
	end
	return count
end

function ToyBrickTheme.remove(map: Instance)
	local overlay = map:FindFirstChild(OVERLAY_NAME)
	if overlay then
		overlay:Destroy()
	end
	for _, node in map:GetDescendants() do
		if node:IsA("Part") then
			restoreOriginal(node)
		end
	end
	map:SetAttribute("VisualTheme", nil)
end

function ToyBrickTheme.apply(map: Instance): { [string]: number }
	ToyBrickTheme.remove(map)
	local styled = 0
	for _, node in map:GetDescendants() do
		if node:IsA("Part") then
			local category = ToyBrickTheme.category(node)
			if category then
				stylePart(node, category)
				styled += 1
			end
		end
	end
	local overlay = Instance.new("Folder")
	overlay.Name = OVERLAY_NAME
	overlay.Parent = map
	local meadow = buildMeadow(overlay)
	local plaza = buildPlaza(overlay)
	local arena = buildArena(overlay, map)
	local dragon = buildDragon(overlay, map)
	local district = buildDistrict(overlay, map)
	-- Orçamentos explícitos para regressão de FPS mobile.
	if meadow > L.MeadowLimit or plaza > L.PlazaLimit or arena > L.ArenaLimit
		or dragon > L.DragonLimit or district > L.DistrictLimit then
		warn("[ToyBrickTheme] orçamento visual excedido:", meadow, plaza, arena, dragon, district)
	end
	map:SetAttribute("VisualTheme", "ToyBrick")
	return { styled = styled, meadow = meadow, plaza = plaza, arena = arena, dragon = dragon, district = district }
end

-- Aplicação no Studio, sempre numa cópia de teste:
-- require(game.ServerScriptService.Server.ToyBrickTheme).apply(workspace.Map)
-- Para reverter:
-- require(game.ServerScriptService.Server.ToyBrickTheme).remove(workspace.Map)
return ToyBrickTheme
