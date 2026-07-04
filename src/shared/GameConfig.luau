--!strict
-- GameConfig: ВСЕ балансовые числа проекта — в одном месте (правило из 02-programming.md).
-- ⚠️ Этот модуль реплицируется клиенту. НИКАКИХ секретов:
-- рецепты фьюжна и шансы мутаций живут на сервере (src/server/config/SecretConfig.luau).

local GameConfig = {}

-- === Валюты ===
GameConfig.Currencies = {
	Coins = "coins", -- валюта владельца парка
	Courage = "courage", -- валюта посетителя
}

-- === Редкости ===
GameConfig.Rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Nightmare", "Secret" }

-- === Фьюжн-машина (00-design-doc §3; баланс — docs/economy/README.md §4) ===
GameConfig.Fusion = {
	SlotCount = 4,
	-- Правило: только 4 монстра ОДНОЙ редкости → результат на 1 выше (анти-микс-эксплойт)
	-- Обычным фьюжном выше Mythic не подняться; Nightmare/Secret — только секретные рецепты
	MaxRegularResultRarity = "Mythic",
	-- Таймеры по редкости РЕЗУЛЬТАТА, в секундах (economy §4 п.7)
	TimersByRarity = {
		Rare = 5 * 60, -- «вкус» внутри сессии
		Epic = 2 * 60 * 60, -- дневной слот машины
		Legendary = 6 * 60 * 60,
		Mythic = 8 * 60 * 60, -- ночной слот
		Nightmare = 8 * 60 * 60,
		Secret = 8 * 60 * 60,
	},
	-- Плата монетами по редкости РЕЗУЛЬТАТА (economy §4 п.8): гейт + главный синк инфляции
	FeesByRarity = {
		Rare = 15,
		Epic = 250,
		Legendary = 7500,
		Mythic = 90000,
		Nightmare = 150000,
		Secret = 150000,
	},
	SpeedupRobuxPer3Min = 1, -- ~1 R$ за 3 минуты
	PaidSkipsPerDay = 5, -- страховка для аудитории 9–16 (economy §4 п.14)
}

-- === Мутации: множители дохода и очков страха (шансы — на сервере!) ===
-- Потолок ×6: Rainbow ×10 был лотерейным джекпотом, ломавшим кривую (economy флаг №7)
GameConfig.Mutations = {
	Neon = { multiplier = 1.5 },
	Shadow = { multiplier = 2.5 },
	BloodMoon = { multiplier = 4 },
	Rainbow = { multiplier = 6 },
}

-- === Магазин (economy §4 п.1–4) ===
GameConfig.Shop = {
	RotationSeconds = 300, -- витрина обновляется каждые 5 минут, сид = floor(os.time()/300)
	SlotCount = 5,
	StockPerSlot = 1, -- позицию витрины можно купить 1 раз за ротацию (анти-скупка)
	-- Дневные лимиты покупок по редкости — главный гейт снабжения фьюжн-пирамиды
	DailyBuyCap = {
		Common = 12,
		Rare = 5,
		Epic = 1,
		Legendary = 1,
	},
	-- Цены: Mythic НЕ продаётся (только фьюжн)
	PriceByRarity = {
		Common = 25,
		Rare = 140,
		Epic = 700,
		Legendary = 4500,
	},
	-- Веса ротации: E/L — редкий праздник, не конвейер
	WeightByRarity = {
		Common = 100,
		Rare = 18,
		Epic = 0.6,
		Legendary = 0.2,
	},
	BuyCooldownSeconds = 0.3, -- серверный rate-limit на запросы покупки
}

