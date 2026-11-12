--!strict
-- V2: cargas efemeras autoritativas. Somente ENTREGA concede item/descoberta persistente.
-- Ovos, inventario salvo e itens comprados nao fazem parte desta mecanica.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Features = require(Shared.Features)
local CargoRules = require(Shared.RebuildV2.CargoRules)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Guard = require(script.Parent.Parent.Guard)
local Analytics = require(script.Parent.Parent.Analytics)
local Hooks = require(script.Parent.Parent.Hooks)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local MapService = require(script.Parent.MapService)
local MountService = require(script.Parent.V2MountService)
local WorldService = require(script.Parent.V2WorldService)
local CookingService = require(script.Parent.V2CookingService)

local Lane = {}
local cargoByUid: { [string]: any } = {}
local carried: { [Player]: any } = {}
local pairCooldowns: { [string]: number } = {}
local stationStates: { any } = {}

local function newRaceData()
	return { version = 1, deliveries = 0, interceptions = 0 }
end

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function addWeld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function cargoVisual(cargo: any): Model
	local model = Instance.new("Model")
	model.Name = "V2Cargo_" .. cargo.uid
	local def = Config.FoodById[cargo.itemId]
	local primary = newPart(model, "CargoRoot", Vector3.new(3.4, 3.4, 3.4), if def then def.color else Color3.fromRGB(250, 196, 97))
	primary.Shape = if def and def.shape == "Block" then Enum.PartType.Block else Enum.PartType.Ball
	primary.Anchored = true
	primary.Material = if cargo.kind == "recipe_scroll" then Enum.Material.Wood else Enum.Material.SmoothPlastic
	model.PrimaryPart = primary
	if cargo.kind == "recipe_scroll" then
		primary.Size = Vector3.new(4.8, 0.8, 2)
		primary.Color = Color3.fromRGB(245, 218, 158)
		for _, x in { -2.25, 2.25 } do
			local roll = newPart(model, "ScrollHandle", Vector3.new(1, 1.3, 2.6), Color3.fromRGB(160, 93, 52))
			roll.Shape = Enum.PartType.Cylinder
			roll.CFrame = primary.CFrame * CFrame.new(x, 0, 0)
			addWeld(primary, roll)
		end
	else
		local band = newPart(model, "RarityBand", Vector3.new(3.6, 0.32, 3.6),
			if cargo.weight == "heavy" then Color3.fromRGB(255, 196, 79) else Color3.fromRGB(110, 205, 184))
		band.Transparency = 0.25
		band.CFrame = primary.CFrame * CFrame.new(0, -1.1, 0)
		addWeld(primary, band)
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "CargoLabel"
	bb.Size = UDim2.fromOffset(200, 55)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	bb.MaxDistance = 100
	bb.Parent = primary
	local txt = Instance.new("TextLabel")
	txt.Name = "Title"
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 0.18
	txt.BackgroundColor3 = Color3.fromRGB(40, 52, 63)
	txt.TextColor3 = Color3.fromRGB(255, 246, 216)
	txt.Font = Enum.Font.GothamBold
	txt.TextScaled = true
	txt.TextWrapped = true
	txt.Text = if cargo.kind == "recipe_scroll" then "RECEITA RARA" else (if def then def.name else "Ingrediente")
	txt.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = txt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "V2PickCargo"
	prompt.ActionText = "Pegar"
	prompt.ObjectText = txt.Text
	prompt.MaxActivationDistance = 17
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = primary
	prompt.Triggered:Connect(function(player: Player)
		Lane.pickup(player, cargo.uid)
	end)
	return model
end

local function visualAt(cargo: any, position: Vector3)
	if not cargo.model or not cargo.model.Parent then return end
	local part = cargo.model.PrimaryPart
	if not part then return end
	local weld = part:FindFirstChild("V2CarryWeld")
	if weld then weld:Destroy() end
	part.Anchored = true
	cargo.model:PivotTo(CFrame.new(position))
	cargo.position = position
	local prompt = part:FindFirstChild("V2PickCargo")
	if prompt and prompt:IsA("ProximityPrompt") then prompt.Enabled = true end
	local bb = part:FindFirstChild("CargoLabel")
	if bb and bb:IsA("BillboardGui") then bb.Enabled = true end
end

