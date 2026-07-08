--!strict
-- Каталог монстров запуска (00-design-doc §3, ростер).
-- Публичные данные: имя, редкость, механика. Доходные коэффициенты можно тюнить здесь.
-- Nightmare/Secret-монстры и их рецепты — ТОЛЬКО на сервере.

export type MonsterDef = {
	id: string,
	name: string,
	rarity: string,
	scareMechanic: string, -- ключ механики, реализуется в ScareService/клиентских эффектах
	baseIncome: number, -- монет/мин на аттракционе
	baseScare: number, -- базовые очки страха за срабатывание
}

local MonsterCatalog: { [string]: MonsterDef } = {
	boo_balloon = {
		id = "boo_balloon",
		name = "Бу-Шарик",
		rarity = "Common",
		scareMechanic = "chase_pop",
		baseIncome = 1,
		baseScare = 5,
	},
	intern_skeleton = {
		id = "intern_skeleton",
		name = "Скелет-Стажёр",
		rarity = "Common",
		scareMechanic = "clumsy_rattle",
		baseIncome = 1,
		baseScare = 5,
	},
	rat_in_coat = {
		id = "rat_in_coat",
		name = "Крыса в Пальто",
		rarity = "Common",
		scareMechanic = "fake_npc_follow",
		baseIncome = 1,
		baseScare = 5,
	},
	jelly = {
		id = "jelly",
		name = "Желешка",
		rarity = "Common",
		scareMechanic = "ceiling_splat",
		baseIncome = 1,
		baseScare = 5,
	},
	mime = {
		id = "mime",
		name = "Мим Молчун",
		rarity = "Common",
		scareMechanic = "move_when_unseen",
		baseIncome = 1,
		baseScare = 5,
	},
	giggle_clown = {
		id = "giggle_clown",
		name = "Клоун Хихик",
		rarity = "Rare",
		scareMechanic = "approaching_laugh",
		baseIncome = 3,
		baseScare = 12,
	},
	stalker_gnome = {
		id = "stalker_gnome",
		name = "Гном-Сталкер",
		rarity = "Rare",
		scareMechanic = "blink_teleport",
		baseIncome = 3,
		baseScare = 12,
	},
	manny_mannequin = {
		id = "manny_mannequin",
		name = "Манекен Мэнни",
		rarity = "Rare",
		scareMechanic = "hidden_in_group",
		baseIncome = 3,
		baseScare = 12,
	},
	shadow_jumper = {
		id = "shadow_jumper",
		name = "Тень-Прыгун",
		rarity = "Rare",
		scareMechanic = "lights_out_jump",
		baseIncome = 3,
		baseScare = 12,
	},
	granny_pies = {
		id = "granny_pies",
		name = "Бабушка с Пирожками",
		rarity = "Epic",
		scareMechanic = "kind_bait",
		baseIncome = 8,
		baseScare = 30,
	},
	doll_mia = {
		id = "doll_mia",
		name = "Кукла Мия",
		rarity = "Epic",
		scareMechanic = "whisper_nickname",
		baseIncome = 8,
		baseScare = 30,
	},
	mirror_double = {
		id = "mirror_double",
		name = "Зеркальный Двойник",
		rarity = "Epic",
		scareMechanic = "avatar_copy",
		baseIncome = 8,
		baseScare = 30,
	},
	dark_conductor = {
		id = "dark_conductor",
		name = "Дирижёр Тьмы",
		rarity = "Legendary",
		scareMechanic = "sync_scream_volley",
		baseIncome = 20,
		baseScare = 75,
	},
	light_eater = {
		id = "light_eater",
		name = "Пожиратель Света",
		rarity = "Legendary",
		scareMechanic = "total_darkness_eyes",
		baseIncome = 20,
		baseScare = 75,
	},
	carousel_master = {
		id = "carousel_master",
		name = "Хозяин Карусели",
		rarity = "Mythic",
		scareMechanic = "boss_carousel",
		baseIncome = 50,
		baseScare = 180,
	},
}

return MonsterCatalog
