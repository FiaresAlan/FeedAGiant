--!strict
-- Golem de Pedra original, feito com Parts e Motor6D para QA no Studio.
-- Nao substitui o rig final, clipes artistico/profissionais ou testes visuais.
-- Sem MeshIds externos e sem dependencias de licencas de terceiros.
local Factory = {}

local STONE = Color3.fromRGB(105, 112, 124)
local STONE_LIGHT = Color3.fromRGB(149, 155, 165)
local STONE_DARK = Color3.fromRGB(64, 72, 84)
local CRYSTAL = Color3.fromRGB(85, 223, 189)
local OUTLINE = Color3.fromRGB(43, 50, 61)

local function part(model: Model, name: string, size: Vector3, origin: CFrame, offset: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = origin * CFrame.new(offset)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanTouch = false
	p.CanQuery = true
	p.CanCollide = false
	p.Massless = true
	p.Parent = model
	return p
end

local function weldDetail(model: Model, to: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = part(model, name, size, to.CFrame, offset, color, material)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function motor(model: Model, name: string, p0: BasePart, p1: BasePart, origin: CFrame, pivot: Vector3): Motor6D
	local world = origin * CFrame.new(pivot)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:ToObjectSpace(world)
	m.C1 = p1.CFrame:ToObjectSpace(world)
	m.Parent = p0
	return m
end

function Factory.create(species: string?): Model
	-- Mesmo esqueleto articulado e mesma hitbox na pista para os tres elementos.
	-- Prototipos de QA, nao artes aprovadas para publicacao.
	local element = if species == "fire_starter" then "fire"
		elseif species == "ice_starter" then "ice" else "stone"
	local STONE = if element == "fire" then Color3.fromRGB(137, 79, 69)
		elseif element == "ice" then Color3.fromRGB(110, 160, 184) else STONE
	local STONE_LIGHT = if element == "fire" then Color3.fromRGB(205, 121, 83)
		elseif element == "ice" then Color3.fromRGB(181, 222, 231) else STONE_LIGHT
	local STONE_DARK = if element == "fire" then Color3.fromRGB(75, 53, 63)
		elseif element == "ice" then Color3.fromRGB(62, 103, 139) else STONE_DARK
	local CRYSTAL = if element == "fire" then Color3.fromRGB(255, 130, 44)
		elseif element == "ice" then Color3.fromRGB(91, 240, 255) else CRYSTAL
	local m = Instance.new("Model")
	m.Name = if element == "fire" then "FireGiant" elseif element == "ice" then "IceGiant" else "StoneGolem"
	m:SetAttribute("V3Element", element)
	m:SetAttribute("V3ProceduralRig", true)
	m:SetAttribute("V3StudioOnly", true)
	local origin = CFrame.new(0, 9.5, 0)

	local root = part(m, "HumanoidRootPart", Vector3.new(4.8, 18, 4.5), origin, Vector3.zero, STONE_DARK)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	m.PrimaryPart = root

	local torso = part(m, "Torso", Vector3.new(7.3, 5.6, 4.8), origin, Vector3.new(0, 1.4, 0), STONE)
	weldDetail(m, torso, "BeltPlate", Vector3.new(5.8, 1.2, 5), Vector3.new(0, -2.5, 0), STONE_DARK)
	weldDetail(m, torso, "ChestPlate", Vector3.new(6.1, 2.0, 0.55), Vector3.new(0, 1.0, -2.6), STONE_LIGHT)
	weldDetail(m, torso, "CoreSocket", Vector3.new(2.4, 2.3, 0.9), Vector3.new(0, 0.6, -2.95), OUTLINE)
	local crystal = weldDetail(m, torso, "CoreCrystal", Vector3.new(1.55, 1.55, 0.35), Vector3.new(0, 0.6, -3.55), CRYSTAL, Enum.Material.Neon)
	crystal.Shape = Enum.PartType.Block
	for _, x in { -2.6, 2.6 } do
		weldDetail(m, torso, "ChestRivet", Vector3.new(0.45, 0.45, 0.28), Vector3.new(x, 1.9, -2.98), STONE_DARK)
	end

	local head = part(m, "Head", Vector3.new(4.65, 3.15, 3.8), origin, Vector3.new(0, 5.6, -0.25), STONE_LIGHT)
	weldDetail(m, head, "Brow", Vector3.new(5.0, 0.65, 4.0), Vector3.new(0, 0.88, -0.05), STONE_DARK)
	for _, x in { -1.05, 1.05 } do
		weldDetail(m, head, "EyeSocket", Vector3.new(0.85, 0.72, 0.22), Vector3.new(x, -0.08, -1.95), OUTLINE)
		weldDetail(m, head, "EyeGlow", Vector3.new(0.48, 0.42, 0.17), Vector3.new(x, -0.08, -2.11), CRYSTAL, Enum.Material.Neon)
	end
	local jaw = part(m, "Jaw", Vector3.new(3.15, 0.72, 1.5), origin, Vector3.new(0, 3.95, -1.55), STONE_DARK)
	weldDetail(m, jaw, "JawInset", Vector3.new(2.6, 0.23, 0.23), Vector3.new(0, 0.23, -0.8), OUTLINE)

	if element == "fire" then
		for _, x in { -1.55, 1.55 } do
			local horn = weldDetail(m, head, "FlameHorn", Vector3.new(1.0, 2.25, 1.15),
				Vector3.new(x, 2.3, 0.2), CRYSTAL, Enum.Material.Neon)
			horn.Shape = Enum.PartType.Block
		end
		weldDetail(m, torso, "EmberBackplate", Vector3.new(3.0, 3.3, 0.9),
			Vector3.new(0, 0.5, 2.9), STONE_DARK)
	elseif element == "ice" then
		for _, x in { -2.4, 2.4 } do
			weldDetail(m, torso, "IceShoulderSpire", Vector3.new(1.45, 3.2, 1.5),
				Vector3.new(x, 4.45, 1.2), CRYSTAL, Enum.Material.Glass)
		end
		weldDetail(m, head, "FrostCrest", Vector3.new(2.25, 1.65, 1.4),
			Vector3.new(0, 2.1, 0.5), CRYSTAL, Enum.Material.Glass)
	end
	motor(m, "RootJoint", root, torso, origin, Vector3.new(0, 0.3, 0))
	motor(m, "Neck", torso, head, origin, Vector3.new(0, 4.05, -0.2))
	motor(m, "JawHinge", head, jaw, origin, Vector3.new(0, 4.2, -1.2))

	for _, side in { -1, 1 } do
		local label = if side < 0 then "Left" else "Right"
		local x = side * 5.05
		local arm = part(m, label .. " Arm", Vector3.new(2.6, 4.15, 3.05), origin, Vector3.new(x, 1.05, 0), STONE)
		weldDetail(m, arm, label .. " ShoulderPlate", Vector3.new(3.05, 1.1, 3.55), Vector3.new(0, 1.8, 0), STONE_DARK)
		local forearm = part(m, label .. " Forearm", Vector3.new(2.65, 3.65, 2.95), origin, Vector3.new(x, -2.65, 0), STONE_LIGHT)
		weldDetail(m, forearm, label .. " Fist", Vector3.new(3.3, 1.55, 3.0), Vector3.new(0, -1.45, -0.25), STONE_DARK)
		motor(m, label .. "Shoulder", torso, arm, origin, Vector3.new(side * 3.75, 3.05, 0))
		motor(m, label .. "Elbow", arm, forearm, origin, Vector3.new(x, -0.9, 0))
		if side > 0 then
			local carry = Instance.new("Attachment")
			carry.Name = "CargoCarryAnchor"
			carry.Position = Vector3.new(0, -1.45, -2.1)
			carry.Parent = forearm
		end

		local thigh = part(m, label .. " Leg", Vector3.new(2.8, 4.35, 3.35), origin, Vector3.new(side * 2.05, -3.3, 0), STONE)
		local shin = part(m, label .. " Shin", Vector3.new(2.8, 3.8, 3.35), origin, Vector3.new(side * 2.05, -6.4, -0.15), STONE_LIGHT)
		weldDetail(m, shin, label .. " Foot", Vector3.new(3.45, 1.35, 4.8), Vector3.new(0, -2.05, -0.58), STONE_DARK)
		weldDetail(m, shin, label .. " Kneecap", Vector3.new(2.9, 0.9, 0.6), Vector3.new(0, 1.15, -1.65), STONE_DARK)
		motor(m, label .. "Hip", torso, thigh, origin, Vector3.new(side * 2.05, -1.35, 0))
		motor(m, label .. "Knee", thigh, shin, origin, Vector3.new(side * 2.05, -5.0, 0))
	end

	local shoulder = Instance.new("Attachment")
	shoulder.Name = "ShoulderSeatAnchor"
	-- Avatar visivel entre os ombros; camera usa Humanoid do gigante.
	shoulder.Position = Vector3.new(0, 2.55, 1.45)
	shoulder.Parent = torso

	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.RigType = Enum.HumanoidRigType.R6
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HipHeight = 0
	hum.WalkSpeed = 20
	hum.JumpPower = 0
	hum.Parent = m
	Instance.new("Animator", hum)

	-- O controlador procedural anima somente este modelo nativo de teste.
	-- Rigs de producao devem usar clips reais com marcadores de passos.
	return m
end

return Factory
