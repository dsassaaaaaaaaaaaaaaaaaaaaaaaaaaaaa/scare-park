--!strict
-- DataService: профили игроков через ProfileStore (session locking, автосейв, анти-дюп).
-- Все остальные сервисы получают данные ТОЛЬКО через DataService.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PROFILE_STORE_NAME = "PlayerData_v1"

local DataService = {}

export type MonsterEntry = {
	uid: string, -- уникальный id экземпляра
	id: string, -- id из MonsterCatalog
	rarity: string,
	mutation: string?,
	legendPoints: number,
	primeStars: number,
}

-- Шаблон профиля (02-programming.md). ProfileStore:Reconcile() дозаполняет новые поля.
DataService.ProfileTemplate = {
	dataVersion = 1,
	coins = 50, -- стартовый капитал (плюс бесплатный Common ниже) — economy §4 п.12
	courage = 0,
	monsters = {
		-- стартовый монстр: первая покупка в первые 2 минуты, но парк не пустой
		{ uid = "m1", id = "boo_balloon", rarity = "Common", mutation = nil, legendPoints = 0, primeStars = 0 },
	} :: { MonsterEntry },
	plot = {} :: { { itemId: string, slot: number, monsterUid: string? } },
	plotSlots = 3, -- куплено слотов аттракционов (рост за монеты, economy §4 п.10)
	rank = { tier = 1, step = 0, points = 0, seasonPeak = 0, lockTier = 0 },
	pass = { xp = 0, premium = false, claimed = {} },
	offers = { firstPurchaseDone = false, ladder = 0 },
	fusion = { slots = {} :: { string }, finishAt = 0, resultUid = "" },
	stats = { scares = 0, visits = 0, escapes = 0 },
	purchaseHistory = {} :: { [string]: boolean }, -- PurchaseId → выдано (идемпотентность)
	lastSeenAt = 0, -- os.time() для офлайн-дохода
	nextMonsterUid = 2,
	-- Магазин: сток витрины и дневные лимиты (economy §4 п.3–4)
	shopState = {
		rotationSeed = 0, -- сид, для которого валидны boughtSlots
		boughtSlots = {} :: { [string]: number }, -- tostring(slotIndex) → куплено раз
		day = 0, -- UTC-день для дневных лимитов
		boughtByRarity = {} :: { [string]: number },
	},
	-- Доход: дробный остаток тика и суточный кап офлайна (economy §4 п.11, 16)
	income = {
		remainder = 0,
		offlineDay = 0, -- UTC-день
		offlinePaidSeconds = 0, -- оплачено офлайн-секунд за offlineDay
	},
	fusionSkipsToday = { day = 0, count = 0 }, -- лимит платных ускорений (economy §4 п.14)
}

-- Миграции: dataVersion N → N+1. Каждая функция ОБЯЗАНА поднять dataVersion.
local migrations: { [number]: (profile: any) -> () } = {
	-- [1] = function(data) data.newField = 0; data.dataVersion = 2 end,
}

local store: any? = nil
if not RunService:IsStudio() then
	local ProfileStore = require(script.Parent.Parent.lib.ProfileStore)
	store = ProfileStore.New(PROFILE_STORE_NAME, DataService.ProfileTemplate)
end

local profiles: { [Player]: any } = {}
local lazyStudioProfilesWarned: { [Player]: boolean } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function makeStudioFallbackProfile(player: Player): any
	local afterSave = Instance.new("BindableEvent")
	local sessionEnd = Instance.new("BindableEvent")
	local profile = {
		Data = deepCopy(DataService.ProfileTemplate),
		OnAfterSave = afterSave.Event,
		OnSessionEnd = sessionEnd.Event,
	}
	function profile:AddUserId(_userId: number) end
	function profile:Reconcile() end
	function profile:IsActive()
		return player.Parent == Players
	end
	function profile:Save()
		afterSave:Fire()
	end
	function profile:EndSession()
		sessionEnd:Fire()
		afterSave:Destroy()
		sessionEnd:Destroy()
	end
	return profile
end

local function migrate(data: any)
	while migrations[data.dataVersion] do
		local before = data.dataVersion
		migrations[before](data)
		assert(data.dataVersion > before, `миграция {before} не подняла dataVersion`)
	end
end