local function attachVisual(cargo: any, player: Player)
	local session = MountService.session(player)
	if not session or not cargo.model then return false end
	local anchor = session.model:FindFirstChild("CargoCarryAnchor", true)
	local targetPart: BasePart
	local targetCF: CFrame
	if anchor and anchor:IsA("Attachment") and anchor.Parent and anchor.Parent:IsA("BasePart") then
		targetPart = anchor.Parent
		targetCF = anchor.WorldCFrame
	else
		-- Posicao de teste, exige CargoCarryAnchor real para a aprovacao artistica.
		targetPart = session.root
		targetCF = session.root.CFrame * CFrame.new(0, 3, -5)
	end
	local main = cargo.model.PrimaryPart
	if not main then return false end
	cargo.model:PivotTo(targetCF)
	main.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Name = "V2CarryWeld"
	weld.Part0 = targetPart
	weld.Part1 = main
	weld.Parent = main
	local prompt = main:FindFirstChild("V2PickCargo")
	if prompt and prompt:IsA("ProximityPrompt") then prompt.Enabled = false end
	local bb = main:FindFirstChild("CargoLabel")
	if bb and bb:IsA("BillboardGui") then bb.Enabled = false end
	return true
end

local function publicCargo(cargo: any)
	return {
		uid = cargo.uid,
		state = cargo.state,
		itemId = cargo.itemId,
		kind = cargo.kind,
		weight = cargo.weight,
		ownerUserId = if cargo.holder then cargo.holder.UserId else nil,
		position = if cargo.model and cargo.model.PrimaryPart then cargo.model.PrimaryPart.Position else cargo.position,
	}
end

local function broadcast()
	if not Features.on("RebuildV2") then return end
	local all = {}
	for _, cargo in cargoByUid do
		if cargo.state == "world" or cargo.state == "carried" or cargo.state == "dropped" then
			table.insert(all, publicCargo(cargo))
		end
	end
	Remotes.V2LaneState:FireAllClients({ kind = "snapshot", cargo = all })
end

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, { text = message, color = Color3.fromRGB(254, 193, 103) })
end

local function inSafeArea(pos: Vector3): boolean
	for _, base in MapService.Bases do
		local rel = base.origin:PointToObjectSpace(pos)
		if math.abs(rel.X) <= Config.BaseSize / 2 + 7
			and math.abs(rel.Z) <= Config.BaseSize / 2 + 7 then
			return true
		end
	end
	return false
end

local function nearOwnDelivery(player: Player, pos: Vector3): boolean
	local base = MapService.getBaseOf(player)
	if not base then return false end
	local zone = WorldService.DeliveryZones[base.index]
	if not zone or not zone.Parent then return false end
	local horizontal = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(zone.Position.X, 0, zone.Position.Z)).Magnitude
	return horizontal <= math.max(zone.Size.X, zone.Size.Z) / 2 + 9 and math.abs(pos.Y - zone.Position.Y) <= 30
end

function Lane.weightOf(player: Player): string
	local cargo = carried[player]
	return if cargo then cargo.weight else "light"
end

local function raceData(player: Player): any
	local profile = DataService.get(player)
	if not profile then return nil end
	local data = (profile :: any).v2Race
	if type(data) ~= "table" then
		data = newRaceData()
		local profileData = profile :: any
		profileData.v2Race = data
		DataService.markDirty(player)
	end
	return data
end

function Lane.pickup(player: Player, uid: any)
	if not Features.on("RebuildV2") or not Guard.allow(player, "V2Lane") or type(uid) ~= "string" or #uid > 80 then return end
	if carried[player] or not MountService.isMounted(player) then return end
	local pos = MountService.rootOf(player)
	local cargo = cargoByUid[uid]
	if not pos or not cargo or (cargo.state ~= "world" and cargo.state ~= "dropped") then return end
	local at = if cargo.model and cargo.model.PrimaryPart then cargo.model.PrimaryPart.Position else cargo.position
	if (pos.Position - at).Magnitude > 19 or os.clock() < cargo.pickableAt then return end
	-- Reserva autoritativa antes de tocar no modelo fisico.
	local previousState = CargoRules.reserve(cargo, player)
	if not previousState then return end
	local ok, attached = pcall(attachVisual, cargo, player)
	if not ok or not attached then
		-- O attach pode falhar apos desancorar a part ou criar um weld.
		-- Restaurar o visual e a reserva para impedir um pickup invisivel.
		local visualOk, visualErr = pcall(visualAt, cargo, cargo.position)
		if not visualOk then warn("[V2Lane] Falha ao restaurar carga:", visualErr) end
		CargoRules.rollbackReservation(cargo, player, previousState)
		if not ok then warn("[V2Lane] Falha ao anexar carga:", attached) end
		Hooks.fire("v2_error_recovered", player, "cargo", "attach")
		return
	end
	if not CargoRules.commitPickup(cargo, player) then
		-- Protecao defensiva caso outra rotina tenha cancelado a reserva.
		visualAt(cargo, cargo.position)
		CargoRules.rollbackReservation(cargo, player, previousState)
		return
	end
	cargo.carriedAt = os.clock()
	carried[player] = cargo
	MountService.playAction(player, "Pickup")
	Hooks.fire("v2_picked", player, cargo.kind, cargo.weight)
	Analytics.event(player, "v2_cargo_picked", 1, { cargo.kind, cargo.weight })
	broadcast()
