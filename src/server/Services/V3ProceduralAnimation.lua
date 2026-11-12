--!nonstrict
-- Animacao procedural de laboratorio para o Golem montavel original do Studio.
-- Motor6D.C0 mantem os bracos/pernas articulados, sem alterar a escala do mesh.
-- Trocar por clips reais antes de considerar a arte aprovada.
local RunService = game:GetService("RunService")

local Procedural = {}
local ACTION_SECONDS = { Pickup = 0.7, Drop = 0.55, Eat = 2.0, Celebrate = 1.7, Ability = 0.8 }

function Procedural.bind(model: Model)
	local joints = {}
	local bases = {}
	local names = {
		"RootJoint", "Neck", "JawHinge",
		"LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
		"LeftHip", "RightHip", "LeftKnee", "RightKnee",
	}
	for _, name in names do
		local j = model:FindFirstChild(name, true)
		if j and j:IsA("Motor6D") then
			joints[name] = j
			bases[name] = j.C0
		else
			warn("[V3GolemPrototype] Junta de animacao ausente:", name)
		end
	end

	local state = {
		current = "Idle",
		speed = 0,
		phase = 0,
		elapsed = 0,
		action = nil,
		actionAt = 0,
		connection = nil,
	}
	local function pose(name, x, y, z, shift)
		local j = joints[name]
		if j then
			j.C0 = bases[name] * (shift or CFrame.new()) * CFrame.Angles(x or 0, y or 0, z or 0)
		end
	end

	function state:setLocomotion(name: string, speed: number)
		self.current = if name == "Run" or name == "Walk" or name == "CarryWalk" then name else "Idle"
		self.speed = math.clamp(tonumber(speed) or 0, 0, 32)
	end

	function state:playAction(name: string)
		if ACTION_SECONDS[name] then
			self.action = name
			self.actionAt = os.clock()
		end
	end

	state.connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then return end
		state.elapsed += dt
		local tickRate = 1 / 15 -- limitacao explicita de atualizacoes C0 (somente Studio)
		if state.elapsed < tickRate then return end
		local elapsed = state.elapsed
		state.elapsed = 0

		local moving = state.current ~= "Idle" and state.speed > 0.6
		local carry = state.current == "CarryWalk"
		local stride = if moving then (if state.current == "Run" then 0.66 else 0.39) else 0
		if carry then stride *= 0.72 end
		state.phase += elapsed * (if moving then math.clamp(state.speed * 0.39, 4, 11) else 1.0)
		local wave = math.sin(state.phase)
		local opposite = -wave
		local bob = math.sin(state.phase * 2) * stride * 0.11
		local idle = math.sin(state.phase * 0.55) * 0.018
		local armSwing = stride * 0.72

		local actionProgress = 0
		if state.action then
			local actionDuration = ACTION_SECONDS[state.action]
			actionProgress = math.min(1, (os.clock() - state.actionAt) / actionDuration)
			if actionProgress >= 1 then
				state.action = nil
				actionProgress = 0
			end
		end

		local bite = if state.action == "Eat" then math.abs(math.sin(actionProgress * math.pi * 5)) else 0
		local reach = if state.action == "Pickup" or state.action == "Eat"
			then math.sin(math.pi * actionProgress) else 0
		local celebrate = if state.action == "Celebrate" then math.sin(math.pi * actionProgress) else 0
		local ability = if state.action == "Ability" then math.sin(math.pi * actionProgress) else 0
		local release = if state.action == "Drop" then math.sin(math.pi * actionProgress) else 0

		pose("RootJoint", if moving then -0.025 else idle, 0, wave * stride * 0.035,
			CFrame.new(0, bob, 0))
		pose("Neck", -0.05 + bite * 0.16, math.sin(state.phase * 0.24) * 0.045, 0)
		pose("JawHinge", bite * 0.33, 0, 0)
		pose("LeftHip", wave * stride, 0, 0)
		pose("RightHip", opposite * stride, 0, 0)
		pose("LeftKnee", math.max(0, -wave) * stride * 0.86, 0, 0)
		pose("RightKnee", math.max(0, wave) * stride * 0.86, 0, 0)
		pose("LeftShoulder", -wave * armSwing - celebrate * 0.85, 0, -celebrate * 0.5)
		pose("RightShoulder", wave * armSwing - reach * 0.85 - celebrate * 0.85 - ability * 0.6,
			0, celebrate * 0.5)
		pose("LeftElbow", -0.06 - (if carry then 0.38 else 0) - celebrate * 0.7, 0, 0)
		pose("RightElbow", -0.06 - (if carry then 0.48 else 0) - reach * 0.9
			- ability * 0.7 + release * 0.25, 0, 0)
	end)

	function state:destroy()
		if self.connection then
			self.connection:Disconnect()
			self.connection = nil
		end
		for name, j in joints do
			if j.Parent then j.C0 = bases[name] end
		end
	end

	return state
end

return Procedural
