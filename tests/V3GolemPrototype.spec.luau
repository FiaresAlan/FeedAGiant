--!nonstrict
-- Testes estruturais do rig gerado, executaveis pelo runner no Roblox Studio.
-- Nao comprovam fluidez de animacao, camera, controles ou teste mobile.
local ServerScriptService = game:GetService("ServerScriptService")
local Factory = require(ServerScriptService.Server.Services.V3StoneGolemPrototype)
local Procedural = require(ServerScriptService.Server.Services.V3ProceduralAnimation)

return function()
	describe("V3: Golem de Pedra de laboratorio", function()
		it("tem raiz e humanoide com articulacoes reais", function()
			local model = Factory.create()
			expect(model.PrimaryPart.Name).to.equal("HumanoidRootPart")
			expect(model:FindFirstChildOfClass("Humanoid")).to.be.ok()
			expect(model:FindFirstChild("Head")).to.be.ok()
			expect(model:FindFirstChild("Torso")).to.be.ok()
			expect(model:GetAttribute("V3StudioOnly")).to.equal(true)
			local motors = 0
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("Motor6D") then
					motors += 1
					expect(descendant.Part0).to.be.ok()
					expect(descendant.Part1).to.be.ok()
				end
			end
			expect(motors >= 11).to.equal(true)
			model:Destroy()
		end)
		it("possui assento e ponto de carga presos a partes articuladas", function()
			local model = Factory.create()
			local seat = model:FindFirstChild("ShoulderSeatAnchor", true)
			local cargo = model:FindFirstChild("CargoCarryAnchor", true)
			expect(seat).to.be.ok()
			expect(cargo).to.be.ok()
			expect(seat:IsA("Attachment")).to.equal(true)
			expect(cargo:IsA("Attachment")).to.equal(true)
			expect(seat.Parent.Name).to.equal("Torso")
			expect(cargo.Parent.Name).to.equal("Right Forearm")
			model:Destroy()
		end)
		it("cria e limpa o controlador procedural sem asset externo", function()
			local model = Factory.create()
			model.Parent = workspace
			local controller = Procedural.bind(model)
			controller:setLocomotion("Walk", 16)
			controller:playAction("Pickup")
			expect(controller.current).to.equal("Walk")
			controller:setLocomotion("Run", 28)
			expect(controller.current).to.equal("Run")
			controller:destroy()
			expect(controller.connection).to.equal(nil)
			model:Destroy()
		end)
	end)
end
