--!strict
-- Features — interruptores das funções novas. Em 09/11/2026 (noite) o diretor, no papel de dono dado
-- pelo usuário, LIGOU as funções prontas e testadas no Play (ver docs/NOITE_2026-11-09_RELATORIO.md).
-- Para voltar ao jogo antigo, basta pôr false. Texto original: tudo nascia DESLIGADO:
-- com todas em false o jogo se comporta exatamente como antes. Ligar uma por vez, testar, e só
-- então deixar ligada. Lido pelo servidor e pelo cliente (ReplicatedStorage.Shared.Features).
--
-- Fica em src/shared/Features.lua (e não em src/shared/Config/Features.lua como a especificação
-- pedia) porque uma pasta "Config" ao lado do módulo Config.lua criaria dois filhos com o mesmo
-- nome no ReplicatedStorage e quebraria todo `require(Shared.Config)`.
local Features = {
	-- Lunchbox: contador de "Épico garantido" (pity). Só caixas abertas com moedas ou Robux contam.
	LunchboxPity = true,
	-- Recompensa diária: proteção de sequência ("backup") ganha ao completar os 7 dias.
	StreakBackup = true,
	-- Uma dica de próximo objetivo por vez, no cartão de META da HUD (depois do tutorial).
	ObjectiveHints = true,
	-- Primeiro acesso: câmera de chegada diante do gigante, 1ª alimentação mais forte e
	-- presente de boas-vindas que precisa ser aberto (complementa o tutorial atual).
	OnboardingV2 = true,
	-- Roubo: proteção de novato (nível < 5) e até 3 roubos bem-sucedidos por dia por ladrão.
	StealProtection = true,
	-- Sistema de Ovos: ninho na praça, 5 tamanhos, loja de moedas, prêmios do Dragão e marcos.
	EggSystem = true,
	-- Efeitos visuais dos ovos por raridade (desligar alivia celulares fracos).
	EggVFX = true,
	-- Notificação "ovo pronto" (Open Cloud): NÃO implementada; exige jogo publicado com 100 visitas.
	EggNotifications = false,
	-- Escolha de 1 das 3 espécies iniciais no primeiro acesso (ainda sem os 3 modelos).
	StarterSpecies = true,
	-- Prompt v4 (09/11/2026). Só WeeklyQuest tem código; as outras esperam a cópia de teste do place.
	TutorialEgg = false, -- ovo de tutorial (Médio, 60-90 s) — aguardando as espécies iniciais
	Revange = false, -- revanche do roubo pelo LUTAR — aguardando a cópia de teste
	WeeklyQuest = true, -- missão semanal: escolher 1 de 3 no Diário (implementada)
	DragonRaidPhase1 = false, -- fase 1 do Dragão (alimentar para enfraquecer) — aguardando a cópia de teste
	-- Noite de 09/11/2026 (melhorias autônomas)
	Mutations = true, -- comida exposta ganha mutação durante os eventos (Dourada, Suculenta, Arco-íris)
	WelcomeBack = true, -- resumo "Bem-vindo de volta" ao entrar depois de 10+ min fora
	Fusion = true, -- 3 comidas iguais da mochila viram 1 Gigantesca (renda e XP x3,2)
	Ancestral = true, -- Gigante Ancestral: banquete coletivo do servidor, chuva de comida e +XP para todos
	EggSteal = true, -- 09/11: ninho em cada base + roubo leve de ovo (pedido do usuário). false = só o ninho da praça
	SocialFeast = true, -- Banquete presencial em dupla: 2 humanos, oferta segura e buff de XP temporário
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
