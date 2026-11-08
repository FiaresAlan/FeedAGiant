--!strict
-- Meat.lua — selo na tela para os eventos coletivos de 08/11/2026 (noite):
--   * CARNE GIGANTE (4.5): aviso com contagem, depois "porções restantes · tempo" e uma seta no mundo
--     (Beam do jogador até a carne) para todo mundo correr para o mesmo lugar;
--   * DRAGÃO na ilha: faixa das fases ("FÚRIA!", "CHUVA DE FOGO!") e o resumo da recompensa
--     (participação + bônus pela sua parte do dano + caixa de conclusão).
-- Só mostra o que o servidor manda (MeatState / BossState).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Locale = require(game.ReplicatedStorage.Shared.Locale)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Util = require(game.ReplicatedStorage.Shared.Util)
local UI = require(script.Parent.Parent.UI)

local Meat = {}
local player = Players.LocalPlayer

local chip: Frame
local chipText: TextLabel
local beamPart: Part? = nil
local beam: Beam? = nil
local target: Vector3? = nil
local endsAt = 0
local portions, maxPortions = 0, 0
local warnUntil = 0

local function mmss(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function clearBeam()
	if beamPart then
		beamPart:Destroy()
		beamPart = nil
		beam = nil
	end
end

local function ensureBeam(pos: Vector3)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if not beamPart then
		local p = Instance.new("Part")
		p.Name = "MeatTarget"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.Parent = Workspace
		local a1 = Instance.new("Attachment")
		a1.Parent = p
		local b = Instance.new("Beam")
		b.Color = ColorSequence.new(Color3.fromRGB(255, 170, 110))
		b.Width0 = 0.6
		b.Width1 = 0.6
		b.FaceCamera = true
		b.Transparency = NumberSequence.new(0.35)
		b.LightEmission = 0.6
		b.Attachment1 = a1
		b.Parent = p
		beamPart = p
		beam = b
	end
	local bp = beamPart :: Part
	bp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	local b = beam :: Beam
	-- fwjelaa-ignore: findfirstchild-chain (root já foi conferido acima)
	local a0 = root:FindFirstChild("MeatBeamA0") :: Attachment?
	if not a0 then
		local na = Instance.new("Attachment")
		na.Name = "MeatBeamA0"
		na.Parent = root
		a0 = na
	end
	b.Attachment0 = a0
end

local function show(text: string, color: Color3)
	chipText.Text = text
	chipText.TextColor3 = color
	if not chip.Visible then
		chip.Visible = true
		UI.pop(chip)
	end
end

function Meat.init(gui: ScreenGui)
	chip = UI.frame(gui, {
		Name = "EventChip",
		Size = UDim2.fromOffset(560, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 20,
	})
	UI.autoScale(chip)
	UI.corner(chip, 16)
	UI.stroke(chip, Color3.fromRGB(255, 150, 90), 3)
	chipText = UI.label(chip, "", {
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		TextScaled = false,
		TextSize = 24,
		TextWrapped = true,
		ZIndex = 21,
	})

	Remotes.MeatState.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Warn" then
			warnUntil = os.clock() + (tonumber(e.left) or 20)
			target = if typeof(e.pos) == "Vector3" then e.pos else nil
			UI.sfx("Bell", 0.7)
		elseif e.kind == "Land" or e.kind == "Update" then
			warnUntil = 0
			target = if typeof(e.pos) == "Vector3" then e.pos else target
			portions = tonumber(e.portions) or 0
			maxPortions = tonumber(e.max) or portions
			endsAt = os.clock() + (tonumber(e.left) or 0)
			if e.kind == "Land" then
				UI.sfx("Impact", 0.8)
			end
		elseif e.kind == "End" then
			target = nil
			endsAt = 0
			warnUntil = 0
			chip.Visible = false
			clearBeam()
		end
	end)

	Remotes.BossState.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then
			return
		end
		if e.kind == "Phase" then
			local text = if e.phase == 2
				then Locale.t("O DRAGÃO ENTROU EM FÚRIA!")
				else Locale.t("CHUVA DE FOGO! Fuja dos círculos!")
			show(text, Color3.fromRGB(255, 110, 80))
			UI.sfx("Heavy", 0.9)
			task.delay(3, function()
				if not target then
					chip.Visible = false
				end
			end)
		elseif e.kind == "Rewards" then
			local text = string.format(
				"%s +%s %s",
				if e.won then Locale.t("DRAGÃO DERROTADO!") else Locale.t("O dragão fugiu. Participação:"),
				Util.formatNumber(tonumber(e.coins) or 0),
				Locale.t("moedas")
			)
			if (tonumber(e.bonus) or 0) > 0 then
				text ..= string.format(
					"  +%s (%s %d%%)",
					Util.formatNumber(tonumber(e.bonus) or 0),
					Locale.t("sua parte"),
					math.floor((tonumber(e.share) or 0) * 100 + 0.5)
				)
			end
			if e.box then
				text ..= "  +" .. Locale.t("Lunchbox Épica")
			end
			show(text, Color3.fromRGB(255, 215, 90))
			task.delay(6, function()
				if not target then
					chip.Visible = false
				end
			end)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			if warnUntil > now then
				show(
					string.format("%s %s", Locale.t("CARNE GIGANTE caindo na praça em"), mmss(warnUntil - now)),
					Color3.fromRGB(255, 190, 130)
				)
				if target then
					ensureBeam(target)
				end
			elseif target and endsAt > now then
				show(
					string.format(
						"%s  %d/%d %s  ·  %s  ·  %s",
						Locale.t("CARNE GIGANTE"),
						portions,
						maxPortions,
						Locale.t("porções"),
						mmss(endsAt - now),
						Locale.t("segure E para cortar")
					),
					Color3.fromRGB(255, 190, 130)
				)
				ensureBeam(target :: Vector3)
			elseif target and endsAt > 0 and endsAt <= now then
				-- acabou o tempo e o "End" ainda não chegou: esconde já
				target = nil
				chip.Visible = false
				clearBeam()
			end
		end
	end)
end

return Meat
