--!strict
-- FeedAGiant V2: montaria do personagem sobre um rig Humanoid do proprietario.
-- Usa um rig importado no Studio; nao transforma os gigantes de vitrine em NPCs inflaveis.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Features)
local Remotes = require(Shared.Remotes)
local RunRules = require(Shared.RebuildV2.RunRules)
local Guard = require(script.Parent.Parent.Guard)
local DataService = require(script.Parent.DataService)
local Hooks = require(script.Parent.Parent.Hooks)
local MapService = require(script.Parent.MapService)
local AnimationService = require(script.Parent.V2AnimationService)
local StudioGolem = require(script.Parent.V3StoneGolemPrototype)

local Mount = {}
type Session = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	character: Model,
	charHumanoid: Humanoid,
	charRoot: BasePart,
	weld: WeldConstraint,
	animations: any,
	oldWalkSpeed: number,
	oldJumpPower: number,
	oldJumpHeight: number,
	oldAutoRotate: boolean,
	oldPlatformStand: boolean,
	oldUseJumpPower: boolean,
	collisions: { [BasePart]: boolean },
	species: string,
	move: Vector3,
	sprint: boolean,
	stamina: number,
	lastInputAt: number,
	boostEndsAt: number,
	boostReadyAt: number,
	nextPushAt: number,
}

local sessions: { [Player]: Session } = {}
Mount.OnUnmount = nil :: ((Player) -> ())?
Mount.CargoWeightOf = nil :: ((Player) -> string)?
Mount.OnBoost = nil :: ((Player, string) -> ())?

local TEMPLATE_NAMES = {
	stone_starter = "StoneGolem",
	golem = "StoneGolem",
	fire_starter = "FireGiant",
	ice_starter = "IceGiant",
}

local function notify(player: Player, msg: string)
	Remotes.Notify:FireClient(player, { text = msg, color = Color3.fromRGB(255, 196, 96) })
end

local function push(player: Player, session: Session?)
	if player.Parent == nil then return end
	if session then
		Remotes.V2MountState:FireClient(player, {
			mounted = true,
			model = session.model,
			stamina = session.stamina,
			boostReadyAt = session.boostReadyAt,
			species = session.species,
		})
	else
		Remotes.V2MountState:FireClient(player, { mounted = false })
	end
end

function Mount.session(player: Player): Session?
	return sessions[player]
end

function Mount.isMounted(player: Player): boolean
	return sessions[player] ~= nil
end

-- Efeitos de animacao sao apenas visuais. A economia e as acoes permanecem no servidor.
function Mount.playAction(player: Player, action: string)
	local s = sessions[player]
	if s and s.animations then
		s.animations:playAction(action)
	end
end

function Mount.isIceShieldActive(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and s.species == "ice_starter" and os.clock() < s.boostEndsAt
end

function Mount.rootOf(player: Player): BasePart?
	local session = sessions[player]
	return if session then session.root else nil
end

local function groundNear(position: Vector3, exclude: { Instance }): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -100, 0), params)
	return CFrame.new((if result then result.Position else position) + Vector3.new(0, 4, 0))
end

function Mount.unmount(player: Player)
	local session = sessions[player]
	if not session then return end
	sessions[player] = nil -- idempotente mesmo que reset e disconnect acontecam juntos
	if Mount.OnUnmount then
		local ok, err = pcall(Mount.OnUnmount, player)
		if not ok then warn("[V2Mount] OnUnmount:", err) end
	end
	if session.animations then session.animations:destroy() end
	if session.weld.Parent then session.weld:Destroy() end
	local hum = session.charHumanoid
	if hum.Parent and hum.Health > 0 then
		hum.PlatformStand = session.oldPlatformStand
		hum.AutoRotate = session.oldAutoRotate
		hum.UseJumpPower = session.oldUseJumpPower
		hum.WalkSpeed = session.oldWalkSpeed
		hum.JumpPower = session.oldJumpPower
		hum.JumpHeight = session.oldJumpHeight
	end
	for part, canCollide in session.collisions do
		if part.Parent then part.CanCollide = canCollide end
	end
	if session.character.Parent and session.charHumanoid.Health > 0 then
		session.character:PivotTo(groundNear(session.root.Position + session.root.CFrame.RightVector * 10, { session.model, session.character }))
	end
	if session.model.Parent then session.model:Destroy() end
	push(player, nil)
