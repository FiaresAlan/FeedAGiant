--!nonstrict
local Manifest = require(game.ReplicatedStorage.Shared.ArtManifest)
return function()
	describe("Manifesto de assets gratuitos do usuário", function()
		it("contém 22 nomes únicos e válidos", function()
			local seen = {}
			expect(#Manifest.Items).to.equal(22)
			for _, item in Manifest.Items do
				expect(item.template ~= "").to.equal(true)
				expect(item.file:sub(-4) == ".fbx").to.equal(true)
				expect(seen[item.key] == nil).to.equal(true)
				expect(seen[item.template] == nil).to.equal(true)
				seen[item.key] = true
				seen[item.template] = true
				expect(Manifest.get(item.key) == item).to.equal(true)
			end
		end)
		it("a fase inicial tem pelo menos 5 alimentos e 4 props medievais", function()
			local food, props = 0, 0
			for _, item in Manifest.Items do
				if item.tier == 1 then
					if item.pack == "Kenney Food Kit" then
						food += 1
					else
						props += 1
					end
				end
			end
			expect(food >= 5).to.equal(true)
			expect(props >= 4).to.equal(true)
		end)
	end)
end
