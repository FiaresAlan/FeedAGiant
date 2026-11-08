--!strict
-- GiantAnim — animação procedural dos gigantes no CLIENTE (Fase 2, item 2).
-- Os modelos 3D (dragão, fênix, golem...) não têm esqueleto; em vez de rig, o cliente move a
-- malha (ou o corpo de blocos) localmente: nada é replicado, custo de rede zero.
--   * respiração/balanço quando parado;
--   * MORDIDA ao ser alimentado (inclina para a frente e dá um pulinho);
--   * COMEMORAÇÃO ao subir de nível (pulo maior com um giro).
-- Desempenho (celular primeiro): só gigantes a até MAX_DIST studs, a 30 Hz.
-- Se o servidor reposiciona/escala o gigante, a pose de repouso é recapturada.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local GiantAnim = {}

local MAX_DIST = 300
local STEP = 1 / 30

type Track = {
	target: PVInstance, -- CreatureMesh (Model) ou o gigante inteiro (blocos)
	rest: CFrame, -- pose do servidor (sem animação)
	applied: CFrame?, -- último CFrame que ESTE script aplicou
	height: number,
	phase: number,
	action: string?, -- "chomp" | "cheer"
	actionT: number,
}

local tracks: { [Model]: Track } = {}

local function targetOf(giant: Model): PVInstance
	local mesh = giant:FindFirstChild("CreatureMesh")
	if mesh and mesh:IsA("Model") then
		return mesh
	end
	return giant
end

local function heightOf(target: PVInstance): number
	if target:IsA("Model") then
		local _, size = target:GetBoundingBox()
		return size.Y
	end
	return 4
end

local function sameCf(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 0.02 and a.LookVector:Dot(b.LookVector) > 0.9999
end

local function getTrack(giant: Model): Track
	local target = targetOf(giant)
	local existing = tracks[giant]
	if existing and existing.target == target and existing.target.Parent then
		return existing
	end
	local t: Track = {
		target = target,
		rest = target:GetPivot(),
		applied = nil,
		height = heightOf(target),
		phase = math.random() * math.pi * 2,
		action = nil,
		actionT = 0,
	}
	tracks[giant] = t
	return t
end

local function giantOf(userId: number): Model?
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == userId then
			return m
		end
	end
	return nil
end

-- Deslocamento da pose para o instante `now`.
local function offset(t: Track, now: number): CFrame
	local h = math.max(t.height, 2)
	local breathe = math.sin(now * 1.6 + t.phase) * 0.025 * h
	local sway = math.rad(math.sin(now * 0.55 + t.phase) * 2.5)
	local cf = CFrame.new(0, breathe, 0) * CFrame.Angles(0, sway, 0)
	if t.action then
		local a = now - t.actionT
		if t.action == "chomp" then
			local d = 0.55
			if a >= d then
				t.action = nil
			else
				local k = math.sin(a / d * math.pi)
				cf = cf * CFrame.new(0, k * 0.12 * h, 0) * CFrame.Angles(-math.rad(14) * k, 0, 0)
			end
		elseif t.action == "cheer" then
			local d = 1.1
			if a >= d then
				t.action = nil
			else
				local k = math.sin(a / d * math.pi)
				cf = cf * CFrame.new(0, k * 0.45 * h, 0) * CFrame.Angles(0, (a / d) * math.pi * 2, 0)
			end
		end
	end
	return cf
end

local function step(now: number)
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") ~= nil and m.Name:match("^Giant_") then
			local t = getTrack(m)
			local current = t.target:GetPivot()
			-- O servidor mexeu (crescimento, troca de espécie): nova pose de repouso.
			if not t.applied or not sameCf(current, t.applied :: CFrame) then
				t.rest = current
				t.height = heightOf(t.target)
			end
			if (t.rest.Position - camPos).Magnitude <= MAX_DIST * math.max(1, t.height / 30) then
				local cf = t.rest * offset(t, now)
				t.target:PivotTo(cf)
				t.applied = cf
			end
		end
	end
	for m in tracks do
		if not m.Parent then
			tracks[m] = nil
		end
	end
end

function GiantAnim.init()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		step(os.clock())
	end)
	Remotes.GiantFed.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or type(e.userId) ~= "number" then
			return
		end
		local m = giantOf(e.userId)
		if m then
			local t = getTrack(m)
			t.action = if e.leveled then "cheer" else "chomp"
			t.actionT = os.clock()
		end
	end)
end

return GiantAnim
