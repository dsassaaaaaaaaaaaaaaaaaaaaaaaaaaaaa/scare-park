--!strict
-- FusionService: таймеры от os.time() (работают офлайн), рецепты — только на сервере.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SecretConfig = require(script.Parent.Parent.config.SecretConfig)

local FusionService = {}

-- Ключ рецепта: отсортированные id через "+"
function FusionService.RecipeKey(monsterIds: { string }): string
	local sorted = table.clone(monsterIds)
	table.sort(sorted)
	return table.concat(sorted, "+")
end

function FusionService.Init()
	-- TODO Неделя 2–3:
	-- 1. RemoteEvent StartFusion: валидация — ровно 4 монстра, игрок ими владеет, слот свободен
	-- 2. Доминантная редкость = усреднение 4 → таймер из GameConfig.Fusion.TimersByRarity
	-- 3. finishAt = os.time() + timer → в профиль
	-- 4. При клейме: проверить os.time() >= finishAt, ролл мутации (SecretConfig.MutationChances),
	--    проверить SecretConfig.FusionRecipes[RecipeKey(...)]
	local _ = GameConfig
	local _2 = SecretConfig
	print("[FusionService] init")
end

return FusionService
