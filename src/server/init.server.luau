--!strict
-- Точка входа сервера: инициализация сервисов в правильном порядке.
-- DataService всегда первый (все остальные зависят от профилей).

local services = script.services

local initOrder = {
	require(services.DataService),
	require(services.MapService),
	require(services.PlotService),
	require(services.ShopService),
	require(services.FusionService),
	require(services.ScareService),
	require(services.IncomeService),
	require(services.MonsterRuntime),
	require(services.RankService),
	require(services.MonetizationService),
	require(services.AnalyticsService),
}

for _, service in initOrder do
	local ok, err = pcall(service.Init)
	if not ok then
		warn(`[Server] service init failed: {err}`)
	end
end

print("[Server] Scare Park started")
