--!strict
-- Features — interruptores das funções da especificação v3 (08/11/2026). Tudo nasce DESLIGADO:
-- com todas em false o jogo se comporta exatamente como antes. Ligar uma por vez, testar, e só
-- então deixar ligada. Lido pelo servidor e pelo cliente (ReplicatedStorage.Shared.Features).
--
-- Fica em src/shared/Features.lua (e não em src/shared/Config/Features.lua como a especificação
-- pedia) porque uma pasta "Config" ao lado do módulo Config.lua criaria dois filhos com o mesmo
-- nome no ReplicatedStorage e quebraria todo `require(Shared.Config)`.
local Features = {
	-- Lunchbox: contador de "Épico garantido" (pity). Só caixas abertas com moedas ou Robux contam.
	LunchboxPity = false,
	-- Recompensa diária: proteção de sequência ("backup") ganha ao completar os 7 dias.
	StreakBackup = false,
	-- Uma dica de próximo objetivo por vez, no cartão de META da HUD (depois do tutorial).
	ObjectiveHints = false,
	-- Primeiro acesso: câmera de chegada diante do gigante, 1ª alimentação mais forte e
	-- presente de boas-vindas que precisa ser aberto (complementa o tutorial atual).
	OnboardingV2 = false,
	-- Roubo: proteção de novato (nível < 5) e até 3 roubos bem-sucedidos por dia por ladrão.
	StealProtection = false,
}

-- Studio: permite ligar tudo para teste sem editar o arquivo (atributo no ReplicatedStorage).
-- Ex.: game.ReplicatedStorage:SetAttribute("Feature_LunchboxPity", true)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function on(name: string): boolean
	if RunService:IsStudio() then
		local override = ReplicatedStorage:GetAttribute("Feature_" .. name)
		if type(override) == "boolean" then
			return override
		end
	end
	return (Features :: any)[name] == true
end

return {
	flags = Features,
	on = on,
}