--- Данные игрока или nil, если профиль ещё грузится/не загрузился
function DataService.Get(player: Player): any?
	local profile = profiles[player]
	if profile == nil and RunService:IsStudio() and player.Parent == Players then
		if not lazyStudioProfilesWarned[player] then
			warn(`[DataService] lazy-created in-memory Studio profile for {player.Name}`)
			lazyStudioProfilesWarned[player] = true
		end
		profile = makeStudioFallbackProfile(player)
		profiles[player] = profile
	end
	return profile and profile.Data or nil
end

--- Ждёт загрузку профиля (для сервисов, стартующих при PlayerAdded)
function DataService.WaitFor(player: Player, timeout: number?): any?
	local deadline = os.clock() + (timeout or 15)
	while os.clock() < deadline do
		local data = DataService.Get(player)
		if data then
			return data
		end
		if player.Parent == nil then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

--- Профиль активен и изменения гарантированно сохранятся
function DataService.IsActive(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

--- Сохранение с ПОДТВЕРЖДЕНИЕМ записи в DataStore (для монетизации).
--- Блокирует до OnAfterSave или таймаута. true = данные точно на диске.
function DataService.SaveConfirmed(player: Player, timeout: number?): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end

	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)
	profile:Save()

	local deadline = os.clock() + (timeout or 10)
	while not saved and os.clock() < deadline and profile:IsActive() do
		task.wait(0.1)
	end
	connection:Disconnect()
	return saved
end

--- Выдать новый uid монстра
function DataService.NextMonsterUid(data: any): string
	local uid = `m{data.nextMonsterUid}`
	data.nextMonsterUid += 1
	return uid
end

--- Изменение валюты. delta может быть отрицательной; уход в минус запрещён.
function DataService.AddCurrency(player: Player, currency: "coins" | "courage", delta: number): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	local newValue = data[currency] + delta
	if newValue < 0 then
		return false
	end
	data[currency] = newValue
	return true
end

local function onPlayerAdded(player: Player)
	local profile: any? = nil
	if RunService:IsStudio() then
		profile = profiles[player]
		if profile == nil then
			warn(`[DataService] using in-memory Studio profile for {player.Name}`)
			profile = makeStudioFallbackProfile(player)
		end
	else
		local ok, profileOrErr = pcall(function()
			return (store :: any):StartSessionAsync(`{player.UserId}`, {
				Cancel = function()
					return player.Parent ~= Players
				end,
			})
		end)
		profile = if ok then profileOrErr else nil
		if not ok then
			warn(`[DataService] ProfileStore failed for {player.Name}: {profileOrErr}`)
		end
	end

	if profile == nil then
		-- Сессию перехватил другой сервер или DataStore недоступен — не пускаем без данных
		player:Kick("Не удалось загрузить данные. Перезайди через минуту.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile() -- дозаполнить новые поля из шаблона
	migrate(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Данные загружены на другом сервере.")
	end)

	if player.Parent == Players then
		profiles[player] = profile
		-- Снапшот для HUD (валюты, монстры, фьюжн) — только отображение
		Remotes.GetEvent(Remotes.Names.ProfileLoaded):FireClient(player, {
			coins = profile.Data.coins,
			courage = profile.Data.courage,
			monsters = profile.Data.monsters,
			fusion = profile.Data.fusion,
			plot = profile.Data.plot,
			plotSlots = profile.Data.plotSlots,
		})
	else
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	lazyStudioProfilesWarned[player] = nil
	local profile = profiles[player]
	if profile then
		profile.Data.lastSeenAt = os.time()
		profile:EndSession()
	end
end

--- Снапшот профиля для HUD (только отображение)
function DataService.Snapshot(player: Player): any?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	return {
		coins = data.coins,
		courage = data.courage,
		monsters = data.monsters,
		fusion = data.fusion,
		plot = data.plot,
		plotSlots = data.plotSlots,
	}
end

function DataService.Init()
	Remotes.GetFunction(Remotes.Names.GetSnapshot).OnServerInvoke = function(player)
		return DataService.Snapshot(player)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- BindToClose обрабатывает сам ProfileStore (IsClosing), но lastSeenAt проставим явно
	game:BindToClose(function()
		for _, profile in profiles do
			profile.Data.lastSeenAt = os.time()
		end
	end)
	print(`[DataService] init, store={PROFILE_STORE_NAME}, mock={RunService:IsStudio()}`)
end

return DataService
