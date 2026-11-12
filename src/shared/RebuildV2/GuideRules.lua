--!strict
-- Jornada V3: metas concretas, adaptativas e nao bloqueantes.
local Guide = {}

Guide.Steps = {
	{ id = "first_feed", text = "Alimente seu gigante com uma comida da mochila.", action = "feed" },
	{ id = "first_mount", text = "Pressione F (ou MONTAR) perto do gigante.", action = "mount" },
	{ id = "first_pickup", text = "Va ate a Pista do Banquete e pegue uma carga.", action = "pickup" },
	{ id = "first_delivery", text = "Volte a sua base e deposite a carga na zona dourada.", action = "deliver" },
	{ id = "first_cook", text = "Na panela, experimente Pao + Queijo para descobrir uma receita.", action = "cook" },
	{ id = "first_claim", text = "Colete seu prato quando a panela ficar PRONTA.", action = "claim" },
	{ id = "second_feed", text = "Alimente mais uma vez e veja sua evolucao.", action = "feed" },
}

function Guide.next(seen: any): (string?, string?, number)
	local marked = if type(seen) == "table" then seen else {}
	for index, entry in Guide.Steps do
		if marked[entry.id] ~= true then
			return entry.id, entry.text, index
		end
	end
	return nil, "Jornada completa! Escolha entre correr, cozinhar ou alimentar.", #Guide.Steps + 1
end

function Guide.mark(seen: any, id: string): boolean
	if type(seen) ~= "table" then return false end
	for _, entry in Guide.Steps do
		if entry.id == id then
			if seen[id] == true then return false end
			seen[id] = true
			return true
		end
	end
	return false
end

return Guide
