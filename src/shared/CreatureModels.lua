--!strict
-- CreatureModels — qual modelo 3D (assets/optimized/<arquivo>.glb) cada espécie usa (Fase 2).
-- Os IDs do Roblox ficam em CreatureAssets (gerado por tools/gen_creature_assets.py a partir de
-- assets/optimized/assets.json). Sem ID, o GiantService mantém o corpo de blocos de sempre.
local CreatureAssets = require(script.Parent.CreatureAssets)

export type Entry = {
	file: string, -- nome do .glb (sem extensão) em assets/optimized
	babyFile: string?, -- modelo do estágio "Bebê" (minLevel 1), se houver
	yaw: number?, -- graus de giro para a frente do modelo olhar para a frente da base
}

local CreatureModels = {}

-- Humano, jacaré, águia e slime (08/11/2026): malhas geradas pela IA do Roblox Studio (generate_mesh),
-- estilo cartoon, ids em assets/optimized/assets.json ("gen-*"). Frente original = -Z (yaw 0).
-- yaw: dragão vermelho e de cristal ficaram virados ~45° na vista de frente do Blender; conferir no Studio
-- depois do primeiro upload e ajustar aqui (não precisa refazer o modelo).
CreatureModels.BySpecies = {
	dragon = { file = "dragon", babyFile = "baby-dragon", yaw = 0 },
	phoenix = { file = "phoenix", yaw = 0 },
	golem = { file = "stone-golem", yaw = 0 },
	goblin = { file = "goblin", yaw = 0 },
	zombie = { file = "zombie", yaw = 0 },
	troll = { file = "troll", yaw = 0 },
	wyvern = { file = "wyvern", yaw = 0 },
	hydra = { file = "hydra", yaw = 0 },
	human = { file = "gen-human", babyFile = "gen-human-baby", yaw = 0 },
	gator = { file = "gen-gator", yaw = 0 },
	eagle = { file = "gen-eagle", yaw = 0 },
	slime = { file = "gen-slime", yaw = 0 },
} :: { [string]: Entry }

-- Arquivo e ID do modelo para a espécie no nível dado; nil se ainda não há ID (sem upload).
function CreatureModels.resolve(speciesId: string, isBabyStage: boolean): (string?, string?, number)
	local e = CreatureModels.BySpecies[speciesId]
	if not e then
		return nil, nil, 0
	end
	local file = if isBabyStage and e.babyFile and CreatureAssets[e.babyFile] then e.babyFile else e.file
	local id = CreatureAssets[file]
	if not id then
		return nil, nil, 0
	end
	return file, id, e.yaw or 0
end

return CreatureModels
