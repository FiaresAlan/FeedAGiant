--!strict
-- ArtFactory — modelo 3D opcional, importado PELO DONO no Studio.
-- Nunca usa IDs inventados, requer assets externos nem substitui o cenário se
-- um template estiver ausente/inválido. Todos os objetos copiados são SOMENTE
-- geometria visual, ancorada e sem física, scripts ou prompts.
local ServerStorage = game:GetService("ServerStorage")
local Manifest = require(game.ReplicatedStorage.Shared.ArtManifest)

local ArtFactory = {}

local MAX_PARTS_PER_PROP = 32
local MAX_SOURCE_EXTENT = 5000
local MAX_FINAL_SPAN = 26
local MAX_SCALE = 30
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, reason: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[ArtFactory] " .. key .. ": " .. reason .. ". Usando fallback geométrico.")
end

local function safeVisualOnly(source: Instance, key: string): Model?
	local count = 0
	-- Não processar sequer templates suspeitos, incluindo scripts escondidos.
	for _, d in source:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
			or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("ProximityPrompt") then
			warnOnce(key, "script, remote ou prompt não autorizado dentro do modelo importado")
			return nil
		end
		if d:IsA("BasePart") then
			count += 1
		end
	end
	if source:IsA("BasePart") then
		count += 1
	end
	if count <= 0 or count > MAX_PARTS_PER_PROP then
		warnOnce(key, string.format("quantidade de peças fora do limite (1–%d): %d", MAX_PARTS_PER_PROP, count))
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Art_" .. key
	local allParts: { BasePart } = {}
	if source:IsA("BasePart") then
		table.insert(allParts, source)
	end
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(allParts, d)
		end
	end
	for _, original in allParts do
		local ok, clone = pcall(function()
			return original:Clone()
		end)
		if not ok or not clone or not clone:IsA("BasePart") then
			model:Destroy()
			warnOnce(key, "peça original não pôde ser clonada")
			return nil
		end
		for _, d in clone:GetDescendants() do
			-- Apenas materiais e texturas 3D. Sem anexos executáveis ou físicos.
			if not (d:IsA("SurfaceAppearance") or d:IsA("SpecialMesh")
				or d:IsA("Decal") or d:IsA("Texture")) then
				d:Destroy()
			end
		end
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false
		clone.CastShadow = false
		clone.Parent = model
	end
	return model
end

local function imported(key: string): Instance?
	local entry = Manifest.get(key)
	if not entry then
		warnOnce(key, "chave de arte desconhecida")
		return nil
	end
	local root = ServerStorage:FindFirstChild(Manifest.FolderName)
	if not root then
		return nil -- instalação opcional: não poluir output em Studio sem imports
	end
	local item = root:FindFirstChild(entry.template)
	if not item then
		return nil
	end
	if item:IsA("Model") or item:IsA("MeshPart") or item:IsA("Part") then
		return item
	end
	warnOnce(key, "template não é Model ou BasePart")
	return nil
end

local function fitAndCenter(
	model: Model,
	cf: CFrame,
	span: number,
	atGround: boolean
): boolean
	local ok, err = pcall(function()
		local _, ext = model:GetBoundingBox()
		local maxSize = math.max(ext.X, ext.Y, ext.Z)
		if maxSize < 0.001 or maxSize > MAX_SOURCE_EXTENT then
			error("dimensões inválidas")
		end
		local target = math.clamp(span, 0.5, MAX_FINAL_SPAN)
		local factor = target / maxSize
		if factor < 0.001 or factor > MAX_SCALE then
			error("escala fora do limite")
		end
		model:ScaleTo(factor)
		local centered, finalExt = model:GetBoundingBox()
		local centerToPivot = centered:ToObjectSpace(model:GetPivot())
		local desiredCenter = if atGround then cf * CFrame.new(0, finalExt.Y / 2, 0) else cf
		model:PivotTo(desiredCenter * centerToPivot)
	end)
	if not ok then
		model:Destroy()
		warn("[ArtFactory] Erro ajustando modelo: ", err)
		return false
	end
	return true
end

local function prepare(key: string, cf: CFrame, span: number, atGround: boolean): Model?
	local template = imported(key)
	if not template then
		return nil
	end
	local safe = safeVisualOnly(template, key)
	if not safe then
		return nil
	end
	if not fitAndCenter(safe, cf, span, atGround) then
		return nil
	end
	safe:SetAttribute("ImportedVisualOnly", true)
	safe:SetAttribute("ArtKey", key)
	return safe
end

-- Substitui APENAS a parte visual. O Part original continua servindo de anchor
-- para ProximityPrompt, atributos e validação de distância no servidor.
function ArtFactory.replace(fallback: BasePart, key: string, span: number): boolean
	local replacement = prepare(key, fallback.CFrame, span, false)
	if not replacement then
		return false
	end
	replacement.Parent = fallback.Parent
	fallback.Transparency = 1
	return true
end

-- Decoração adicional de chão. Se não houver importação, nada é colocado.
function ArtFactory.decorate(parent: Instance, key: string, cf: CFrame, span: number): Model?
	local visual = prepare(key, cf, span, true)
	if visual then
		visual.Parent = parent
	end
	return visual
end

return ArtFactory
