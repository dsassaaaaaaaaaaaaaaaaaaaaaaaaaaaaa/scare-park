local GameConfig = require("./src/shared/GameConfig")

return function(Runner)
	Runner.test("GameConfig keeps positive economy prices and fees", function()
		for rarity, price in pairs(GameConfig.Shop.PriceByRarity) do
			Runner.expect(price > 0, "shop price must be positive for " .. rarity)
		end
		for rarity, fee in pairs(GameConfig.Fusion.FeesByRarity) do
			Runner.expect(fee > 0, "fusion fee must be positive for " .. rarity)
		end
		for slot, cost in pairs(GameConfig.Plot.SlotCosts) do
			Runner.expect(cost > 0, "plot slot cost must be positive for slot " .. tostring(slot))
		end
	end)

	Runner.test("GameConfig shop limits agree with sellable rarities", function()
		Runner.expectEqual(GameConfig.Shop.StockPerSlot, 1, "each rotation slot should have one stock")
		for rarity, cap in pairs(GameConfig.Shop.DailyBuyCap) do
			Runner.expect(cap > 0, "daily cap must be positive for " .. rarity)
			Runner.expect(GameConfig.Shop.PriceByRarity[rarity] ~= nil, "daily-capped rarity must have a price: " .. rarity)
			Runner.expect(GameConfig.Shop.WeightByRarity[rarity] ~= nil, "daily-capped rarity must have a rotation weight: " .. rarity)
		end
		for rarity in pairs(GameConfig.Shop.PriceByRarity) do
			Runner.expect(GameConfig.Shop.DailyBuyCap[rarity] ~= nil, "priced rarity must have a daily cap: " .. rarity)
		end
	end)

	Runner.test("GameConfig offline income uses 8 hour daily cap at 50 percent", function()
		Runner.expectEqual(GameConfig.Income.OfflineDailyCapHours, 8)
		Runner.expectEqual(GameConfig.Income.OfflineRate, 0.5)
	end)
end