end

function Lane.dropFor(player: Player, reason: string?)
	local cargo = carried[player]
	if not cargo then return end
	if not CargoRules.drop(cargo, player) then
		carried[player] = nil
		return
	end
	carried[player] = nil
	MountService.playAction(player, "Drop")
	Hooks.fire("v2_dropped", player, cargo.weight, reason or "unmount")
	cargo.pickableAt = os.clock() + 1
	cargo.expiresAt = os.clock() + 28
	local pos = MountService.rootOf(player)
	local point = if pos then pos.Position + pos.CFrame.LookVector * 4 else (if cargo.model and cargo.model.PrimaryPart then cargo.model.PrimaryPart.Position else cargo.position)
	visualAt(cargo, Vector3.new(point.X, math.max(11, point.Y), point.Z))
	broadcast()
end

local function deposit(player: Player)
	local cargo = carried[player]
	local root = MountService.rootOf(player)
	if not root or not CargoRules.canDeposit(cargo, player)
		or not nearOwnDelivery(player, root.Position) then return end
	local profile = DataService.get(player)
	local race = raceData(player)
	if not profile or not race then return end
	-- O estado 'depositing' bloqueia repeticoes ANTES do credito. Se um
	-- adaptador fizer yield no futuro, outra requisicao nao duplica o premio.
	if not CargoRules.beginDeposit(cargo, player) then return end
	local ok, success = pcall(function(): boolean
		if cargo.kind == "recipe_scroll" then
			return CookingService.unlockRecipe(player, cargo.recipeId)
		end
		-- false nao remove a carga: a mochila cheia pode ser liberada e tentada de novo.
		return PlotService.giveFood(player, cargo.itemId)
	end)
	if not ok then
		-- O adaptador pode ter creditado o item ANTES do erro.
		-- Nao liberar retry automaticamente, pois isso pode duplicar a recompensa.
		warn("[V2Lane] Entrega em quarentena:", cargo.uid, tostring(success))
		Hooks.fire("v2_error_recovered", player, "cargo", "credit_uncertain")
		notify(player, "Falha ao concluir esta entrega. A carga foi bloqueada para evitar duplicacao.")
		return
	end
	if success ~= true then
		CargoRules.rollbackDeposit(cargo, player)
		notify(player, "Nao foi possivel entregar. Confira sua mochila.")
		return
	end
	if not CargoRules.commitDeposit(cargo, player) then
		warn("[V2Lane] Credito efetuado, mas transicao inconsistente:", cargo.uid)
		return -- nunca repetir um premio ja creditado
	end
	MountService.playAction(player, "Celebrate")
	carried[player] = nil
	race.deliveries = math.max(0, tonumber(race.deliveries) or 0) + 1
	DataService.markDirty(player)
	if cargo.model then cargo.model:Destroy() end
	local station = stationStates[cargo.stationIndex]
	if station then station.uid = nil; station.nextAt = os.clock() + station.respawn end
	cargoByUid[cargo.uid] = nil
	notify(player, "Entrega concluida! Volte para alimentar seu gigante.")
	Hooks.fire("v2_delivered", player, cargo.kind, cargo.weight, math.max(0, os.clock() - (cargo.carriedAt or os.clock())))
	Analytics.event(player, "v2_cargo_delivered", 1, { cargo.kind, cargo.weight })
	-- O broadcast global omite contadores privados; atualizar o HUD do dono tambem.
	Remotes.V2LaneState:FireClient(player, { kind = "stats", deliveries = race.deliveries })
	broadcast()
end

