--!strict
-- SkyAssets — GERADO por tools/gen_sky_assets.py a partir de assets/sky/*/sky.json. Não editar à mão.
-- Céus de 6 faces enviados ao Roblox (HDRI CC0 do Poly Haven, recoloridos). Sem entrada = céu padrão.
export type SkyFaces = { Bk: string, Dn: string, Ft: string, Lf: string, Rt: string, Up: string }

local SkyAssets: { [string]: SkyFaces } = {
	-- polyhaven:qwantani_sunset_puresky (CC0 1.0), https://polyhaven.com/a/qwantani_sunset_puresky
	["dourado"] = {
		Bk = "rbxassetid://84801158027898",
		Dn = "rbxassetid://105977939280582",
		Ft = "rbxassetid://93242303895608",
		Lf = "rbxassetid://122405299116112",
		Rt = "rbxassetid://89948045828370",
		Up = "rbxassetid://127052389029895",
	},
}

return SkyAssets
