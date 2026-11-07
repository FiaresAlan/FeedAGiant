--!strict
-- CombatService — BOXE. Socos leves/pesados, bloqueio, stamina, combo e KO.
-- Substitui o bastão da v1. Usado para disputar drops, defender o pátio e brigar na arena.
-- Regras anti-grief: ninguém pode ser socado dentro da zona segura do PRÓPRIO pátio.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Util = require(game.ReplicatedStorage.Shared.Util)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local GiantService = require(script.Parent.GiantService)
local Guard = require(script.Parent.Parent.Guard)

local CombatService = {}

export type Fighter = {
	stamina: number,
	hp: number,
	blocking: boolean,
	lastPunch: number,
	lastHeavy: number,
	combo: number,
	comboAt: number,
	koUntil: number,
	infiniteStaminaUntil: number,
	lastHitBy: Player?,
}

local fighters: { [Player]: Fighter } = {}
local C = Config.Combat

-- callbacks que outros serviços registram (DropService, ArenaService)
CombatService.OnHit = nil :: ((attacker: Player, victim: Player, heavy: boolean) -> ())?
CombatService.OnKO = nil :: ((attacker: Player, victim: Player) -> ())?

local function getFighter(player: Player): Fighter
	local f = fighters[player]
	if not f then
		f = {
			stamina = C.MaxStamina,
			hp = 999999,
			blocking = false,
			lastPunch = 0,
			lastHeavy = 0,
			combo = 0,
			comboAt = 0,
			koUntil = 0,
			infiniteStaminaUntil = 0,
			lastHitBy = nil,
		}
		fighters[player] = f
	end
	return f
end

function CombatService.get(player: Player): Fighter
	local f = getFighter(player)
	f.hp = math.min(f.hp, CombatService.maxHp(player))
	return f
end

function CombatService.maxStamina(player: Player): number
	local profile = DataService.get(player)
	local m = C.MaxStamina
	if profile and profile.passes.BoxerPro then
		m = math.floor(m * 1.3)
	end
	return m
end

function CombatService.maxHp(player: Player): number
	local profile = DataService.get(player)
	local hp = C.KOHealth
	if profile then
		hp += profile.level * C.HpPerLevel + profile.rebirths * C.HpPerRebirth
		hp *= GiantService.species(profile).arenaHp / 100
		if profile.passes.BoxerPro then
			hp *= 1.2
		end
	end
	return math.floor(hp)
end

function CombatService.strength(player: Player): number
	local profile = DataService.get(player)
	local s = 1
	if profile then
		s += profile.level * C.StrengthPerLevel + profile.rebirths * C.StrengthPerRebirth
		if GiantService.mood(profile) == "Feliz" then
			s *= C.StrengthMoodHappy
		end
		if profile.passes.BoxerPro then
			s *= 1.25
		end
	end
	return s
end

function CombatService.isKO(player: Player): boolean
	return getFighter(player).koUntil > os.clock()
end

local function push(player: Player)
	if player.Parent == nil then
		return -- saiu (ex.: push atrasado do KO): não recria o estado de quem já foi
	end
	local f = getFighter(player)
	f.hp = math.min(f.hp, CombatService.maxHp(player))
	Remotes.CombatState:FireClient(player, {
		stamina = f.stamina,
		maxStamina = CombatService.maxStamina(player),
		hp = f.hp,
		maxHp = CombatService.maxHp(player),
		strength = CombatService.strength(player),
		blocking = f.blocking,
		combo = f.combo,
		ko = f.koUntil > os.clock(),
		koUntil = f.koUntil,
	})
end

function CombatService.refillStamina(player: Player, infiniteSeconds: number?)
	local f = getFighter(player)
	f.stamina = CombatService.maxStamina(player)
	if infiniteSeconds then
		f.infiniteStaminaUntil = os.clock() + infiniteSeconds
	end
	push(player)
end

