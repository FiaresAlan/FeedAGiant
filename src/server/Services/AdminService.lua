--!strict
-- AdminService — PAINEL DE CONTROLE DO ADMIN (pedido do usuário, 08/11/2026).
--
-- Segurança (vault "Admin Commands Done Safely - Permissions and Audit Logs" e "Gated Tester
-- Commands and Debug Panels"):
--   * papel resolvido NO SERVIDOR por UserId (AdminConfig, só no servidor); erro = sem acesso;
--   * cada comando exige uma capacidade; o cliente só manda o pedido, o servidor confere tudo;
--   * argumentos validados (tipo, faixa, alvo existente); admins não agem contra outros admins;
--   * economia com teto por chamada e por dia; BANIR em 2 passos (pede, confirma em até 30 s);
--   * TODA tentativa vai para o registro (memória + DataStore FAG_AdminLog_v1, últimas 200).
-- O atributo AdminRole no jogador só serve para o cliente desenhar o botão (não dá poder nenhum).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local AdminConfig = require(script.Parent.Parent.AdminConfig)
local DataService = require(script.Parent.DataService)
local GiantService = require(script.Parent.GiantService)
local PlotService = require(script.Parent.PlotService)
local EventService = require(script.Parent.EventService)
local MeatService = require(script.Parent.MeatService)
local BossService = require(script.Parent.BossService)
local Guard = require(script.Parent.Parent.Guard)

local AdminService = {}

export type Role = "Owner" | "Developer" | "Player"
local CAPS: { [Role]: { [string]: boolean } } = {
	Owner = { all = true },
	Developer = { events = true, bots = true, announce = true, kick = true, view = true },
	Player = {},
}

local roles: { [Player]: Role } = {}
local coinsToday: { [number]: { day: number, n: number } } = {}
local pendingBans: { [Player]: { token: string, target: number, minutes: number, reason: string, at: number } } = {}
local logRing: { { [string]: any } } = {}
local logStore: any = nil

-- Bots (BotService preenche; o painel só chama).
AdminService.Bots = nil :: { setCount: (number) -> number, count: () -> number, list: () -> { any } }?

local function resolveRole(p: Player): Role
	local role: Role = "Player"
	local isCreator = game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and p.UserId == game.CreatorId
	if AdminConfig.Owners[p.UserId] or isCreator then
		role = "Owner"
	elseif AdminConfig.Developers[p.UserId] then
		role = "Developer"
	end
	return role
end

local function can(p: Player, cap: string): boolean
	local role: Role = roles[p] or "Player"
	local caps = CAPS[role]
	return caps.all == true or caps[cap] == true
end

local function audit(admin: Player, cmd: string, args: any, ok: boolean, msg: string)
	local entry = {
		t = os.time(),
		by = admin.UserId,
		name = admin.Name,
		cmd = cmd,
		args = HttpService:JSONEncode(args or {}),
		ok = ok,
		msg = msg,
	}
	table.insert(logRing, entry)
	while #logRing > 100 do
		table.remove(logRing, 1)
	end
	if logStore then
		task.spawn(function()
			pcall(function()
				logStore:UpdateAsync("log", function(old: any): any
					local list = if type(old) == "table" then old else {}
					table.insert(list, entry)
					while #list > 200 do
						table.remove(list, 1)
					end
					return list
				end)
			end)
		end)
	end
end

local function targetOf(userId: any): Player?
	if type(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function protectedTarget(admin: Player, target: Player): boolean
	-- admins não agem contra admins (nem contra si mesmos em comandos de punição)
	return target ~= admin and (roles[target] or "Player") ~= "Player"
end

local function snapshot(): { [string]: any }
	local players = {}
	for _, p in Players:GetPlayers() do
		local prof = DataService.get(p)
		table.insert(players, {
			userId = p.UserId,
			name = p.Name,
			display = p.DisplayName,
			role = roles[p] or "Player",
			level = if prof then prof.level else 0,
			coins = if prof then prof.coins else 0,
			species = if prof then prof.species else "?",
		})
	end
	local bots = AdminService.Bots
	return {
		players = players,
		bots = if bots then bots.list() else {},
		botCount = if bots then bots.count() else 0,
		log = logRing,
		events = { "GoldenHour", "FoodRain", "LuckyBoxes" },
		serverUptime = math.floor(workspace.DistributedGameTime),
	}
end

local function reply(admin: Player, ok: boolean, msg: string)
	Remotes.AdminState:FireClient(admin, { kind = "Result", ok = ok, msg = msg, state = snapshot() })
end

type Handler = (admin: Player, args: { [string]: any }) -> (boolean, string)
type Command = { cap: string, run: Handler }

local function econAllowed(admin: Player, amount: number): boolean
	local day = os.time() // 86400
	local rec = coinsToday[admin.UserId]
	if not rec or rec.day ~= day then
		local fresh = { day = day, n = 0 }
		coinsToday[admin.UserId] = fresh
		rec = fresh
	end
	assert(rec, "registro")
	if rec.n + amount > AdminConfig.MaxCoinsPerDay then
		return false
	end
	rec.n += amount
	return true
end

local COMMANDS: { [string]: Command } = {
	state = {
		cap = "view",
		run = function()
			return true, "ok"
		end,
	},
	coins = {
		cap = "economy",
		run = function(admin, a)
			local target = targetOf(a.target)
			local n = a.amount
			if not target or type(n) ~= "number" or n ~= n or n < 1 or n > AdminConfig.MaxCoinsPerCall then
				return false, "Alvo ou quantidade inválida (1 a " .. AdminConfig.MaxCoinsPerCall .. ")."
			end
			n = math.floor(n)
			if not econAllowed(admin, n) then
				return false, "Teto diário de moedas do admin atingido."
			end
			local prof = DataService.get(target)
			if not prof then
				return false, "Perfil não carregado."
			end
			prof.coins += n
			DataService.markDirty(target)
			PlotService.pushState(target)
			return true, string.format("+%d moedas para %s.", n, target.Name)
		end,
	},
	level = {
		cap = "economy",
		run = function(_admin, a)
			local target = targetOf(a.target)
			local lv = a.level
			if not target or type(lv) ~= "number" or lv ~= lv or lv < 1 or lv > Config.Giant.MaxLevel then
				return false, "Nível inválido (1 a " .. Config.Giant.MaxLevel .. ")."
			end
			local prof = DataService.get(target)
			if not prof then
				return false, "Perfil não carregado."
			end
			prof.level = math.floor(lv)
			prof.xp = 0
			prof.peakLevel = math.max(prof.peakLevel, prof.level)
			DataService.markDirty(target)
			GiantService.refresh(target, true)
			PlotService.pushState(target)
			return true, string.format("%s agora está no nível %d.", target.Name, prof.level)
		end,
	},
	food = {
		cap = "economy",
		run = function(_admin, a)
			local target = targetOf(a.target)
			local id = a.foodId
			local count = a.count
			if
				not target
				or type(id) ~= "string"
				or not Config.FoodById[id]
				or type(count) ~= "number"
				or count < 1
				or count > AdminConfig.MaxFoodPerCall
			then
				return false, "Comida ou quantidade inválida (1 a " .. AdminConfig.MaxFoodPerCall .. ")."
			end
			local given = 0
			for _ = 1, math.floor(count) do
				if PlotService.giveFood(target, id, true) then
					given += 1
				end
			end
			return true, string.format("%d x %s para %s.", given, Config.FoodById[id].name, target.Name)
		end,
	},
	species = {
		cap = "economy",
		run = function(_admin, a)
			local target = targetOf(a.target)
			if not target or type(a.species) ~= "string" or not Config.SpeciesById[a.species] then
				return false, "Espécie inválida."
			end
			GiantService.grantSpecies(target, a.species)
			PlotService.pushState(target)
			return true, string.format("%s ganhou %s.", target.Name, Config.SpeciesById[a.species].name)
		end,
	},
	kick = {
		cap = "kick",
		run = function(admin, a)
			local target = targetOf(a.target)
			if not target then
				return false, "Jogador não está no servidor."
			end
			if target == admin or protectedTarget(admin, target) then
				return false, "Não é possível expulsar um admin."
			end
			local reason = if type(a.reason) == "string" then string.sub(a.reason, 1, 80) else ""
			target:Kick("Você foi removido por um administrador. " .. reason)
			return true, target.Name .. " foi expulso."
		end,
	},
	ban = {
		cap = "ban",
		run = function(admin, a)
			-- 2 passos: sem token → pede confirmação; com o token certo em até 30 s → bane.
			local token = a.token
			local pend = pendingBans[admin]
			if type(token) == "string" and pend and pend.token == token and os.clock() - pend.at <= 30 then
				pendingBans[admin] = nil
				local okBan, err = pcall(function()
					Players:BanAsync({
						UserIds = { pend.target },
						Duration = pend.minutes * 60,
						DisplayReason = "Banido por um administrador. " .. pend.reason,
						PrivateReason = "Painel de admin, por " .. admin.UserId,
						ExcludeAltAccounts = true, -- banimento temporário: só a conta (vault, Logging Bans and Appeals)
						ApplyToUniverse = true,
					})
				end)
				if not okBan then
					return false, "BanAsync falhou: " .. tostring(err)
				end
				local still = Players:GetPlayerByUserId(pend.target)
				if still then
					still:Kick("Banido por um administrador. " .. pend.reason)
				end
				return true, string.format("Usuário %d banido por %d min.", pend.target, pend.minutes)
			end
			local target = targetOf(a.target)
			local minutes = a.minutes
			if not target or type(minutes) ~= "number" or minutes < 1 or minutes > 60 * 24 * 365 then
				return false, "Alvo ou duração inválida."
			end
			if target == admin or protectedTarget(admin, target) then
				return false, "Não é possível banir um admin."
			end
			local t = HttpService:GenerateGUID(false)
			pendingBans[admin] = {
				token = t,
				target = target.UserId,
				minutes = math.floor(minutes),
				reason = if type(a.reason) == "string" then string.sub(a.reason, 1, 80) else "",
				at = os.clock(),
			}
			Remotes.AdminState:FireClient(admin, {
				kind = "Confirm",
				token = t,
				text = string.format("Banir %s por %d min? Confirme em 30 s.", target.Name, math.floor(minutes)),
			})
			return true, "Aguardando confirmação."
		end,
	},
	event = {
		cap = "events",
		run = function(_admin, a)
			local id = a.id
			local valid = false
			for _, d in Config.Events.List do
				if d.id == id then
					valid = true
				end
			end
			if not valid then
				return false, "Evento inválido."
			end
			task.spawn(EventService.start, id)
			return true, "Evento " .. tostring(id) .. " iniciado (se nenhum outro estiver rodando)."
		end,
	},
	meat = {
		cap = "events",
		run = function()
			if MeatService.isActive() then
				return false, "Já tem Carne Gigante no mapa."
			end
			MeatService.nextAt = os.time()
			return true, "Carne Gigante vai cair (aviso de 20 s)."
		end,
	},
	boss = {
		cap = "events",
		run = function()
			if BossService.isActive() then
				return false, "O Dragão já está na ilha."
			end
			BossService.nextAt = os.time()
			return true, "O Dragão Faminto está chegando na ilha."
		end,
	},
	announce = {
		cap = "announce",
		run = function(admin, a)
			local text = a.text
			if type(text) ~= "string" or #text < 1 or #text > 120 then
				return false, "Texto de 1 a 120 caracteres."
			end
			-- Texto digitado por pessoa → filtro da Roblox antes de mostrar para todos.
			local okF, filtered = pcall(function()
				local result = TextService:FilterStringAsync(text, admin.UserId)
				return result:GetNonChatStringForBroadcastAsync()
			end)
			if not okF or type(filtered) ~= "string" then
				return false, "O filtro de texto falhou; nada foi enviado."
			end
			Remotes.Notify:FireAllClients({ text = "📢 " .. filtered, color = Color3.fromRGB(255, 220, 90) })
			return true, "Aviso enviado."
		end,
	},
	bots = {
		cap = "bots",
		run = function(_admin, a)
			local bots = AdminService.Bots
			local n = a.count
			if not bots then
				return false, "Bots indisponíveis."
			end
			if type(n) ~= "number" or n ~= n or n < 0 or n > 7 then
				return false, "Quantidade de 0 a 7."
			end
			local now = bots.setCount(math.floor(n))
			return true, string.format("Bots no servidor: %d.", now)
		end,
	},
}

function AdminService.roleOf(p: Player): Role
	return roles[p] or "Player"
end

function AdminService.init()
	local okStore, ds = pcall(function()
		return DataStoreService:GetDataStore("FAG_AdminLog_v1")
	end)
	if okStore and not RunService:IsStudio() then
		logStore = ds
	end
	local function onJoin(p: Player)
		local role = resolveRole(p)
		roles[p] = role :: any
		if role ~= "Player" then
			p:SetAttribute("AdminRole", role) -- só para o cliente desenhar o botão
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		roles[p] = nil
		pendingBans[p] = nil
	end)
	Remotes.AdminCommand.OnServerEvent:Connect(function(admin, cmd, args)
		if type(cmd) ~= "string" or #cmd > 20 then
			return
		end
		if args ~= nil and type(args) ~= "table" then
			return
		end
		if not Guard.allow(admin, "Admin") then
			return
		end
		local command = COMMANDS[cmd]
		if not command then
			return
		end
		if (roles[admin] or "Player") == "Player" or not can(admin, command.cap) then
			-- sem permissão: registra a tentativa e não responde nada útil
			audit(admin, cmd, args, false, "sem permissão")
			return
		end
		local okRun, ok, msg = pcall(command.run, admin, (args or {}) :: { [string]: any })
		if not okRun then
			audit(admin, cmd, args, false, "erro: " .. tostring(ok))
			reply(admin, false, "Erro no comando.")
			return
		end
		audit(admin, cmd, args, ok, msg)
		reply(admin, ok, msg)
	end)
end

return AdminService
