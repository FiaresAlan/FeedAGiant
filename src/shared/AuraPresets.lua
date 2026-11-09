--!strict
-- AuraPresets — auras dos gigantes por elemento, a partir de efeitos GRÁTIS da Loja do Criador (pedido
-- do usuário em 09/11/2026: "usar os efeitos da Loja do Criador que aparecem quando você pesquisa").
--
-- Por que receitas em código e não o modelo inserido no place:
--   * InsertService:LoadAsset em jogo NÃO carrega modelos de outros criadores ("User is not authorized",
--     medido em 09/11); inserir no place oficial exige salvá-lo (regra do projeto: não escrever nele);
--   * os efeitos foram feitos para um avatar de ~5 studs e somem num gigante de 26 a 100+ studs.
-- Então os modelos foram abertos SÓ no Studio (modo Play), auditados (0 scripts nos três), e daqui
-- copiamos as configurações dos emissores (mesmas texturas públicas, cores, transparências, flipbook),
-- escaladas pelo tamanho do gigante e com teto de partículas para o celular (vault: "ParticleEmitter -
-- Engine Reference Card", "Juice on a Budget").
--
-- Fontes (Loja do Criador, grátis, sem scripts):
--   fire  ← "GritoRageModeVFX" (80009599818855, NoFonPal)
--   ice   ← "POF:RE Aura: Ice Wizard" (9452880987, counteractedpills)
--   stone ← "POF:RE AURA EARTH ELEMENTAL" (8436875117, BigBubbaBrock)
local AuraPresets = {}

-- Teto de partículas vivas por gigante (todas as camadas somadas). Até 8 gigantes por servidor.
AuraPresets.MaxAlive = 60

type Key = { number } -- {tempo, valor} ou {tempo, r, g, b}
export type Layer = {
	tex: string,
	rate: number, -- por camada, já dentro do teto (o original da Loja era maior; anotado ao lado)
	life: { number },
	speed: { number },
	spread: number,
	size: { Key }, -- em "studs de avatar"; multiplicado pela escala do gigante
	transp: { Key },
	color: { Key },
	light: number, -- LightEmission
	bright: number,
	rot: { number },
	rotSpeed: { number },
	accel: number?, -- aceleração para cima (studs/s², escalada)
	locked: boolean,
	flipbook: Enum.ParticleFlipbookLayout?,
	zOffset: number?,
	orient: Enum.ParticleOrientation?,
	fromVolume: boolean, -- emite do volume do corpo (true) ou do centro (false)
}

local FIRE_GRADIENT = { { 0, 255, 201, 135 }, { 0.3, 255, 112, 16 }, { 0.74, 255, 112, 16 }, { 1, 0, 75, 5 } }

AuraPresets.Presets = {
	fire = {
		{ -- labaredas animadas (flipbook 4x4) — a camada principal do GritoRageModeVFX
			tex = "rbxassetid://12994153008",
			rate = 40,
			life = { 0.5, 0.6 },
			speed = { 0, 0 },
			spread = 0,
			size = { { 0, 9 }, { 1, 9 } },
			transp = { { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.6 }, { 1, 1 } },
			color = FIRE_GRADIENT,
			light = 1,
			bright = 4,
			rot = { -360, 360 },
			rotSpeed = { 0, 0 },
			locked = true,
			flipbook = Enum.ParticleFlipbookLayout.Grid4x4,
			zOffset = 2,
			fromVolume = true,
		},
		{ -- chamas que crescem (10357952493)
			tex = "rbxassetid://10357952493",
			rate = 40,
			life = { 0.5, 0.6 },
			speed = { 0, 0 },
			spread = 0,
			size = { { 0, 0 }, { 1, 6 } },
			transp = { { 0, 1 }, { 0.3, 0.5 }, { 0.7, 0.55 }, { 1, 1 } },
			color = FIRE_GRADIENT,
			light = 1,
			bright = 3,
			rot = { -360, 360 },
			rotSpeed = { -360, -360 },
			locked = true,
			zOffset = 2,
			fromVolume = true,
		},
		{ -- brasas subindo (547900945)
			tex = "rbxassetid://547900945",
			rate = 12,
			life = { 1.2, 1.8 },
			speed = { 2, 4 },
			spread = 25,
			size = { { 0, 0.6 }, { 1, 0 } },
			transp = { { 0, 0 }, { 1, 1 } },
			color = { { 0, 255, 170, 60 }, { 1, 255, 80, 10 } },
			light = 1,
			bright = 2,
			rot = { 0, 0 },
			rotSpeed = { 0, 0 },
			accel = 2,
			locked = false,
			fromVolume = true,
		},
	},
	ice = {
		{ -- redemoinho gelado (7216848832)
			tex = "rbxassetid://7216848832",
			rate = 0.6,
			life = { 10, 10 },
			speed = { 0, 0 },
			spread = 0,
			size = { { 0, 5 }, { 1, 5 } },
			transp = { { 0, 0.2 }, { 0.9, 0.5 }, { 1, 1 } },
			color = { { 0, 0, 243, 255 }, { 1, 0, 243, 255 } },
			light = 1,
			bright = 1,
			rot = { 180, 180 },
			rotSpeed = { 50, 50 },
			locked = true,
			zOffset = -1,
			fromVolume = false,
		},
		{ -- véus azuis subindo (1075864321)
			tex = "rbxassetid://1075864321",
			rate = 8,
			life = { 3, 4 },
			speed = { 0, 0 },
			spread = 0,
			size = { { 0, 1.6 }, { 1, 1.2 } },
			transp = { { 0, 0.1 }, { 1, 1 } },
			color = { { 0, 94, 253, 255 }, { 1, 94, 253, 255 } },
			light = 1,
			bright = 1,
			rot = { 180, 180 },
			rotSpeed = { 100, 100 },
			accel = 0.5,
			locked = false,
			fromVolume = true,
		},
		{ -- flocos de neve (68072538)
			tex = "rbxassetid://68072538",
			rate = 4,
			life = { 4, 6 },
			speed = { 1, 1 },
			spread = 25,
			size = { { 0, 0.25 }, { 1, 0.25 } },
			transp = { { 0, 0 }, { 1, 0 } },
			color = { { 0, 255, 255, 255 }, { 1, 255, 255, 255 } },
			light = 1,
			bright = 1,
			rot = { -90, -90 },
			rotSpeed = { 130, 130 },
			locked = false,
			fromVolume = true,
		},
	},
	stone = {
		{ -- estilhaços que sobem e giram (2058077944)
			tex = "rbxassetid://2058077944",
			rate = 6,
			life = { 1, 2 },
			speed = { 5, 5 },
			spread = 2,
			size = { { 0, 2.37 }, { 1, 5 } },
			transp = { { 0, 0.35 }, { 1, 1 } },
			color = { { 0, 255, 255, 255 }, { 1, 255, 255, 255 } },
			light = 0.3,
			bright = 1,
			rot = { 0, 0 },
			rotSpeed = { -300, 300 },
			locked = true,
			orient = Enum.ParticleOrientation.VelocityPerpendicular,
			fromVolume = true,
		},
		{ -- pedrinhas flutuando ao redor (394144370)
			tex = "rbxassetid://394144370",
			rate = 5,
			life = { 4, 5 },
			speed = { 0.15, 0.15 },
			spread = 360,
			size = { { 0, 1.1 }, { 1, 1.1 } },
			transp = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
			color = { { 0, 150, 140, 130 }, { 1, 150, 140, 130 } },
			light = 0,
			bright = 1,
			rot = { 0, 0 },
			rotSpeed = { -300, 300 },
			locked = true,
			fromVolume = true,
		},
		{ -- poeira (243474653)
			tex = "rbxassetid://243474653",
			rate = 5,
			life = { 4, 5 },
			speed = { 0.03, 0.03 },
			spread = 360,
			size = { { 0, 1.4 }, { 1, 2 } },
			transp = { { 0, 0.6 }, { 0.75, 0.7 }, { 1, 1 } },
			color = { { 0, 200, 190, 175 }, { 1, 200, 190, 175 } },
			light = 0,
			bright = 1,
			rot = { 0, 0 },
			rotSpeed = { -300, 300 },
			locked = true,
			fromVolume = true,
		},
	},
} :: { [string]: { Layer } }

local function numSeq(keys: { Key }, k: number): NumberSequence
	local kp = {}
	for _, key in keys do
		table.insert(kp, NumberSequenceKeypoint.new(key[1], key[2] * k))
	end
	return NumberSequence.new(kp)
end

local function colorSeq(keys: { Key }): ColorSequence
	local kp = {}
	for _, key in keys do
		table.insert(kp, ColorSequenceKeypoint.new(key[1], Color3.fromRGB(key[2], key[3], key[4])))
	end
	return ColorSequence.new(kp)
end

-- Taxa por camada respeitando o teto: o total de vivas (rate x vida máx.) fica <= MaxAlive.
function AuraPresets.rates(kind: string): { number }
	local layers = AuraPresets.Presets[kind]
	assert(layers, `aura desconhecida {kind}`)
	local total = 0
	for _, l in layers do
		total += l.rate * l.life[2]
	end
	local f = math.min(1, AuraPresets.MaxAlive / math.max(total, 1e-6))
	local out = {}
	for _, l in layers do
		table.insert(out, l.rate * f)
	end
	return out
end

-- Monta a aura num corpo do gigante. `height` = altura do gigante em studs (escala ~ altura/5, como os
-- efeitos originais feitos para um avatar de 5 studs, amortecida para não virar uma bola de partículas).
function AuraPresets.build(part: BasePart, kind: string, height: number): { ParticleEmitter }
	local layers = AuraPresets.Presets[kind]
	if not layers then
		return {}
	end
	local k = math.max(1, (height / 5) ^ 0.85)
	local rates = AuraPresets.rates(kind)
	local center = Instance.new("Attachment")
	center.Name = "AuraCenter"
	center.Parent = part
	local out = {}
	for i, l in layers do
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Aura_" .. kind .. "_" .. i
		pe.Texture = l.tex
		pe.Rate = rates[i]
		pe.Lifetime = NumberRange.new(l.life[1], l.life[2])
		pe.Speed = NumberRange.new(l.speed[1] * k, l.speed[2] * k)
		pe.SpreadAngle = Vector2.new(l.spread, l.spread)
		pe.Size = numSeq(l.size, k)
		pe.Transparency = numSeq(l.transp, 1)
		pe.Color = colorSeq(l.color)
		pe.LightEmission = l.light
		pe.LightInfluence = 0
		pe.Brightness = l.bright
		pe.Rotation = NumberRange.new(l.rot[1], l.rot[2])
		pe.RotSpeed = NumberRange.new(l.rotSpeed[1], l.rotSpeed[2])
		pe.Acceleration = Vector3.new(0, (l.accel or 0) * k, 0)
		pe.LockedToPart = l.locked
		pe.ZOffset = l.zOffset or 0
		if l.flipbook then
			pe.FlipbookLayout = l.flipbook
			pe.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		if l.orient then
			pe.Orientation = l.orient
		end
		if l.fromVolume then
			pe.Shape = Enum.ParticleEmitterShape.Box
			pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			pe.Parent = part -- emite do volume do corpo (envolve o gigante)
		else
			pe.Parent = center
		end
		table.insert(out, pe)
	end
	return out
end

return AuraPresets
