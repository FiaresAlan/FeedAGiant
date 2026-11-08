--!strict
-- ShieldService — pedestal "RENOVAR ESCUDO" dentro de cada base (pedido do usuário, item 8, 08/11/2026).
--
-- Cada base ganha um pedestal com placa grande "RENOVAR ESCUDO" e um ProximityPrompt (E no teclado,
-- X no controle, toque no celular). Ao usar:
--   * o servidor confere que a base é SUA (outro jogador vê "Esta base não é sua");
--   * o cliente abre a janela com o tempo restante e as opções com preço;
--   * nada é cobrado sem o segundo clique de confirmação (moedas) ou o diálogo da Roblox (Robux).
-- Opções: renovar com moedas (Config.Shield.CoinRenew) e o Super Escudo pago que já existia
-- (Config.DevProducts.SuperShield, entregue pelo MonetizationService). O escudo em si é o mesmo do
-- StealService (bloqueia roubo na base e mostra a bolha azul).
local Config = require(game.ReplicatedStorage.Shared.Config)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local Guard = require(script.Parent.Parent.Guard)

local ShieldService = {}
local S = Config.Shield

local pedestals: { [number]: BasePart } = {}

-- Preço em moedas: Config.Shield.CoinRenew.secondsOfIncome segundos da renda atual (mínimo fixo).
function ShieldService.coinPrice(player: Player): number
	local cps = PlotService.coinsPerSecond(player)
	return math.max(S.CoinRenew.minPrice, math.floor(cps * S.CoinRenew.secondsOfIncome))
end

local function sendMenu(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local product = (Config.DevProducts :: any).SuperShield
	Remotes.ShieldMenu:FireClient(player, {
		left = math.max(0, profile.shieldUntil - os.time()),
		coinSeconds = S.CoinRenew.seconds,
		coinPrice = ShieldService.coinPrice(player),
		superSeconds = Config.Steal.SuperShieldSec,
		superAvailable = product ~= nil and (product.id or 0) ~= 0,
	})
end

local function build(index: number, base: MapService.BaseInfo)
	local cf = base.origin * CFrame.new(S.PedestalOffset.X, 0, S.PedestalOffset.Z)
	local model = Instance.new("Model")
	model.Name = "ShieldPedestal"
	Util.makePart({
		Name = "Foot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 8, 8),
		CFrame = cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 140, 128),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	Util.makePart({
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 5, 5),
		CFrame = cf * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(196, 186, 170),
		Material = Enum.Material.Sandstone,
		Parent = model,
	})
	local button = Util.makePart({
		Name = "Button",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 4, 4),
		CFrame = cf * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 200, 255),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	-- Placa grande e legível de longe
	local board = Util.makePart({
		Name = "Sign",
		Size = Vector3.new(10, 3.4, 0.6),
		CFrame = cf * CFrame.new(0, 9.5, 0) * CFrame.Angles(0, math.rad(S.PedestalYaw), 0),
		Color = Color3.fromRGB(40, 43, 50),
		Parent = model,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = "🛡 RENOVAR ESCUDO"
		t.TextColor3 = Color3.fromRGB(110, 210, 255)
		t.TextStrokeTransparency = 0.2
		t.Parent = sg
	end
	for _, x in { -4.2, 4.2 } do
		Util.makePart({
			Name = "Post",
			Size = Vector3.new(0.5, 7.8, 0.5),
			CFrame = cf * CFrame.Angles(0, math.rad(S.PedestalYaw), 0) * CFrame.new(x, 3.9, 0),
			Color = Color3.fromRGB(90, 94, 108),
			Parent = model,
		})
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Shield"
	prompt.ActionText = "RENOVAR ESCUDO"
	prompt.ObjectText = "Sua base"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = button
	prompt.Triggered:Connect(function(player)
		if base.owner ~= player then
			Remotes.Notify:FireClient(
				player,
				{ text = "Esta base não é sua: só o dono renova o escudo.", color = Color3.fromRGB(255, 120, 90) }
			)
			return
		end
		sendMenu(player)
	end)
	model.Parent = base.model
	pedestals[index] = button
end

function ShieldService.init()
	for i, base in MapService.Bases do
		local ok, err = pcall(function()
			build(i, base)
		end)
		if not ok then
			warn("[ShieldService] pedestal da base", i, err)
		end
	end
	Remotes.RequestShieldRenew.OnServerEvent:Connect(function(player)
		if not Guard.allow(player, "Shield") then
			return
		end
		local base = MapService.getBaseOf(player)
		local profile = DataService.get(player)
		if not base or not profile or base.owner ~= player then
			return
		end
		local pedestal = pedestals[base.index]
		if not pedestal or not Guard.withinReach(player, pedestal, 14) then
			return -- só renova no pedestal da própria base
		end
		local price = ShieldService.coinPrice(player)
		if profile.coins < price then
			Remotes.Notify:FireClient(player, { text = "Moedas insuficientes!", color = Color3.fromRGB(255, 90, 90) })
			return
		end
		profile.coins -= price
		DataService.markDirty(player)
		StealService.giveShield(player, S.CoinRenew.seconds)
		Remotes.Notify:FireClient(
			player,
			{ text = "Escudo renovado! Sua base está protegida.", color = Color3.fromRGB(80, 200, 255) }
		)
		sendMenu(player)
	end)
end

return ShieldService
