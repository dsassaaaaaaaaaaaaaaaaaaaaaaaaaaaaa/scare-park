--!strict
-- MonetizationService: покупки Robux через ProcessReceipt.
-- Инварианты (02-programming.md, правило №3):
--   1. Идемпотентность: повторный чек с тем же PurchaseId не выдаёт товар дважды.
--   2. PurchaseGranted возвращается ТОЛЬКО после подтверждённого сохранения профиля.
--   Иначе — NotProcessedYet, и Roblox сам повторит чек позже.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}

-- ProductId из дашборда Roblox → обработчик выдачи.
-- ⚠️ Заполнить реальные ID после создания Dev Products в Creator Hub!
-- Обработчик мутирует data и возвращает true, если выдача успешна.
local productHandlers: { [number]: (player: Player, data: any) -> boolean } = {
	-- [1234567890] = function(player, data) -- Оффер «Первый Испуг», 5 R$
	-- 	if data.offers.firstPurchaseDone then
	-- 		return true -- уже куплен: одноразовый оффер, повторно не выдаём, но чек закрываем
	-- 	end
	-- 	data.offers.firstPurchaseDone = true
	-- 	data.offers.ladder = 1
	-- 	-- Содержимое: скин + 3 жетона ускорения + рамка (economy §4 п.15: БЕЗ «×2 доход» —
	-- 	-- сила за деньги нарушала ограничение «только время и косметика»)
	-- 	return true
	-- end,
	-- [1234567891] = function(player, data) -- Платное ускорение фьюжна
	-- 	if data.fusion.finishAt == 0 then
	-- 		return false -- нечего ускорять
	-- 	end
	-- 	-- Лимит 5 платных скипов/день (economy §4 п.14, защита детской аудитории)
	-- 	local day = math.floor(os.time() / 86400)
	-- 	if data.fusionSkipsToday.day ~= day then
	-- 		data.fusionSkipsToday.day = day
	-- 		data.fusionSkipsToday.count = 0
	-- 	end
	-- 	if data.fusionSkipsToday.count >= GameConfig.Fusion.PaidSkipsPerDay then
	-- 		return false
	-- 	end
	-- 	data.fusionSkipsToday.count += 1
	-- 	data.fusion.finishAt = 0
	-- 	return true
	-- end,
}

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		-- игрок вышел: не выдаём, Roblox повторит при следующем входе
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.Get(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseKey = tostring(receiptInfo.PurchaseId)

	-- 1. Идемпотентность: уже выдавали и сохранили? Просто закрываем чек.
	if data.purchaseHistory[purchaseKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local handler = productHandlers[receiptInfo.ProductId]
	if handler == nil then
		warn(`[Monetization] нет обработчика для ProductId={receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 2. Выдача в профиль (в памяти)
	local granted = handler(player, data)
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.purchaseHistory[purchaseKey] = true

	-- 3. Подтверждённое сохранение ПЕРЕД PurchaseGranted.
	-- Метку НЕ откатываем при неудаче: выдача и метка сохраняются атомарно
	-- (одним профилем), поэтому повторный чек либо увидит метку (профиль сохранился —
	-- закроет чек), либо не увидит ни метки, ни выдачи (профиль потерян — выдаст заново).
	if not DataService.SaveConfirmed(player, 10) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- уведомить HUD (валюты могли измениться)
	Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	if not GameConfig.Flags.MonetizationEnabled then
		print("[MonetizationService] disabled by flag")
		return
	end
	MarketplaceService.ProcessReceipt = processReceipt
	print("[MonetizationService] init")
end

return MonetizationService
