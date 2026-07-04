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

-- === Фьюжн-машина (00-design-doc §3) ===
GameConfig.Fusion = {
	SlotCount = 4,
	-- Таймеры по доминантной редкости результата, в секундах
	TimersByRarity = {
		Common = 10 * 60,
		Rare = 10 * 60,
		Epic = 10 * 60,
		Legendary = 30 * 60,
		Mythic = 30 * 60,
		Nightmare = 2 * 60 * 60,
		Secret = 2 * 60 * 60,
	},
	SpeedupRobuxPer3Min = 1, -- ~1 R$ за 3 минуты
}

-- === Мутации: множители дохода и очков страха (шансы — на сервере!) ===
GameConfig.Mutations = {
	Neon = { multiplier = 1.5 },
	Shadow = { multiplier = 3 },
	BloodMoon = { multiplier = 6 },
	Rainbow = { multiplier = 10 },
}

-- === Магазин ===
GameConfig.Shop = {
	RotationSeconds = 300, -- витрина обновляется каждые 5 минут, сид = floor(os.time()/300)
	SlotCount = 5,
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

-- === Участок ===
GameConfig.Plot = {
	StartAttractionSlots = 3,
	MaxAttractionSlots = 10,
}

-- === Кража/переманивание ===
GameConfig.Steal = {
	CooldownHours = 6, -- "раз в N часов" — стартовое значение, тюнить по данным
}

-- === Монетизация: цены в Robux (00-design-doc §6.1) ===
-- ⚠️ С Managed Pricing реальные цены задаются в дашборде Roblox; здесь — референс для UI.
GameConfig.Products = {
	FirstScareOffer = { price = 5, type = "DevProduct" },
	ScarePass = { price = 399, type = "DevProduct" },
	ScarePassDeluxe = { price = 799, type = "DevProduct" },
	NightmarePass = { price = 499, type = "DevProduct", minRankTier = 3 }, -- только с Gold+
	ExtraAttractionSlot = { price = 249, type = "Gamepass" },
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