-- === Ранговая лестница (00-design-doc §5.1) ===
GameConfig.Ranks = {
	StepsPerTier = 3,
	Tiers = {
		{ name = "Bronze", pointsPerStep = 250 },
		{ name = "Silver", pointsPerStep = 250 },
		{ name = "Gold", pointsPerStep = 400 },
		{ name = "Diamond", pointsPerStep = 500 },
		{ name = "Mythic", pointsPerStep = 600 },
		{ name = "Legendary", pointsPerStep = 750 },
		{ name = "Masters", pointsPerStep = 1000 },
		{ name = "Nightmare", pointsPerStep = 0 }, -- без ступеней, глобальный лидерборд
	},
	SeasonLengthDays = 28,
	SoftResetSteps = 6, -- мягкий сброс: −6 ступеней от пика сезона
	MatchmakingTierRange = 1, -- посетитель матчится ±1 тир
}

-- === Храбрость и испуг (00-design-doc §4) ===
GameConfig.Scare = {
	-- урон храбрости в ПРОЦЕНТАХ от максимума (честно для всех уровней)
	TourModeVisits = 5, -- экскурсионный режим: первые N визитов храбрость не падает ниже 10%
	TourModeCourageFloor = 0.10,
	LowTierScoreMultiplier = 0.1, -- испуг посетителя сильно ниже тира почти не даёт очков
	EscapeBeforeMidpointScore = 0, -- сбежал до середины → владельцу 0 очков (анти-непроходимые парки)
}

-- === Престиж монстров (00-design-doc §5.4) ===
GameConfig.Prestige = {
	LegendPerPrimeStar = 1000,
	ScareBonusPerStar = 0.02, -- +2% к очкам страха за Prime-звезду
}

-- === Участок (economy §4 п.10: слоты только за монеты, gamepass удалён — анти-P2W) ===
GameConfig.Plot = {
	StartAttractionSlots = 3,
	MaxAttractionSlots = 10,
	-- Цена слота N (4..10): ранние — цели первых сессий, поздние — недельные цели и синк
	SlotCosts = {
		[4] = 400,
		[5] = 1500,
		[6] = 6000,
		[7] = 25000,
		[8] = 75000,
		[9] = 150000,
		[10] = 400000,
	},
}

-- === Доход (economy §4 п.11, 16) ===
GameConfig.Income = {
	TickSeconds = 10,
	OfflineRate = 0.5, -- офлайн = 50% от онлайн: онлайн должен быть выгоднее
	OfflineDailyCapHours = 8, -- кап В СУТКИ (UTC), не на окно отсутствия (анти-инфляция, флаг №5)
}

-- === Кража/переманивание ===
GameConfig.Steal = {
	CooldownHours = 6, -- "раз в N часов" — стартовое значение, тюнить по данным
}

-- === Монетизация: цены в Robux (00-design-doc §6.1) ===
-- ⚠️ С Managed Pricing реальные цены задаются в дашборде Roblox; здесь — референс для UI.
GameConfig.Products = {
	-- Оффер: ТОЛЬКО косметика + жетоны (economy §4 п.15: «×2 доход» была силой за деньги)
	FirstScareOffer = { price = 5, type = "DevProduct" }, -- скин + 3 жетона ускорения + рамка
	ScarePass = { price = 399, type = "DevProduct" },
	ScarePassDeluxe = { price = 799, type = "DevProduct" },
	NightmarePass = { price = 499, type = "DevProduct", minRankTier = 3 }, -- только с Gold+
	-- ExtraAttractionSlot удалён: слот = доход навсегда = P2W (economy флаг №8)
	VipForever = { price = 399, type = "Gamepass" },
	VipSubscription = { price = 99, type = "Subscription" },
}

-- === Сервер ===
GameConfig.Server = {
	MaxPlayers = 8,
	AutosaveIntervalSeconds = 45,
}

-- === Feature flags (правило: каждая крупная фича выключается флагом) ===
GameConfig.Flags = {
	FusionEnabled = true,
	VisitingEnabled = true,
	StealEnabled = false, -- Этап 2
	RanksEnabled = false, -- Этап 2 (упрощённые) / Этап 3 (полные)
	ScarePassEnabled = false, -- Этап 3
	MonetizationEnabled = false, -- включить после теста ProcessReceipt
	OfflineIncomeEnabled = true,
}

return GameConfig
