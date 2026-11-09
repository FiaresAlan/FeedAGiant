--!strict
-- EggNotificationService — ESTRUTURA da notificação "ovo pronto" (prompt v4 §2.3). NÃO chama a API.
--
-- Bloqueada até o jogo ser publicado com 100+ visitas (requisito da Roblox). O que já está pronto:
--   * planJob: decide SE e QUANDO avisar (1 por ovo, só para o ovo que choca primeiro, só offline);
--   * a ligação no PlayerRemoving (com Features.EggNotifications desligada não faz nada).
-- O que falta depois de publicar (docs/PENDENCIAS_POS_PUBLICACAO.md):
--   1. criar a mensagem no Creator Dashboard (Engagement > Notifications) e pôr o id em MESSAGE_ID;
--   2. instalar o pacote Open Cloud da Creator Store e chamar createUserNotification em `send`;
--   3. fila no MemoryStore (uma chave por usuário, ordenada pela hora, "reivindicar antes de enviar",
--      não enviar se o jogador estiver online) — vault "Experience Notifications and Return Prompts" §5.
-- A Roblox só entrega para quem tem 13+ e ativou notificações; isso é filtrado por ela, não por nós.
local Features = require(game.ReplicatedStorage.Shared.Features)
local GameRules = require(game.ReplicatedStorage.Shared.GameRules)
local DataService = require(script.Parent.DataService)

local EggNotificationService = {}

EggNotificationService.MESSAGE_ID = "" -- TODO pós-publicação: id da mensagem criada no Creator Dashboard

export type Job = { userId: number, dueAt: number, size: string, sizeName: string }

-- Pura: o aviso do ovo que choca primeiro (no futuro). nil = nada a avisar.
-- `sentForHatchAt` evita mandar duas vezes para o mesmo ovo.
function EggNotificationService.planJob(
	userId: number,
	nest: { [string]: { size: string, hatchAt: number } },
	now: number,
	sentForHatchAt: number?
): Job?
	local best: { size: string, hatchAt: number }? = nil
	for _, slot in nest do
		if slot.hatchAt > now and (best == nil or slot.hatchAt < best.hatchAt) then
			best = slot
		end
	end
	if not best or best.hatchAt == sentForHatchAt then
		return nil
	end
	local def = GameRules.Eggs.Sizes[best.size]
	return {
		userId = userId,
		dueAt = best.hatchAt,
		size = best.size,
		sizeName = if def then def.name else best.size,
	}
end

-- Pós-publicação: enfileirar no MemoryStore e enviar pela Open Cloud. Hoje: não faz nada.
function EggNotificationService.send(_job: Job): boolean
	return false
end

function EggNotificationService.init()
	-- onReleasing recebe o perfil ANTES do save final (no PlayerRemoving ele já pode ter sido liberado).
	DataService.onReleasing(function(player: Player, profile: DataService.Profile)
		if not Features.on("EggNotifications") or EggNotificationService.MESSAGE_ID == "" then
			return
		end
		local sent = profile.eggNotifyHatchAt
		local job = EggNotificationService.planJob(player.UserId, profile.nest :: any, os.time(), sent)
		if job then
			-- marca no perfil (salvo agora) para nunca avisar 2 vezes o mesmo ovo
			profile.eggNotifyHatchAt = job.dueAt
			task.spawn(EggNotificationService.send, job)
		end
	end)
end

return EggNotificationService