end

local function sourceRig(species: string): Model?
	local folder = ServerStorage:FindFirstChild("V2RigTemplates")
	local file = TEMPLATE_NAMES[species]
	local source = if folder and file then folder:FindFirstChild(file) else nil
	-- Somente em Studio e com a flag QA ligada: rig proprio para prototipar
	-- movimento/articulacao enquanto o asset final ainda nao foi importado.
	if not source and file == "StoneGolem" and RunService:IsStudio() and Features.on("RebuildV2") then
		if not folder then
			local created = Instance.new("Folder")
			created.Name = "V2RigTemplates"
			created.Parent = ServerStorage
			folder = created
		end
		source = StudioGolem.create()
		source.Parent = folder
		warn("[V3GolemPrototype] Rig de QA criado: nao publicar como versao final.")
	end
	return if source and source:IsA("Model") then source else nil
end

function Mount.mount(player: Player)
	if sessions[player] then return end
	local profile = DataService.get(player)
	local base = MapService.getBaseOf(player)
	local root = Guard.rootOf(player)
	if not profile or not base or not root or (root.Position - base.giantAnchor.Position).Magnitude > 50 then
		notify(player, "Aproxime-se do seu gigante na base para montar.")
		return
	end
	local species = profile.species
	local original = sourceRig(species)
	if not original then
		notify(player, "Este gigante ainda nao possui um rig montavel aprovado.")
		warn("[V2Mount] Ausente template em ServerStorage/V2RigTemplates para", species)
		return
	end
	local char = player.Character
	local human = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local characterRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not char or not human or not characterRoot or not characterRoot:IsA("BasePart") or human.Health <= 0 then
		return
	end
	local creature = original:Clone()
	local creatureRoot = creature:FindFirstChild("HumanoidRootPart")
	local creatureHum = creature:FindFirstChildOfClass("Humanoid")
	local anchor = creature:FindFirstChild("ShoulderSeatAnchor", true)
	if not creatureRoot or not creatureRoot:IsA("BasePart") or not creatureHum or not anchor or not anchor:IsA("Attachment")
		or not anchor.Parent or not anchor.Parent:IsA("BasePart") then
		creature:Destroy()
		notify(player, "O rig nao tem RootPart, Humanoid ou ShoulderSeatAnchor validos.")
		return
	end
	local animator = creatureHum:FindFirstChildOfClass("Animator")
	if not animator then
		Instance.new("Animator", creatureHum)
	end
	creature.Name = "V2Mounted_" .. tostring(player.UserId)
	creature:SetAttribute("OwnerUserId", player.UserId)
	creature.PrimaryPart = creatureRoot
	for _, inst in creature:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = false
			inst.CanTouch = false
			inst.CanCollide = inst == creatureRoot
		end
	end
	creature.Parent = workspace
	local spawnY = if creature:GetAttribute("V3ProceduralRig") == true then 11 else 6
	creature:PivotTo(base.origin * CFrame.new(12, spawnY, -18))
	pcall(function() creatureRoot:SetNetworkOwner(nil) end) -- fisica autoritativa para evitar teleport exploits
	local collisions: { [BasePart]: boolean } = {}
	for _, inst in char:GetDescendants() do
		if inst:IsA("BasePart") then
			collisions[inst] = inst.CanCollide
			inst.CanCollide = false
		end
	end
	local oldWalk, oldJump, oldHeight = human.WalkSpeed, human.JumpPower, human.JumpHeight
	local oldRotate, oldStand, oldUses = human.AutoRotate, human.PlatformStand, human.UseJumpPower
	human.WalkSpeed = 0
	human.JumpPower = 0
	human.JumpHeight = 0
	human.AutoRotate = false
	human.PlatformStand = true
	char:PivotTo(anchor.WorldCFrame)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "V2RiderWeld"
	weld.Part0 = characterRoot
	weld.Part1 = anchor.Parent
	weld.Parent = characterRoot
	local session: Session = {
		model = creature,
		humanoid = creatureHum,
		root = creatureRoot,
		character = char,
		charHumanoid = human,
		charRoot = characterRoot,
		weld = weld,
		animations = AnimationService.bind(creature, creatureHum),
		oldWalkSpeed = oldWalk,
		oldJumpPower = oldJump,
		oldJumpHeight = oldHeight,
		oldAutoRotate = oldRotate,
		oldPlatformStand = oldStand,
		oldUseJumpPower = oldUses,
		collisions = collisions,
		species = species,
		move = Vector3.zero,
		sprint = false,
		stamina = RunRules.STAMINA_MAX,
		lastInputAt = os.clock(),
		boostEndsAt = 0,
		boostReadyAt = 0,
		nextPushAt = 0,
	}
	sessions[player] = session
	Hooks.fire("v2_mounted", player)
	push(player, session)
