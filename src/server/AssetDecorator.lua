--!strict
-- AssetDecorator: substituição OPCIONAL das primitivas por meshes importadas pelo dono.
-- Nunca chama InsertService, require(assetId), HttpService nem carrega modelos remotos.
-- Espera ServerStorage/FeedAGiantAssets/{FantasyProps,KenneyFood}/<AssetName>.
-- Os templates são modelos auditados, sem scripts. Sem importação, a ilha funciona igual.
local ServerStorage = game:GetService("ServerStorage")
local AssetDecorator = {}

export type AssetSpec = {
	pack: string,
	name: string,
	anchor: string,
	offset: CFrame,
	height: number,
}

-- Nomes exatos: lista de FBX do usuário e overview.html Kenney Food Kit.
-- O campo anchor aponta para uma peça procedural existente da Cozinha Colossal.
AssetDecorator.Specs = {
	{ pack = "FantasyProps", name = "Cauldron", anchor = "Panela", offset = CFrame.new(), height = 4.3 },
	{ pack = "FantasyProps", name = "Workbench", anchor = "PrepA", offset = CFrame.new(), height = 3.6 },
	{ pack = "FantasyProps", name = "Barrel_Apples", anchor = "Barril", offset = CFrame.new(), height = 3.8 },
	{ pack = "FantasyProps", name = "Stall_Empty", anchor = "TotemCozinha", offset = CFrame.new(0, 0, 0), height = 10 },
	{ pack = "KenneyFood", name = "cutting-board", anchor = "Tábua", offset = CFrame.new(), height = 0.3 },
	{ pack = "KenneyFood", name = "carrot", anchor = "Legume", offset = CFrame.new(), height = 1.8 },
	{ pack = "KenneyFood", name = "pot-stew", anchor = "Sopa", offset = CFrame.new(), height = 1.5 },
}

local function sanitizedClone(template: Instance): Model?
	if not template:IsA("Model") and not template:IsA("BasePart") then
		return nil
	end
	local ok, copy = pcall(function()
		return template:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local wrapper: Model
	if copy:IsA("Model") then
		wrapper = copy
	else
		wrapper = Instance.new("Model")
		copy.Parent = wrapper
	end
	local count = 0
	for _, descendant in wrapper:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")
			or descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector")
			or descendant:IsA("Sound") or descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction") or descendant:IsA("BindableEvent")
			or descendant:IsA("BindableFunction") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			count += 1
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		end
	end
	if count < 1 or count > 25 then
		wrapper:Destroy()
		return nil
	end
	return wrapper
end

function AssetDecorator.apply(kitchen: Model): number
	local folder = ServerStorage:FindFirstChild("FeedAGiantAssets")
	if not folder then
		return 0
	end
	local placed = 0
	local consumed: { [Instance]: boolean } = {}
	for _, spec: AssetSpec in AssetDecorator.Specs do
		local pack = folder:FindFirstChild(spec.pack)
		local template = pack and pack:FindFirstChild(spec.name)
		if not template then
			continue
		end
		local anchor: BasePart? = nil
		for _, node in kitchen:GetDescendants() do
			if node:IsA("BasePart") and node.Name == spec.anchor and not consumed[node] then
				anchor = node
				break
			end
		end
		if not anchor then
			continue
		end
		local model = sanitizedClone(template)
		if not model then
			warn("[AssetDecorator] template ignorado: ", spec.pack, spec.name)
			continue
		end
		local _, size = model:GetBoundingBox()
		if size.Y < 0.01 then
			model:Destroy()
			continue
		end
		local ok = pcall(function()
			model:ScaleTo(model:GetScale() * (spec.height / size.Y))
			model:PivotTo(anchor.CFrame * spec.offset)
		end)
		if not ok then
			model:Destroy()
			continue
		end
		model.Name = "Imported_" .. spec.name
		model.Parent = kitchen
		consumed[anchor] = true
		-- Invisível, mas mantém o Part com ProximityPrompt, atributos e geometria
		-- lógica para a cozinha continuar funcionando. Evita criar uma cópia funcional.
		anchor.Transparency = 1
		placed += 1
	end
	return placed
end

return AssetDecorator
