--!strict
-- GiantService v2 — espécies, estágios visuais (Bebê→DEUS), decay por ausência, bônus de retorno.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local CreatureModels = require(game.ReplicatedStorage.Shared.CreatureModels)
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local GiantService = {}
local giants: { [Player]: Model } = {}
local anchors: { [Player]: Part } = {}

---------------------------------------------------------------------------
-- Fase 2: modelos 3D das criaturas (CreatureModels/CreatureAssets). Sem ID, nada muda.
---------------------------------------------------------------------------
local templateFolder: Folder? = nil
local templates: { [string]: Model | false } = {}

-- Carrega o Model enviado (InsertService, uma vez por arquivo) e guarda em ServerStorage.
local function getTemplate(file: string, assetId: string): Model?
	local cached = templates[file]
	if cached == false then
		return nil -- já falhou antes: não tenta de novo a cada atualização
	elseif cached then
		return cached :: Model
	end
	-- "mesh:<malha>|<textura>": só malha+textura (ex.: gerado pela IA do Studio e ainda não publicado
	-- como pacote). Monta a MeshPart com AssetService:CreateMeshPartAsync (vault: Importing Models and Rigs).
	local meshUri, texUri = string.match(assetId, "^mesh:([^|]+)|(.+)$")
	if meshUri and texUri then
		local okMesh, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(meshUri), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		if not okMesh or not part then
			warn("[GiantService] não montou a malha", file, part)
			templates[file] = false
			return nil
		end
		local mp = part :: MeshPart
		mp.TextureID = texUri
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanTouch = false
		mp.CanQuery = false
		local model = Instance.new("Model")
		model.Name = file
		mp.Parent = model
		model.PrimaryPart = mp
		if not templateFolder then
			local f = Instance.new("Folder")
			f.Name = "CreatureTemplates"
			f.Parent = ServerStorage
			templateFolder = f
		end
		model.Parent = templateFolder
		templates[file] = model
		return model
	end
	local numeric = tonumber(string.match(assetId, "%d+"))
	local ok, loaded = pcall(function()
		return InsertService:LoadAsset(numeric :: number)
	end)
	if not ok or not loaded then
		warn("[GiantService] não carregou o modelo", file, assetId, loaded)
		templates[file] = false
		return nil
	end
	local model = Instance.new("Model")
	model.Name = file
	for _, child in (loaded :: Instance):GetChildren() do
		child.Parent = model
	end
	(loaded :: Instance):Destroy()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	if not templateFolder then
		local f = Instance.new("Folder")
		f.Name = "CreatureTemplates"
		f.Parent = ServerStorage
		templateFolder = f
	end
	model.Parent = templateFolder
	templates[file] = model
	return model
end

-- Esconde (ou mostra de novo) o corpo de blocos; guarda a transparência original.
local function setPrimitivesHidden(model: Model, hidden: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:FindFirstAncestor("CreatureMesh") then
			if hidden then
				if d:GetAttribute("OrigTransparency") == nil then
					d:SetAttribute("OrigTransparency", d.Transparency)
				end
				d.Transparency = 1
			else
				local t = d:GetAttribute("OrigTransparency")
				if type(t) == "number" then
					d.Transparency = t
					d:SetAttribute("OrigTransparency", nil)
				end
			end
		end
	end
end

-- Coloca/troca a malha da espécie (chamar com o modelo em escala 1, depois do applyStage).
local function ensureCreatureMesh(player: Player, model: Model, speciesId: string, isBaby: boolean)
	local file, assetId, yaw = CreatureModels.resolve(speciesId, isBaby)
	local current = model:FindFirstChild("CreatureMesh")
	if current and file and current:GetAttribute("File") == file then
		setPrimitivesHidden(model, true) -- o applyStage pode ter mostrado olhos/chifres de novo
		return
	end
	if current then
		current:Destroy()
	end
	local template = if file and assetId then getTemplate(file, assetId) else nil
	local anchor = anchors[player]
	if not template or not anchor then
		setPrimitivesHidden(model, false)
		return
	end
	local mesh = template:Clone()
	mesh.Name = "CreatureMesh"
	mesh:SetAttribute("File", file)
	-- pés no topo do pedestal, centro no pedestal, frente da base (+ yaw da espécie)
	local cf, size = mesh:GetBoundingBox()
	local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
	local offset = mesh:GetPivot():ToObjectSpace(bottom)
	local target = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(yaw), 0)
	mesh:PivotTo(target * offset:Inverse())
	mesh.Parent = model
	setPrimitivesHidden(model, true)
