--!nonstrict
-- Regras puras de posse de carga; nao exige mapa, DataStore ou usuario real.
local Rules = require(game:GetService("ReplicatedStorage").Shared.RebuildV2.CargoRules)

local function fresh()
	return { uid = "cargo-test-1", state = "world", holder = nil }
end

return function()
	describe("V3: seguranca de cargo e replays", function()
		it("reserva unica: dois clientes nao pegam a mesma carga", function()
			local a, b = { id = 1 }, { id = 2 }
			local cargo = fresh()
			local previous = Rules.reserve(cargo, a)
			expect(previous).to.equal("world")
			expect(cargo.state).to.equal("reserved")
			expect(Rules.reserve(cargo, b)).to.equal(nil)
			expect(Rules.commitPickup(cargo, b)).to.equal(false)
			expect(Rules.commitPickup(cargo, a)).to.equal(true)
			expect(cargo.holder).to.equal(a)
			expect(cargo.state).to.equal("carried")
		end)
		it("falha visual devolve a reserva sem criar outro dono", function()
			local owner = { id = 1 }
			local cargo = fresh()
			local previous = Rules.reserve(cargo, owner)
			expect(Rules.rollbackReservation(cargo, owner, previous)).to.equal(true)
			expect(cargo.state).to.equal("world")
			expect(cargo.holder).to.equal(nil)
			expect(Rules.rollbackReservation(cargo, owner, previous)).to.equal(false)
		end)
		it("reserva devolve ao estado dropped quando interrompida", function()
			local owner = { id = 1 }
			local cargo = fresh()
			cargo.state = "dropped"
			local previous = Rules.reserve(cargo, owner)
			expect(previous).to.equal("dropped")
			expect(Rules.rollbackReservation(cargo, owner, previous)).to.equal(true)
			expect(cargo.state).to.equal("dropped")
		end)
		it("depositar repetidamente concede no maximo uma transicao valida", function()
			local owner = { id = 1 }
			local cargo = fresh()
			Rules.reserve(cargo, owner)
			Rules.commitPickup(cargo, owner)
			expect(Rules.canDeposit(cargo, owner)).to.equal(true)
			expect(Rules.deposit(cargo, owner)).to.equal(true)
			for _ = 1, 100 do
				expect(Rules.deposit(cargo, owner)).to.equal(false)
			end
			expect(cargo.state).to.equal("deposited")
			expect(cargo.holder).to.equal(nil)
			expect(Rules.reserve(cargo, owner)).to.equal(nil)
		end)
		it("outra conta nao deposita ou solta carga alheia", function()
			local a, b = { id = 1 }, { id = 2 }
			local cargo = fresh()
			Rules.reserve(cargo, a)
			Rules.commitPickup(cargo, a)
			expect(Rules.canDeposit(cargo, b)).to.equal(false)
			expect(Rules.drop(cargo, b)).to.equal(false)
			expect(Rules.deposit(cargo, b)).to.equal(false)
			expect(Rules.drop(cargo, a)).to.equal(true)
			expect(cargo.state).to.equal("dropped")
			expect(Rules.canDeposit(cargo, a)).to.equal(false)
			expect(Rules.reserve(cargo, b)).to.equal("dropped")
			expect(Rules.commitPickup(cargo, b)).to.equal(true)
			expect(Rules.deposit(cargo, b)).to.equal(true)
		end)
	end)
end
