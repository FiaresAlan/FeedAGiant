--!strict
-- StealService — roubo de comida entre bases e escudos.
--
-- Fase 0.6 (ver docs/DIAGNOSTICO_E_PLANO.md, H4/H5/M5/M8):
--   * O bastão da v1 foi REMOVIDO: batia por Touched numa peça controlada pelo cliente,
--     sem checar distância nem zona segura (qualquer jogador do mapa podia ser derrubado).
--     O contra-jogo continua: um ladrão que leva SOCO (CombatService, validado no servidor)
--     derruba a comida, que volta para o dono.
--   * Clique na comida: distância conferida no servidor (ClickDetector não é validado).
--   * Fim do canal de 3 s: escudo do dono e o MESMO item (uid) são conferidos de novo.
--   * Depósito: tempo mínimo de viagem entre o pátio roubado e a própria base
--     (teleporte não deposita).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Parent.Guard)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)
local CombatService = require(script.Parent.CombatService)

local StealService = {}

local CLICK_REACH = 25 -- igual ao ClickDetector.MaxActivationDistance do PlotService
local CHANNEL_MAX_MOVE = 6
-- Velocidade máxima plausível (WalkSpeed 20 + pulos/empurrões). Mais rápido que isso = teleporte.
local MAX_TRAVEL_SPEED = 45
local DEPOSIT_MARGIN = 6 -- studs além da borda da base (latência)

type Carry = { food: DataService.FoodInstance, from: Player, model: Model?, pickedAt: number, pickedPos: Vector3 }
local carrying: { [Player]: Carry } = {}
local channeling: { [Player]: boolean } = {}

