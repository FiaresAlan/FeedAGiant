--!strict
-- V2: funil e atividade reais; sem dados pessoais ou telemetria inventada.
-- Os relatórios Roblox so sao observaveis corretamente apos publicar ambiente de teste adequado.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local Analytics = require(script.Parent.Parent.Analytics)
local Hooks = require(script.Parent.Parent.Hooks)
local Guard = require(script.Parent.Parent.Guard)
local Mount = require(script.Parent.V2MountService)

local Metrics = {}
local records: { [Player]: any } = {}
local milestones = { 60, 300, 600, 900, 1800 }

local function step(player: Player, id: string, phase: number)
	local record = records[player]
	if not record or not Features.on("RebuildV2") then return end
	if record.seen[id] then return end
	record.seen[id] = true
	record.phase = math.max(record.phase, phase)
	Analytics.event(player, "v2_" .. id, 1, { tostring(phase) })
end

function Metrics.onJoin(player: Player)
	if not Features.on("RebuildV2") then return end
	records[player] = {
		enteredAt = os.clock(),
		activeSeconds = 0,
		phase = 0,
		feeds = 0,
		seen = {},
	}
	step(player, "entered", 0)
end

function Metrics.init()
	Hooks.on("v2_mounted", function(player: Player)
		step(player, "first_mount", 1)
	end)
	Hooks.on("v2_picked", function(player: Player, _kind: string)
		step(player, "first_pickup", 2)
	end)
	Hooks.on("v2_delivered", function(player: Player, _kind: string)
		step(player, "first_delivery", 3)
	end)
	Hooks.on("v2_cooked", function(player: Player, _recipe: string)
		step(player, "first_cook", 4)
	end)
	Hooks.on("fed", function(player: Player)
		local record = records[player]
		if not record or not Features.on("RebuildV2") then return end
		record.feeds += 1
		if record.feeds == 1 then
			step(player, "first_feed", 5)
		elseif record.feeds == 2 then
			step(player, "second_feed", 6)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			if not Features.on("RebuildV2") then continue end
			for player, record in records do
				if player.Parent == nil then continue end
				local mounted = Mount.session(player)
				local active = mounted and mounted.move.Magnitude > 0.05
					and os.clock() - mounted.lastInputAt < 1
				if not active then
					local root = Guard.rootOf(player)
					active = root ~= nil and root.AssemblyLinearVelocity.Magnitude > 2
				end
				if active then
					record.activeSeconds += 5
					for _, seconds in milestones do
						if record.activeSeconds >= seconds then
							step(player, "active_" .. tostring(seconds) .. "s", record.phase)
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local record = records[player]
		if not record then return end
		local sessionSeconds = math.max(0, os.clock() - record.enteredAt)
		Analytics.event(player, "v2_session_end", math.floor(sessionSeconds), {
			"phase_" .. tostring(record.phase),
			"active_" .. tostring(math.floor(record.activeSeconds)),
			"feeds_" .. tostring(record.feeds),
		})
		records[player] = nil
	end)
end

return Metrics
