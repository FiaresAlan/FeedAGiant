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

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FeedAGiantGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

State.init()
Notifications.init(gui)
HUD.init(gui)
Shop.init(gui)
Inventory.init(gui)
Hatch.init(gui)
Combat.init(gui)
Drops.init(gui)
Effects.init(gui)
GiantAnim.init()
Arena.init(gui)
Arena.playSound = Combat.sound
Arena.shake = Combat.shake
Effects.playSound = Combat.sound

HUD.OnOpenShop = Shop.open
HUD.OnOpenInventory = Inventory.open
HUD.OnOpenCodes = Shop.openCodes
HUD.OnOpenArena = Arena.open

print("[FeedAGiant] Cliente pronto.")
