--!strict
-- Locale.lua — tradução PT-BR / EN / ES (gerado). Fonte dos textos: português.
-- Locale.t(texto, locale) traduz strings estáticas; Locale.fmt(chave, locale, params) monta mensagens dinâmicas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Locale = {}
Locale.Supported = { "pt-br", "en", "es" }
Locale.Default = "pt-br"

Locale.Exact = {
	-- Fase 4: coleção
	["COLEÇÃO"] = { en = "COLLECTION", es = "COLECCIÓN" },
	["COMIDAS"] = { en = "FOODS", es = "COMIDAS" },
	["ESPÉCIES DE GIGANTE"] = { en = "GIANT SPECIES", es = "ESPECIES DE GIGANTE" },
	["✔ TENHO"] = { en = "✔ OWNED", es = "✔ TENGO" },
	["🔒 FALTA"] = { en = "🔒 MISSING", es = "🔒 FALTA" },
	["ALIMENTAR GIGANTE"] = { en = "FEED GIANT", es = "ALIMENTAR GIGANTE" },
	["LOJA — entre para abrir"] = { en = "SHOP — walk in to open", es = "TIENDA — entra para abrir" },
	["BASE LIVRE"] = { en = "FREE BASE", es = "BASE LIBRE" },
	["Carregando..."] = { en = "Loading...", es = "Cargando..." },
	["Seja o primeiro!"] = { en = "Be the first!", es = "¡Sé el primero!" },
	["MAIORES GIGANTES"] = { en = "BIGGEST GIANTS", es = "GIGANTES MÁS GRANDES" },
	["MAIS REBIRTHS"] = { en = "MOST REBIRTHS", es = "MÁS REBIRTHS" },
	["REIS DA ARENA"] = { en = "ARENA KINGS", es = "REYES DE LA ARENA" },
	["PRODUTOS"] = { en = "PRODUCTS", es = "PRODUCTOS" },
	["ESPÉCIES"] = { en = "SPECIES", es = "ESPECIES" },
	["CÓDIGOS"] = { en = "CODES", es = "CÓDIGOS" },
	["DIÁRIO"] = { en = "DAILY", es = "DIARIO" },
	["DIÁRIO!"] = { en = "DAILY!", es = "¡DIARIO!" },
	["REBIRTH!"] = { en = "REBIRTH!", es = "¡REBIRTH!" },
	["MOCHILA"] = { en = "BACKPACK", es = "MOCHILA" },
	["PÁTIO"] = { en = "YARD", es = "PATIO" },
	["INVENTÁRIO & PÁTIO"] = { en = "INVENTORY & YARD", es = "INVENTARIO Y PATIO" },
	["Fome"] = { en = "Hunger", es = "Hambre" },
	["Bebê Nv. 1"] = { en = "Baby Lv. 1", es = "Bebé Nv. 1" },
	["EQUIPADO ✓"] = { en = "EQUIPPED ✓", es = "EQUIPADO ✓" },
	["EQUIPAR"] = { en = "EQUIP", es = "EQUIPAR" },
	["COMPRAR"] = { en = "BUY", es = "COMPRAR" },
	["ALIMENTAR"] = { en = "FEED", es = "ALIMENTAR" },
	["COLOCAR"] = { en = "PLACE", es = "COLOCAR" },
	["GUARDAR"] = { en = "STORE", es = "GUARDAR" },
	["ABRIR"] = { en = "OPEN", es = "ABRIR" },
	["FECHAR"] = { en = "CLOSE", es = "CERRAR" },
	["RESGATAR"] = { en = "REDEEM", es = "CANJEAR" },
	["LOJA"] = { en = "SHOP", es = "TIENDA" },
	["ARENA"] = { en = "ARENA", es = "ARENA" },
	["INVENTÁRIO"] = { en = "INVENTORY", es = "INVENTARIO" },
	["REBIRTH"] = { en = "REBIRTH", es = "REBIRTH" },
	["Vazio. Compre uma Lunchbox na Loja!"] = {
		en = "Empty. Buy a Lunchbox at the Shop!",
		es = "Vacío. ¡Compra una Lunchbox en la Tienda!",
	},
	["Nenhuma comida no pátio. Coloque para gerar moedas."] = {
		en = "No food in the yard. Place some to earn coins.",
		es = "No hay comida en el patio. Coloca para generar monedas.",
	},
	["Digite um código promocional:"] = { en = "Enter a promo code:", es = "Escribe un código promocional:" },
	["EX: GIGANTE"] = { en = "E.g.: GIANT", es = "EJ: GIGANTE" },
	["Cada espécie muda forma, XP, moedas, fome e força na arena. Trocar é grátis depois de comprar."] = {
		en = "Each species changes shape, XP, coins, hunger and arena power. Switching is free after buying.",
		es = "Cada especie cambia forma, XP, monedas, hambre y fuerza en la arena. Cambiar es gratis después de comprar.",
	},
	["Alimenta a comida mais rara do seu pátio (+XP). Comida no pátio gera moedas; comida alimentada vira crescimento."] = {
		en = "Feeds the rarest food in your yard (+XP). Food in the yard earns coins; fed food becomes growth.",
		es = "Alimenta la comida más rara de tu patio (+XP). La comida en el patio genera monedas; la comida dada se vuelve crecimiento.",
	},
	["GIANT CLASH — ARENA"] = { en = "GIANT CLASH — ARENA", es = "GIANT CLASH — ARENA" },
	["DESAFIAR ⚔"] = { en = "CHALLENGE ⚔", es = "DESAFIAR ⚔" },
	["ACEITAR ⚔"] = { en = "ACCEPT ⚔", es = "ACEPTAR ⚔" },
	["RECUSAR"] = { en = "DECLINE", es = "RECHAZAR" },
	["FORÇA x1.00"] = { en = "POWER x1.00", es = "FUERZA x1.00" },
	["🛡 BLOQUEANDO"] = { en = "🛡 BLOCKING", es = "🛡 BLOQUEANDO" },
	["BLOQUEADO"] = { en = "BLOCKED", es = "BLOQUEADO" },
	["PESADO!"] = { en = "HEAVY!", es = "¡PESADO!" },
	["Sem stamina!"] = { en = "No stamina!", es = "¡Sin stamina!" },
	["Guarda QUEBRADA!"] = { en = "Guard BROKEN!", es = "¡Guardia ROTA!" },
	["Clique/J: soco  •  Dir./K: pesado  •  F: bloquear  •  zona segura no seu pátio"] = {
		en = "Click/J: punch  •  Right/K: heavy  •  F: block  •  safe zone in your yard",
		es = "Clic/J: golpe  •  Der./K: pesado  •  F: bloquear  •  zona segura en tu patio",
	},
	["Nenhum oponente no servidor. Convide amigos!"] = {
		en = "No opponents in this server. Invite friends!",
		es = "No hay oponentes en el servidor. ¡Invita amigos!",
	},
	["Vencedor rouba as 2 comidas mais raras do PÁTIO do perdedor + 5% das moedas. Força = espécie × nível × rebirth × humor (+sorte)."] = {
		en = "Winner steals the loser's 2 rarest YARD foods + 5% of coins. Power = species × level × rebirth × mood (+luck).",
		es = "El ganador roba las 2 comidas más raras del PATIO del perdedor + 5% de monedas. Fuerza = especie × nivel × rebirth × humor (+suerte).",
	},
	["⚔ DISPUTA DE COMIDA"] = { en = "⚔ FOOD DROP FIGHT", es = "⚔ DISPUTA DE COMIDA" },
	["▼ COMIDA CAINDO NO CENTRO ▼"] = {
		en = "▼ FOOD DROPPING AT THE CENTER ▼",
		es = "▼ COMIDA CAYENDO EN EL CENTRO ▼",
	},
	["Ninguém no círculo — CORRA!"] = {
		en = "Nobody in the circle — RUN!",
		es = "Nadie en el círculo — ¡CORRE!",
	},
	["BOSS FAMINTO\nClique em mim com comida no inventário!"] = {
		en = "HUNGRY BOSS\nClick me with food in your inventory!",
		es = "JEFE HAMBRIENTO\n¡Haz clic en mí con comida en el inventario!",
	},
	["Bem-vindo! Coloque comida no pátio e alimente seu Gigante."] = {
		en = "Welcome! Place food in your yard and feed your Giant.",
		es = "¡Bienvenido! Coloca comida en el patio y alimenta a tu Gigante.",
	},
	["Compra recebida. Obrigado!"] = { en = "Purchase received. Thank you!", es = "Compra recibida. ¡Gracias!" },
	["Moedas insuficientes!"] = { en = "Not enough coins!", es = "¡Monedas insuficientes!" },
	["Código inválido."] = { en = "Invalid code.", es = "Código inválido." },
	["Código já usado."] = { en = "Code already used.", es = "Código ya usado." },
	["Dados não carregados."] = { en = "Data not loaded.", es = "Datos no cargados." },
	["Já está em uma luta."] = { en = "Already in a fight.", es = "Ya estás en una pelea." },
	["Servidor cheio."] = { en = "Server full.", es = "Servidor lleno." },
	["Roubo cancelado."] = { en = "Steal cancelled.", es = "Robo cancelado." },
	["Pronto para lutar!"] = { en = "Ready to fight!", es = "¡Listo para luchar!" },
	["Volte amanhã para a próxima recompensa!"] = {
		en = "Come back tomorrow for the next reward!",
		es = "¡Vuelve mañana para la próxima recompensa!",
	},
	["Você precisa de comida no inventário!"] = {
		en = "You need food in your inventory!",
		es = "¡Necesitas comida en el inventario!",
	},
	["Você recuperou sua comida!"] = { en = "You got your food back!", es = "¡Recuperaste tu comida!" },
	["Você foi atingido e derrubou a comida!"] = {
		en = "You got hit and dropped the food!",
		es = "¡Te golpearon y soltaste la comida!",
	},
	["Pegou! Corra para sua base e toque no seu pátio."] = {
		en = "Got it! Run to your base and touch your yard.",
		es = "¡Lo tienes! Corre a tu base y toca tu patio.",
	},
	["Pátio cheio! Alimente seu Gigante para liberar espaço."] = {
		en = "Yard full! Feed your Giant to free space.",
		es = "¡Patio lleno! Alimenta a tu Gigante para liberar espacio.",
	},
	["Esta base está protegida por um escudo!"] = {
		en = "This base is protected by a shield!",
		es = "¡Esta base está protegida por un escudo!",
	},
	["Falha ao carregar seus dados. Tente novamente."] = {
		en = "Failed to load your data. Try again.",
		es = "Error al cargar tus datos. Inténtalo de nuevo.",
	},
	["Você já tem todas as espécies! +50.000 moedas."] = {
		en = "You already own every species! +50,000 coins.",
		es = "¡Ya tienes todas las especies! +50.000 monedas.",
	},
	["Nocauteado! Progresso da disputa zerado."] = {
		en = "Knocked out! Drop progress reset.",
		es = "¡Noqueado! Progreso de la disputa reiniciado.",
	},
	["Saiu do círculo! Perdeu metade do progresso."] = {
		en = "Left the circle! Lost half your progress.",
		es = "¡Saliste del círculo! Perdiste la mitad del progreso.",
	},
	["Encolhimento CONGELADO por 7 dias!"] = {
		en = "Shrinking FROZEN for 7 days!",
		es = "¡Encogimiento CONGELADO por 7 días!",
	},
	["Stamina INFINITA por 60s!"] = { en = "INFINITE stamina for 60s!", es = "¡Stamina INFINITA por 60s!" },
	["Cooldown de duelo zerado!"] = { en = "Duel cooldown reset!", es = "¡Cooldown de duelo reiniciado!" },
	["Game Pass ainda não configurado (ID 0 em Config.lua)."] = {
		en = "Game Pass not configured yet (ID 0 in Config.lua).",
		es = "Game Pass aún no configurado (ID 0 en Config.lua).",
	},
	["Produto ainda não configurado (ID 0 em Config.lua)."] = {
		en = "Product not configured yet (ID 0 in Config.lua).",
		es = "Producto aún no configurado (ID 0 en Config.lua).",
	},
	["🏆 VOCÊ VENCEU!"] = { en = "🏆 YOU WON!", es = "🏆 ¡GANASTE!" },
	["Chuva de Comida"] = { en = "Food Rain", es = "Lluvia de Comida" },
	["Boss Faminto"] = { en = "Hungry Boss", es = "Jefe Hambriento" },
	["Gigante Humano"] = { en = "Human Giant", es = "Gigante Humano" },
	["Gigante Jacaré"] = { en = "Gator Giant", es = "Gigante Caimán" },
	["Gigante Águia"] = { en = "Eagle Giant", es = "Gigante Águila" },
	["Gigante Golem"] = { en = "Golem Giant", es = "Gigante Golem" },
	["Gigante Slime"] = { en = "Slime Giant", es = "Gigante Slime" },
	["Gigante Dragão"] = { en = "Dragon Giant", es = "Gigante Dragón" },
	["Gigante Fênix"] = { en = "Phoenix Giant", es = "Gigante Fénix" },
	["Gigante DRAGÃO"] = { en = "DRAGON Giant", es = "Gigante DRAGÓN" },
	["Gigante FÊNIX"] = { en = "PHOENIX Giant", es = "Gigante FÉNIX" },
	["Bebê"] = { en = "Baby", es = "Bebé" },
	["Criança"] = { en = "Kid", es = "Niño" },
	["Adolescente"] = { en = "Teen", es = "Adolescente" },
	["Guerreiro"] = { en = "Warrior", es = "Guerrero" },
	["Titã"] = { en = "Titan", es = "Titán" },
	["Colosso"] = { en = "Colossus", es = "Coloso" },
	["DEUS"] = { en = "GOD", es = "DIOS" },
	["Maçã"] = { en = "Apple", es = "Manzana" },
	["Pão"] = { en = "Bread", es = "Pan" },
	["Hambúrguer"] = { en = "Burger", es = "Hamburguesa" },
	["Bolo de Lava"] = { en = "Lava Cake", es = "Pastel de Lava" },
	["Taco Dourado"] = { en = "Golden Taco", es = "Taco Dorado" },
	["Ramen Épico"] = { en = "Epic Ramen", es = "Ramen Épico" },
	["Donut de Diamante"] = { en = "Diamond Donut", es = "Donut de Diamante" },
	["Sorvete Galáctico"] = { en = "Galactic Ice Cream", es = "Helado Galáctico" },
	["Churrasco Infinito"] = { en = "Infinite BBQ", es = "Asado Infinito" },
	["Pizza Dourada"] = { en = "Golden Pizza", es = "Pizza Dorada" },
	["Hambúrguer Lendário"] = { en = "Legendary Burger", es = "Hamburguesa Legendaria" },
	["Lasanha do Universo"] = { en = "Universe Lasagna", es = "Lasaña del Universo" },
	["Coxinha Cósmica"] = { en = "Cosmic Coxinha", es = "Coxinha Cósmica" },
	["Brigadeiro Infinito"] = { en = "Infinite Brigadeiro", es = "Brigadeiro Infinito" },
	["Lunchbox Comum"] = { en = "Common Lunchbox", es = "Lunchbox Común" },
	["Lunchbox Rara"] = { en = "Rare Lunchbox", es = "Lunchbox Rara" },
	["Lunchbox Épica"] = { en = "Epic Lunchbox", es = "Lunchbox Épica" },
	["Lunchbox Lendária"] = { en = "Legendary Lunchbox", es = "Lunchbox Legendaria" },
	["Lunchbox Mítica"] = { en = "Mythic Lunchbox", es = "Lunchbox Mítica" },
	["2x Moedas"] = { en = "2x Coins", es = "2x Monedas" },
	["Guardião"] = { en = "Guardian", es = "Guardián" },
	["Boxeador Pro"] = { en = "Pro Boxer", es = "Boxeador Pro" },
	["10.000 Moedas"] = { en = "10,000 Coins", es = "10.000 Monedas" },
	["100.000 Moedas"] = { en = "100,000 Coins", es = "100.000 Monedas" },
	["Super Escudo (10 min)"] = { en = "Super Shield (10 min)", es = "Super Escudo (10 min)" },
	["Congelar Gigante (7 dias)"] = { en = "Freeze Giant (7 days)", es = "Congelar Gigante (7 días)" },
	["Restaurar Níveis"] = { en = "Restore Levels", es = "Restaurar Niveles" },
	["Energético"] = { en = "Energy Drink", es = "Energético" },
	["Revanche Imediata"] = { en = "Instant Rematch", es = "Revancha Inmediata" },
	["Trocar Espécie"] = { en = "Switch Species", es = "Cambiar Especie" },
	["Comum"] = { en = "Common", es = "Común" },
	["Raro"] = { en = "Rare", es = "Raro" },
	["Épico"] = { en = "Epic", es = "Épico" },
	["Lendário"] = { en = "Legendary", es = "Legendario" },
	["Mítico"] = { en = "Mythic", es = "Mítico" },
	["SECRETO"] = { en = "SECRET", es = "SECRETO" },
	["Equilibrado. Come de tudo, cresce rápido."] = {
		en = "Balanced. Eats everything, grows fast.",
		es = "Equilibrado. Come de todo, crece rápido.",
	},
	["Mandíbula de aço. +40% força na arena, cresce mais devagar."] = {
		en = "Steel jaws. +40% arena power, grows slower.",
		es = "Mandíbula de acero. +40% fuerza en la arena, crece más lento.",
	},
	["Visão de caçador. +50% XP por comida, mas fome cai 1.5x."] = {
		en = "Hunter's eye. +50% XP per food, but hunger drops 1.5x.",
		es = "Visión de cazador. +50% XP por comida, pero el hambre baja 1.5x.",
	},
	["Tanque de pedra. 2x HP na arena, +25% moedas, come devagar."] = {
		en = "Stone tank. 2x arena HP, +25% coins, eats slowly.",
		es = "Tanque de piedra. 2x HP en la arena, +25% monedas, come lento.",
	},
	["Absorve tudo. +100% moedas, cresce muito devagar."] = {
		en = "Absorbs everything. +100% coins, grows very slowly.",
		es = "Absorbe todo. +100% monedas, crece muy lento.",
	},
	["O ápice. +100% XP, +50% moedas e nunca passa fome."] = {
		en = "The apex. +100% XP, +50% coins and never gets hungry.",
		es = "La cima. +100% XP, +50% monedas y nunca pasa hambre.",
	},
	["Renasce das cinzas: Rebirth dá +50% em vez de +25%. Nunca passa fome."] = {
		en = "Rises from the ashes: Rebirth gives +50% instead of +25%. Never gets hungry.",
		es = "Renace de las cenizas: Rebirth da +50% en vez de +25%. Nunca pasa hambre.",
	},
	["Dobra TODA a renda passiva. Para sempre."] = {
		en = "Doubles ALL passive income. Forever.",
		es = "Duplica TODA la renta pasiva. Para siempre.",
	},
	["Nametag dourada, 1.5x XP e +4 slots no pátio."] = {
		en = "Golden nametag, 1.5x XP and +4 yard slots.",
		es = "Nametag dorado, 1.5x XP y +4 espacios en el patio.",
	},
	["Seu Gigante come sozinho do pátio a cada 30s."] = {
		en = "Your Giant auto-eats from the yard every 30s.",
		es = "Tu Gigante come solo del patio cada 30s.",
	},
	["Espécie secreta: 2x XP, 1.5x moedas e nunca passa fome."] = {
		en = "Secret species: 2x XP, 1.5x coins and never gets hungry.",
		es = "Especie secreta: 2x XP, 1.5x monedas y nunca pasa hambre.",
	},
	["Espécie secreta: Rebirth dá +50%, 1.5x moedas e nunca passa fome."] = {
		en = "Secret species: Rebirth gives +50%, 1.5x coins and never gets hungry.",
		es = "Especie secreta: Rebirth da +50%, 1.5x monedas y nunca pasa hambre.",
	},
	["Seu Gigante NUNCA passa fome (sempre Feliz), qualquer espécie. Aura dourada."] = {
		en = "Your Giant NEVER gets hungry (always Happy), any species. Golden aura.",
		es = "Tu Gigante NUNCA pasa hambre (siempre Feliz), cualquier especie. Aura dorada.",
	},
	["+25% dano nos socos, +30% stamina e luvas douradas."] = {
		en = "+25% punch damage, +30% stamina and golden gloves.",
		es = "+25% daño en golpes, +30% stamina y guantes dorados.",
	},
	["Metade do cooldown de duelo e rouba 3 comidas por vitória."] = {
		en = "Half duel cooldown and steals 3 foods per win.",
		es = "Mitad del cooldown de duelo y roba 3 comidas por victoria.",
	},
	["Cooldown de duelo pela metade e rouba 3 comidas ao vencer."] = {
		en = "Half duel cooldown and steals 3 foods on win.",
		es = "Cooldown de duelo a la mitad y roba 3 comidas al ganar.",
	},
	["Pacote inicial de moedas."] = { en = "Starter coin pack.", es = "Paquete inicial de monedas." },
	["Pacote grande de moedas."] = { en = "Big coin pack.", es = "Paquete grande de monedas." },
	["Ninguém rouba do seu pátio por 10 minutos."] = {
		en = "Nobody can steal from your yard for 10 minutes.",
		es = "Nadie roba de tu patio por 10 minutos.",
	},
	["Uma Lunchbox com raridade mínima Rare garantida."] = {
		en = "A Lunchbox with guaranteed Rare minimum rarity.",
		es = "Una Lunchbox con rareza mínima Rare garantizada.",
	},
	["Seu Gigante não encolhe por 7 dias, mesmo sem jogar."] = {
		en = "Your Giant won't shrink for 7 days, even offline.",
		es = "Tu Gigante no encoge por 7 días, aunque no juegues.",
	},
	["Recupera todos os níveis perdidos por inatividade."] = {
		en = "Restores all levels lost to inactivity.",
		es = "Recupera todos los niveles perdidos por inactividad.",
	},
	["Stamina cheia agora + 60s de stamina infinita."] = {
		en = "Full stamina now + 60s of infinite stamina.",
		es = "Stamina llena ahora + 60s de stamina infinita.",
	},
	["Zera o cooldown de duelo da arena."] = {
		en = "Resets the arena duel cooldown.",
		es = "Reinicia el cooldown de duelo de la arena.",
	},
	["Troca para qualquer espécie comprável mantendo o nível."] = {
		en = "Switch to any purchasable species keeping your level.",
		es = "Cambia a cualquier especie comprable manteniendo el nivel.",
	},
	["CAMPEONATO"] = { en = "TOURNAMENT", es = "CAMPEONATO" },
	["Faminto"] = { en = "Hungry", es = "Hambriento" },
	["Satisfeito"] = { en = "Satisfied", es = "Satisfecho" },
	["Feliz"] = { en = "Happy", es = "Feliz" },
	["Gigante"] = { en = "Giant", es = "Gigante" },
	["comida"] = { en = "food", es = "comida" },
	["Common"] = { en = "Common", es = "Común" },
	["Uncommon"] = { en = "Uncommon", es = "Poco común" },
	["Rare"] = { en = "Rare", es = "Raro" },
	["Epic"] = { en = "Epic", es = "Épico" },
	["Legendary"] = { en = "Legendary", es = "Legendario" },
	["Mythic"] = { en = "Mythic", es = "Mítico" },
	["Secret"] = { en = "Secret", es = "Secreto" },
}

