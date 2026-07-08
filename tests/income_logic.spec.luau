local GameConfig = require("./src/shared/GameConfig")
local MonsterCatalog = require("./src/shared/MonsterCatalog")
local IncomeLogic = require("./src/shared/logic/IncomeLogic")

return function(Runner)
	Runner.test("IncomeLogic sums assigned monster income and mutation multipliers", function()
		local data = {
			monsters = {
				{ uid = "m1", id = "boo_balloon", mutation = nil },
				{ uid = "m2", id = "giggle_clown", mutation = "Neon" },
			},
			plot = {
				{ monsterUid = "m1" },
				{ monsterUid = "m2" },
			},
		}

		Runner.expectEqual(IncomeLogic.GetIncomePerMinute(data, GameConfig, MonsterCatalog), 1 + (3 * 1.5))
	end)

	Runner.test("IncomeLogic offline grant is capped at 8 hours per UTC day and pays 50 percent", function()
		local now = 100 * 86400 + 12 * 3600
		local data = {
			coins = 0,
			lastSeenAt = now - 24 * 3600,
			monsters = {
				{ uid = "m1", id = "boo_balloon", mutation = nil },
			},
			plot = {
				{ monsterUid = "m1" },
			},
			income = {
				remainder = 0,
				offlineDay = 0,
				offlinePaidSeconds = 0,
			},
		}

		local grant = IncomeLogic.GrantOffline(data, GameConfig, MonsterCatalog, now)

		Runner.expectEqual(grant.payableSeconds, 8 * 3600)
		Runner.expectEqual(grant.credited, 8 * 60 * GameConfig.Income.OfflineRate)
		Runner.expectEqual(data.coins, 240)

		data.lastSeenAt = now - 8 * 3600
		local secondGrant = IncomeLogic.GrantOffline(data, GameConfig, MonsterCatalog, now)
		Runner.expectEqual(secondGrant.payableSeconds, 0)
		Runner.expectEqual(secondGrant.credited, 0)
		Runner.expectEqual(data.coins, 240)
	end)
end
