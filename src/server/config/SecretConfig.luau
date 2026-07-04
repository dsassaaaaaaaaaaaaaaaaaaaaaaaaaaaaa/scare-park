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
SecretConfig.FusionRecipes = {
	-- «Симфония Криков»: Дирижёр Тьмы + 3 Epic (пример; результат добавить в серверный каталог)
	["dark_conductor+doll_mia+granny_pies+mirror_double"] = "scream_symphony",
	-- «АнтиМим»: 4 Мима Молчуна
	["mime+mime+mime+mime"] = "anti_mime",
}

return SecretConfig
