--!strict
-- Guard.lua — checagens de servidor contra exploits (Fase 0.6).
-- ClickDetector.MaxActivationDistance e Touched NÃO são validados pelo servidor
-- (vault: Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched),
-- então toda ação disparada por clique/toque confere a distância aqui.
local Guard = {}

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
