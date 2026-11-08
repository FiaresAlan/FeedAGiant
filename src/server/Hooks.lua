--!strict
-- Hooks — avisos internos do servidor entre serviços (sem dependência circular).
-- Ex.: PlotService avisa "fed"; ProgressService (recordes e objetivos) escuta.
-- Nunca recebe nada do cliente: só serviços do servidor disparam.
local Hooks = {}

type Listener = (...any) -> ()
local listeners: { [string]: { Listener } } = {}

function Hooks.on(name: string, fn: Listener)
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, fn)
end

function Hooks.fire(name: string, ...: any)
	local list = listeners[name]
	if not list then
		return
	end
	for _, fn in list do
		local ok, err = pcall(fn :: any, ...)
		if not ok then
			warn("[Hooks]", name, err)
		end
	end
end

return Hooks
