--!strict
-- V3Journey: onboarding server-authoritative. Nao altera inventario ou niveis.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.RebuildV2.GuideRules)
local Guard = require(script.Parent.Parent.Guard)
local Hooks = require(script.Parent.Parent.Hooks)
local DataService = require(script.Parent.DataService)

local Journey = {}

local function fresh()
	return { version = 1, seen = {}, feeds = 0 }
end

local function dataOf(player: Player): (any, any)
	local profile = DataService.get(player)
	if not profile then return nil, nil end
	local data = (profile :: any).v3Journey
	if type(data) ~= "table" then
		data = fresh()
		(profile :: any).v3Journey = data
		DataService.markDirty(player)
	end
	if type(data.seen) ~= "table" then data.seen = {}; DataService.markDirty(player) end
	if type(data.feeds) ~= "number" or data.feeds < 0 then
		data.feeds = 0
		DataService.markDirty(player)
	end
	return profile, data
end

function Journey.push(player: Player)
	if not Features.on("RebuildV2") or player.Parent == nil then return end
	local profile, data = dataOf(player)
	if not profile then return end
	-- Nao obrigar veteranos a repetir alimentacoes anteriores.
	if (profile.totalFeeds or 0) >= 1 and Rules.mark(data.seen, "first_feed") then
		DataService.markDirty(player)
	end
	if (profile.totalFeeds or 0) >= 2 and Rules.mark(data.seen, "second_feed") then
		DataService.markDirty(player)
	end
	local id, line, step = Rules.next(data.seen)
	Remotes.V3GuideState:FireClient(player, {
		stepId = id,
		step = step,
		message = line,
		finished = id == nil,
	})
end

local function milestone(player: Player, id: string)
	if not Features.on("RebuildV2") then return end
	local _, data = dataOf(player)
	if data and Rules.mark(data.seen, id) then
		DataService.markDirty(player)
		Journey.push(player)
	end
end

function Journey.init()
	DataService.registerSlice("v3Journey", fresh)
	Hooks.on("fed", function(player: Player)
		if not Features.on("RebuildV2") then return end
		local _, data = dataOf(player)
		if not data then return end
		data.feeds += 1
		DataService.markDirty(player)
		milestone(player, "first_feed")
		if data.feeds >= 2 then milestone(player, "second_feed") end
	end)
	Hooks.on("v2_mounted", function(player: Player) milestone(player, "first_mount") end)
	Hooks.on("v2_picked", function(player: Player) milestone(player, "first_pickup") end)
	Hooks.on("v2_delivered", function(player: Player) milestone(player, "first_delivery") end)
	Hooks.on("v2_cooked", function(player: Player) milestone(player, "first_cook") end)
	Hooks.on("v2_cook_claimed", function(player: Player) milestone(player, "first_claim") end)
	Remotes.V3GuideRequest.OnServerEvent:Connect(function(player: Player, action: any)
		if Features.on("RebuildV2") and action == "snapshot" and Guard.allow(player, "V3Guide") then
			Journey.push(player)
		end
	end)
end

function Journey.onJoin(player: Player)
	Journey.push(player)
end

return Journey
