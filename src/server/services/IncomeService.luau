--!strict
-- IncomeService: доход с аттракционов — онлайн-тик + офлайн-начисление при входе.
-- Фиксы из docs/economy/README.md:
--   флаг №4: дробный остаток копится (иначе новичок с < 6 монет/мин получал 0 онлайн);
--   флаг №5: офлайн-кап 8 ч В СУТКИ, а не на каждое окно отсутствия
--            (2–3 захода в день давали 16–24 ч оплаченного офлайна → инфляция
--            и уравнивание казуала с хардкором).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local IncomeLogic = require(ReplicatedStorage.Shared.logic.IncomeLogic)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local IncomeService = {}

function IncomeService.GetIncomePerMinute(data: any): number
	return IncomeLogic.GetIncomePerMinute(data, GameConfig, MonsterCatalog)
end

local function grantOffline(player: Player)
	local data = DataService.WaitFor(player)
	if data == nil then
		return
	end

	local grant = IncomeLogic.GrantOffline(data, GameConfig, MonsterCatalog, os.time())
	if grant.credited > 0 then
		Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
		AnalyticsService.LogEconomy(player, "Source", "coins", grant.credited, "offline_income")
	end
	-- TODO UI: приветственный экран «Пока тебя не было: +N монет»
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
			task.wait(GameConfig.Income.TickSeconds)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					local raw = IncomeService.GetIncomePerMinute(data) * (GameConfig.Income.TickSeconds / 60)
					local credited = IncomeLogic.Credit(data, raw)
					if credited > 0 then
						Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
						AnalyticsService.LogEconomy(player, "Source", "coins", credited, "online_income")
					end
				end
			end
		end
	end)

	print("[IncomeService] init")
end

return IncomeService
