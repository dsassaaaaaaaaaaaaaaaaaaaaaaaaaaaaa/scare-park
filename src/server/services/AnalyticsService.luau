--!strict
-- AnalyticsService: события с первого дня (07-analytics.md).
-- Roblox AnalyticsService: воронка онбординга + кастомные события.
-- Кастомные события дешёвые — логируем щедро, фильтровать можно потом.

local RobloxAnalytics = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local AnalyticsService = {}

-- Шаги воронки онбординга (FunnelStep должен быть стабильным!)
AnalyticsService.OnboardingSteps = {
	Joined = 1,
	FirstShopOpen = 2,
	FirstMonsterBought = 3,
	FirstMonsterPlaced = 4,
	FirstFusionStarted = 5,
	FirstFusionClaimed = 6,
	FirstVisit = 7,
}

local sessionIds: { [Player]: string } = {}

function AnalyticsService.LogOnboardingStep(player: Player, step: number, stepName: string)
	local ok, err = pcall(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
	if not ok then
		warn(`[Analytics] onboarding step failed: {err}`)
	end
end

function AnalyticsService.LogEvent(player: Player, eventName: string, value: number?)
	local ok, err = pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1)
	end)
	if not ok then
		warn(`[Analytics] custom event failed: {err}`)
	end
end

--- Экономика: источники и стоки монет (для баланса инфляции)
function AnalyticsService.LogEconomy(
	player: Player,
	flowType: "Source" | "Sink",
	currency: string,
	amount: number,
	sku: string
)
	local ok, err = pcall(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			if flowType == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			currency,
			amount,
			0, -- endingBalance проставит вызывающий сервис при желании
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			sku
		)
	end)
	if not ok then
		warn(`[Analytics] economy event failed: {err}`)
	end
end

function AnalyticsService.Init()
	Players.PlayerAdded:Connect(function(player)
		sessionIds[player] = game:GetService("HttpService"):GenerateGUID(false)
		AnalyticsService.LogOnboardingStep(player, AnalyticsService.OnboardingSteps.Joined, "Joined")
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionIds[player] = nil
	end)
	print("[AnalyticsService] init")
end

return AnalyticsService