Locale.Templates = {
	arena_won_broadcast = {
		["pt-br"] = "⚔️ {a} venceu {b} no Giant Clash!",
		en = "⚔️ {a} beat {b} in Giant Clash!",
		es = "⚔️ ¡{a} venció a {b} en Giant Clash!",
	},
	arena_wait = {
		["pt-br"] = "Aguarde {n}s para desafiar de novo (ou compre Revanche).",
		en = "Wait {n}s to challenge again (or buy Rematch).",
		es = "Espera {n}s para desafiar de nuevo (o compra Revancha).",
	},
	arena_protected = {
		["pt-br"] = "{p} está protegido por {n}s.",
		en = "{p} is protected for {n}s.",
		es = "{p} está protegido por {n}s.",
	},
	arena_pending = {
		["pt-br"] = "{p} já tem um desafio pendente.",
		en = "{p} already has a pending challenge.",
		es = "{p} ya tiene un desafío pendiente.",
	},
	arena_minlevel = {
		["pt-br"] = "Gigante precisa ser nível {n}.",
		en = "Giant must be level {n}.",
		es = "El Gigante debe ser nivel {n}.",
	},
	tourney_start = {
		["pt-br"] = "🏆 CAMPEONATO GIANT CLASH começou com {n} gigantes!",
		en = "🏆 GIANT CLASH TOURNAMENT started with {n} giants!",
		es = "🏆 ¡El CAMPEONATO GIANT CLASH empezó con {n} gigantes!",
	},
	tourney_champ = {
		["pt-br"] = "👑 {p} é o CAMPEÃO do Giant Clash! (+{n} moedas + Lunchbox Lendária)",
		en = "👑 {p} is the Giant Clash CHAMPION! (+{n} coins + Legendary Lunchbox)",
		es = "👑 ¡{p} es el CAMPEÓN de Giant Clash! (+{n} monedas + Lunchbox Legendaria)",
	},
	ko_victim = {
		["pt-br"] = "K.O.! Você foi nocauteado por {p}!",
		en = "K.O.! You were knocked out by {p}!",
		es = "¡K.O.! ¡{p} te noqueó!",
	},
	ko_attacker = { ["pt-br"] = "NOCAUTE em {p}!", en = "KNOCKOUT on {p}!", es = "¡NOCAUT a {p}!" },
	safe_zone = {
		["pt-br"] = "{p} está na zona segura do próprio pátio.",
		en = "{p} is in their own yard's safe zone.",
		es = "{p} está en la zona segura de su patio.",
	},
	drop_defended = {
		["pt-br"] = "Você DEFENDEU e ganhou {f}!",
		en = "You DEFENDED and won {f}!",
		es = "¡DEFENDISTE y ganaste {f}!",
	},
	drop_won_broadcast = {
		["pt-br"] = "{p} venceu a disputa por {f} ({r})!",
		en = "{p} won the fight for {f} ({r})!",
		es = "¡{p} ganó la disputa por {f} ({r})!",
	},
	drop_incoming = {
		["pt-br"] = "Um(a) {f} [{r}] vai cair no centro! Defenda por {n}s para ficar com ele(a)!",
		en = "A {f} [{r}] is dropping at the center! Hold it for {n}s to keep it!",
		es = "¡Un(a) {f} [{r}] va a caer en el centro! ¡Defiéndelo por {n}s para quedártelo!",
	},
	rain_caught = {
		["pt-br"] = "Pegou {f} da chuva!",
		en = "Caught {f} from the rain!",
		es = "¡Atrapaste {f} de la lluvia!",
	},
	boss_rank = {
		["pt-br"] = "{p} ficou em #{n} no Boss Faminto e ganhou uma Legendary!",
		en = "{p} placed #{n} in Hungry Boss and won a Legendary!",
		es = "¡{p} quedó #{n} en el Jefe Hambriento y ganó una Legendary!",
	},
	evolved_broadcast = {
		["pt-br"] = "{p} evoluiu seu Gigante para {s}!",
		en = "{p} evolved their Giant into {s}!",
		es = "¡{p} evolucionó su Gigante a {s}!",
	},
	levelup = {
		["pt-br"] = "Seu Gigante subiu para o nível {n}!",
		en = "Your Giant reached level {n}!",
		es = "¡Tu Gigante subió al nivel {n}!",
	},
	welcome_back = {
		["pt-br"] = "Bem-vindo de volta! +{n} moedas e uma Lunchbox de presente.",
		en = "Welcome back! +{n} coins and a free Lunchbox.",
		es = "¡Bienvenido de vuelta! +{n} monedas y una Lunchbox de regalo.",
	},
	shrunk = {
		["pt-br"] = "Seu Gigante ficou {d} dias sem comer e ENCOLHEU {n} níveis! (Recupere na Loja)",
		en = "Your Giant went {d} days without eating and SHRANK {n} levels! (Restore at the Shop)",
		es = "¡Tu Gigante pasó {d} días sin comer y ENCOGIÓ {n} niveles! (Recupera en la Tienda)",
	},
	restored = {
		["pt-br"] = "+{n} níveis RESTAURADOS!",
		en = "+{n} levels RESTORED!",
		es = "¡+{n} niveles RESTAURADOS!",
	},
	new_species = {
		["pt-br"] = "Nova espécie desbloqueada: {s}!",
		en = "New species unlocked: {s}!",
		es = "¡Nueva especie desbloqueada: {s}!",
	},
	found_food = {
		["pt-br"] = "{p} encontrou {f} ({r})!",
		en = "{p} found {f} ({r})!",
		es = "¡{p} encontró {f} ({r})!",
	},
	rebirth_req = {
		["pt-br"] = "Rebirth exige Gigante nível {n}!",
		en = "Rebirth requires Giant level {n}!",
		es = "¡Rebirth exige Gigante nivel {n}!",
	},
	rebirth_broadcast = {
		["pt-br"] = "{p} fez REBIRTH #{n}!",
		en = "{p} did REBIRTH #{n}!",
		es = "¡{p} hizo REBIRTH #{n}!",
	},
	code_ok = {
		["pt-br"] = "Código resgatado: +{n} moedas!",
		en = "Code redeemed: +{n} coins!",
		es = "¡Código canjeado: +{n} monedas!",
	},
	daily_ok = {
		["pt-br"] = "Recompensa diária: +{n} moedas!",
		en = "Daily reward: +{n} coins!",
		es = "¡Recompensa diaria: +{n} monedas!",
	},
	pass_only = {
		["pt-br"] = "{s} é exclusivo de Game Pass.",
		en = "{s} is Game Pass exclusive.",
		es = "{s} es exclusivo de Game Pass.",
	},
	need_coins = {
		["pt-br"] = "Faltam {n} moedas para {s}.",
		en = "You need {n} more coins for {s}.",
		es = "Te faltan {n} monedas para {s}.",
	},
	species_unlocked_broadcast = {
		["pt-br"] = "{p} desbloqueou o {s} [{r}]!",
		en = "{p} unlocked the {s} [{r}]!",
		es = "¡{p} desbloqueó el {s} [{r}]!",
	},
	stealing = {
		["pt-br"] = "Roubando {f}... fique parado 3s!",
		en = "Stealing {f}... stand still for 3s!",
		es = "Robando {f}... ¡quédate quieto 3s!",
	},
	stolen_owner = {
		["pt-br"] = "{p} ROUBOU seu {f}! Dê um soco nele para recuperar!",
		en = "{p} STOLE your {f}! Punch them to get it back!",
		es = "¡{p} ROBÓ tu {f}! ¡Dale un puñetazo para recuperarlo!",
	},
	steal_done = {
		["pt-br"] = "Roubo concluído: {f} é sua!",
		en = "Steal complete: {f} is yours!",
		es = "Robo completado: ¡{f} es tuya!",
	},
	steal_alert = {
		["pt-br"] = "ALERTA: {p} está roubando seu {f}!",
		en = "ALERT: {p} is stealing your {f}!",
		es = "ALERTA: ¡{p} está robando tu {f}!",
	},
	event_banner = { ["pt-br"] = "EVENTO: {s}", en = "EVENT: {s}", es = "EVENTO: {s}" },
	fight_title = { ["pt-br"] = "{t}{a} vs {b}", en = "{t}{a} vs {b}", es = "{t}{a} vs {b}" },
	fight_won = { ["pt-br"] = "🏆 VOCÊ VENCEU!{x}", en = "🏆 YOU WON!{x}", es = "🏆 ¡GANASTE!{x}" },
	fight_stole = { ["pt-br"] = " Roubou: {s}", en = " Stole: {s}", es = " Robaste: {s}" },
	fight_lost = {
		["pt-br"] = "💀 Derrota... {p} venceu.",
		en = "💀 Defeat... {p} won.",
		es = "💀 Derrota... {p} ganó.",
	},
	fight_other = { ["pt-br"] = "{p} venceu!", en = "{p} won!", es = "¡{p} ganó!" },
	arena_stats = {
		["pt-br"] = "Vitórias {w}  •  Derrotas {l}  •  {s}",
		en = "Wins {w}  •  Losses {l}  •  {s}",
		es = "Victorias {w}  •  Derrotas {l}  •  {s}",
	},
	cooldown_s = { ["pt-br"] = "Cooldown {n}s", en = "Cooldown {n}s", es = "Cooldown {n}s" },
	challenge_popup = {
		["pt-br"] = "{p} te desafiou para o GIANT CLASH!\nForça dele: {n}  •  Você perde 2 comidas do pátio se perder.",
		en = "{p} challenged you to GIANT CLASH!\nTheir power: {n}  •  You lose 2 yard foods if you lose.",
		es = "¡{p} te desafió a GIANT CLASH!\nSu fuerza: {n}  •  Pierdes 2 comidas del patio si pierdes.",
	},
	drop_card = {
		["pt-br"] = "{f} ({r}) — segure {n}s",
		en = "{f} ({r}) — hold {n}s",
		es = "{f} ({r}) — aguanta {n}s",
	},
	evolved_banner = {
		["pt-br"] = "✨ SEU GIGANTE EVOLUIU: {s}! ✨",
		en = "✨ YOUR GIANT EVOLVED: {s}! ✨",
		es = "✨ ¡TU GIGANTE EVOLUCIONÓ: {s}! ✨",
	},
	level_label = { ["pt-br"] = "{s} Nv. {n} (x{m})", en = "{s} Lv. {n} (x{m})", es = "{s} Nv. {n} (x{m})" },
	rebirth_btn = { ["pt-br"] = "REBIRTH (Nv.{n})", en = "REBIRTH (Lv.{n})", es = "REBIRTH (Nv.{n})" },
	daily_btn = { ["pt-br"] = "DIÁRIO ({n}/7)", en = "DAILY ({n}/7)", es = "DIARIO ({n}/7)" },
	shield_active = { ["pt-br"] = "ESCUDO ATIVO: {t}", en = "SHIELD ACTIVE: {t}", es = "ESCUDO ACTIVO: {t}" },
	collection_count = {
		["pt-br"] = "Comidas descobertas: {n} de {m}",
		en = "Foods discovered: {n} of {m}",
		es = "Comidas descubiertas: {n} de {m}",
	},
	backpack_n = { ["pt-br"] = "MOCHILA ({n})", en = "BACKPACK ({n})", es = "MOCHILA ({n})" },
	yard_n = { ["pt-br"] = "PÁTIO ({n} / {m})", en = "YARD ({n} / {m})", es = "PATIO ({n} / {m})" },
	food_row = {
		["pt-br"] = "{r}  ·  {x} XP  ·  +{c} $/s",
		en = "{r}  ·  {x} XP  ·  +{c} $/s",
		es = "{r}  ·  {x} XP  ·  +{c} $/s",
	},
	owner_sign = { ["pt-br"] = "GIGANTE DE {p}", en = "{p}'S GIANT", es = "GIGANTE DE {p}" },
	boss_score = {
		["pt-br"] = "BOSS FAMINTO\n{p}: {n} pts",
		en = "HUNGRY BOSS\n{p}: {n} pts",
		es = "JEFE HAMBRIENTO\n{p}: {n} pts",
	},
	combo = { ["pt-br"] = "COMBO x{n}!", en = "COMBO x{n}!", es = "¡COMBO x{n}!" },
}

