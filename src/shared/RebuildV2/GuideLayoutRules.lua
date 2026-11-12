--!strict
-- Layout puro do cartao de ajuda V3. Evita a HUD superior esquerda (292px)
-- e as escolhas do gigante em telas estreitas. Sem dependencias de Roblox.
local Rules = {}

function Rules.place(width: number, height: number, choosingStarter: boolean, studio: boolean): (string, number, number)
	local w = math.max(280, if width == width then width else 800)
	local h = math.max(280, if height == height then height else 600)
	if w >= 520 then
		-- A HUD da criatura termina em X=306; o cartao comeca apos X=320.
		return "right", math.min(255, math.max(180, w - 340)), 12
	end
	local intended = if choosingStarter then (if studio then 267 else 181) else 126
	-- Em paisagem estreita, nao deixar o cartao completamente fora da tela.
	return "left", math.min(255, w - 28), math.min(intended, h - 100)
end

return Rules
