--!strict
-- GiantAnim v2 — os gigantes parecem VIVOS (missão de 08/11/2026, prioridade P1).
--
-- Por que procedural: os modelos chegam ao Roblox como 1 MeshPart sem ossos (medido no Studio em
-- 08/11/2026: goblin, troll, dragão e hidra = 0 Bones). Sem esqueleto não existe AnimationTrack;
-- então o cliente move a malha (pose) e estica/achata (squash & stretch) só localmente:
-- nada é replicado, custo de rede zero, e o servidor continua dono da posição e da escala.
--
-- Estados (todos ligados a eventos REAIS do jogo, nunca aleatórios):
--   idle      respiração (squash), olhar em volta, balanço, flutuar (voadores) — sempre;
--   feliz     respiração mais ampla (atributo Mood = "Feliz");
--   faminto   corpo caído + BIRRA a cada 8-12 s (pisa, sacode a cabeça, solta vapor) — Mood "Faminto";
--   feed      ANTECIPAÇÃO enquanto a comida voa (inclina para trás e estica) → MORDIDA exatamente
--             quando a comida chega (GameRules.Feed.FlightSeconds, o mesmo tempo do FeedFx) →
--             2 mastigadas → volta com overshoot;
--   crit      antecipação maior, mordida dupla, pulo e "sacudida de alegria";
--   cheer     subir de nível / vencer batalha (estilo por espécie: pulo, giro, voo, pisão, rebolado);
--   evolve    novo estágio: agacha, salta girando, aterrissa amassando e RUGE.
-- Personalidade por espécie em shared/GiantPersonality (dragão ≠ golem ≠ hidra ≠ humano).
-- Desempenho (celular): 30 Hz, só gigantes perto da câmera; squash só em modelos de até 4 peças.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local GiantPersonality = require(game.ReplicatedStorage.Shared.GiantPersonality)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local GiantAnim = {}

local MAX_DIST = 320
local STEP = 1 / 30
local MAX_SQUASH_PARTS = 4
local FEED_DUR = 0.75
local CRIT_DUR = 1.45
local CHEER_DUR = 1.25
local EVOLVE_DUR = 2.4
local TANTRUM_DUR = 0.95

type PartRest = { part: BasePart, rel: CFrame, size: Vector3 }
type Action = { kind: string, t0: number, dur: number, impact: number }
type Track = {
	giant: Model,
	target: PVInstance,
	parts: { PartRest },
	squashable: boolean,
	restPivot: CFrame,
	base: CFrame, -- pés (centro de baixo da caixa), mesma rotação da pose
	height: number,
	applied: CFrame?, -- CFrame que ESTE script pôs na 1ª peça
	appliedSize: Vector3?,
	posed: boolean,
	phase: number,
	action: Action?,
	after: { string }, -- fila: "cheer" | "evolve" depois da mordida
	nextTantrum: number,
	nextTwitch: number,
	twitchAt: number,
	twitchSign: number,
	steam: ParticleEmitter?,
	dust: ParticleEmitter?,
	-- follow-through: mola atrasada (~0,08 s) sobre a inclinação/balanço da pose
	springX: number,
	springZ: number,
	velX: number,
	velZ: number,
	lastNow: number,
	landedAt: number, -- última poeira (para emitir 1 vez por aterrissagem)
	watchNext: number,
	watchTarget: number,
	watchYaw: number,
}

local tracks: { [Model]: Track } = {}
-- Gigantes no Workspace (mantido por ChildAdded/ChildRemoved: nada de varrer o Workspace a 30 Hz).
local candidates: { [Model]: boolean } = {}
local function watchChild(m: Instance)
	if m:IsA("Model") and string.match(m.Name, "^Giant_") then
		candidates[m] = true
	end
end

local function targetOf(giant: Model): PVInstance
	local mesh = giant:FindFirstChild("CreatureMesh")
	if mesh and mesh:IsA("Model") then
		return mesh
	end
	return giant
end

