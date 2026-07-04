--!strict
-- MonetizationService: все покупки через ProcessReceipt, ИДЕМПОТЕНТНО.
-- Правило №3: выдача товара ТОЛЬКО после подтверждённого сохранения —
-- иначе дюп через краш сервера.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local MonetizationService = {}

function MonetizationService.Init()
	if not GameConfig.Flags.MonetizationEnabled then
		print("[MonetizationService] disabled by flag")
		return
	end

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		-- TODO Неделя 5–6:
		-- 1. Проверить в профиле purchaseHistory[receiptInfo.PurchaseId] → уже выдано? PurchaseGranted
		-- 2. Выдать товар в профиль + записать PurchaseId
		-- 3. Дождаться УСПЕШНОГО сохранения профиля
		-- 4. Только после этого → Enum.ProductPurchaseDecision.PurchaseGranted
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("[MonetizationService] init")
end

return MonetizationService
