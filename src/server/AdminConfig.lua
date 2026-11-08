--!strict
-- AdminConfig — quem pode usar o painel de admin. SÓ NO SERVIDOR (ServerScriptService: o cliente
-- nunca vê esta lista). Papéis por UserId (nunca por nome, que muda). Vault: "Admin Commands Done
-- Safely - Permissions and Audit Logs" §2.
local AdminConfig = {}

-- Dono: tudo (inclusive economia e banir). 11072958195 = conta do dono do projeto.
AdminConfig.Owners = {
	[11072958195] = true,
} :: { [number]: boolean }

-- Desenvolvedores de confiança: eventos, bots, avisos, expulsar. Sem economia nem banir.
AdminConfig.Developers = {} :: { [number]: boolean }

-- Limites dos comandos de economia (por chamada e por dia, por admin).
AdminConfig.MaxCoinsPerCall = 1000000
AdminConfig.MaxCoinsPerDay = 10000000
AdminConfig.MaxFoodPerCall = 20

return AdminConfig