local function partsOf(target: PVInstance): { BasePart }
	local out = {}
	if target:IsA("BasePart") then
		table.insert(out, target)
	end
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function capture(t: Track)
	local target = t.target
	t.restPivot = target:GetPivot()
	local bbCf, size
	if target:IsA("Model") then
		bbCf, size = target:GetBoundingBox()
	else
		bbCf, size = (target :: BasePart).CFrame, (target :: BasePart).Size
	end
	t.height = math.max(size.Y, 2)
	local rot = t.restPivot - t.restPivot.Position
	t.base = CFrame.new(bbCf.Position - Vector3.new(0, size.Y / 2, 0)) * rot
	local list = partsOf(target)
	t.parts = {}
	for _, part in list do
		table.insert(t.parts, { part = part, rel = t.base:ToObjectSpace(part.CFrame), size = part.Size })
	end
	t.squashable = #list > 0 and #list <= MAX_SQUASH_PARTS
	t.applied = nil
	t.appliedSize = nil
end

local function newTrack(giant: Model): Track
	local t: Track = {
		giant = giant,
		target = targetOf(giant),
		parts = {},
		squashable = false,
		restPivot = CFrame.identity,
		base = CFrame.identity,
		height = 4,
		applied = nil,
		appliedSize = nil,
		posed = false,
		phase = math.random() * math.pi * 2,
		action = nil,
		after = {},
		nextTantrum = os.clock() + 4 + math.random() * 6,
		nextTwitch = os.clock() + 2,
		twitchAt = -10,
		twitchSign = 1,
		steam = nil,
		dust = nil,
		springX = 0,
		springZ = 0,
		velX = 0,
		velZ = 0,
		lastNow = os.clock(),
		landedAt = 0,
		watchNext = 0,
		watchTarget = 0,
		watchYaw = 0,
	}
	capture(t)
	return t
end

local function getTrack(giant: Model): Track
	local t = tracks[giant]
	local target = targetOf(giant)
	if t and t.target == target and target.Parent then
		return t
	end
	if t and t.steam then
		t.steam:Destroy()
	end
	local fresh = newTrack(giant)
	tracks[giant] = fresh
	return fresh
end

local function giantOf(userId: number): Model?
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == userId and m.Name:match("^Giant_") then
			return m
		end
	end
	return nil
end

local function ease(x: number): number -- smoothstep
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeIn(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x
end

-- Vapor de raiva (birra do faminto): 1 emissor por gigante, só Emit (sem Rate contínuo).
local function steamOf(t: Track): ParticleEmitter?
	if t.steam and t.steam.Parent then
		return t.steam
	end
	local first = t.parts[1]
	if not first then
		return nil
	end
	local att = Instance.new("Attachment")
	att.Name = "AngerSteam"
	att.Position = Vector3.new(0, first.size.Y * 0.45, 0)
	att.Parent = first.part
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 150))
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Size = NumberSequence.new(math.clamp(t.height * 0.08, 0.6, 8), math.clamp(t.height * 0.18, 1.2, 16))
	pe.Lifetime = NumberRange.new(0.6, 1)
	pe.Speed = NumberRange.new(4, 9)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.LightInfluence = 0.3
	pe.Parent = att
	t.steam = pe
	return pe
end

-- Poeira no chão (aterrissagem de comemoração/evolução e pisão da birra): peso de contato.
local function dust(t: Track, now: number, amount: number)
	if now - t.landedAt < 0.3 then
		return
	end
	t.landedAt = now
	if not (t.dust and t.dust.Parent) then
		local first = t.parts[1]
		if not first then
			return
		end
		local att = Instance.new("Attachment")
		att.Name = "LandDust"
		att.Position = Vector3.new(0, -first.size.Y * 0.48, 0)
		att.Parent = first.part
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 0
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(214, 190, 150))
		pe.Transparency = NumberSequence.new(0.35, 1)
		pe.Size = NumberSequence.new(math.clamp(t.height * 0.1, 0.8, 10), math.clamp(t.height * 0.25, 2, 24))
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Speed = NumberRange.new(6, 14)
		pe.SpreadAngle = Vector2.new(180, 8)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.LightInfluence = 0.6
		pe.Parent = att
		t.dust = pe
	end
	(t.dust :: ParticleEmitter):Emit(amount)
end