end

local function boost(player: Player)
	local s = sessions[player]
	if not s then return end
	local now = os.clock()
	if now < s.boostReadyAt then return end
	local rules = RunRules.BOOSTS[s.species]
	if not rules then return end
	if s.species == "fire_starter" and s.stamina < 20 then return end
	s.animations:playAction("Ability")
	s.boostEndsAt = now + rules.seconds
	s.boostReadyAt = now + rules.cooldown
	if s.species == "fire_starter" then s.stamina = math.max(0, s.stamina - 20) end
	if Mount.OnBoost then
		Mount.OnBoost(player, s.species)
	end
	push(player, s)
end

function Mount.init()
	-- O GiantService/PlotService preserva a verdade economica: reproduzir
	-- mastigacao apenas depois do evento de alimentacao concluida.
	Hooks.on("fed", function(player: Player)
		Mount.playAction(player, "Eat")
	end)
	Remotes.V2MountRequest.OnServerEvent:Connect(function(player: Player, action: any)
		if not Features.on("RebuildV2") or type(action) ~= "string" or not Guard.allow(player, "V2Mount") then return end
		if action == "mount" then Mount.mount(player)
		elseif action == "unmount" then Mount.unmount(player)
		elseif action == "boost" then boost(player)
		elseif action == "snapshot" then push(player, sessions[player])
		end
	end)
	Remotes.V2MountInput.OnServerEvent:Connect(function(player: Player, direction: any, sprint: any)
		if not Features.on("RebuildV2") or not Guard.allow(player, "V2MountInput") then return end
		local s = sessions[player]
		if not s or typeof(direction) ~= "Vector3" or type(sprint) ~= "boolean" then return end
		if direction.X ~= direction.X or direction.Z ~= direction.Z or math.abs(direction.X) > 1.1
			or math.abs(direction.Z) > 1.1 or math.abs(direction.Y) > 0.1 then return end
		s.move = Vector3.new(direction.X, 0, direction.Z)
		if s.move.Magnitude > 1 then s.move = s.move.Unit end
		s.sprint = sprint
		s.lastInputAt = os.clock()
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if not Features.on("RebuildV2") then return end
		local now = os.clock()
		for player, s in sessions do
			local profile = DataService.get(player)
			if not profile or player.Character ~= s.character or not s.model.Parent or s.charHumanoid.Health <= 0
				or s.humanoid.Health <= 0 or profile.species ~= s.species then
				Mount.unmount(player)
				continue
			end
			local moving = now - s.lastInputAt < 0.5 and s.move.Magnitude > 0.05
			local sprint = moving and s.sprint and s.stamina > 0
			s.stamina = RunRules.stamina(s.stamina, dt, sprint)
			local weight = if Mount.CargoWeightOf then Mount.CargoWeightOf(player) else "light"
			s.humanoid.WalkSpeed = RunRules.speed(profile.level, weight, sprint, s.species, now < s.boostEndsAt)
			s.humanoid:Move(if moving then s.move else Vector3.zero, false)
			-- Preferir ciclos animados; nao escalar o mesh para simular movimento.
			local gait = if not moving then "Idle" elseif weight ~= "light" then "CarryWalk" elseif sprint then "Run" else "Walk"
			s.animations:setLocomotion(gait, s.root.AssemblyLinearVelocity.Magnitude)
			if now >= s.nextPushAt then
				s.nextPushAt = now + 0.5
				push(player, s)
			end
		end
	end)
	local function track(player: Player)
		player.CharacterAdded:Connect(function()
			Mount.unmount(player)
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do track(player) end
	Players.PlayerRemoving:Connect(function(player)
		Mount.unmount(player)
	end)
end

return Mount
