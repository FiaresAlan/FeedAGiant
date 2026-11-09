--!strict
-- Util.lua — funções utilitárias compartilhadas.
local Util = {}

function Util.formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

function Util.weightedPick(weights: { [string]: number }, bonus: number?): string
	local mult = bonus or 0
	local total = 0
	local adjusted: { [string]: number } = {}
	for key, w in weights do
		local adj = w
		if key ~= "Common" and key ~= "Uncommon" then
			adj = w * (1 + mult)
		end
		adjusted[key] = adj
		total += adj
	end
	local roll = math.random() * total
	local acc = 0
	local last = "Common"
	for key, w in adjusted do
		acc += w
		last = key
		if roll <= acc then
			return key
		end
	end
	return last
end

local scaleTargets: { [Model]: { scale: number } } = {}

function Util.cancelScaleTween(model: Model)
	scaleTargets[model] = nil
end

function Util.tweenScale(model: Model, targetScale: number, duration: number)
	local current = scaleTargets[model]
	if current and current.scale == targetScale then
		return
	end
	local target = { scale = targetScale }
	scaleTargets[model] = target
	local TweenService = game:GetService("TweenService")
	local start = model:GetScale()
	local t0 = os.clock()
	task.spawn(function()
		while model.Parent and scaleTargets[model] == target do
			local alpha = math.clamp((os.clock() - t0) / duration, 0, 1)
			local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local s = start + (targetScale - start) * eased
			if s > 0 then
				model:ScaleTo(s)
			end
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		if scaleTargets[model] == target then
			scaleTargets[model] = nil
		end
	end)
end

function Util.makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

function Util.makeBillboard(parent: BasePart, text: string, size: UDim2, offset: Vector3, color: Color3?): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = offset
	bb.AlwaysOnTop = false
	bb.MaxDistance = 400
	bb.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text -- servidor: texto fonte PT; LocalizationTable (ReplicatedStorage.Localization) traduz no cliente
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = bb
	return label
end

return Util