-- Pose de uma ação. Devolve (pose no espaço dos pés, squash horizontal, squash vertical).
local function actionPose(t: Track, act: Action, now: number, P: GiantPersonality.Personality): (CFrame, number, number)
	local h = t.height
	local a = now - act.t0
	local kind = act.kind
	if kind == "feed" or kind == "crit" then
		local crit = kind == "crit"
		local antic = if crit then 14 else 8 + 6 * P.weight
		if a < act.impact then
			-- Antecipação: a comida está voando; o gigante se prepara (olha para cima e estica).
			local k = ease(a / act.impact)
			local s = (if crit then 0.1 else 0.05) * k
			return CFrame.Angles(math.rad(antic * k), 0, 0), 1 - s * 0.5, 1 + s
		end
		local b = (a - act.impact) * P.chompSpeed
		local pitch = P.chompPitch * (if crit then 1.35 else 1)
		local sq = P.squash * (if crit then 1.5 else 1)
		if b < 0.08 then
			-- acelera até o contato (o maior salto é o último quadro antes de morder)
			local k = easeIn(b / 0.08)
			local ang = antic + (-pitch - antic) * k
			return CFrame.Angles(math.rad(ang), 0, 0), 1 + sq * 0.5 * k, 1 - sq * k
		end
		local chewEnd = if crit then 0.9 else 0.5
		if b < chewEnd then
			local u = (b - 0.08) / (chewEnd - 0.08)
			local chews = if crit then 4 else 2
			local c = math.cos(u * chews * math.pi * 2)
			local decay = 1 - u * 0.6
			local ang = -pitch * (0.55 + 0.45 * c) * decay
			local y, yaw = 0, 0
			if crit then
				-- pulinho de alegria e sacudida no meio da mastigação
				y = math.sin(math.clamp(u * 2, 0, 1) * math.pi) * 0.14 * h
				yaw = math.sin(u * math.pi * 6) * 10 * (1 - u)
			end
			local s = sq * 0.45 * c * decay
			return CFrame.new(0, y, 0) * CFrame.Angles(math.rad(ang), math.rad(yaw), 0), 1 + s * 0.5, 1 - s
		end
		-- volta ao repouso com overshoot pequeno (preset pesado: 3-6%)
		local u = math.clamp((b - chewEnd) / 0.2, 0, 1)
		local over = math.sin(u * math.pi) * 0.04
		local ang = -pitch * 0.55 * 0.4 * (1 - ease(u))
		return CFrame.Angles(math.rad(ang), 0, 0), 1 - over * 0.5, 1 + over
	elseif kind == "cheer" then
		local u = a / act.dur
		local style = P.cheer
		if style == "flap" then
			local y = math.sin(math.clamp(u, 0, 1) * math.pi) * 0.32 * h
			local roll = math.sin(u * math.pi * 8) * 10 * (1 - u * 0.5)
			return CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(roll)), 1, 1 + 0.04 * math.sin(u * math.pi)
		elseif style == "stomp" then
			local beat = (u * 2) % 1
			local side = if u < 0.5 then 1 else -1
			local y = math.sin(beat * math.pi) * 0.07 * h
			local s = if beat > 0.8 then (beat - 0.8) / 0.2 * P.squash else 0
			return CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(6 * side * math.sin(beat * math.pi))),
				1 + s * 0.5,
				1 - s
		elseif style == "wobble" then
			local roll = math.sin(u * math.pi * 6) * 14 * (1 - u)
			local y = math.sin(math.clamp(u * 1.5, 0, 1) * math.pi) * 0.12 * h
			return CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(roll)), 1, 1
		end
		-- hop / spin: agacha (antecipação) → salto → aterrissa amassando → assenta
		if u < 0.15 then
			local k = ease(u / 0.15)
			return CFrame.identity, 1 + 0.06 * k, 1 - 0.12 * k
		elseif u < 0.7 then
			local k = (u - 0.15) / 0.55
			local y = math.sin(k * math.pi) * 0.3 * h
			local yaw = if style == "spin" then ease(k) * 360 else 0
			return CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(yaw), 0), 0.96, 1.08
		elseif u < 0.82 then
			dust(t, now, 10)
			local k = (u - 0.7) / 0.12
			return CFrame.identity, 1 + 0.07 * math.sin(k * math.pi), 1 - 0.14 * math.sin(k * math.pi)
		end
		return CFrame.identity, 1, 1
	elseif kind == "evolve" then
		local u = a / act.dur
		if u < 0.17 then -- agacha fundo
			local k = ease(u / 0.17)
			return CFrame.identity, 1 + 0.1 * k, 1 - 0.2 * k
		elseif u < 0.45 then -- salto girando
			local k = (u - 0.17) / 0.28
			local y = math.sin(k * math.pi) * 0.45 * h
			return CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(ease(k) * 360), 0), 0.93, 1.12
		elseif u < 0.53 then -- aterrissa amassando
			dust(t, now, 24)
			local k = (u - 0.45) / 0.08
			return CFrame.identity, 1 + 0.11 * math.sin(k * math.pi), 1 - 0.22 * math.sin(k * math.pi)
		elseif u < 0.88 then -- RUGIDO: peito para trás e tremida
			local k = (u - 0.53) / 0.35
			local env = math.sin(k * math.pi)
			local shake = math.sin(k * math.pi * 24) * 4 * env
			return CFrame.Angles(math.rad(14 * env), math.rad(shake), 0), 1 - 0.03 * env, 1 + 0.06 * env
		end
		return CFrame.identity, 1, 1
	elseif kind == "tantrum" then
		local u = a / act.dur
		local y = if u < 0.3 then math.sin(u / 0.3 * math.pi * 0.5) * 0.06 * h else 0
		local slam = if u >= 0.3 and u < 0.45 then math.sin((u - 0.3) / 0.15 * math.pi) else 0
		if slam > 0.9 then
			dust(t, now, 8)
		end
		local shake = if u >= 0.35 then math.sin(u * math.pi * 14) * 9 * (1 - u) else 0
		return CFrame.new(0, y, 0) * CFrame.Angles(math.rad(-6 * slam), math.rad(shake), 0),
			1 + P.squash * 0.6 * slam,
			1 - P.squash * slam
	end
	return CFrame.identity, 1, 1
