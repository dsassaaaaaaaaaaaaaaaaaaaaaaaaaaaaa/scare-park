--!strict
-- 🔒 СЕКРЕТЫ. Живёт только в ServerScriptService — клиент этого не видит НИКОГДА.
-- Правило №6 из 02-programming.md: рецепты и шансы не попадают в ReplicatedStorage.

local SecretConfig = {}

-- Шансы мутаций при фьюжне (сумма < 1; остаток — без мутации)
SecretConfig.MutationChances = {
	Neon = 0.10,
	Shadow = 0.04,
	BloodMoon = 0.015,
	Rainbow = 0.005,
}

-- Секретные рецепты: точная комбинация 4 монстров → уникальный босс.
-- Ключ — отсортированные id через "+". Не публикуются, комьюнити ищет само.
-- ⚠️ Правило (economy флаг №3): ингредиенты только Epic+ — иначе Nightmare за копейки
-- утекает в TikTok в день релиза («АнтиМим» из 4 Common стоил 100 монет).
SecretConfig.FusionRecipes = {
	-- «Симфония Криков»: Дирижёр Тьмы (Legendary) + 3 Epic
	["dark_conductor+doll_mia+granny_pies+mirror_double"] = "scream_symphony",
	-- «АнтиМим»: 4 Зеркальных Двойника (Epic) — «копия копий рождает пустоту»
	["mirror_double+mirror_double+mirror_double+mirror_double"] = "anti_mime",
}

return SecretConfig
