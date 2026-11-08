--!strict
-- FoodModels — veste as peças de comida (pátio, drops, chuva, comida carregada) com a malha 3D
-- (Fase 2, item 3). A peça original continua existindo, invisível, com o mesmo tamanho da malha:
-- ela guarda o ClickDetector, o letreiro, a física e os atributos. Sem ID/modelo, nada muda.
--
-- Carregamento: InsertService uma vez por arquivo, em segundo plano no início do servidor
-- (preload). Quem monta comida usa só o cache (nunca cede/yield no meio da montagem).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(game.ReplicatedStorage.Shared.Config)
local FoodAssets = require(game.ReplicatedStorage.Shared.FoodAssets)
local FoodVisuals = require(game.ReplicatedStorage.Shared.FoodVisuals)

local FoodModels = {}

local folder: Folder? = nil
local templates: { [string]: Model | false } = {} -- arquivo -> modelo (false = falhou)
local onReady: { () -> () } = {}
local ready = false

-- Os modelos ficam em ReplicatedStorage.FoodTemplates para o cliente usar em ViewportFrames
-- (abertura de caixa, inventário, loja). São só malhas com textura: nada de lógica.
local function templateFolder(): Folder
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "FoodTemplates"
		f.Parent = ReplicatedStorage
		folder = f
	end
	return folder :: Folder
end

local function load(file: string): Model?
	local cached = templates[file]
	if typeof(cached) == "Instance" then
		return cached :: Model
	elseif cached == false then
		return nil
	end
	local assetId = (FoodAssets :: { [string]: string })[file]
	local numeric = assetId and tonumber(string.match(assetId, "%d+"))
	if not numeric then
		templates[file] = false
		return nil
	end
	local ok, loaded = pcall(function()
		return InsertService:LoadAsset(numeric :: number)
	end)
	if not ok or not loaded then
		warn("[FoodModels] não carregou", file, assetId, loaded)
		templates[file] = false
		return nil
	end
	local model = Instance.new("Model")
	model.Name = file
	for _, d in (loaded :: Instance):GetDescendants() do
		if d:IsA("MeshPart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = true
			d.Parent = model
		end
	end
	(loaded :: Instance):Destroy()
	if #model:GetChildren() == 0 then
		model:Destroy()
		templates[file] = false
		return nil
	end
	model.Parent = templateFolder()
	templates[file] = model
	return model
end

-- Carrega todos os modelos em segundo plano; chama as funções de FoodModels.whenReady no fim.
function FoodModels.preload()
	task.spawn(function()
		local seen: { [string]: boolean } = {}
		for _, visual in FoodVisuals.ByFood do
			if not seen[visual.file] then
				seen[visual.file] = true
				load(visual.file)
			end
		end
		ready = true
		for _, fn in onReady do
			task.spawn(fn)
		end
		table.clear(onReady)
	end)
end

function FoodModels.whenReady(fn: () -> ())
	if ready then
		task.spawn(fn)
	else
		table.insert(onReady, fn)
	end
end

local function cachedTemplate(foodId: string): Model?
	local visual = FoodVisuals.get(foodId)
	if not visual then
		return nil
	end
	local t = templates[visual.file]
	if typeof(t) == "Instance" then
		return t :: Model
	end
	return nil
end

function FoodModels.has(foodId: string): boolean
	return cachedTemplate(foodId) ~= nil
end

-- Tamanho (caixa) que a malha terá com a maior dimensão = `size` studs.
function FoodModels.boundsFor(foodId: string, size: number): Vector3?
	local t = cachedTemplate(foodId)
	if not t then
		return nil
	end
	local _, ext = t:GetBoundingBox()
	local k = size / math.max(ext.X, ext.Y, ext.Z, 1e-3)
	return ext * k
end

local function emitter(parent: BasePart, color: Color3, rate: number, opts: { [string]: any }?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "FoodFx"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(0.6, 1.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.1, 1)
	local extra: { [string]: any } = opts or {}
	for k, v in extra do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function addEffects(holder: BasePart, def: Config.FoodDef, visual: FoodVisuals.Visual)
	local rar = Config.Rarities[def.rarity]
	local glow = FoodVisuals.Glow[rar.order]
	if glow then
		emitter(holder, rar.color, glow.sparkles)
		if glow.light > 0 then
			local light = Instance.new("PointLight")
			light.Name = "FoodLight"
			light.Color = rar.color
			light.Brightness = glow.light
			light.Range = 3 + rar.order * 0.5
			light.Shadows = false
			light.Parent = holder
		end
	end
	local fx = visual.fx
	if fx == "lava" then
		emitter(holder, Color3.fromRGB(255, 120, 40), 6, {
			Speed = NumberRange.new(1.5, 3),
			SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(0, -4, 0),
		})
	elseif fx == "smoke" or fx == "steam" then
		emitter(holder, if fx == "smoke" then Color3.fromRGB(150, 140, 135) else Color3.fromRGB(255, 255, 255), 3, {
			LightEmission = 0,
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(10, 10),
			Size = NumberSequence.new(0.4, 1.4),
			Transparency = NumberSequence.new(0.55, 1),
			Lifetime = NumberRange.new(1.2, 2),
		})
	elseif fx == "stars" or fx == "aura" then
		emitter(holder, if fx == "stars" then Color3.fromRGB(255, 255, 255) else rar.color, 5, {
			Speed = NumberRange.new(0.2, 0.6),
			Lifetime = NumberRange.new(1.5, 2.5),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
end

-- Veste `holder` com a malha da comida. A malha fica centrada no holder, com a maior dimensão =
-- `size` studs, presa por solda (acompanha drops que caem e comida carregada na cabeça).
-- O holder fica invisível (Transparency 1) e sem contorno. Retorna o Model da malha, ou nil.
function FoodModels.dress(holder: BasePart, foodId: string, size: number): Model?
	local template = cachedTemplate(foodId)
	local def = Config.FoodById[foodId]
	local visual = FoodVisuals.get(foodId)
	if not template or not def or not visual then
		return nil
	end
	local mesh = template:Clone()
	mesh.Name = "FoodMesh"
	local _, ext = mesh:GetBoundingBox()
	mesh:ScaleTo(mesh:GetScale() * size / math.max(ext.X, ext.Y, ext.Z, 1e-3))
	local style = visual.style and FoodVisuals.Styles[visual.style]
	for _, d in mesh:GetDescendants() do
		if d:IsA("MeshPart") and style then
			d.TextureID = ""
			d.Color = style.color
			d.Material = style.material
			d.Transparency = style.transparency
		end
	end
	-- Centro da malha no centro do holder, sem herdar rotação do holder (cilindros deitados da v4).
	local upright = CFrame.new(holder.Position) * CFrame.Angles(0, select(2, holder.CFrame:ToOrientation()), 0)
	local boxCf = mesh:GetBoundingBox()
	mesh:PivotTo(upright * boxCf:ToObjectSpace(mesh:GetPivot()))
	for _, d in mesh:GetDescendants() do
		if d:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = holder
			weld.Part1 = d
			weld.Parent = d
		end
	end
	mesh.Parent = holder
	holder.Transparency = 1
	for _, child in holder:GetChildren() do
		if child:IsA("SelectionBox") or child.Name == "FoodFx" then
			child:Destroy()
		end
	end
	addEffects(holder, def, visual)
	return mesh
end

return FoodModels
