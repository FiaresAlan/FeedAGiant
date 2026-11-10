--!nonstrict
local District = require(game.ServerScriptService.Server.PlazaDistrict)

return function()
	describe("Ilha viva — layout sem aumentar o terreno", function()
		it("mantém todas as atrações dentro da praça existente", function()
			local L = District.Layout
			for _, spot in { L.Kitchen, L.TrailStart, L.Lookout } do
				expect(spot.radius <= 120).to.equal(true)
				expect(spot.radius >= 80).to.equal(true)
			end
			expect(#L.TrailSteps).to.equal(3)
		end)
		it("nunca cruza o eixo das oito estradas radiais", function()
			local L = District.Layout
			local spots = {
				L.Kitchen, L.TrailStart, L.Lookout,
				{ angle = L.TrailSteps[1], radius = L.TrailStart.radius },
				{ angle = L.TrailSteps[2], radius = L.TrailStart.radius },
				{ angle = L.TrailSteps[3], radius = L.TrailStart.radius },
			}
			for _, spot in spots do
				for road = 0, 315, 45 do
					local cross = math.abs(math.sin(math.rad(spot.angle - road))) * spot.radius
					expect(cross > 24).to.equal(true)
				end
			end
		end)
		it("não conflita com o centro do caldeirão ou a coroa de estátuas", function()
			local L = District.Layout
			for _, s in { L.Kitchen, L.TrailStart, L.Lookout } do
				expect(s.radius > 65).to.equal(true)
				expect(s.radius < 140).to.equal(true)
			end
		end)
	end)
end
