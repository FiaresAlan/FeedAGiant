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
Arena.OnOpenGiantBattle = GiantBattle.open
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
Collection.OnNewDiscovery = function(_n: number)
	HUD.markNewDiscovery()
end

print("[FeedAGiant] Cliente pronto.")
