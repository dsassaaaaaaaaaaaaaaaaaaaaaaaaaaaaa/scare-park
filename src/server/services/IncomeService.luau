--!strict
-- IncomeService: доход с аттракционов — онлайн-тик + офлайн-начисление при входе
-- (модель Grow a Garden: «урожай» копится, пока тебя нет).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local IncomeService = {}

local TICK_SECONDS = 10
local OFFLINE_CAP_HOURS = 8 -- дальше доход не копится — причина зайти
local OFFLINE_RATE = 0.5 -- офлайн-доход = 50% от онлайн (онлайн должен быть выгоднее)

--- Доход игрока в минуту: сумма по монстрам, приставленным к слотам участка
function IncomeService.GetIncomePerMinute(data: any): number
	local total = 0
	for _, item in data.plot do
		if item.monsterUid then
			for _, monster in data.monsters do
				if monster.uid == item.monsterUid then
					local def = MonsterCatalog[monster.id]
					local base = if def then def.baseIncome else 1
					local mutation = monster.mutation and GameConfig.Mutations[monster.mutation]
					local mult = if mutation then mutation.multiplier else 1
					total += base * mult
					break
				end
			end
		end
	end
	return total
end

local function grantOffline(player: Player)
	local data = DataService.WaitFor(player)
	if data == nil or data.lastSeenAt == 0 then
		return
	end
	local awaySeconds = math.min(os.time() - data.lastSeenAt, OFFLINE_CAP_HOURS * 3600)
	if awaySeconds <= 0 then
		return
	end
	local income = math.floor(IncomeService.GetIncomePerMinute(data) * (awaySeconds / 60) * OFFLINE_RATE)
	if income > 0 then
		DataService.AddCurrency(player, "coins", income)
		Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
		-- TODO UI: приветственный экран «Пока тебя не было: +N монет»
	end
end

function IncomeService.Init()
	if not GameConfig.Flags.OfflineIncomeEnabled then
		print("[IncomeService] disabled by flag")
		return
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(grantOffline, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(grantOffline, player)
	end

	-- онлайн-тик
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					local income = math.floor(IncomeService.GetIncomePerMinute(data) * (TICK_SECONDS / 60))
					if income > 0 then
						DataService.AddCurrency(player, "coins", income)
						Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
					end
				end
			end
		end
	end)

	print("[IncomeService] init")
end

return IncomeService