function StealService.isShielded(player: Player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.shieldUntil > os.time()
end

function StealService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function StealService.giveShield(player: Player, seconds: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.shieldUntil = math.max(profile.shieldUntil, os.time() + seconds)
	local base = MapService.getBaseOf(player)
	if base then
		local old = base.model:FindFirstChild("ShieldFX")
		if old then
			old:Destroy()
		end
		local fx = Util.makePart({
			Name = "ShieldFX",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(Config.BaseSize * 1.2, Config.BaseSize * 1.2, Config.BaseSize * 1.2),
			CFrame = base.origin * CFrame.new(0, 2, 0),
			Color = Color3.fromRGB(80, 200, 255),
			Material = Enum.Material.ForceField,
			Transparency = 0.4,
			CanCollide = false,
			CanQuery = false,
			Parent = base.model,
		})
		task.delay(profile.shieldUntil - os.time(), function()
			if fx.Parent and not StealService.isShielded(player) then
				fx:Destroy()
			end
		end)
	end
	PlotService.pushState(player)
end

local function attachCarryVisual(thief: Player, def: Config.FoodDef): Model?
	local char = thief.Character
	local head = char and char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "CarriedFood"
	local p = Util.makePart({
		Name = "Body",
		Anchored = false,
		CanCollide = false,
		Massless = true,
		Size = Vector3.new(2.5, 2.5, 2.5),
		Color = def.color,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	p.Shape = Enum.PartType.Ball
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = p
	p.CFrame = head.CFrame * CFrame.new(0, 2.5, 0)
	weld.Parent = p
	Util.makeBillboard(
		p,
		"ROUBANDO: " .. def.name,
		UDim2.fromOffset(200, 40),
		Vector3.new(0, 2, 0),
		Color3.fromRGB(255, 80, 80)
	)
	model.Parent = char
	return model
end

-- Ladrão perde a comida. returnTo = devolve ao dono (se ainda estiver no servidor).
local function dropCarry(thief: Player, returnTo: boolean)
	local c = carrying[thief]
	if not c then
		return
	end
	carrying[thief] = nil
	if c.model then
		c.model:Destroy()
	end
	if returnTo and c.from.Parent then
		local profile = DataService.get(c.from)
		if profile then
			-- A comida já existia: volta mesmo com a mochila cheia.
			table.insert(profile.inventory, c.food)
			DataService.markDirty(c.from)
			PlotService.pushState(c.from)
			Remotes.Notify:FireClient(
				c.from,
				{ text = "Você recuperou sua comida!", color = Color3.fromRGB(80, 255, 120) }
			)
		end
	end
end

local function tryStartSteal(thief: Player, foodModel: Model)
	if carrying[thief] or channeling[thief] then
		return
	end
	local primary = foodModel.PrimaryPart
	if not primary or not Guard.withinReach(thief, primary, CLICK_REACH) then
		return
	end
	local ownerId = foodModel:GetAttribute("OwnerUserId")
	local slot = foodModel:GetAttribute("SlotIndex")
	if type(ownerId) ~= "number" or type(slot) ~= "number" then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner or owner == thief then
		return
	end
	if StealService.isShielded(owner) then
		Remotes.Notify:FireClient(
			thief,
			{ text = "Esta base está protegida por um escudo!", color = Color3.fromRGB(80, 200, 255) }
		)
		return
	end
	local ownerProfile = DataService.get(owner)
	local target = ownerProfile and ownerProfile.plot[tostring(slot)]
	if not target then
		return
	end
	local targetUid = target.uid
	local def = Config.FoodById[target.id]
	if not def then
		return
	end

	channeling[thief] = true
	-- O canal roda protegido: `channeling` é limpo SEMPRE, mesmo se algo der erro.
	local beam: BasePart? = nil
	local okRun, ok = pcall(function(): boolean
		Remotes.StealAlert:FireClient(owner, { thiefName = thief.DisplayName, food = def.name })
		Remotes.Notify:FireClient(thief, Locale.msg("stealing", { f = def.name }, Color3.fromRGB(255, 200, 80)))

		beam = Util.makePart({
			Name = "StealBeam",
			Size = Vector3.new(1.5, 40, 1.5),
			CFrame = primary.CFrame * CFrame.new(0, 20, 0),
			Color = Color3.fromRGB(255, 50, 50),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide = false,
			Parent = foodModel,
		})

		local startRoot = Guard.rootOf(thief)
		local startPos = startRoot and startRoot.Position
		local t0 = os.clock()
		local alive = startPos ~= nil
		while alive and os.clock() - t0 < Config.Steal.ChannelTime do
			task.wait(0.1)
			local root = Guard.rootOf(thief)
			alive = root ~= nil
				and foodModel.Parent ~= nil
				and startPos ~= nil
				and (root.Position - startPos).Magnitude <= CHANNEL_MAX_MOVE
				and not CombatService.isKO(thief)
		end
		return alive
	end)
	if beam then
		beam:Destroy()
	end
	channeling[thief] = nil
	if not okRun then
		warn("[StealService] canal:", ok)
		ok = false
	end

	-- Reconfere TUDO no fim: o mundo pode ter mudado durante os 3 s.
	local current = DataService.get(owner)
	local still = current and current.plot[tostring(slot)]
	if ok and (not owner.Parent or StealService.isShielded(owner) or not still or still.uid ~= targetUid) then
		ok = false
	end
	if not ok then
		Remotes.Notify:FireClient(thief, { text = "Roubo cancelado.", color = Color3.fromRGB(255, 90, 90) })
		return
	end
	local food = PlotService.removeFromPlot(owner, slot)
	if not food then
		return
	end
	local visual = attachCarryVisual(thief, def)
	carrying[thief] = { food = food, from = owner, model = visual, pickedAt = os.clock(), pickedPos = primary.Position }
	Remotes.Notify:FireClient(
		thief,
		{ text = "Pegou! Corra para sua base e toque no seu pátio.", color = Color3.fromRGB(80, 255, 120) }
	)
	Remotes.Notify:FireClient(
		owner,
		Locale.msg("stolen_owner", { p = thief.DisplayName, f = def.name }, Color3.fromRGB(255, 60, 60))
	)
end

local function tryDeposit(thief: Player, base: MapService.BaseInfo)
	local c = carrying[thief]
	if not c then
		return
	end
	-- O toque (Touched) pode ser forjado pelo cliente: o servidor confere se o
	-- personagem está mesmo dentro do quadrado da própria base.
	local root = Guard.rootOf(thief)
	if not root then
		return
	end
	local here = base.origin:PointToObjectSpace(root.Position)
	local half = Config.BaseSize / 2 + DEPOSIT_MARGIN
	if math.abs(here.X) > half or math.abs(here.Z) > half then
		return
	end
	-- Anti-teleporte: tempo mínimo do ponto do roubo até a borda da base, a MAX_TRAVEL_SPEED.
	local toBase = (base.origin.Position - c.pickedPos).Magnitude - Config.BaseSize * 0.75
	local minTime = math.max(0, toBase) / MAX_TRAVEL_SPEED
	if os.clock() - c.pickedAt < minTime then
		return -- chegou rápido demais; tenta de novo no próximo toque
	end
	local profile = DataService.get(thief)
	if not profile then
		return
	end
	carrying[thief] = nil
	if c.model then
		c.model:Destroy()
	end
	table.insert(profile.inventory, c.food) -- item já existia: entra mesmo com mochila cheia
	profile.totalSteals += 1
	DataService.markDirty(thief)
	PlotService.pushState(thief)
	local def = Config.FoodById[c.food.id]
	Remotes.Notify:FireClient(
		thief,
		Locale.msg("steal_done", { f = (def and def.name or "comida") }, Color3.fromRGB(80, 255, 120))
	)
end

local function onCharacterAdded(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		hum.Died:Connect(function()
			dropCarry(player, true)
		end)
	end
	-- Depositar ao tocar no próprio pátio
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if root and root:IsA("BasePart") then
		root.Touched:Connect(function(hit)
			if not carrying[player] then
				return
			end
			local baseIndex = hit:GetAttribute("BaseIndex")
			if type(baseIndex) == "number" then
				local base = MapService.Bases[baseIndex]
				if base and base.owner == player then
					tryDeposit(player, base)
				end
			end
		end)
	end
end

function StealService.init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropCarry(player, true)
		channeling[player] = nil
	end)

	-- Ladrão que leva soco derruba a comida (substitui o bastão da v1).
	local previousOnHit = CombatService.OnHit
	CombatService.OnHit = function(attacker: Player, victim: Player, heavy: boolean)
		if previousOnHit then
			previousOnHit(attacker, victim, heavy)
		end
		if carrying[victim] then
			dropCarry(victim, true)
			Remotes.Notify:FireClient(
				victim,
				{ text = "Você levou um soco e derrubou a comida!", color = Color3.fromRGB(255, 90, 90) }
			)
		end
	end

	-- Cliques em comidas (ClickDetector criado pelo PlotService)
	Workspace.DescendantAdded:Connect(function(inst: Instance)
		if inst:IsA("ClickDetector") then
			local model: Model? = inst:FindFirstAncestorOfClass("Model") :: any
			if model and model:GetAttribute("FoodId") then
				inst.MouseClick:Connect(function(clicker)
					local ownerId = model:GetAttribute("OwnerUserId")
					if ownerId == clicker.UserId then
						local slot = model:GetAttribute("SlotIndex")
						local part = model.PrimaryPart
						if type(slot) == "number" and part and Guard.withinReach(clicker, part, CLICK_REACH) then
							PlotService.feed(clicker, slot)
						end
					else
						tryStartSteal(clicker, model)
					end
				end)
			end
		end
	end)
end

return StealService
