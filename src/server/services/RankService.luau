--!strict
-- RankService / SeasonService: очки ранга, rank lock, сезонный сброс
-- по глобальному таймстампу сезона (одинаков на всех серверах).
-- Этап 2 (упрощённая лестница 5 тиров) → Этап 3 (полная).

local RankService = {}

function RankService.Init()
	-- TODO Этап 2–3:
	-- 1. Начисление очков: испуги, защита от кражи, ивенты
	-- 2. Rank lock: пересёк мажорный тир → lockTier в профиле
	-- 3. Сезон: SEASON_START (глобальная константа) + GameConfig.Ranks.SeasonLengthDays
	-- 4. Мягкий сброс −6 ступеней от seasonPeak; Scare Boost ×2–×3 первую неделю
	print("[RankService] init (disabled by flag)")
end

return RankService
