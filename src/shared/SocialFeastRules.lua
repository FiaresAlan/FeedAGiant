--!strict
-- Regras puras do Banquete em Dupla; teste sem Roblox Studio.
-- O desafio não retira comida na inscrição: consome ambas apenas no sucesso.
local Config = require(script.Parent.Config)

local SocialFeastRules = {}

SocialFeastRules.WindowSeconds = 120
SocialFeastRules.CooldownSeconds = 180 -- por pessoa, não bloqueia o servidor inteiro
SocialFeastRules.GlobalResetSeconds = 10 -- só a curta celebração do pedestal
SocialFeastRules.BuffSeconds = 240
SocialFeastRules.BuffMult = 1.15
SocialFeastRules.RewardCoins = 150
SocialFeastRules.MaxPerDay = 3
SocialFeastRules.PromptReach = 14
SocialFeastRules.PartnerReach = 35

function SocialFeastRules.findFood(inventory: { any }, uid: string?): (number?, any?)
	local bestIndex, bestItem, rank = nil :: number?, nil :: any, math.huge
	for i, item in inventory do
		if type(item) ~= "table" or type(item.id) ~= "string" then
			continue
		end
		local def = Config.FoodById[item.id]
		local rarity = def and Config.Rarities[def.rarity]
		local order = rarity and rarity.order or math.huge
		if order > 2 or item.mut ~= nil or item.big == true then
			continue
		end
		if uid then
			if item.uid == uid then
				return i, item
			end
		elseif order < rank then
			rank, bestIndex, bestItem = order, i, item
		end
	end
	return bestIndex, bestItem
end

function SocialFeastRules.available(slice: any, now: number): boolean
	if type(slice) ~= "table" then
		return false
	end
	local day = math.floor(now / 86400)
	return slice.day ~= day or (tonumber(slice.count) or 0) < SocialFeastRules.MaxPerDay
end

function SocialFeastRules.completed(slice: any, now: number): any
	local day = math.floor(now / 86400)
	return {
		v = 1,
		day = day,
		count = (if slice.day == day then (tonumber(slice.count) or 0) else 0) + 1,
		total = (tonumber(slice.total) or 0) + 1,
	}
end

function SocialFeastRules.canPair(a: number, b: number, expiry: number, now: number): boolean
	-- UserIds negativos são contas de teste locais do Roblox Studio.
	-- Só uma instância Player real passa pelo ProximityPrompt do servidor.
	return a ~= 0 and b ~= 0 and a ~= b and now < expiry
end

return SocialFeastRules
