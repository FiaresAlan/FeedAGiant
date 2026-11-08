--!strict
-- Analytics — um módulo só, no SERVIDOR, para as métricas da especificação v3 (§11).
-- Regras do vault ("Analytics and Funnels" §3; "Measuring Onboarding"): só servidor, toda chamada
-- em pcall (métrica nunca derruba o jogo), campos curtos de listas fixas (nada de UserId, hora ou
-- texto livre), funil de onboarding só para frente. No Studio a Roblox não registra nada (esperado):
-- por isso o módulo também guarda as últimas chamadas em memória para os testes conferirem.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

assert(RunService:IsServer(), "Analytics é só do servidor")

local Analytics = {}

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

-- Últimas 50 chamadas (nome + campos), para os testes no Studio.
Analytics.recent = {} :: { { name: string, fields: { string } } }

local function remember(name: string, fields: { string }?)
	table.insert(Analytics.recent, { name = name, fields = fields or {} })
	if #Analytics.recent > 50 then
		table.remove(Analytics.recent, 1)
	end
end

local function toFields(values: { string }?): { [string]: string }?
	if not values then
		return nil
	end
	local out = {}
	for i = 1, math.min(#values, 3) do
		out[FIELD_KEYS[i]] = string.sub(tostring(values[i]), 1, 40)
	end
	return out
end

local function safe(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[Analytics]", err)
	end
end

-- Evento simples (ex.: "gacha_roll", "streak_preserved_by_backup"). value é opcional.
function Analytics.event(player: Player, name: string, value: number?, fields: { string }?)
	remember(name, fields)
	if player.Parent == nil then
		return
	end
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, toFields(fields))
	end)
end

-- Funil de primeiro acesso: só registra passos novos (para frente) por jogador.
local onboardingMax: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
function Analytics.onboarding(player: Player, step: number, stepName: string)
	if step <= (onboardingMax[player] or 0) then
		return
	end
	onboardingMax[player] = step
	remember("onboarding:" .. stepName, { tostring(step) })
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

return Analytics
