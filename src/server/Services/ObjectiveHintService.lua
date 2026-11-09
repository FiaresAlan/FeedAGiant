--!strict
-- ObjectiveHintService (especificação v3 §6.6, adaptado ao jogo real; Features.ObjectiveHints).
-- Escolhe UMA dica de "próximo objetivo" por jogador, por prioridade, e manda para o cartão de
-- META da HUD (não cria outro cartão: no celular não sobra espaço). Regras:
--   * nada durante o tutorial (ele já mostra o objetivo no mesmo cartão);
--   * prioridade: o que dá para fazer AGORA > evento iminente > meta curta > meta longa;
--   * reavalia a cada 15 s, mas só reenvia quando a dica muda (ou a cada 60 s, para o cronômetro);
--   * métrica "objective_acted_on" no servidor: a dica sumiu porque o jogador fez a coisa
--     (a condição deixou de valer em até 90 s depois de mostrada).
-- Vault: "Onboarding and FTUE - Tutorials That Keep Players" (uma meta, 8 palavras), "Retention and
-- Return Hooks" (no máximo um aviso automático por vez), "Analytics and Funnels".
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Features = require(game.ReplicatedStorage.Shared.Features)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Parent.Analytics)
local Guard = require(script.Parent.Parent.Guard)
local DataService = require(script.Parent.DataService)
local DropService = require(script.Parent.DropService)
local BossService = require(script.Parent.BossService)
local MeatService = require(script.Parent.MeatService)
local ProgressService = require(script.Parent.ProgressService)

local ObjectiveHintService = {}

local TICK = 15
local RESEND = 60
local ACTED_WINDOW = 90
local NEAR_DROP = 45 -- studs
local IMMINENT = 180 -- segundos

export type Hint = { id: string, text: string, category: string }

type Shown = { id: string, at: number, sentAt: number, text: string }
local shown: { [Player]: Shown } = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function tutorialActive(profile: any): boolean
	local t = profile.tutorial
	return type(t) == "table" and not (t.finished or t.skipped)
end

-- Cada provedor devolve uma dica ou nil. A ordem da lista É a prioridade.
local providers: { (Player, any, number) -> Hint? } = {
	-- 1) agora: caixa guardada esperando abrir
	function(_player, profile)
		local n = #(profile.pendingBoxes or {})
		if n > 0 then
			return { id = "pending_box", text = "Abra sua Lunchbox guardada na base!", category = "now" }
		end
		return nil
	end,
	-- 1) agora: prêmio do Diário pronto (diário ou tarefa concluída)
	function(player)
		local st = ProgressService.state(player)
		if not st then
			return nil
		end
		if st.daily and st.daily.ready then
			return { id = "daily_ready", text = "Prêmio diário pronto: abra o DIÁRIO!", category = "now" }
		end
		for _, o in st.objectives or {} do
			if not o.claimed and (o.progress or 0) >= (o.goal or math.huge) then
				return { id = "task_done", text = "Tarefa concluída: resgate no DIÁRIO!", category = "now" }
			end
		end
		return nil
	end,
	-- 1) agora: comida no chão perto
	function(player)
		local root = Guard.rootOf(player)
		if not root then
			return nil
		end
		for _, it in DropService.freeItems() do
			if it.kind == "food" and (it.pos - root.Position).Magnitude <= NEAR_DROP then
				return { id = "drop_near", text = "Comida no chão perto: pegue e leve à base!", category = "now" }
			end
		end
		return nil
	end,
	-- 2) iminente: Dragão ou Carne Gigante
	function(_player, _profile, now)
		if BossService.isActive() then
			return { id = "boss_live", text = "O Dragão Faminto apareceu na ilha!", category = "soon" }
		end
		local left = BossService.nextAt - now
		if BossService.nextAt > 0 and left > 0 and left <= IMMINENT then
			return { id = "boss_soon", text = "Dragão Faminto em " .. clock(left), category = "soon" }
		end
		return nil
	end,
	function(_player, _profile, now)
		if MeatService.isActive() then
			return { id = "meat_live", text = "Carne Gigante no mapa: corte uma porção!", category = "soon" }
		end
		local left = MeatService.nextAt - now
		if MeatService.nextAt > 0 and left > 0 and left <= 60 then
			return { id = "meat_soon", text = "Carne Gigante em " .. clock(left), category = "soon" }
		end
		return nil
	end,
	-- 1) agora / 3) curta: ovos no ninho (Sistema de Ovos)
	function(_player, profile, now)
		if not Features.on("EggSystem") then
			return nil
		end
		local soonest: number? = nil
		for _, slot in profile.nest or {} do
			if now >= slot.hatchAt then
				return { id = "egg_ready", text = "Seu ovo está pronto: vá ao NINHO!", category = "now" }
			end
			soonest = math.min(soonest or math.huge, slot.hatchAt - now)
		end
		if soonest and soonest <= 3600 then
			return {
				id = "egg_soon",
				text = string.format("Seu ovo choca em %d min", math.max(1, math.ceil(soonest / 60))),
				category = "short",
			}
		end
		return nil
	end,
	-- 3) curta: gigante com fome
	function(_player, profile)
		if (profile.hunger or 100) < 30 then
			return { id = "hungry", text = "Seu Gigante está com fome: alimente!", category = "short" }
		end
		return nil
	end,
	-- 4) longa: espécies que faltam na coleção (compráveis com moedas)
	function(_player, profile)
		local missing = 0
		for _, sp in Config.Species do
			if not sp.robux and not profile.ownedSpecies[sp.id] then
				missing += 1
			end
		end
		if missing > 0 then
			return {
				id = "collection",
				text = string.format("Faltam %d gigantes na sua coleção", missing),
				category = "long",
			}
		end
		return nil
	end,
}