local function intercept(attacker: Player, targetUserId: any)
	if type(targetUserId) ~= "number" or targetUserId ~= targetUserId
		or math.abs(targetUserId) > 1e15 or math.floor(targetUserId) ~= targetUserId
		or attacker.UserId == targetUserId or not MountService.isMounted(attacker) then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not MountService.isMounted(target) then return end
	local cargo = carried[target]
	local aRoot, tRoot = MountService.rootOf(attacker), MountService.rootOf(target)
	if not cargo or cargo.state ~= "carried" or not aRoot or not tRoot then return end
	if (aRoot.Position - tRoot.Position).Magnitude > 16 or inSafeArea(aRoot.Position) or inSafeArea(tRoot.Position) then return end
	local data = raceData(target)
	if not data or (tonumber(data.deliveries) or 0) < 2 then
		notify(attacker, "As primeiras duas entregas deste jogador sao protegidas.")
		return
	end
	if MountService.isIceShieldActive(target) then
		notify(attacker, "Escudo de Gelo! Tente depois.")
		return
	end
	local key = tostring(attacker.UserId) .. ":" .. tostring(target.UserId)
	local now = os.clock()
	if now < (pairCooldowns[key] or 0) then return end
	pairCooldowns[key] = now + 12
	Lane.dropFor(target, "intercept")
	Hooks.fire("v2_intercepted", attacker, target, cargo.weight)
	local race = raceData(attacker)
	if race then race.interceptions = math.max(0, tonumber(race.interceptions) or 0) + 1; DataService.markDirty(attacker) end
	Analytics.event(attacker, "v2_intercept_success", 1, { cargo.weight })
	notify(target, "Sua carga caiu! Voce pode recupera-la.")
end

local function spawnCargo(index: number)
	local station = stationStates[index]
	local pos = WorldService.SpawnPoints[index]
	if not station or not pos or station.uid then return end
	local uid = DataService.newUid()
	local cargo = {
		uid = uid, stationIndex = index, itemId = pos.itemId, kind = pos.kind,
		recipeId = pos.recipeId, weight = pos.weight,
		state = "world", holder = nil, position = pos.position, pickableAt = 0,
	}
	local model = cargoVisual(cargo)
	cargo.model = model
	model.Parent = workspace:FindFirstChild("V2BanquetRun") or workspace
	model:PivotTo(CFrame.new(pos.position))
	station.uid = uid
	cargoByUid[uid] = cargo
end

function Lane.pushSnapshot(player: Player)
	if not Features.on("RebuildV2") then return end
	local all = {}
	for _, cargo in cargoByUid do
		if cargo.state == "world" or cargo.state == "carried" or cargo.state == "dropped" then table.insert(all, publicCargo(cargo)) end
	end
	local r = raceData(player)
	local base = MapService.getBaseOf(player)
	local zone = if base then WorldService.DeliveryZones[base.index] else nil
	Remotes.V2LaneState:FireClient(player, {
		kind = "snapshot", cargo = all,
		myCargoUid = if carried[player] then carried[player].uid else nil,
		deliveries = if r then r.deliveries else 0,
		homePosition = if zone and zone.Parent then zone.Position else nil,
	})
end

function Lane.init()
	DataService.registerSlice("v2Race", newRaceData)
	MountService.OnUnmount = Lane.dropFor
	MountService.CargoWeightOf = Lane.weightOf
	if Features.on("RebuildV2") then
		for i, spec in WorldService.SpawnPoints do
			stationStates[i] = { uid = nil, nextAt = 0, respawn = spec.respawn }
			spawnCargo(i)
		end
		for _, zone in WorldService.DeliveryZones do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "V2DepositCargo"
			prompt.ActionText = "Entregar carga"
			prompt.ObjectText = "Sua base"
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 21
			prompt.Parent = zone
			prompt.Triggered:Connect(function(player: Player)
				if Guard.allow(player, "V2Lane") then deposit(player) end
			end)
		end
	end
	Remotes.V2LaneRequest.OnServerEvent:Connect(function(player: Player, action: any, arg: any)
		if not Features.on("RebuildV2") or type(action) ~= "string" then return end
		if action == "snapshot" then
			if Guard.allow(player, "V2Lane") then Lane.pushSnapshot(player) end
			return
		end
		if action == "pickup" then Lane.pickup(player, arg); return end
		if not Guard.allow(player, "V2Lane") then return end
		if action == "deposit" then deposit(player)
		elseif action == "intercept" then intercept(player, arg)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			if not Features.on("RebuildV2") then continue end
			local changed = false
			for i, station in stationStates do
				if station.uid then
					local cargo = cargoByUid[station.uid]
					if cargo and cargo.state == "dropped" and os.clock() >= (cargo.expiresAt or math.huge) then
						cargo.state = "expired"
						if cargo.model then cargo.model:Destroy() end
						cargoByUid[station.uid] = nil
						station.uid = nil
						station.nextAt = os.clock() + station.respawn
						changed = true
					end
				elseif os.clock() >= station.nextAt then
					spawnCargo(i)
					changed = true
				end
			end
			if changed then broadcast() end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Lane.dropFor(player)
	end)
end

return Lane
