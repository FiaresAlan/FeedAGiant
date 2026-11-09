--!strict
-- Speed.lua — dono ÚNICO da velocidade de andar dos jogadores (09/11/2026).
-- Antes cada sistema guardava a "velocidade original" e multiplicava por conta própria (carregar drop,
-- turbo da ponte). Com o evento CORRIDA TURBO seriam 3 sistemas brigando. Agora cada um só declara o
-- seu multiplicador e este módulo calcula: WalkSpeed = base × produto dos multiplicadores.
--   * base = StarterPlayer.CharacterWalkSpeed (o mesmo valor de quem acabou de nascer);
--   * WalkSpeed 0 = congelado pela arena: não mexe (a arena devolve depois e o laço corrige);
--   * um laço de 1 s aplica os globais em quem renasceu.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Speed = {}

local perPlayer: { [Player]: { [string]: number } } = {}
local global: { [string]: number } = {}

local function multOf(player: Player): number
	local m = 1
	for _, v in global do
		m *= v
	end
	local mine = perPlayer[player]
	if mine then
		for _, v in mine do
			m *= v
		end
	end
	return m
end

function Speed.refresh(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.WalkSpeed == 0 then
		return
	end
	local want = StarterPlayer.CharacterWalkSpeed * multOf(player)
	if math.abs(hum.WalkSpeed - want) > 0.01 then
		hum.WalkSpeed = want
	end
end

-- Multiplicador de um sistema para um jogador (nil ou 1 = tira).
function Speed.set(player: Player, source: string, mult: number?)
	local mine = perPlayer[player]
	if not mine then
		mine = {}
		perPlayer[player] = mine
	end
	local m = mine :: { [string]: number }
	m[source] = if mult and mult ~= 1 then mult :: number else nil :: any
	Speed.refresh(player)
end

-- Multiplicador para TODOS (eventos). nil ou 1 = tira.
function Speed.setGlobal(source: string, mult: number?)
	global[source] = if mult and mult ~= 1 then mult :: number else nil :: any
	for _, p in Players:GetPlayers() do
		Speed.refresh(p)
	end
end

function Speed.globalMult(): number
	local m = 1
	for _, v in global do
		m *= v
	end
	return m
end

function Speed.init()
	Players.PlayerRemoving:Connect(function(p)
		perPlayer[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in Players:GetPlayers() do
				Speed.refresh(p)
			end
		end
	end)
end

return Speed
