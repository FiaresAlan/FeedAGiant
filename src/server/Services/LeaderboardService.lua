--!strict
-- LeaderboardService — atualiza os placares físicos e o leaderstats (lista do Roblox).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local BotService = require(script.Parent.BotService)

local LeaderboardService = {}

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok then name else "???"
	nameCache[userId] = result
	return result
end

type Entry = { userId: number, value: number, name: string? }

-- Pedido do usuário (09/11, item 9): os bots do servidor entram nos placares pelo que têm (nível,
-- renascimentos, pontos de arena), misturados com o ranking salvo e na ordem certa. Eles não são
-- gravados no DataStore: só aparecem enquanto estão no servidor.
local function withBots(entries: { Entry }, field: string, n: number): { Entry }
	local out: { Entry } = table.clone(entries)
	for _, b in BotService.list() do
		local v = tonumber(b[field]) or 0
		if v > 0 then
			table.insert(out, { userId = b.uid, value = v, name = b.name })
		end
	end
	table.sort(out, function(a, b)
		return a.value > b.value
	end)
	while #out > n do
		table.remove(out)
	end
	return out
end

local function render(boardName: string, entries: { Entry }, suffix: string)
	local map = Workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild(boardName)
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local list = gui and gui:FindFirstChild("List") :: TextLabel?
	if not list then
		return
	end
	local lines = {}
	for i, e in entries do
		table.insert(
			lines,
			string.format("#%d  %s — %s%s", i, e.name or nameOf(e.userId), Util.formatNumber(e.value), suffix)
		)
	end
	list.Text = if #lines > 0 then table.concat(lines, "\n") else "Seja o primeiro!"
end

local function setupLeaderstats(player: Player)
	local profile = DataService.waitFor(player)
	if not profile then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local lvl = Instance.new("IntValue")
	lvl.Name = "Giant Lv"
	lvl.Value = profile.level
	lvl.Parent = ls
	local rb = Instance.new("IntValue")
	rb.Name = "Rebirths"
	rb.Value = profile.rebirths
	rb.Parent = ls
	local aw = Instance.new("IntValue")
	aw.Name = "Wins"
	aw.Value = profile.arenaWins
	aw.Parent = ls
	ls.Parent = player
	task.spawn(function()
		while player.Parent do
			task.wait(2)
			local p = DataService.get(player)
			if p then
				lvl.Value = p.level
				rb.Value = p.rebirths
				aw.Value = p.arenaWins
			end
		end
	end)
end

function LeaderboardService.init()
	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, p in Players:GetPlayers() do
		task.spawn(setupLeaderstats, p)
	end
	task.spawn(function()
		-- O ranking salvo é lido a cada 120 s (limite do DataStore); os bots mudam mais rápido, então a
		-- placa é redesenhada a cada 20 s com o último ranking lido.
		local lvl: { Entry }, reb: { Entry }, arena: { Entry } = {}, {}, {}
		local lastRead = -math.huge
		while true do
			if os.clock() - lastRead >= 120 then
				lastRead = os.clock()
				lvl = DataService.getLeaderboard("Level", 10) :: any
				for _, e in lvl do
					e.value = e.value % 1000 -- valor salvo = level + rebirths*1000; exibe só o nível
				end
				reb = DataService.getLeaderboard("Rebirth", 10) :: any
				arena = DataService.getLeaderboard("Arena", 10) :: any
			end
			render("Leaderboard1", withBots(lvl, "level", 10), "")
			render("Leaderboard2", withBots(reb, "rebirths", 10), " rebirths")
			render("Leaderboard3", withBots(arena, "arenaPts", 10), " pts")
			task.wait(20)
		end
	end)
end

return LeaderboardService
