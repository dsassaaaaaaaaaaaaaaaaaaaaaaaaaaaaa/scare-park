local GameConfig = require("../src/shared/GameConfig")
local MonsterCatalog = require("../src/shared/MonsterCatalog")
local FusionLogic = require("../src/shared/logic/FusionLogic")

local function monster(uid, id)
	local def = MonsterCatalog[id]
	return {
		uid = uid,
		id = id,
		rarity = def.rarity,
		mutation = nil,
		legendPoints = 0,
		primeStars = 0,
	}
end

local function fusionData(monsters, coins)
	return {
		coins = coins,
		monsters = monsters,
		plot = {
			{ itemId = "slot1", slot = 1, monsterUid = monsters[1] and monsters[1].uid or nil },
		},
		fusion = { slots = {}, finishAt = 0, resultUid = "" },
	}
end

return function(Runner)
	Runner.test("FusionLogic rejects a fusion with mixed rarities", function()
		local data = fusionData({
			monster("m1", "boo_balloon"),
			monster("m2", "giggle_clown"),
			monster("m3", "granny_pies"),
			monster("m4", "dark_conductor"),
		}, 100000)

		local ok, result, err = FusionLogic.StartFusion(data, GameConfig, MonsterCatalog, { "m1", "m2", "m3", "m4" }, {
			now = 1000,
		})

		Runner.expectEqual(ok, false)
		Runner.expectEqual(result, nil)
		Runner.expectEqual(err, "mixed_rarities")
	end)

	Runner.test("FusionLogic turns four Common monsters into a paid Rare fusion", function()
		local data = fusionData({
			monster("m1", "boo_balloon"),
			monster("m2", "intern_skeleton"),
			monster("m3", "rat_in_coat"),
			monster("m4", "jelly"),
		}, 100)

		local ok, result, err = FusionLogic.StartFusion(data, GameConfig, MonsterCatalog, { "m1", "m2", "m3", "m4" }, {
			now = 1000,
		})

		Runner.expectEqual(ok, true)
		Runner.expectEqual(err, nil)
		Runner.expectEqual(result.rarity, "Rare")
		Runner.expectEqual(result.fee, GameConfig.Fusion.FeesByRarity.Rare)
		Runner.expectEqual(data.coins, 100 - GameConfig.Fusion.FeesByRarity.Rare)
		Runner.expectEqual(data.fusion.finishAt, 1000 + GameConfig.Fusion.TimersByRarity.Rare)
		Runner.expectEqual(#data.monsters, 0)
		Runner.expectEqual(data.plot[1].monsterUid, nil)
	end)
end