function Locale.normalize(localeId: string?): string
	local id = string.lower(localeId or "")
	if string.sub(id, 1, 2) == "pt" then
		return "pt-br"
	end
	if string.sub(id, 1, 2) == "es" then
		return "es"
	end
	if string.sub(id, 1, 2) == "en" then
		return "en"
	end
	return Locale.Default
end

function Locale.of(player: Player?): string
	if player then
		return Locale.normalize(player.LocaleId)
	end
	if RunService:IsClient() and Players.LocalPlayer then
		return Locale.normalize(Players.LocalPlayer.LocaleId)
	end
	return Locale.Default
end

-- Traduz string estática (fonte PT). Devolve o original se não houver tradução.
function Locale.t(text: string, locale: string?): string
	local loc = locale or Locale.of(nil)
	if loc == "pt-br" then
		return text
	end
	local e = Locale.Exact[text]
	if e then
		return (e :: any)[loc] or text
	end
	return text
end

-- Monta mensagem dinâmica a partir de chave + params ({p}, {f}, {n}...). Params string são traduzidos por Locale.t.
-- Nome da raridade no idioma do jogador (os IDs Common/Rare... são internos, em inglês).
local RARITY_NAMES: { [string]: { [string]: string } } = {
	["pt-br"] = {
		Common = "Comum",
		Uncommon = "Incomum",
		Rare = "Raro",
		Epic = "Épico",
		Legendary = "Lendário",
		Mythic = "Mítico",
		Secret = "Secreto",
	},
	es = {
		Common = "Común",
		Uncommon = "Poco común",
		Rare = "Raro",
		Epic = "Épico",
		Legendary = "Legendario",
		Mythic = "Mítico",
		Secret = "Secreto",
	},
}

function Locale.rarity(id: string, locale: string?): string
	local names = RARITY_NAMES[locale or Locale.of(nil)]
	return (names and names[id]) or id
end

function Locale.fmt(key: string, locale: string?, params: { [string]: any }?): string
	local loc = locale or Locale.of(nil)
	local tpl = Locale.Templates[key]
	local text = tpl and ((tpl :: any)[loc] or tpl["pt-br"]) or key
	if params then
		text = string.gsub(text, "{(%w+)}", function(k)
			local v = params[k]
			if v == nil then
				return "{" .. k .. "}"
			end
			if type(v) == "string" then
				return Locale.t(v, loc)
			end
			return tostring(v)
		end)
	end
	return text
end

-- Payload para Remotes: o cliente formata no idioma dele.
function Locale.msg(key: string, params: { [string]: any }?, color: Color3?): { [string]: any }
	return { key = key, params = params or {}, color = color }
end

return Locale
