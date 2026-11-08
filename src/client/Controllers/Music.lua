--!strict
-- Music.lua — trilhas do jogo (as 8 músicas aprovadas pelo usuário em 08/11/2026, assets/audio/music_*).
--
-- Regras (pedido do usuário, item 3):
--   * só UMA trilha contínua por vez: música da ilha (padrão) ou do evento (durante os eventos do
--     servidor, como a Chuva de Comida); troca com transição suave e volta para a ilha no fim;
--   * fanfarras são curtas e ABAIXAM a trilha enquanto tocam, depois restauram;
--   * prioridade: mítico > lendário > (descoberta, evolução, marco, vitória). Uma fanfarra de
--     prioridade menor não interrompe uma maior;
--   * lendário e mítico: anúncio global, uma vez por conquista (o servidor manda um Fireworks por
--     comida tirada; mesmo gatilho dos fogos);
--   * descoberta de criatura, evolução e marco: só para o próprio jogador;
--   * vitória: só DEPOIS da luta (fim da luta de boxe vencida ou da batalha de gigantes vencida).
--   * O código atual NÃO tinha música de combate nem de abertura de caixa (só efeitos): nada foi
--     removido; durante as lutas a trilha da ilha só fica mais baixa.
-- Canais de volume separados: SoundGroups Musica, Efeitos e Vozes (Music.setVolume).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local AudioAssets = require(game.ReplicatedStorage.Shared.AudioAssets)
local Config = require(game.ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)

local Music = {}
local player = Players.LocalPlayer

local BG_VOLUME = 0.32
local DUCK_VOLUME = 0.07
local FADE = 1.2

local groups: { [string]: SoundGroup } = {}
local tracks: { [string]: Sound } = {}
local currentBg: string? = nil
local fanfare: Sound? = nil
local fanfarePriority = 0
local fighting = false

local function group(name: string, volume: number): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g or not g:IsA("SoundGroup") then
		local ng = Instance.new("SoundGroup")
		ng.Name = name
		ng.Volume = volume
		ng.Parent = SoundService
		g = ng
	end
	groups[name] = g :: SoundGroup
	return g :: SoundGroup
end

-- Canal de volume (0..1): "Musica", "Efeitos" ou "Vozes".
function Music.setVolume(channel: string, v: number)
	local g = groups[channel]
	if g then
		g.Volume = math.clamp(v, 0, 1)
	end
end

function Music.group(channel: string): SoundGroup?
	return groups[channel]
end

local function sound(key: string, looped: boolean): Sound?
	local id = (AudioAssets :: { [string]: string })[key]
	if not id then
		return nil
	end
	local s = tracks[key]
	if not s then
		local ns = Instance.new("Sound")
		ns.Name = key
		ns.SoundId = id
		ns.Looped = looped
		ns.Volume = 0
		ns.SoundGroup = groups.Musica
		ns.Parent = SoundService
		tracks[key] = ns
		s = ns
	end
	return s
end

local function bgTarget(): number
	if fanfare and fanfare.IsPlaying then
		return DUCK_VOLUME
	end
	return if fighting then BG_VOLUME * 0.45 else BG_VOLUME
end

local function fadeTo(s: Sound, v: number, t: number?)
	TweenService:Create(s, TweenInfo.new(t or FADE), { Volume = v }):Play()
end

-- Troca a trilha contínua (crossfade). Nunca duas tocando ao mesmo tempo depois da transição.
local function setBackground(key: string)
	if currentBg == key then
		return
	end
	local old = currentBg and tracks[currentBg]
	currentBg = key
	local s = sound(key, true)
	if old then
		local o: Sound = old
		fadeTo(o, 0)
		task.delay(FADE + 0.05, function()
			if currentBg ~= o.Name then
				o:Stop()
			end
		end)
	end
	if s then
		if not s.IsPlaying then
			s.Volume = 0
			s:Play()
		end
		fadeTo(s, bgTarget())
	end
end

local function restoreBackground()
	local s = currentBg and tracks[currentBg]
	if s then
		fadeTo(s, bgTarget(), 0.8)
	end
end

-- Fanfarra curta com prioridade (3 mítico, 2 lendário, 1 o resto).
function Music.fanfare(key: string, priority: number)
	if fanfare and fanfare.IsPlaying and priority < fanfarePriority then
		return -- uma maior está tocando
	end
	if fanfare and fanfare.IsPlaying then
		fanfare:Stop()
	end
	local s = sound(key, false)
	if not s then
		return
	end
	fanfare = s
	fanfarePriority = priority
	s.Volume = 0.8
	s.TimePosition = 0
	s:Play()
	restoreBackground() -- abaixa (bgTarget vê a fanfarra tocando)
	s.Ended:Once(function()
		if fanfare == s then
			fanfare = nil
			fanfarePriority = 0
			restoreBackground()
		end
	end)
end

function Music.setFighting(on: boolean)
	fighting = on
	restoreBackground()
end

function Music.init()
	group("Musica", 1)
	group("Efeitos", 1)
	group("Vozes", 1)
	task.defer(function()
		setBackground("music_main_island")
	end)
	Remotes.EventStarted.OnClientEvent:Connect(function()
		setBackground("music_event_feast")
	end)
	Remotes.EventEnded.OnClientEvent:Connect(function()
		setBackground("music_main_island")
	end)
	-- Lendário / mítico: o mesmo aviso global dos fogos (uma vez por conquista)
	Remotes.Fireworks.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or type(e.rarity) ~= "string" then
			return
		end
		local order = Config.Rarities[e.rarity] and Config.Rarities[e.rarity].order or 0
		if order >= 6 then
			Music.fanfare("music_mythic_fanfare", 3)
		elseif order == 5 then
			Music.fanfare("music_legendary_fanfare", 2)
		end
	end)
	-- Evolução (mudança de estágio do PRÓPRIO gigante)
	Remotes.GiantEvolved.OnClientEvent:Connect(function(e)
		if type(e) == "table" and e.userId == player.UserId then
			Music.fanfare("music_giant_evolution", 1)
		end
	end)
	-- Descoberta de criatura (espécie nova na conta) e marcos de nível (a cada 5, fora dos estágios)
	local knownSpecies: { [string]: boolean }? = nil
	local lastLevel: number? = nil
	State.onChanged(function(s)
		local a = s :: any
		if a.ownedSpecies then
			if knownSpecies then
				for id in a.ownedSpecies do
					if not knownSpecies[id] then
						Music.fanfare("music_creature_discovery", 1)
					end
				end
			end
			knownSpecies = table.clone(a.ownedSpecies)
		end
		if lastLevel and s.level > lastLevel and s.level % 5 == 0 then
			local isStage = false
			for _, st in Config.GiantStages do
				if st.minLevel == s.level then
					isStage = true
				end
			end
			if not isStage then
				Music.fanfare("music_giant_milestone", 1)
			end
		end
		lastLevel = s.level
	end)
end

return Music
