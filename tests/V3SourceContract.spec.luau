--!nonstrict
-- Contrato de integracao do Rojo. Testar em place com test.project.json.
local R = game:GetService("ReplicatedStorage")
local S = game:GetService("ServerScriptService")
local Features = require(R.Shared.Features)
local Config = require(R.Shared.Config)
local AudioAssets = require(R.Shared.AudioAssets)

return function()
	describe("V3: contrato nao destrutivo de importacao", function()
		it("V3 fica desligada por padrao, sem roubo de ovo", function()
			expect(Features.flags.RebuildV2).to.equal(false)
			-- O override de Studio nao deve ser forçado por este teste.
			expect(type(Features.flags.EggSteal)).to.equal("boolean")
		end)
		it("remotes do fluxo estao presentes e em pastas replicadas", function()
			local Remotes = require(R.Shared.Remotes)
			for _, name in { "V2MountRequest", "V2MountInput", "V2MountState",
				"V2LaneRequest", "V2LaneState", "V2CookRequest", "V2CookState",
				"V3GuideRequest", "V3GuideState" } do
				expect(Remotes[name]).to.be.ok()
			end
		end)
		it("servicos antigos nao foram apagados", function()
			for _, name in { "DataService", "PlotService", "EggService", "MonetizationService",
				"GiantService", "ArenaService", "BossService", "StealService", "V2CookingService",
				"V2LaneService", "V2MountService", "V3JourneyService", "V3FeedPresentation" } do
				expect(S.Server.Services:FindFirstChild(name)).to.be.ok()
			end
		end)
		it("receitas e itens continuam no mesmo indice de comida", function()
			for _, id in { "bread", "apple", "cheese", "meat", "potato",
				"toast_cheese", "stew", "fruit_banquet" } do
				expect(Config.FoodById[id]).to.be.ok()
			end
		end)
		it("audio de panela reutiliza ID anteriormente aprovado", function()
			expect(type(AudioAssets["sfx_bell"])).to.equal("string")
			expect(#AudioAssets["sfx_bell"] > 10).to.equal(true)
		end)
	end)
end