end

local function startAction(t: Track, kind: string, now: number, impact: number?)
	local dur = if kind == "feed"
		then FEED_DUR
		elseif kind == "crit" then CRIT_DUR
		elseif kind == "evolve" then EVOLVE_DUR
		elseif kind == "tantrum" then TANTRUM_DUR
		else CHEER_DUR
	local P = GiantPersonality.get(t.giant:GetAttribute("Species") :: string?)
	if kind == "feed" or kind == "crit" then
		dur = (impact or 0) + dur / math.max(P.chompSpeed, 0.5)
	end
	t.action = { kind = kind, t0 = now, dur = dur, impact = impact or 0 }
	if kind == "tantrum" then
		local steam = steamOf(t)
		if steam then
			task.delay(0.35, function()
				if steam.Parent then
					steam:Emit(8)
				end
			end)
		end
	end
end

-- O gigante acompanha quem visita a base com um pequeno giro do corpo.
-- Amostragem a cada 0,7 s: evita buscar jogadores em todos os frames no celular.
local function visitorYaw(t: Track, now: number): number
	if now >= t.watchNext then
		t.watchNext = now + 0.7
		t.watchTarget = 0
		local nearest = 40
		for _, pl in Players:GetPlayers() do
			local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local off = root.Position - t.base.Position
				local horizontal = Vector3.new(off.X, 0, off.Z)
				local dist = horizontal.Magnitude
				if dist > 4 and dist < nearest then
					local localPos = t.giant:GetPivot():VectorToObjectSpace(horizontal)
					local ang = math.deg(math.atan2(localPos.X, -localPos.Z))
					if math.abs(ang) <= 85 then
						nearest = dist
						t.watchTarget = math.clamp(-ang, -17, 17)
					end
				end
			end
		end
	end
	t.watchYaw += (t.watchTarget - t.watchYaw) * math.min(1, STEP * 4)
	return t.watchYaw
end

