--!strict
-- Guard.lua — checagens de servidor contra exploits (Fase 0.6).
-- ClickDetector.MaxActivationDistance e Touched NÃO são validados pelo servidor
-- (vault: Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched),
-- então toda ação disparada por clique/toque confere a distância aqui.
local RateLimit = require(game:GetService("ReplicatedStorage"):WaitForChild("fwjelaa"):WaitForChild("RateLimit"))

local Guard = {}

-- Limites por jogador e por remote (token bucket; vault: 1,5x a 2x o uso legítimo
-- mais rápido). Os baldes de quem sai são limpos pelo próprio RateLimit.
local limiters: { [string]: RateLimit.Limiter } = {}
local LIMITS: { [string]: { burst: number, perSecond: number } } = {
	Plot = { burst = 8, perSecond = 5 }, -- colocar/pegar/alimentar (toques rápidos em sequência)
	Species = { burst = 3, perSecond = 1 }, -- comprar/equipar espécie reconstrói o Gigante
	Rebirth = { burst = 2, perSecond = 0.5 },
	Daily = { burst = 2, perSecond = 0.5 },
	Redeem = { burst = 3, perSecond = 0.1 }, -- depois de 3, 1 código a cada 10 s (contra força bruta)
	Duel = { burst = 3, perSecond = 0.5 },
	Combat = { burst = 12, perSecond = 8 }, -- socos/bloqueio; o cooldown real fica no CombatService
}

-- true se o jogador ainda pode usar a ação `kind` agora.
function Guard.allow(player: Player, kind: string): boolean
	local limiter = limiters[kind]
	if not limiter then
		local cfg = LIMITS[kind]
		assert(cfg, `Guard.allow: limite desconhecido {kind}`)
		limiter = RateLimit.new(cfg.burst, cfg.perSecond)
		limiters[kind] = limiter
	end
	return limiter:Allow(player)
end

-- Índice inteiro em [1, max] (rejeita NaN, infinito, fração e negativos).
function Guard.isIndex(x: any, max: number): boolean
	return type(x) == "number" and x == x and x >= 1 and x <= max and math.floor(x) == x
end

-- Margem para latência e tamanho do personagem (vault: MaxActivationDistance + 4).
Guard.MARGIN = 4

function Guard.rootOf(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- O jogador (vivo) está a no máximo `maxDistance` studs da peça?
function Guard.withinReach(player: Player, target: BasePart, maxDistance: number): boolean
	local root = Guard.rootOf(player)
	if not root then
		return false
	end
	-- Distância até a superfície aproximada: centro menos metade da maior dimensão da peça.
	local half = math.max(target.Size.X, target.Size.Y, target.Size.Z) / 2
	local dist = (root.Position - target.Position).Magnitude - half
	return dist <= maxDistance + Guard.MARGIN
end

-- Distância entre dois jogadores (vivos); math.huge se algum não tiver personagem.
function Guard.distanceBetween(a: Player, b: Player): number
	local ra, rb = Guard.rootOf(a), Guard.rootOf(b)
	if not ra or not rb then
		return math.huge
	end
	return (ra.Position - rb.Position).Magnitude
end

return Guard
