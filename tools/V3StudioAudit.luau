--!nonstrict
-- FEEDAGIANT V3: auditoria de SOMENTE LEITURA.
-- Cole no Command Bar do Roblox Studio, preferencialmente no Play -> Server.
-- Nao habilita flags, nao altera Workspace, nao salva perfis e nao publica assets.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local warnings = 0
local function check(label: string, ok: boolean, details: string?)
	print(("[V3 AUDIT] %s | %s%s"):format(if ok then "OK" else "PENDENTE", label,
		if details then " | " .. details else ""))
	if not ok then warnings += 1 end
end

check("Rodando no Roblox Studio", RunService:IsStudio())
local shared = ReplicatedStorage:FindFirstChild("Shared")
check("ReplicatedStorage/Shared", shared ~= nil)
local featuresModule = shared and shared:FindFirstChild("Features")
local features = featuresModule and require(featuresModule)
check("Features.RebuildV2 definido", features ~= nil and type(features.flags.RebuildV2) == "boolean")
if features then
	print("[V3 AUDIT] Feature efetiva RebuildV2 =", features.on("RebuildV2"))
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
for _, name in { "V2MountInput", "V2MountRequest", "V2MountState", "V2LaneRequest",
	"V2LaneState", "V2CookRequest", "V2CookState" } do
	check("Remote " .. name, remotes ~= nil and remotes:FindFirstChild(name) ~= nil)
end

local services = ServerScriptService:FindFirstChild("Server")
services = services and services:FindFirstChild("Services")
for _, name in { "V2MountService", "V2AnimationService", "V2LaneService", "V2CookingService",
	"V3StoneGolemPrototype", "V3ProceduralAnimation" } do
	check("ModuleScript " .. name, services ~= nil and services:FindFirstChild(name) ~= nil)
end

local map = workspace:FindFirstChild("Map")
local bases = 0
if map then
	for _, child in map:GetChildren() do
		if child:IsA("Model") and string.match(child.Name, "^Base%d+$") then
			bases += 1
		end
	end
end
check("8 bases na ilha ativa", bases == 8, "observadas=" .. tostring(bases))
local track = workspace:FindFirstChild("V2BanquetRun")
if RunService:IsRunning() and features and features.on("RebuildV2") then
	check("Pista V3 criada no Play", track ~= nil)
end

local folder = ServerStorage:FindFirstChild("V2RigTemplates")
check("Pasta de rigs montaveis", folder ~= nil, "Golem de QA e criado ao montar no Studio")
if folder then
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local root = model:FindFirstChild("HumanoidRootPart")
			local hum = model:FindFirstChildOfClass("Humanoid")
			local anchor = model:FindFirstChild("ShoulderSeatAnchor", true)
			local cargo = model:FindFirstChild("CargoCarryAnchor", true)
			local joints = 0
			for _, inst in model:GetDescendants() do
				if inst:IsA("Motor6D") or inst:IsA("Bone") then joints += 1 end
			end
			check("Rig " .. model.Name, root ~= nil and hum ~= nil and anchor ~= nil and cargo ~= nil
				and joints >= 10, "juntas=" .. tostring(joints))
			print("[V3 AUDIT] Rig", model.Name, "procedural=",
				model:GetAttribute("V3ProceduralRig"), "studioOnly=", model:GetAttribute("V3StudioOnly"))
			local animations = model:FindFirstChild("Animations")
			if animations then
				for _, name in { "Idle", "Walk", "Run", "CarryWalk", "Pickup", "Eat" } do
					local clip = animations:FindFirstChild(name)
					check(model.Name .. " clip " .. name, clip and clip:IsA("Animation") and clip.AnimationId ~= "")
				end
			end
		end
	end
end

for _, player in Players:GetPlayers() do
	local model = workspace:FindFirstChild("V2Mounted_" .. tostring(player.UserId))
	if model then
		local anchor = model:FindFirstChild("ShoulderSeatAnchor", true)
		local rider = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		check("Rider em " .. player.DisplayName, anchor ~= nil and rider ~= nil)
	end
end

print("[V3 AUDIT] Inspecao concluida. Pendencias:", warnings)
print("[V3 AUDIT] NENHUMA verificacao acima prova persistencia, licencas, camera, mobile ou 2 clientes.")
