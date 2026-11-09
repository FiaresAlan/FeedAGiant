--!strict
-- Main.client.lua — ponto de entrada do cliente. Cria o ScreenGui e inicializa controladores.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local State = require(script.Parent.State)
local Controllers = script.Parent.Controllers
local HUD = require(Controllers.HUD)
local Shop = require(Controllers.Shop)
local Inventory = require(Controllers.Inventory)
local Hatch = require(Controllers.Hatch)
local Notifications = require(Controllers.Notifications)
local Combat = require(Controllers.Combat)
local Drops = require(Controllers.Drops)
local Arena = require(Controllers.Arena)
local Effects = require(Controllers.Effects)
local GiantAnim = require(Controllers.GiantAnim)
local FeedFx = require(Controllers.FeedFx)
local Tutorial = require(Controllers.Tutorial)
local Collection = require(Controllers.Collection)
local GiantBattle = require(Controllers.GiantBattle)
local Music = require(Controllers.Music)
local Diary = require(Controllers.Diary)
local Meat = require(Controllers.Meat)
local Admin = require(Controllers.Admin)
local V3 = require(Controllers.V3)
local Eggs = require(Controllers.Eggs)
local Travel = require(Controllers.Travel)
local Dragon = require(Controllers.Dragon)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FeedAGiantGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- Fase 3 (HUD): conteúdo interativo dentro da área segura (entalhe, barra do Roblox);
-- a HUD lê GuiService.TopbarInset para começar abaixo da barra (skill fwjelaa-ui-builder).
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

State.init()
Music.init()
Notifications.init(gui)
HUD.init(gui)
Shop.init(gui)
Inventory.init(gui)
Collection.init(gui)
Hatch.init(gui)
Combat.init(gui)
Drops.init(gui)
Effects.init(gui)
GiantAnim.init()
FeedFx.init()
Tutorial.init()
Arena.init(gui)
GiantBattle.init(gui)
Diary.init(gui)
Meat.init(gui)
Admin.init(gui)
V3.init(gui)
Eggs.init(gui)
Travel.init(gui) -- 09/11: menu dos blips de viagem rápida
Dragon.init(gui) -- 09/11: animação do Dragão + convite com o botão JOGAR
Arena.OnOpenGiantBattle = GiantBattle.open
-- ARENA única (09/11, item 7): a lista da batalha de gigantes vira a 2ª aba da janela da arena.
GiantBattle.embed(Arena.giantContainer())
GiantBattle.OpenHost = function()
	Arena.open("giant")
end
GiantBattle.OnLaunch = Arena.close
Arena.OnShowGiantTab = GiantBattle.refresh
-- Música: trilha mais baixa durante as lutas; fanfarra de vitória só no fim (item 3, regra 9)
Arena.OnFight = function(started: boolean, won: boolean?)
	Music.setFighting(started)
	if not started and won then
		Music.fanfare("music_arena_victory", 1)
	end
end
GiantBattle.OnFight = function(started: boolean)
	Music.setFighting(started)
	HUD.setBattleMode(started)
end
GiantBattle.OnVictory = function()
	Music.fanfare("music_arena_victory", 1)
end
Arena.playSound = Combat.sound
Arena.shake = Combat.shake
Effects.playSound = Combat.sound
Effects.toast = Notifications.toast

HUD.OnOpenShop = Shop.open
HUD.OnOpenRobux = Shop.openRobux
HUD.OnOpenInventory = Inventory.open
HUD.OnOpenCodes = Shop.openCodes
HUD.OnOpenArena = Arena.open
HUD.OnOpenCollection = Collection.open
HUD.OnOpenDiary = Diary.open
V3.OnOpenDiary = Diary.open -- botão DIÁRIO do "Bem-vindo de volta"
Diary.OnClaimable = HUD.setDiaryClaimable
Collection.OnNewDiscovery = function(_n: number)
	HUD.markNewDiscovery()
end

print("[FeedAGiant] Cliente pronto.")
