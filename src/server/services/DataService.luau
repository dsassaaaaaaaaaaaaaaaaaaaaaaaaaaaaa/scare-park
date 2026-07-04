--!strict
-- DataService: профиль игрока через ProfileStore. Делается ПЕРВЫМ (Неделя 1).
-- TODO: подключить ProfileStore — https://github.com/MadStudioRoblox/ProfileStore
--   (положить модуль в src/server/lib/ProfileStore.luau или через Wally)
-- Жёсткие правила: dataVersion + миграции; BindToClose с принудительным сейвом;
-- валюта/инвентарь только на сервере.

local Players = game:GetService("Players")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local DataService = {}

-- Шаблон профиля (02-programming.md, схема данных)
DataService.ProfileTemplate = {
	dataVersion = 1,
	coins = 0,
	courage = 0,
	monsters = {} :: { { id: string, rarity: string, mutation: string?, legendPoints: number, primeStars: number } },
	plot = {}, -- сериализованные постройки (НЕ инстансы)
	rank = { tier = 1, step = 0, points = 0, seasonPeak = 0, lockTier = 0 },
	pass = { xp = 0, premium = false, claimed = {} },
	offers = { firstPurchaseDone = false, ladder = 0 },
	fusion = { slots = {}, finishAt = 0 }, -- os.time()
	stats = { scares = 0, visits = 0, escapes = 0 },
	lastSeenAt = 0, -- для офлайн-дохода
}

local profiles: { [Player]: any } = {}

-- Миграции схемы: profile.dataVersion → следующая версия
local migrations: { [number]: (profile: any) -> () } = {
	-- [1] = function(profile) ... profile.dataVersion = 2 end,
}

local function migrate(profile: any)
	while migrations[profile.dataVersion] do
		migrations[profile.dataVersion](profile)
	end
end

function DataService.GetProfile(player: Player): any?
	return profiles[player]
end

local function onPlayerAdded(player: Player)
	-- TODO: ProfileStore:StartSessionAsync, затем migrate(), затем profiles[player] = profile
	-- До подключения ProfileStore — заглушка в памяти (НЕ деплоить в прод!)
	local profile = table.clone(DataService.ProfileTemplate)
	migrate(profile)
	profiles[player] = profile
end

local function onPlayerRemoving(player: Player)
	-- TODO: profile:EndSession()
	profiles[player] = nil
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Правило №7: принудительное сохранение при выключении сервера
	game:BindToClose(function()
		-- TODO: EndSession для всех активных профилей; ProfileStore делает это сам,
		-- но оставляем хук для явного контроля
	end)

	print(`[DataService] init, autosave every {GameConfig.Server.AutosaveIntervalSeconds}s (via ProfileStore)`)
end

return DataService
