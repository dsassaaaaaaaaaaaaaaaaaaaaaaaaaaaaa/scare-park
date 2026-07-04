--!strict
-- ShopService: ротация магазина. Сид = floor(os.time()/300) —
-- одинаковая витрина на всех серверах, обновление каждые 5 минут.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ShopService = {}

function ShopService.GetCurrentSeed(): number
	return math.floor(os.time() / GameConfig.Shop.RotationSeconds)
end

function ShopService.Init()
	-- TODO Неделя 2–3:
	-- 1. Генерация витрины из сида (Random.new(seed)): GameConfig.Shop.SlotCount монстров
	-- 2. RemoteFunction BuyMonster: валидация цены/валюты НА СЕРВЕРЕ, витрина пересчитывается из сида
	-- 3. Пуш клиентам таймера следующей ротации
	print(`[ShopService] init, seed={ShopService.GetCurrentSeed()}`)
end

return ShopService
