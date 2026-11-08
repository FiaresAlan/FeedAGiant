--!strict
-- Remotes.lua — cria/obtém RemoteEvents e RemoteFunctions de forma segura em servidor e cliente.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:WaitForChild("Remotes")

local EVENTS = {
	"StateChanged", -- server -> client: snapshot parcial do estado do jogador
	"Notify", -- server -> client: {text, color}
	"HatchResult", -- server -> client: {foodId, rarity}
	"EventStarted", -- server -> all: {id, name, duration, color}
	"EventEnded",
	"GiantFed", -- server -> all: {userId, xp}
	"StealAlert", -- server -> owner: {thiefName}
	"RequestFeed", -- client -> server: slotIndex
	"RequestPlace", -- client -> server: inventoryIndex
	"RequestPickup", -- client -> server: slotIndex
	"RequestBuyBox", -- client -> server: lunchboxId
	"RequestRebirth",
	"RequestRedeemCode", -- client -> server: code
	"RequestClaimDaily",
	"RequestPurchase", -- client -> server: productKey
	"RequestGamePass", -- client -> server: passKey
	-- v2
	"CombatState", -- server -> client: {stamina, maxStamina, hp, maxHp, blocking, combo, ko}
	"CombatEvent", -- server -> all: {kind = Swing|Hit|KO|Impact, ...}
	"RequestPunch", -- client -> server: heavy:boolean
	"RequestBlock", -- client -> server: on:boolean
	"DropState", -- server -> all: {id, foodId, name, rarity, pos, holdTime, contenders} | {id, removed}
	"ArenaState", -- server -> client(s): {kind = Challenge|Sent|Start|Tick|End|Tournament|Declined}
	"RequestDuel", -- client -> server: targetUserId
	"RequestDuelAnswer", -- client -> server: challengerUserId, accept:boolean
	"RequestBuySpecies", -- client -> server: speciesId
	"RequestEquipSpecies", -- client -> server: speciesId
	"GiantEvolved", -- server -> all: {userId, stageName, level}
	"RareFound", -- server -> all: {userId, name, foodId, rarity} (no máximo 1 a cada 6 s)
	"RequestFightMode", -- client -> server: on:boolean (modo de luta: luvas, soco e bloqueio)
	"Fireworks", -- server -> all: {userId, name, foodId, rarity} (fogos no servidor inteiro)
	"EventSchedule", -- server -> all: {nextId, nextName, at (os.time), activeId?, endsAt?}
	"PendingBox", -- server -> client: {boxId, count} (lunchbox entregue na base, esperando abrir)
	"RequestOpenPending", -- client -> server: index (abre uma caixa guardada; nunca sozinha)
	"ShieldMenu", -- server -> client: {left, coinSeconds, coinPrice, superSeconds, superAvailable}
	"RequestShieldRenew", -- client -> server: renovar escudo com moedas (no pedestal da própria base)
	"GiantBattle", -- server -> client: {kind = Start|Tick|End, ...} (arena dos gigantes)
	"RequestGiantBattle", -- client -> server: speciesId (leva um gigante seu ao coliseu)
	"RequestGiantSpecial", -- (antigo GOLPE FORTE; sem uso desde a batalha por turnos)
	-- Missão de 08/11/2026 (noite)
	"RequestGiantMove", -- client -> server: índice do golpe (1..3) na batalha por turnos
	"GiantReact", -- server -> all: {userId, kind = cheer|evolve} (vitórias, recordes)
	"DiaryState", -- server -> client: {daily, objectives, records, offline}
	"RequestDiary", -- client -> server: abrir o Diário (pede o estado)
	"RequestClaimObjective", -- client -> server: índice da tarefa (1..3) ou 0 = bônus do dia
	"RequestDisplay", -- client -> server: speciesId, on:boolean (expor gigante na base)
	"MeatState", -- server -> all: {kind = Warn|Land|Update|End, pos, portions, endsAt}
	"BossState", -- server -> all: {kind = Phase|Rewards, ...} (ilha do Dragão)
	-- Painel de admin (08/11/2026): o servidor confere o papel em todo comando
	"AdminCommand", -- client -> server: cmd:string, args:table
	"AdminState", -- server -> admin: {kind = Result|Confirm, ...}
}

local FUNCTIONS = {
	"GetFullState",
}

local Remotes = {}

for _, name in EVENTS do
	local inst = folder:FindFirstChild(name)
	if not inst then
		if RunService:IsServer() then
			inst = Instance.new("RemoteEvent")
			inst.Name = name
			inst.Parent = folder
		else
			inst = folder:WaitForChild(name)
		end
	end
	Remotes[name] = inst :: RemoteEvent
end

for _, name in FUNCTIONS do
	local inst = folder:FindFirstChild(name)
	if not inst then
		if RunService:IsServer() then
			inst = Instance.new("RemoteFunction")
			inst.Name = name
			inst.Parent = folder
		else
			inst = folder:WaitForChild(name)
		end
	end
	-- RemoteFunctions ficam no mesmo módulo; o cast evita misturar tipos com os RemoteEvents.
	(Remotes :: any)[name] = inst
end

return Remotes
