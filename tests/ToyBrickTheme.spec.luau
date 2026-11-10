--!nonstrict
local Theme = require(game.ServerScriptService.Server.ToyBrickTheme)

return function()
	describe("ToyBrickTheme — superfície Studs e rollback", function()
		it("tem orçamento explícito de peças para computadores e celulares", function()
			local L = Theme.Layout
			expect(L.MeadowGrid >= 40).to.equal(true)
			expect(L.PlazaGrid >= 10).to.equal(true)
			expect(L.MeadowLimit + L.PlazaLimit + L.ArenaLimit + L.DragonLimit + L.DistrictLimit < 900).to.equal(true)
		end)

		it("identifica bases e caminhos, sem estilizar todos os objetos arbitrariamente", function()
			local model = Instance.new("Model")
			model.Name = "Base1"
			local floor = Instance.new("Part")
			floor.Name = "Floor"
			floor.Parent = model
			expect(Theme.category(floor)).to.equal("base")
			local path = Instance.new("Part")
			path.Name = "Path"
			path.Size = Vector3.new(14, 1, 100)
			path.Parent = model
			expect(Theme.category(path)).to.equal("path")
			local food = Instance.new("Part")
			food.Name = "GoldenApple"
			food.Parent = model
			expect(Theme.category(food)).to.equal(nil)
			model:Destroy()
		end)

		it("preserva neons, transparências e marcadores de exclusão", function()
			local part = Instance.new("Part")
			part.Name = "Path"
			part.Transparency = 1
			expect(Theme.category(part)).to.equal(nil)
			part.Transparency = 0
			part:SetAttribute("ToyBrickExclude", true)
			expect(Theme.category(part)).to.equal(nil)
			part:Destroy()
		end)

		it("aplica studs Plastic e restaura integralmente o material da base", function()
			local map = Instance.new("Folder")
			map.Name = "Map"
			local model = Instance.new("Model")
			model.Name = "Base2"
			model.Parent = map
			local floor = Instance.new("Part")
			floor.Name = "Floor"
			floor.Color = Color3.fromRGB(235, 120, 65)
			floor.Material = Enum.Material.WoodPlanks
			floor.TopSurface = Enum.SurfaceType.Smooth
			floor.Parent = model
			local before = floor.Color
			local result = Theme.apply(map)
			expect(result.styled >= 1).to.equal(true)
			expect(floor.Material).to.equal(Enum.Material.Plastic)
			expect(floor.TopSurface).to.equal(Enum.SurfaceType.Studs)
			local plates = map:FindFirstChild("ToyBrickSurfaceOverlay")
			expect(plates ~= nil).to.equal(true)
			expect(#plates:GetChildren() < 900).to.equal(true)
			local first = plates:GetChildren()[1]
			expect(first.CanCollide).to.equal(false)
			expect(first.CanQuery).to.equal(false)
			Theme.remove(map)
			expect(map:FindFirstChild("ToyBrickSurfaceOverlay")).to.equal(nil)
			expect(floor.Material).to.equal(Enum.Material.WoodPlanks)
			expect(floor.TopSurface).to.equal(Enum.SurfaceType.Smooth)
			expect(floor.Color).to.equal(before)
			map:Destroy()
		end)

		it("a aplicação repetida não acumula overlays nem troca de cor irreversível", function()
			local map = Instance.new("Folder")
			local model = Instance.new("Model")
			model.Name = "Base1"
			model.Parent = map
			local floor = Instance.new("Part")
			floor.Name = "Floor"
			floor.Parent = model
			local initial = floor.Color
			Theme.apply(map)
			local firstColor = floor.Color
			Theme.apply(map)
			expect(floor.Color).to.equal(firstColor)
			local overlays = 0
			for _, child in map:GetChildren() do
				if child.Name == "ToyBrickSurfaceOverlay" then
					overlays += 1
				end
			end
			expect(overlays).to.equal(1)
			Theme.remove(map)
			expect(floor.Color).to.equal(initial)
			map:Destroy()
		end)
	end)
end
