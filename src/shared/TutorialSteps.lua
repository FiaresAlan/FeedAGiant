--!strict
-- TutorialSteps — primeiro minuto do Feed a Giant (Fase 4; skill fwjelaa-tutorial, módulo FwjelaaTutorial).
-- Loop central numa linha: "alimentar o gigante (XP/crescer) ou pôr comida no pátio (moedas) → comprar
-- lunchbox → repetir". Objetivos com 8 palavras ou menos; dicas só quando o jogador trava (hintAfter).
-- Ordem = ordem de ensino. Os ganchos do servidor (isComplete) ficam no TutorialService.
-- Vault: "Onboarding and FTUE - Tutorials That Keep Players", "Tutorial Step Design Patterns".
local steps: { any } = {
	{
		id = "feed",
		objective = "Alimente seu Gigante!",
		signal = "Fed",
		guide = "none", -- alvo é botão da HUD: o próprio botão ALIMENTAR pulsa
		hint = {
			Keyboard = "Fique perto do Gigante e clique em ALIMENTAR!",
			Touch = "Fique perto do Gigante e toque em ALIMENTAR!",
			Gamepad = "Fique perto do Gigante e use ALIMENTAR!",
			any = "Fique perto do Gigante e use ALIMENTAR!",
		},
		hintAfter = 6,
		reward = "SpareFood", -- garante comida para o próximo passo
	},
	{
		id = "place",
		objective = "Ponha comida no pátio: rende moedas",
		signal = "Placed",
		requires = { "feed" },
		guide = "none",
		hint = {
			Keyboard = "Abra ITENS (mochila) e clique em COLOCAR",
			Touch = "Toque em ITENS (mochila) e depois COLOCAR",
			any = "Abra ITENS e escolha COLOCAR",
		},
		hintAfter = 8,
		reward = "BoxMoney", -- garante dinheiro exato para a primeira lunchbox
	},
	{
		id = "box",
		objective = "Compre uma Lunchbox na LOJA",
		signal = "BoughtBox",
		requires = { "place" },
		target = { tag = "TutorialShop", beam = true, highlight = false },
		hint = {
			Keyboard = "Siga a trilha até a loja ou clique em LOJA",
			Touch = "Siga a trilha ou toque em LOJA",
			any = "Siga a trilha até a loja ou abra LOJA",
		},
		hintAfter = 10,
		reward = "BonusApple", -- comida extra: o passo seguinte pede 3 alimentações
	},
	{
		-- Teste de 08/11: "chegar ao nível 3" pedia ~18 comidas (181 XP) e estourava os 3 minutos.
		-- 3 alimentações cabem com a comida da caixa + a do pátio.
		id = "grow",
		objective = "Alimente seu Gigante mais 3 vezes",
		signal = "Fed",
		goal = 3,
		requires = { "box" },
		guide = "none",
		hint = { any = "Volte ao seu Gigante e use ALIMENTAR!" },
		hintAfter = 15,
		reward = "FirstGrowth",
	},
}

return steps
