--!strict
-- Secrets.lua — dados que NUNCA vão para o cliente (ServerScriptService não replica).
-- Fase 0.6: os códigos promocionais saíram de ReplicatedStorage/Shared/Config, onde
-- qualquer jogador conseguia lê-los.
local Secrets = {}

-- CÓDIGO (maiúsculas) -> moedas
Secrets.PromoCodes = {
	GIGANTE = 1000,
	LAUNCH = 2500,
} :: { [string]: number }

return Secrets