-- Função pura de escolha (a primeira que valer). Exposta para o teste no Studio.
function ObjectiveHintService.pick(player: Player, profile: any, now: number): Hint?
	for _, provider in providers do
		local ok, hint = pcall(provider, player, profile, now)
		if ok and hint then
			return hint
		elseif not ok then
			warn("[ObjectiveHint]", hint)
		end
	end
	return nil
end

local function stillValid(player: Player, profile: any, now: number, id: string): boolean
	for _, provider in providers do
		local ok, hint = pcall(provider, player, profile, now)
		if ok and hint and hint.id == id then
			return true
		end
	end
	return false
end

function ObjectiveHintService.update(player: Player)
	if not Features.on("ObjectiveHints") then
		return
	end
	local profile = DataService.get(player)
	if not profile or tutorialActive(profile) then
		return
	end
	local now = os.time()
	local prev = shown[player]
	local hint = ObjectiveHintService.pick(player, profile, now)
	-- A dica anterior sumiu porque o jogador agiu?
	if prev and (not hint or hint.id ~= prev.id) then
		if now - prev.at <= ACTED_WINDOW and not stillValid(player, profile, now, prev.id) then
			Analytics.event(player, "objective_acted_on", now - prev.at, { prev.id })
		end
	end
	if not hint then
		if prev then
			shown[player] = nil
			Remotes.ObjectiveHint:FireClient(player, { text = "", category = "none", id = "" })
		end
		return
	end
	if not prev or prev.id ~= hint.id then
		Remotes.ObjectiveHint:FireClient(player, hint)
		Analytics.event(player, "objective_shown", 1, { hint.id, hint.category })
		shown[player] = { id = hint.id, at = now, sentAt = now, text = hint.text }
	elseif now - prev.sentAt >= RESEND or (prev.text ~= hint.text and hint.category == "soon") then
		-- mesma dica: só reenvia para manter o cronômetro certo (ou lembrar a cada minuto)
		Remotes.ObjectiveHint:FireClient(player, hint)
		prev.sentAt = now
		prev.text = hint.text
	end
end

function ObjectiveHintService.init()
	Players.PlayerRemoving:Connect(function(p)
		shown[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			if Features.on("ObjectiveHints") then
				for _, p in Players:GetPlayers() do
					task.spawn(ObjectiveHintService.update, p)
				end
			end
		end
	end)
end

return ObjectiveHintService