-- Zona segura: perto do próprio pátio ninguém pode te socar.
local function inOwnSafeZone(player: Player): boolean
	local base = MapService.getBaseOf(player)
	local char = player.Character
	if not base or not char then
		return false
	end
	return (char:GetPivot().Position - base.origin.Position).Magnitude < C.SafeZoneRadius
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function hitFx(pos: Vector3, heavy: boolean)
	local p = Util.makePart({
		Name = "HitFX",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(pos),
		Color = if heavy then Color3.fromRGB(255, 80, 40) else Color3.fromRGB(255, 220, 80),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = Workspace,
	})
	task.spawn(function()
		for i = 1, 6 do
			p.Size = p.Size + Vector3.new(1.2, 1.2, 1.2)
			p.Transparency = i / 6
			task.wait(0.03)
		end
		p:Destroy()
	end)
end

local function knockout(victim: Player, attacker: Player)
	local f = getFighter(victim)
	f.koUntil = os.clock() + C.KOSeconds
	f.hp = CombatService.maxHp(victim)
	f.combo = 0
	f.blocking = false
	local hum = humanoidOf(victim)
	if hum then
		hum.PlatformStand = true
		hum.Sit = true
	end
	local root = rootOf(victim)
	if root then
		root.AssemblyLinearVelocity = Vector3.new(0, 40, 0)
	end
	local ap = DataService.get(attacker)
	if ap then
		ap.knockouts += 1
		DataService.markDirty(attacker)
	end
	Remotes.Notify:FireClient(
		victim,
		Locale.msg("ko_victim", { p = attacker.DisplayName }, Color3.fromRGB(255, 80, 80))
	)
	Remotes.Notify:FireClient(
		attacker,
		Locale.msg("ko_attacker", { p = victim.DisplayName }, Color3.fromRGB(255, 200, 60))
	)
	Remotes.CombatEvent:FireAllClients({ kind = "KO", attacker = attacker.UserId, victim = victim.UserId })
	if CombatService.OnKO then
		CombatService.OnKO(attacker, victim)
	end
	push(victim)
	task.delay(C.KOSeconds, function()
		local h = humanoidOf(victim)
		if h then
			h.PlatformStand = false
			h.Sit = false
		end
		push(victim)
	end)
end

local function tryPunch(attacker: Player, heavy: boolean)
	local f = getFighter(attacker)
	local now = os.clock()
	if f.koUntil > now then
		return
	end
	local cd = if heavy then C.HeavyCooldown else C.PunchCooldown
	local last = if heavy then f.lastHeavy else f.lastPunch
	if now - last < cd then
		return
	end
	local cost = if heavy then C.StaminaHeavy else C.StaminaPunch
	local infinite = f.infiniteStaminaUntil > now
	if not infinite and f.stamina < cost then
		Remotes.Notify:FireClient(attacker, { text = "Sem stamina!", color = Color3.fromRGB(255, 120, 80) })
		return
	end
	if heavy then
		f.lastHeavy = now
	else
		f.lastPunch = now
	end
	if not infinite then
		f.stamina -= cost
	end
	f.blocking = false

	local root = rootOf(attacker)
	if not root then
		return
	end
	local range = if heavy then C.HeavyRange else C.PunchRange
	local origin = root.Position
	local look = root.CFrame.LookVector
	Remotes.CombatEvent:FireAllClients({ kind = "Swing", attacker = attacker.UserId, heavy = heavy })

	local profile = DataService.get(attacker)
	local dmgMult = CombatService.strength(attacker)

	-- Encontra a melhor vítima no cone à frente
	local best: Player? = nil
	local bestDot = 0.45
	for _, other in Players:GetPlayers() do
		if other == attacker then
			continue
		end
		local oroot = rootOf(other)
		if not oroot then
			continue
		end
		local delta = oroot.Position - origin
		local dist = delta.Magnitude
		if dist > range then
			continue
		end
		local dot = if dist < 1 then 1 else look:Dot(delta.Unit)
		if dot > bestDot then
			bestDot = dot
			best = other
		end
	end
	if not best then
		push(attacker)
		return
	end
	local victim: Player = best
	if inOwnSafeZone(victim) then
		Remotes.Notify:FireClient(
			attacker,
			Locale.msg("safe_zone", { p = victim.DisplayName }, Color3.fromRGB(120, 200, 255))
		)
		push(attacker)
		return
	end
	local vf = getFighter(victim)
	if vf.koUntil > now then
		push(attacker)
		return
	end

	-- Combo
	if now - f.comboAt <= C.ComboWindow then
		f.combo = math.min(5, f.combo + 1)
	else
		f.combo = 1
	end
	f.comboAt = now

	local dmg = (if heavy then C.HeavyDamage else C.PunchDamage) * dmgMult * (1 + (f.combo - 1) * C.ComboDamageBonus)
	local kb = if heavy then C.HeavyKnockback else C.Knockback
	local blocked = false
	if vf.blocking then
		if heavy and C.BlockBreakHeavy then
			vf.blocking = false
			Remotes.Notify:FireClient(victim, { text = "Guarda QUEBRADA!", color = Color3.fromRGB(255, 120, 80) })
		else
			dmg *= C.BlockDamageMult
			kb *= 0.3
			blocked = true
		end
	end
	vf.hp = math.max(0, vf.hp - dmg)
	vf.lastHitBy = attacker

	local vroot = rootOf(victim)
	if vroot then
		local dir = (vroot.Position - origin)
		dir = if dir.Magnitude < 0.1 then look else dir.Unit
		vroot.AssemblyLinearVelocity = dir * kb + Vector3.new(0, if heavy then 35 else 18, 0)
		hitFx(vroot.Position + Vector3.new(0, 1, 0), heavy)
	end
	if profile then
		profile.punchesLanded += 1
	end
	Remotes.CombatEvent:FireAllClients({
		kind = "Hit",
		attacker = attacker.UserId,
		victim = victim.UserId,
		heavy = heavy,
		blocked = blocked,
		combo = f.combo,
	})
	if CombatService.OnHit then
		CombatService.OnHit(attacker, victim, heavy)
	end
	if vf.hp <= 0 then
		knockout(victim, attacker)
	end
	push(attacker)
	push(victim)