-- Pose completa no instante `now`: idle + humor + ação.
local function pose(t: Track, now: number): (CFrame, number, number)
	local P = GiantPersonality.get(t.giant:GetAttribute("Species") :: string?)
	local mood = t.giant:GetAttribute("Mood")
	local h = t.height
	local hz = P.breatheHz * (if mood == "Faminto" then 0.8 else 1)
	local amp = P.breathe * (if mood == "Feliz" then 1.35 else 1)
	local br = math.sin(now * hz * math.pi * 2 + t.phase)
	local sy = 1 + br * amp
	local sxz = 1 - br * amp * 0.5
	local sway = math.sin(now * 0.45 + t.phase) * P.sway + visitorYaw(t, now)
	local roll = math.sin(now * 0.6 + t.phase * 1.3) * P.roll
	local lift = P.hover * h * (0.5 + 0.5 * math.sin(now * 1.1 + t.phase))
	local lean = P.lean + (if mood == "Faminto" then 4 else 0)
	-- espasmos (zumbi): tranco de 0,18 s a cada 2-4 s
	if P.twitch > 0 then
		if now >= t.nextTwitch then
			t.nextTwitch = now + 1.8 + math.random() * 2.5
			t.twitchAt = now
			t.twitchSign = if math.random() < 0.5 then -1 else 1
		end
		local k = math.clamp(1 - (now - t.twitchAt) / 0.18, 0, 1)
		roll += P.twitch * t.twitchSign * k
	end
	local idle = CFrame.new(0, lift, 0) * CFrame.Angles(math.rad(-lean), math.rad(sway), math.rad(roll))
	-- Mesmo sem squash (corpo de blocos), a respiração vira um sobe-e-desce pequeno.
	if not t.squashable then
		idle = CFrame.new(0, br * amp * h * 0.5, 0) * idle
	end
	-- birra periódica quando faminto (nunca no meio de outra ação)
	if mood == "Faminto" and not t.action and now >= t.nextTantrum then
		t.nextTantrum = now + 8 + math.random() * 4
		startAction(t, "tantrum", now)
	end
	local act = t.action
	if act then
		if now - act.t0 >= act.dur then
			t.action = nil
			local nextKind = table.remove(t.after, 1)
			if nextKind then
				startAction(t, nextKind, now)
			end
		else
			local cf, ax, ay = actionPose(t, act, now, P)
			return idle * cf, sxz * ax, sy * ay
		end
	end
	return idle, sxz, sy
end

-- Follow-through / overlap: uma mola subamortecida persegue a inclinação (X) e o balanço (Z) da
-- pose; a diferença entra como um pequeno "atraso" extra. Movimentos rápidos (mordida, pouso)
-- ganham um balanço que assenta sozinho, como cabeça/corpo atrasados (sem esqueleto).
local SPRING_K = 140 -- rigidez
local SPRING_D = 11 -- amortecimento (subamortecido: ~1 balanço visível)
local FOLLOW = 0.55
local function followThrough(t: Track, cf: CFrame, now: number): CFrame
	local dt = math.clamp(now - t.lastNow, 0, 0.1)
	t.lastNow = now
	local rx, _, rz = cf:ToEulerAnglesXYZ()
	local ax = SPRING_K * (rx - t.springX) - SPRING_D * t.velX
	local az = SPRING_K * (rz - t.springZ) - SPRING_D * t.velZ
	t.velX += ax * dt
	t.velZ += az * dt
	t.springX += t.velX * dt
	t.springZ += t.velZ * dt
	local lagX = math.clamp((t.springX - rx) * FOLLOW, -0.2, 0.2)
	local lagZ = math.clamp((t.springZ - rz) * FOLLOW, -0.2, 0.2)
	return cf * CFrame.Angles(lagX, 0, lagZ)
end

local function apply(t: Track, cf: CFrame, sxz: number, sy: number)
	if t.squashable then
		local scale = Vector3.new(sxz, sy, sxz)
		local frame = t.base * cf
		for i, pr in t.parts do
			if not pr.part.Parent then
				continue
			end
			local pos = pr.rel.Position * scale
			local partCf = frame * CFrame.new(pos) * pr.rel.Rotation
			pr.part.Size = pr.size * scale
			pr.part.CFrame = partCf
			if i == 1 then
				t.applied = partCf
				t.appliedSize = pr.part.Size
			end
		end
	else
		local pivot = t.base * cf * t.base:ToObjectSpace(t.restPivot)
		t.target:PivotTo(pivot)
		local first = t.parts[1]
		if first and first.part.Parent then
			t.applied = first.part.CFrame
			t.appliedSize = first.part.Size
		end
	end
	t.posed = true
end

local function restore(t: Track)
	if not t.posed then
		return
	end
	for _, pr in t.parts do
		if pr.part.Parent then
			pr.part.Size = pr.size
			pr.part.CFrame = t.base * pr.rel
		end
	end
	t.posed = false
	t.applied = nil
	t.appliedSize = nil
end

