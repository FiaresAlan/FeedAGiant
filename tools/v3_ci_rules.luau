--!nonstrict
-- Executavel por Lune: regras puras da V3, sem instancia, Workspace ou DataStore.
-- Nao substitui os testes de Studio; falha no CI se alguma assercao nao passar.
local Cargo = require("../src/shared/RebuildV2/CargoRules")
local Cook = require("../src/shared/RebuildV2/CookRules")
local Guide = require("../src/shared/RebuildV2/GuideRules")
local Stages = require("../src/shared/RebuildV2/StageRules")
local Run = require("../src/shared/RebuildV2/RunRules")

local checks = 0
local function test(name, fn)
	fn()
	checks += 1
	print("[V3 rules] PASS", name)
end

test("cargo exclusivo durante 100 replays", function()
	local a, b = { id = 1 }, { id = 2 }
	local cargo = { uid = "x", state = "world" }
	assert(Cargo.reserve(cargo, a) == "world")
	assert(Cargo.reserve(cargo, b) == nil)
	assert(Cargo.commitPickup(cargo, b) == false)
	assert(Cargo.commitPickup(cargo, a))
	for _ = 1, 100 do
		assert(Cargo.deposit(cargo, b) == false)
	end
	assert(Cargo.deposit(cargo, a))
	for _ = 1, 100 do assert(not Cargo.deposit(cargo, a)) end
	assert(cargo.state == "deposited")
	assert(Cargo.reserve(cargo, a) == nil)
end)

test("deposito reservado e quarentena sao terminalmente idempotentes", function()
	local owner, rival = { id = 10 }, { id = 11 }
	local cargo = { uid = "pending", state = "world" }
	assert(Cargo.reserve(cargo, owner) == "world")
	assert(Cargo.commitPickup(cargo, owner))
	assert(Cargo.beginDeposit(cargo, owner))
	for _ = 1, 100 do
		assert(not Cargo.beginDeposit(cargo, owner))
		assert(not Cargo.drop(cargo, owner))
		assert(not Cargo.beginDeposit(cargo, rival))
	end
	assert(Cargo.rollbackDeposit(cargo, owner))
	assert(Cargo.canDeposit(cargo, owner))
	assert(Cargo.beginDeposit(cargo, owner))
	assert(Cargo.quarantineDeposit(cargo, owner))
	assert(cargo.holder == nil and cargo.state == "quarantined")
	assert(not Cargo.reserve(cargo, rival))
	assert(not Cargo.commitDeposit(cargo, owner))

	local second = { uid = "ok", state = "world" }
	assert(Cargo.reserve(second, owner) == "world")
	assert(Cargo.commitPickup(second, owner))
	assert(Cargo.beginDeposit(second, owner))
	assert(Cargo.commitDeposit(second, owner))
	assert(not Cargo.commitDeposit(second, owner))
end)

test("rollback restaura dropped, sem criar segundo dono", function()
	local player = { id = 3 }
	local cargo = { uid = "y", state = "dropped" }
	local prior = Cargo.reserve(cargo, player)
	assert(prior == "dropped")
	assert(Cargo.rollbackReservation(cargo, player, prior))
	assert(cargo.holder == nil and cargo.state == "dropped")
	assert(not Cargo.rollbackReservation(cargo, player, prior))
end)

test("cozinha nao duplica ingrediente de mesmo UID", function()
	local one = { { id = "apple", uid = "same" } }
	assert(Cook.selectIndices(one, { "apple", "apple" }) == nil)
	local two = { { id = "apple", uid = "a" }, { id = "apple", uid = "b" } }
	local indexes = Cook.selectIndices(two, { "apple", "apple" })
	assert(indexes and indexes[1] == 2 and indexes[2] == 1)
	assert(#two == 2)
	assert(Cook.selectIndices(two, { "apple", "cheese" }) == nil)
	assert(#two == 2)
end)

test("duas panelas: UTC independente e claim unico", function()
	local first = { state = "cooking", jobId = "A", endsAtUtc = 120 }
	local second = { state = "cooking", jobId = "B", endsAtUtc = 140 }
	assert(not Cook.isReady(first, 119))
	assert(Cook.isReady(first, 120))
	assert(not Cook.isReady(second, 120))
	assert(Cook.canClaim(first, "A", 120))
	assert(not Cook.canClaim(second, "A", 150))
	first.state = "empty"
	first.jobId = nil
	for _ = 1, 100 do assert(not Cook.canClaim(first, "A", 150)) end
	assert(Cook.canClaim(second, "B", 150))
	assert(Cook.hasSpace(299, 300) and not Cook.hasSpace(300, 300))
end)

test("jornada nao aceita progresso inventado", function()
	local seen = {}
	assert(Guide.next(seen) == "first_feed")
	assert(not Guide.mark(seen, "fake_xp"))
	assert(Guide.mark(seen, "first_delivery"))
	assert(Guide.next(seen) == "first_feed")
	for _, step in Guide.Steps do
		assert(Guide.mark(seen, step.id) == (step.id ~= "first_delivery"))
		assert(not Guide.mark(seen, step.id))
	end
	assert(Guide.next(seen) == nil)
end)

test("estagios visuais limitados, sem reset do nivel", function()
	local k1, _, b = Stages.stage(1)
	local k9, _, b9 = Stages.stage(9)
	local k10, _, y = Stages.stage(10)
	local k30, _, c = Stages.stage(30)
	assert(k1 == "baby" and k9 == "baby" and b == b9)
	assert(k10 == "young" and k30 == "colossus")
	assert(b < y and y < c and c <= 2.2)
	assert(Stages.stage(250) == "colossus")
	local old = { name = "old", teeth = false }
	local new = Stages.style(30, old)
	assert(old.name == "old" and new.name == "Colosso" and new.teeth)
end)

test("velocidade e peso limitados, sem sprint infinito", function()
	local light = Run.speed(1, "light", false, "stone_starter", false)
	local heavy = Run.speed(1, "heavy", false, "stone_starter", false)
	assert(heavy < light and light == 20)
	assert(Run.speed(1, "heavy", false, "stone_starter", true) > heavy)
	assert(Run.speed(250, "light", true, "fire_starter", true) <= 31)
	local stamina = Run.STAMINA_MAX
	for _ = 1, 8 do stamina = Run.stamina(stamina, 1, true) end
	assert(stamina == 0)
	for _ = 1, 10 do stamina = Run.stamina(stamina, 1, false) end
	assert(stamina == Run.STAMINA_MAX)
end)

print(string.format("[V3 rules] %d pure behavior scenarios passed (not Roblox Studio integration)", checks))