end

local function setBlock(player: Player, on: boolean)
	local f = getFighter(player)
	if f.koUntil > os.clock() then
		return
	end
	f.blocking = on and f.stamina > 5
	push(player)
end

function CombatService.init()
	Remotes.RequestPunch.OnServerEvent:Connect(function(player, heavy)
		if type(heavy) ~= "boolean" or not Guard.allow(player, "Combat") then
			return
		end
		tryPunch(player, heavy)
	end)
	Remotes.RequestBlock.OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" or not Guard.allow(player, "Combat") then
			return
		end
		setBlock(player, on)
	end)

	Players.PlayerRemoving:Connect(function(player)
		fighters[player] = nil
		-- Evita recriar o lutador por um push atrasado (task.delay) depois da saída.
		task.defer(function()
			fighters[player] = nil
		end)
	end)
	local function onCharacter(player: Player)
		local f = getFighter(player)
		f.hp = CombatService.maxHp(player)
		f.koUntil = 0
		f.blocking = false
		task.wait(0.5)
		push(player)
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			task.spawn(onCharacter, player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do -- quem entrou antes do init
		watch(player)
	end

	-- Regen de stamina / HP e consumo do bloqueio
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, f in fighters do
				if not player.Parent then
					fighters[player] = nil -- limpeza defensiva (PlayerRemoving já remove)
					continue
				end
				local max = CombatService.maxStamina(player)
				local changed = false
				if f.blocking then
					if f.infiniteStaminaUntil <= now then
						f.stamina = math.max(0, f.stamina - C.StaminaBlockPerSec * 0.25)
					end
					if f.stamina <= 0 then
						f.blocking = false
					end
					changed = true
				elseif f.stamina < max then
					f.stamina = math.min(max, f.stamina + C.StaminaRegenPerSec * 0.25)
					changed = true
				end
				local maxHp = CombatService.maxHp(player)
				if f.hp < maxHp and now - f.comboAt > 3 and f.koUntil <= now then
					f.hp = math.min(maxHp, f.hp + math.max(4, maxHp * 0.03))
					changed = true
				end
				if changed then
					push(player)
				end
			end
		end
	end)
end

return CombatService