-- O servidor mexeu (crescimento, troca de malha)? Nova pose de repouso.
local function serverMoved(t: Track): boolean
	local first = t.parts[1]
	if not first or not first.part.Parent then
		return true
	end
	if not t.applied then
		return false
	end
	local cf = first.part.CFrame
	local a = t.applied :: CFrame
	if (cf.Position - a.Position).Magnitude > 0.02 or cf.LookVector:Dot(a.LookVector) < 0.9999 then
		return true
	end
	local s = t.appliedSize
	return s ~= nil and (first.part.Size - s).Magnitude > 0.02
end

local function step(now: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	for m in candidates do
		if m.Parent == Workspace and m:GetAttribute("OwnerUserId") ~= nil then
			local t = getTrack(m)
			if serverMoved(t) then
				capture(t)
			end
			local near = (t.base.Position - camPos).Magnitude <= MAX_DIST * math.max(1, t.height / 30)
			if near then
				local cf, sxz, sy = pose(t, now)
				apply(t, followThrough(t, cf, now), sxz, sy)
			else
				restore(t)
			end
		end
	end
	for m, t in tracks do
		if not m.Parent then
			if t.steam then
				t.steam:Destroy()
			end
			tracks[m] = nil
		end
	end
end

-- API para outros controladores (batalha, chefe, recordes).
function GiantAnim.play(userId: number, kind: string)
	local m = giantOf(userId)
	if not m then
		return
	end
	local t = getTrack(m)
	if t.action and (t.action.kind == "feed" or t.action.kind == "crit" or t.action.kind == "evolve") then
		table.insert(t.after, kind) -- não corta uma mordida/evolução no meio
	else
		startAction(t, kind, os.clock())
	end
end

function GiantAnim.init()
	for _, c in Workspace:GetChildren() do
		watchChild(c)
	end
	Workspace.ChildAdded:Connect(watchChild)
	Workspace.ChildRemoved:Connect(function(c)
		if c:IsA("Model") then
			candidates[c] = nil
		end
	end)
	local acc = 0
	-- Medidor só no Studio (orçamento de celular): média do custo do passo, em ms, no atributo
	-- Workspace.GiantAnimMs. Fora do Studio não mede nada.
	local measure = RunService:IsStudio()
	local costSum, costN = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		if measure then
			local t0 = os.clock()
			step(t0)
			costSum += os.clock() - t0
			costN += 1
			if costN >= 30 then
				Workspace:SetAttribute("GiantAnimMs", math.floor(costSum / costN * 1e5) / 100)
				costSum, costN = 0, 0
			end
			return
		end
		step(os.clock())
	end)
	local pendingEvolve: { [number]: number } = {}
	Remotes.GiantEvolved.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or type(e.userId) ~= "number" then
			return
		end
		local uid = e.userId
		-- O servidor manda Evolved logo antes do GiantFed: a evolução entra DEPOIS da mordida.
		-- Se não vier mordida (XP de batalha, por exemplo), evolui sozinho em 0,3 s.
		pendingEvolve[uid] = os.clock()
		task.delay(0.3, function()
			if pendingEvolve[uid] then
				pendingEvolve[uid] = nil
				GiantAnim.play(uid, "evolve")
			end
		end)
	end)
	Remotes.GiantFed.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or type(e.userId) ~= "number" then
			return
		end
		local m = giantOf(e.userId)
		if not m then
			return
		end
		local t = getTrack(m)
		local now = os.clock()
		-- A mordida acontece quando a comida chega à boca (mesmo tempo do FeedFx). Sem comida voando
		-- (XP de batalha/objetivo), morde na hora.
		local impact = if e.foodId ~= nil then GameRules.Feed.FlightSeconds else 0.12
		-- (a fila de reações já marcadas — vitória, recorde — continua; só entra a mordida agora)
		startAction(t, if e.crit then "crit" else "feed", now, impact)
		if pendingEvolve[e.userId] then
			pendingEvolve[e.userId] = nil
			table.insert(t.after, "evolve")
		elseif e.leveled then
			table.insert(t.after, "cheer")
		end
	end)
	Remotes.GiantReact.OnClientEvent:Connect(function(e)
		if type(e) == "table" and type(e.userId) == "number" and type(e.kind) == "string" then
			if e.kind == "cheer" or e.kind == "evolve" then
				GiantAnim.play(e.userId, e.kind)
			end
		end
	end)
end

return GiantAnim
