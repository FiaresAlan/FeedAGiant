--!strict
-- LeaderboardService — atualiza os placares físicos e o leaderstats (lista do Roblox).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Util = require(game.ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)

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

local function render(boardName: string, entries: { { userId: number, value: number } }, suffix: string)
	local map = Workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild(boardName)
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local list = gui and gui:FindFirstChild("List") :: TextLabel?
	if not list then
		return
	end
	local lines = {}
	for i, e in entries do
		table.insert(lines, string.format("#%d  %s — %s%s", i, nameOf(e.userId), Util.formatNumber(e.value), suffix))
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
		while true do
			local lvl = DataService.getLeaderboard("Level", 10)
			for _, e in lvl do
				e.value = e.value % 1000 -- valor salvo = level + rebirths*1000; exibe só o nível
			end
			render("Leaderboard1", lvl, "")
			render("Leaderboard2", DataService.getLeaderboard("Rebirth", 10), " rebirths")
			render("Leaderboard3", DataService.getLeaderboard("Arena", 10), " pts")
			task.wait(120)
		end
	end)
end

return LeaderboardService
