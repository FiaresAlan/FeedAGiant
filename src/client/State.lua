--!strict
-- State.lua — cache local do estado do jogador recebido via StateChanged, com assinatura de mudanças.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

export type FoodInstance = { id: string, uid: string }
export type PlayerState = {
	coins: number,
	level: number,
	xp: number,
	xpNeeded: number,
	rebirths: number,
	hunger: number,
	inventory: { FoodInstance },
	plot: { [string]: FoodInstance },
	maxSlots: number,
	cps: number,
	passes: { [string]: boolean },
	shieldUntil: number,
	dailyStreak: number,
	lastDaily: number,
	species: string?,
	ownedSpecies: { [string]: boolean }?,
	stage: string?,
	arenaWins: number?,
	arenaLosses: number?,
	lastDuel: number?,
	levelsLostToDecay: number?,
	championUntil: number?,
}

local State = {}

State.current = {
	coins = 0,
	level = 1,
	xp = 0,
	xpNeeded = 50,
	rebirths = 0,
	hunger = 60,
	inventory = {},
	plot = {},
	maxSlots = 12,
	cps = 0,
	passes = {},
	shieldUntil = 0,
	dailyStreak = 0,
	lastDaily = 0,
} :: PlayerState

State.Changed = Instance.new("BindableEvent")

local function apply(data: { [string]: any })
	local s = State.current :: any
	for k, v in data do
		s[k] = v
	end
	State.Changed:Fire(State.current)
end

function State.onChanged(callback: (PlayerState) -> ()): RBXScriptConnection
	callback(State.current)
	return State.Changed.Event:Connect(callback)
end

function State.plotCount(): number
	local n = 0
	for _ in State.current.plot do
		n += 1
	end
	return n
end

function State.init()
	Remotes.StateChanged.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			apply(data)
		end
	end)
	task.spawn(function()
		local ok, _ = pcall(function()
			return Remotes.GetFullState:InvokeServer()
		end)
		if not ok then
			warn("[Client] Falha ao solicitar estado inicial")
		end
	end)
end

return State