end
local lastStage: { [Player]: string } = {}
GiantService.OnReturnBonus = nil :: ((Player, number) -> ())?

function GiantService.scaleForLevel(level: number): number
	return Config.Giant.BaseScale + level * Config.Giant.ScalePerLevel
end

function GiantService.species(profile: DataService.Profile): Config.SpeciesDef
	return Config.SpeciesById[profile.species] or Config.SpeciesById[Config.DefaultSpecies]
end

function GiantService.isDecayImmune(profile: DataService.Profile): boolean
	return GiantService.species(profile).decayImmune
		or profile.passes.Guardian == true
		or profile.freezeUntil > os.time()
end

local function mk(
	model: Model,
	anchor: Part,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Util.makePart({
		Name = name,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	if shape then
		p.Shape = shape
	end
	p.CFrame = anchor.CFrame * CFrame.new(offset)
	return p
end

local function buildGiantModel(player: Player, anchor: Part, sp: Config.SpeciesDef): Model
	local model = Instance.new("Model")
	model.Name = "Giant_" .. player.Name
	local skin, body = sp.skin, sp.color
	local shape = sp.bodyShape
	local torso: Part
	if shape == "Beast" then
		torso = mk(model, anchor, "Torso", Vector3.new(2.2, 1.6, 3.2), Vector3.new(0, 2.6, 0), body)
		mk(model, anchor, "Head", Vector3.new(1.6, 1.2, 2.2), Vector3.new(0, 3.2, -2.4), skin)
		mk(model, anchor, "Tail", Vector3.new(0.6, 0.6, 2.4), Vector3.new(0, 2.6, 2.6), body)
		for i, x in { -0.8, 0.8 } do
			mk(model, anchor, "LegF" .. i, Vector3.new(0.7, 1.8, 0.7), Vector3.new(x, 0.9, -1), skin)
			mk(model, anchor, "LegB" .. i, Vector3.new(0.7, 1.8, 0.7), Vector3.new(x, 0.9, 1), skin)
		end
	elseif shape == "Bird" then
		torso = mk(model, anchor, "Torso", Vector3.new(1.8, 2.2, 1.4), Vector3.new(0, 3.2, 0), body, Enum.PartType.Ball)
		mk(model, anchor, "Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 5, -0.2), skin, Enum.PartType.Ball)
		mk(model, anchor, "Beak", Vector3.new(0.4, 0.3, 0.8), Vector3.new(0, 4.9, -1), Color3.fromRGB(255, 190, 40))
		mk(model, anchor, "WingL", Vector3.new(0.3, 1.6, 2.6), Vector3.new(-1.3, 3.4, 0), body)
		mk(model, anchor, "WingR", Vector3.new(0.3, 1.6, 2.6), Vector3.new(1.3, 3.4, 0), body)
		mk(model, anchor, "LeftLeg", Vector3.new(0.4, 2, 0.4), Vector3.new(-0.5, 1, 0), Color3.fromRGB(255, 190, 40))
		mk(model, anchor, "RightLeg", Vector3.new(0.4, 2, 0.4), Vector3.new(0.5, 1, 0), Color3.fromRGB(255, 190, 40))
	elseif shape == "Dragon" then
		torso = mk(model, anchor, "Torso", Vector3.new(2.4, 2.4, 2.2), Vector3.new(0, 3.6, 0), body)
		mk(model, anchor, "Head", Vector3.new(1.6, 1.4, 2), Vector3.new(0, 5.6, -0.8), skin)
		mk(model, anchor, "Tail", Vector3.new(0.7, 0.7, 3), Vector3.new(0, 3, 2.4), body)
		mk(model, anchor, "WingL", Vector3.new(0.2, 2.6, 3), Vector3.new(-1.9, 4.6, 0.4), skin)
		mk(model, anchor, "WingR", Vector3.new(0.2, 2.6, 3), Vector3.new(1.9, 4.6, 0.4), skin)
		mk(model, anchor, "LeftLeg", Vector3.new(1, 2.4, 1), Vector3.new(-0.7, 1.2, 0), body)
		mk(model, anchor, "RightLeg", Vector3.new(1, 2.4, 1), Vector3.new(0.7, 1.2, 0), body)
	elseif shape == "Robot" then
		torso = mk(
			model,
			anchor,
			"Torso",
			Vector3.new(2.6, 2.4, 1.4),
			Vector3.new(0, 3.6, 0),
			body,
			nil,
			Enum.Material.Slate
		)
		mk(model, anchor, "Head", Vector3.new(1.6, 1.4, 1.4), Vector3.new(0, 5.6, 0), skin, nil, Enum.Material.Slate)
		mk(
			model,
			anchor,
			"LeftArm",
			Vector3.new(1.2, 2.6, 1.2),
			Vector3.new(-2, 3.4, 0),
			skin,
			nil,
			Enum.Material.Slate
		)
		mk(
			model,
			anchor,
			"RightArm",
			Vector3.new(1.2, 2.6, 1.2),
			Vector3.new(2, 3.4, 0),
			skin,
			nil,
			Enum.Material.Slate
		)
		mk(
			model,
			anchor,
			"LeftLeg",
			Vector3.new(1.1, 2.4, 1.1),
			Vector3.new(-0.7, 1.2, 0),
			body,
			nil,
			Enum.Material.Slate
		)
		mk(
			model,
			anchor,
			"RightLeg",
			Vector3.new(1.1, 2.4, 1.1),
			Vector3.new(0.7, 1.2, 0),
			body,
			nil,
			Enum.Material.Slate
		)
	elseif shape == "Slime" then
		torso = mk(model, anchor, "Torso", Vector3.new(2.8, 2.2, 2.8), Vector3.new(0, 1.1, 0), body, Enum.PartType.Ball)
		torso.Transparency = 0.25
		local head =
			mk(model, anchor, "Head", Vector3.new(1.8, 1.6, 1.8), Vector3.new(0, 2.8, 0), skin, Enum.PartType.Ball)
		head.Transparency = 0.2
	else
		torso = mk(model, anchor, "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3.5, 0), body)
		mk(model, anchor, "Head", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 5.4, 0), skin, Enum.PartType.Ball)
		mk(model, anchor, "LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3.5, 0), skin)
		mk(model, anchor, "RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3.5, 0), skin)
		mk(model, anchor, "LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1.5, 0), Color3.fromRGB(60, 60, 120))
		mk(model, anchor, "RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1.5, 0), Color3.fromRGB(60, 60, 120))
	end
	local head = model:FindFirstChild("Head") :: Part
	local hc = head.CFrame
	local hz = -head.Size.Z / 2
	local function face(name: string, size: Vector3, off: Vector3, color: Color3): Part
		local p = Util.makePart({
			Name = name,
			Size = size,
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
		p.CFrame = hc * CFrame.new(off)
		return p
	end
	face("EyeL", Vector3.new(0.25, 0.35, 0.1), Vector3.new(-0.3, 0.15, hz), Color3.new(0, 0, 0))
	face("EyeR", Vector3.new(0.25, 0.35, 0.1), Vector3.new(0.3, 0.15, hz), Color3.new(0, 0, 0))
	face("BrowL", Vector3.new(0.4, 0.1, 0.1), Vector3.new(-0.3, 0.45, hz), Color3.new(0, 0, 0))
	face("BrowR", Vector3.new(0.4, 0.1, 0.1), Vector3.new(0.3, 0.45, hz), Color3.new(0, 0, 0))
	face("Mouth", Vector3.new(0.7, 0.25, 0.1), Vector3.new(0, -0.3, hz), Color3.fromRGB(200, 40, 60))
	local teeth = face("Teeth", Vector3.new(0.6, 0.1, 0.1), Vector3.new(0, -0.22, hz - 0.02), Color3.new(1, 1, 1))
	teeth.Transparency = 1
	for i, x in { -0.45, 0.45 } do
		local horn = Util.makePart({
			Name = "Horn" .. i,
			Size = Vector3.new(0.3, 0.8, 0.3),
			Color = Color3.fromRGB(240, 230, 200),
			CanCollide = false,
			Parent = model,
		})
		horn.CFrame = hc * CFrame.new(x, head.Size.Y / 2 + 0.3, 0) * CFrame.Angles(0, 0, math.rad(-x * 40))
		horn.Transparency = 1
	end
	model.PrimaryPart = torso
	-- Pivô nos PÉS (topo do pedestal), não no tronco: o ScaleTo cresce a partir do pivô, e com o pivô
	-- no tronco os pés afundavam no chão ~(altura do tronco x (escala - 1)) — medido no teste de
	-- 08/11: gigante nível 12 com as pernas enterradas ~15 studs.
	torso.PivotOffset = torso.CFrame:ToObjectSpace(anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0))

	local label = Util.makeBillboard(torso, "", UDim2.fromOffset(260, 80), Vector3.new(0, 4, 0))
	local infoGui = label.Parent
	if infoGui then
		infoGui.Name = "InfoGui"
	end
	label.Name = "Info"

	local fx = Instance.new("ParticleEmitter")
	fx.Name = "FeedFX"
	fx.Rate = 0
	fx.Lifetime = NumberRange.new(0.6, 1.2)
	fx.Speed = NumberRange.new(6, 12)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
	fx.Size = NumberSequence.new(0.8, 0)
	fx.Parent = torso

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Rate = 0
	aura.Lifetime = NumberRange.new(1, 2)
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.LightEmission = 1
	aura.Size = NumberSequence.new(1.5, 0)
	aura.Parent = torso
	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Brightness = 0
	light.Range = 30
	light.Parent = torso

	model.Parent = Workspace
	return model
end

local function applyStage(model: Model, stage: Config.StageDef, profile: DataService.Profile)
	for _, n in { "EyeL", "EyeR" } do
		local e = model:FindFirstChild(n) :: Part?
		if e then
			e.Color = stage.eyeColor
		end
	end
	local head = model:FindFirstChild("Head") :: Part?
	if head then
		for sign, n in { [-1] = "BrowL", [1] = "BrowR" } do
			local b = model:FindFirstChild(n) :: Part?
			if b then
				b.CFrame = head.CFrame
					* CFrame.new(sign * 0.3, 0.45, -head.Size.Z / 2)
					* CFrame.Angles(0, 0, math.rad(stage.browAngle * sign))
			end
		end
	end
	local mouth = model:FindFirstChild("Mouth") :: Part?
	if mouth then
		mouth.Size = Vector3.new(0.7 * stage.mouthWidth * 2, 0.25, 0.1)
	end
	local teeth = model:FindFirstChild("Teeth") :: Part?
	if teeth then
		teeth.Transparency = if stage.teeth then 0 else 1
	end
	for i = 1, 2 do
		local h = model:FindFirstChild("Horn" .. i) :: Part?
		if h then
			h.Transparency = if stage.horns then 0 else 1
		end
	end
	local torso = model.PrimaryPart
	if torso then
		local aura = torso:FindFirstChild("Aura") :: ParticleEmitter?
		local light = torso:FindFirstChild("AuraLight") :: PointLight?
		local color = stage.aura
		if profile.passes.Guardian then
			color = Color3.fromRGB(255, 215, 0)
		end
		if profile.championUntil > os.time() then
			color = Color3.fromRGB(255, 255, 255)
		end
		if aura and light then
			if color then
				aura.Color = ColorSequence.new(color)
				aura.Rate = 25
				light.Color = color
				light.Brightness = 2
			else
				aura.Rate = 0
				light.Brightness = 0
			end
		end
	end
end

local function refreshVisual(player: Player, pulse: boolean)
	local model = giants[player]
	local profile = DataService.get(player)
	if not model or not profile then
		return
	end
	local scale = GiantService.scaleForLevel(profile.level)
	model:ScaleTo(1)
	local stage = Config.stageForLevel(profile.level)
	applyStage(model, stage, profile)
	ensureCreatureMesh(player, model, profile.species, stage.minLevel == 1)
	if pulse then
		Util.tweenScale(model, scale, 0.6)
	else
		model:ScaleTo(scale)
	end
	local sp = GiantService.species(profile)
	local torso = model.PrimaryPart
	if torso then
		local info = torso:FindFirstChild("InfoGui") :: BillboardGui?
		local lbl = info and info:FindFirstChild("Info") :: TextLabel?
		if lbl then
			local tag = if profile.championUntil > os.time() then "  👑" else ""
			lbl.Text = string.format(
				"%s%s\n%s • %s\nLv. %d • %s",
				player.DisplayName,
				tag,
				sp.name,
				stage.name,
				profile.level,
				GiantService.mood(profile)
			)
			lbl.TextColor3 = sp.color
		end
		if info then
			info.StudsOffset = Vector3.new(0, 4 * scale, 0)
			info.Size = UDim2.fromOffset(260 + scale * 10, 100 + scale * 3)
		end
	end
	if lastStage[player] and lastStage[player] ~= stage.name and Config.stageForLevel(profile.level).minLevel > 1 then
		Remotes.GiantEvolved:FireAllClients({ userId = player.UserId, stageName = stage.name, level = profile.level })
		Remotes.Notify:FireAllClients(
			Locale.msg("evolved_broadcast", { p = player.DisplayName, s = stage.name }, stage.eyeColor)
		)
	end
	lastStage[player] = stage.name
end

function GiantService.mood(profile: DataService.Profile): string
	if profile.hunger < 30 then
		return "Faminto"
	elseif profile.hunger < 75 then
		return "Satisfeito"
	end
	return "Feliz"
end

function GiantService.moodMultiplier(profile: DataService.Profile): number
	local m = GiantService.mood(profile)
	if m == "Faminto" then
		return Config.Giant.MoodMultipliers.Hungry
	elseif m == "Feliz" then
		return Config.Giant.MoodMultipliers.Happy
	end
	return Config.Giant.MoodMultipliers.Fine
end

-- foodId/from (Fase 3, juice): qual comida foi dada e de onde ela sai, para o cliente animar a
-- comida voando até a boca do gigante. Opcionais (eventos sem comida continuam funcionando).
function GiantService.addXp(player: Player, amount: number, foodId: string?, from: Vector3?)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if profile.passes.VIP then
		amount = math.floor(amount * 1.5)
	end
	amount = math.floor(amount * GiantService.species(profile).xpMult)
	profile.xp += amount
	profile.hunger = math.min(100, profile.hunger + Config.Giant.HungerPerFeed)
	profile.lastFed = os.time()
	local leveled = false
	while profile.level < Config.Giant.MaxLevel and profile.xp >= Config.xpNeeded(profile.level) do
		profile.xp -= Config.xpNeeded(profile.level)
		profile.level += 1
		leveled = true
	end
	profile.peakLevel = math.max(profile.peakLevel, profile.level)
	DataService.markDirty(player)
	local model = giants[player]
	local fx = model and model.PrimaryPart and model.PrimaryPart:FindFirstChild("FeedFX") :: ParticleEmitter?
	if fx then
		fx:Emit(20)
	end
	refreshVisual(player, true)
	Remotes.GiantFed:FireAllClients({
		userId = player.UserId,
		xp = amount,
		leveled = leveled,
		foodId = foodId,
		from = from,
	})
	if leveled then
		Remotes.Notify:FireClient(player, Locale.msg("levelup", { n = profile.level }, Color3.fromRGB(255, 220, 80)))
	end
end

-- Decay por ausência (chamado ao entrar). Retorna níveis perdidos.
function GiantService.applyDecay(player: Player, profile: DataService.Profile): number
	local D = Config.Decay
	local away = os.time() - math.max(profile.lastFed, profile.lastSeen)
	if away >= 86400 then
		-- bônus de retorno (independe do decay)
		profile.coins += D.ReturnBonusCoins
		if GiantService.OnReturnBonus then
			GiantService.OnReturnBonus(player, away)
		end
		Remotes.Notify:FireClient(
			player,
			Locale.msg("welcome_back", { n = D.ReturnBonusCoins }, Color3.fromRGB(120, 255, 160))
		)
	end
	if GiantService.isDecayImmune(profile) or away <= D.GraceSeconds then
		return 0
	end
	local days = (away - D.GraceSeconds) / 86400
	local lost = math.min(D.MaxLevelsLost, math.floor(days * D.LevelsLostPerDay), profile.level - 1)
	if lost <= 0 then
		return 0
	end
	profile.level -= lost
	profile.xp = 0
	profile.levelsLostToDecay += lost
	profile.hunger = 10
	DataService.markDirty(player)
	Remotes.Notify:FireClient(
		player,
		Locale.msg("shrunk", { d = math.floor(days + 3), n = lost }, Color3.fromRGB(255, 90, 90))
	)
	return lost
end

function GiantService.setSpecies(player: Player, speciesId: string): boolean
	local profile = DataService.get(player)
	if not profile or not Config.SpeciesById[speciesId] or not profile.ownedSpecies[speciesId] then
		return false
	end
	profile.species = speciesId
	DataService.markDirty(player)
	GiantService.spawnFor(player)
	return true
end

function GiantService.onPassesChanged(player: Player)
	local profile = DataService.get(player)
	if profile then
		for _, sp in Config.Species do
			if sp.robux and sp.passKey and profile.passes[sp.passKey] then
				profile.ownedSpecies[sp.id] = true
			end
		end
	end
	refreshVisual(player, false)
end

function GiantService.spawnFor(player: Player)
	local base = MapService.getBaseOf(player)
	local profile = DataService.get(player)
	if not base or not profile then
		return
	end
	if giants[player] then
		giants[player]:Destroy()
	end
	anchors[player] = base.giantAnchor
	local model = buildGiantModel(player, base.giantAnchor, GiantService.species(profile))
	model:SetAttribute("OwnerUserId", player.UserId)
	giants[player] = model
	lastStage[player] = nil
	refreshVisual(player, false)
end

function GiantService.getModel(player: Player): Model?
	return giants[player]
end

function GiantService.refresh(player: Player, pulse: boolean?)
	refreshVisual(player, pulse == true)
end

function GiantService.init()
	Players.PlayerRemoving:Connect(function(player)
		if giants[player] then
			giants[player]:Destroy()
			giants[player] = nil
		end
		lastStage[player] = nil
		anchors[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			for player, _ in giants do
				local profile = DataService.get(player)
				if profile then
					local before = GiantService.mood(profile)
					local mult = GiantService.species(profile).hungerDecayMult
					profile.hunger = math.max(0, profile.hunger - Config.Giant.HungerDecayPerSec * 5 * mult)
					if GiantService.mood(profile) ~= before then
						refreshVisual(player, false)
					end
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2 + math.random() * 3)
			for _, model in giants do
				local eyeL = model:FindFirstChild("EyeL") :: Part?
				local eyeR = model:FindFirstChild("EyeR") :: Part?
				-- com modelo 3D os olhos de bloco ficam escondidos: piscar os mostraria de novo
				if eyeL and eyeR and not model:FindFirstChild("CreatureMesh") then
					eyeL.Transparency = 1
					eyeR.Transparency = 1
					task.delay(0.12, function()
						if model:FindFirstChild("CreatureMesh") then
							return -- o modelo 3D entrou durante a piscada: olhos ficam escondidos
						end
						eyeL.Transparency = 0
						eyeR.Transparency = 0
					end)
				end
			end
		end
	end)
end

return GiantService
