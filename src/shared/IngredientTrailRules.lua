--!strict
-- Regras puras da Trilha da Comida; servidor é a autoridade para local e tempo.
local TrailRules = {}
TrailRules.DurationSeconds = 180
TrailRules.MaxRewardsPerDay = 2
TrailRules.RewardCoins = 200
TrailRules.LastStage = 3

function TrailRules.canClaim(saved: any, now: number): boolean
	local day = math.floor(now / 86400)
	return type(saved) ~= "table" or saved.day ~= day
		or (tonumber(saved.rewards) or 0) < TrailRules.MaxRewardsPerDay
end

function TrailRules.canAdvance(current: number, requested: number, deadline: number, now: number): boolean
	return type(current) == "number" and type(requested) == "number"
		and requested >= 1 and requested <= TrailRules.LastStage
		and current + 1 == requested and now < deadline
end

function TrailRules.claim(saved: any, now: number): any
	local day = math.floor(now / 86400)
	local prior = if type(saved) == "table" then saved else {}
	return {
		v = 1,
		day = day,
		rewards = (if prior.day == day then (tonumber(prior.rewards) or 0) else 0) + 1,
		lifetime = (tonumber(prior.lifetime) or 0) + 1,
	}
end

return TrailRules
