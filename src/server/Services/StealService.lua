--!strict
-- StealService — roubo de comida entre bases, escudos, derrubar ladrão com o Bat.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)

local StealService = {}

type Carry = { food: DataService.FoodInstance, from: Player, model: Model }
local carrying: { [Player]: Carry } = {}
local channeling: { [Player]: boolean } = {}

local function playerFromUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

function StealService.isShielded(player: Player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.shieldUntil > os.time()
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
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
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
	Util.makeBillboard(p, "ROUBANDO: " .. def.name, UDim2.fromOffset(200, 40), Vector3.new(0, 2, 0), Color3.fromRGB(255, 80, 80))
	model.Parent = char
	return model
end

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
			table.insert(profile.inventory, c.food)
			DataService.markDirty(c.from)
			PlotService.pushState(c.from)
			Remotes.Notify:FireClient(c.from, { text = "Você recuperou sua comida!", color = Color3.fromRGB(80, 255, 120) })
		end
	end
end

local function tryStartSteal(thief: Player, foodModel: Model)
	if carrying[thief] or channeling[thief] then
		return
	end
	local ownerId = foodModel:GetAttribute("OwnerUserId")
	local slot = foodModel:GetAttribute("SlotIndex")
	if type(ownerId) ~= "number" or type(slot) ~= "number" then
		return
	end
	local owner = playerFromUserId(ownerId)
	if not owner or owner == thief then
		return
	end
	if StealService.isShielded(owner) then
		Remotes.Notify:FireClient(thief, { text = "Esta base está protegida por um escudo!", color = Color3.fromRGB(80, 200, 255) })
		return
	end
	local foodId = foodModel:GetAttribute("FoodId")
	local def = Config.FoodById[foodId]
	if not def then
		return
	end

	channeling[thief] = true
	Remotes.StealAlert:FireClient(owner, { thiefName = thief.DisplayName, food = def.name })
	Remotes.Notify:FireClient(thief, Locale.msg("stealing", { f = def.name }, Color3.fromRGB(255, 200, 80)))

	local primary = foodModel.PrimaryPart
	local beam
	if primary then
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
	end

	local startPos = thief.Character and thief.Character:GetPivot().Position
	local t0 = os.clock()
	local ok = true
	while os.clock() - t0 < Config.Steal.ChannelTime do
		task.wait(0.1)
		local char = thief.Character
		if not char or not char.Parent or not foodModel.Parent or not startPos then
			ok = false
			break
		end
		if (char:GetPivot().Position - startPos).Magnitude > 6 then
			ok = false
			break
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			ok = false
			break
		end
	end
	if beam then
		beam:Destroy()
	end
	channeling[thief] = nil
	if not ok then
		Remotes.Notify:FireClient(thief, { text = "Roubo cancelado.", color = Color3.fromRGB(255, 90, 90) })
		return
	end
	local food = PlotService.removeFromPlot(owner, slot)
	if not food then
		return
	end
	local visual = attachCarryVisual(thief, def)
	carrying[thief] = { food = food, from = owner, model = visual :: Model }
	Remotes.Notify:FireClient(thief, { text = "Pegou! Corra para sua base e toque no seu pátio.", color = Color3.fromRGB(80, 255, 120) })
	Remotes.Notify:FireClient(owner, Locale.msg("stolen_owner", { p = thief.DisplayName, f = def.name }, Color3.fromRGB(255, 60, 60)))
end

local function tryDeposit(thief: Player)
	local c = carrying[thief]
	if not c then
		return
	end
	local profile = DataService.get(thief)
	if not profile then
		return
	end
	carrying[thief] = nil
	if c.model then
		c.model:Destroy()
	end
	table.insert(profile.inventory, c.food)
	profile.totalSteals += 1
	DataService.markDirty(thief)
	PlotService.pushState(thief)
	local def = Config.FoodById[c.food.id]
	Remotes.Notify:FireClient(thief, Locale.msg("steal_done", { f = (def and def.name or "comida") }, Color3.fromRGB(80, 255, 120)))
end

local function giveBat(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Bastão") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Bastão"
	tool.RequiresHandle = true
	tool.ToolTip = "Bata em ladrões para derrubar a comida"
	local handle = Util.makePart({
		Name = "Handle",
		Anchored = false,
		CanCollide = false,
		Size = Vector3.new(0.6, 4, 0.6),
		Color = Color3.fromRGB(150, 90, 40),
		Material = Enum.Material.Wood,
		Parent = tool,
	})
	local lastHit = 0
	handle.Touched:Connect(function(hit)
		if os.clock() - lastHit < 0.8 then
			return
		end
		local target = Players:GetPlayerFromCharacter(hit.Parent)
		if not target or target == player then
			return
		end
		if not tool.Parent or tool.Parent ~= player.Character then
			return
		end
		lastHit = os.clock()
		if carrying[target] then
			dropCarry(target, true)
			Remotes.Notify:FireClient(target, { text = "Você foi atingido e derrubou a comida!", color = Color3.fromRGB(255, 90, 90) })
		end
		local root = hit.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local dir = (root.Position - handle.Position).Unit
			root.AssemblyLinearVelocity = dir * Config.Steal.KnockbackForce + Vector3.new(0, 30, 0)
		end
	end)
	tool.Parent = backpack
end

function StealService.init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.5)
			giveBat(player)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					dropCarry(player, true)
				end)
			end
			-- Depositar ao tocar no próprio pátio
			local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
			if root then
				root.Touched:Connect(function(hit)
					if not carrying[player] then
						return
					end
					local baseIndex = hit:GetAttribute("BaseIndex")
					if type(baseIndex) == "number" then
						local base = MapService.Bases[baseIndex]
						if base and base.owner == player then
							tryDeposit(player)
						end
					end
				end)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dropCarry(player, true)
		channeling[player] = nil
	end)

	-- Cliques em comidas (ClickDetector criado pelo PlotService)
	Workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("ClickDetector") then
			local model = inst:FindFirstAncestorOfClass("Model")
			if model and model:GetAttribute("FoodId") then
				inst.MouseClick:Connect(function(clicker)
					local ownerId = model:GetAttribute("OwnerUserId")
					if ownerId == clicker.UserId then
						local slot = model:GetAttribute("SlotIndex")
						if type(slot) == "number" then
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
