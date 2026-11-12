--!strict
-- Cargo efemero: estados puros e posse unica. Nao mexe em inventario/DataStore.
-- A recompensa persistente continua sendo responsabilidade do servico de entrega.
local Rules = {}

function Rules.reserve(cargo: any, holder: any): string?
	if type(cargo) ~= "table" or holder == nil or cargo.holder ~= nil then
		return nil
	end
	local previous = cargo.state
	if previous ~= "world" and previous ~= "dropped" then
		return nil
	end
	cargo.state = "reserved"
	cargo.holder = holder
	return previous
end

function Rules.rollbackReservation(cargo: any, holder: any, previous: string): boolean
	if cargo.state ~= "reserved" or cargo.holder ~= holder then
		return false
	end
	if previous ~= "world" and previous ~= "dropped" then
		return false
	end
	cargo.state = previous
	cargo.holder = nil
	return true
end

function Rules.commitPickup(cargo: any, holder: any): boolean
	if cargo.state ~= "reserved" or cargo.holder ~= holder then
		return false
	end
	cargo.state = "carried"
	return true
end

function Rules.canDeposit(cargo: any, holder: any): boolean
	return cargo ~= nil and cargo.state == "carried" and cargo.holder == holder
end

-- Reserva a transacao ANTES de chamar o adaptador de recompensa.
-- Nenhum replay, drop ou intercept pode transferir uma carga em processamento.
function Rules.beginDeposit(cargo: any, holder: any): boolean
	if not Rules.canDeposit(cargo, holder) then return false end
	cargo.state = "depositing"
	return true
end

function Rules.rollbackDeposit(cargo: any, holder: any): boolean
	if cargo == nil or cargo.state ~= "depositing" or cargo.holder ~= holder then
		return false
	end
	cargo.state = "carried"
	return true
end

function Rules.commitDeposit(cargo: any, holder: any): boolean
	if cargo == nil or cargo.state ~= "depositing" or cargo.holder ~= holder then
		return false
	end
	cargo.state = "deposited"
	cargo.holder = nil
	return true
end

function Rules.deposit(cargo: any, holder: any): boolean
	if not Rules.canDeposit(cargo, holder) then
		return false
	end
	cargo.state = "deposited"
	cargo.holder = nil
	return true
end

function Rules.drop(cargo: any, holder: any): boolean
	if not Rules.canDeposit(cargo, holder) then
		return false
	end
	cargo.state = "dropped"
	cargo.holder = nil
	return true
end

return Rules
