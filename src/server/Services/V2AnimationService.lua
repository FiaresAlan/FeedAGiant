--!nonstrict
-- V2: faz o rig importado reproduzir os clipes reais do Animation Editor.
-- Sem malha animavel/AnimationIds corretos, nao existe uma animacao "automaticamente bonita".
local AnimationService = {}
local LOOPED = { Idle = true, Walk = true, Run = true, CarryWalk = true }
local ACTIONS = { Pickup = true, Drop = true, Eat = true, Celebrate = true, Ability = true }

function AnimationService.bind(model: Model, humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator", humanoid) end
	local folder = model:FindFirstChild("Animations")
	local tracks = {}
	local connections = {}
	if not folder or not folder:IsA("Folder") then
		warn("[V2Animation] Missing Animations folder:", model:GetFullName())
	else
		for name in LOOPED do
			local animation = folder:FindFirstChild(name)
			if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
				local ok, result = pcall(function() return animator:LoadAnimation(animation) end)
				if ok then
					tracks[name] = result
					result.Looped = true
					result.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
				else
					warn("[V2Animation] Could not load", name, result)
				end
			else
				warn("[V2Animation] Missing animation clip:", name)
			end
		end
		for name in ACTIONS do
			local animation = folder:FindFirstChild(name)
			if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
				local ok, result = pcall(function() return animator:LoadAnimation(animation) end)
				if ok then
					tracks[name] = result
					result.Looped = false
					result.Priority = Enum.AnimationPriority.Action
				end
			end
		end
	end
	local footsteps = model:FindFirstChild("FootstepSound", true)
	if footsteps and footsteps:IsA("Sound") then
		for _, name in { "Walk", "Run", "CarryWalk" } do
			local t = tracks[name]
			if t then
				table.insert(connections, t:GetMarkerReachedSignal("Footstep"):Connect(function()
					footsteps:Play()
				end))
			end
		end
	end
	local chew = model:FindFirstChild("ChewSound", true)
	if chew and chew:IsA("Sound") and tracks.Eat then
		table.insert(connections, tracks.Eat:GetMarkerReachedSignal("Bite"):Connect(function()
			chew:Play()
		end))
	end
	local controller = { current = nil, tracks = tracks, connections = connections }

	function controller:setLocomotion(name: string, speed: number)
		local track = self.tracks[name]
		if not track and name == "CarryWalk" then
			name = "Walk"
			track = self.tracks.Walk
		end
		if not track then
			name = "Idle"
			track = self.tracks.Idle
		end
		if self.current ~= name then
			local old = self.tracks[self.current]
			if old then old:Stop(0.16) end
			self.current = name
			if track then track:Play(0.16, 1, 1) end
		end
		if track then
			track:AdjustSpeed(if name == "Idle" then 1 else math.clamp(speed / 20, 0.65, 1.8))
		end
	end

	function controller:playAction(name: string)
		local track = self.tracks[name]
		if track then track:Play(0.1, 1, 1) end
	end

	function controller:destroy()
		for _, connection in self.connections do connection:Disconnect() end
		for _, track in self.tracks do track:Stop(0.1); track:Destroy() end
	end

	return controller
end

return AnimationService
