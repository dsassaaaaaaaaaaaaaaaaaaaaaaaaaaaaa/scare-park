--!strict
-- AnalyticsService: лог событий с ПЕРВОГО дня (правило №5 из рекомендаций).
-- Roblox AnalyticsService (funnel/economy events) + свои кастомные события.
-- Список событий — docs/plan/07-analytics.md.

local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsService = {}

function AnalyticsService.LogEvent(player: Player, eventName: string, data: { [string]: any }?)
	-- TODO: маппинг на RobloxAnalytics:LogCustomEvent / LogFunnelStepEvent
	local _ = RobloxAnalytics
	print(`[Analytics] {player.Name}: {eventName}`)
end

function AnalyticsService.Init()
	print("[AnalyticsService] init")
end

return AnalyticsService
