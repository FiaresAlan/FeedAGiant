-- EXECUTAR NO COMMAND BAR DO ROBLOX STUDIO depois de selecionar os modelos
-- importados no Explorer. Este arquivo NÃO é executado automaticamente no jogo.
-- Mova somente objetos que você selecionou; nunca publica, compra ou deleta assets.
-- Seleção aceita os nomes originais dos FBX da lista enviada (ex.: Stall_Empty)
-- ou o nome final do Manifest (ex.: Quaternius_Stall_Empty).
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local Manifest = require(game.ReplicatedStorage.Shared.ArtManifest)
local folder = ServerStorage:FindFirstChild(Manifest.FolderName)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = Manifest.FolderName
	folder.Parent = ServerStorage
end

local function norm(s)
	s = string.lower(s)
	s = string.gsub(s, "%.fbx$", "")
	return string.gsub(s, "[^a-z0-9]", "")
end

local function candidates(name)
	local out = {}
	for _, entry in Manifest.Items do
		if norm(name) == norm(entry.template) or norm(name) == norm(entry.file) then
			table.insert(out, entry)
		end
	end
	return out
end

local added, ignored = 0, 0
for _, selected in Selection:Get() do
	if not selected:IsA("Model") and not selected:IsA("MeshPart") and not selected:IsA("Part") then
		warn("[Assets] ignorado: " .. selected:GetFullName() .. " (não é Model/Part)")
		ignored += 1
		continue
	end
	local found = candidates(selected.Name)
	if #found ~= 1 then
		warn("[Assets] " .. selected.Name .. ": " .. #found
			.. " correspondências. Renomeie manualmente para o template exato em ArtManifest.")
		ignored += 1
		continue
	end
	local entry = found[1]
	local scriptFound = false
	for _, desc in selected:GetDescendants() do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript")
			or desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
			scriptFound = true
			break
		end
	end
	if scriptFound then
		warn("[Assets] BLOQUEADO " .. selected.Name .. ": contém código ou Remotes desconhecidos.")
		ignored += 1
		continue
	end
	if folder:FindFirstChild(entry.template) and folder:FindFirstChild(entry.template) ~= selected then
		warn("[Assets] já existe " .. entry.template .. "; não sobrepondo versão instalada.")
		ignored += 1
		continue
	end
	selected.Name = entry.template
	selected.Parent = folder
	added += 1
	print("[Assets] instalado: " .. entry.template .. " <- " .. entry.file)
end
local installed, total = 0, #Manifest.Items
print("[Assets] " .. added .. " organizados; " .. ignored .. " ignorados. Verificação:")
for _, entry in Manifest.Items do
	if folder:FindFirstChild(entry.template) then
		installed += 1
	else
		print(string.format("[Assets] pendente tier %d: %s (%s)", entry.tier, entry.template, entry.file))
	end
end
print(string.format("[Assets] %d/%d disponíveis em ServerStorage.%s.", installed, total, Manifest.FolderName))
