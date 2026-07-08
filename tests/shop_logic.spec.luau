local GameConfig = require("../src/shared/GameConfig")
local MonsterCatalog = require("../src/shared/MonsterCatalog")
local ShopLogic = require("../src/shared/logic/ShopLogic")

return function(Runner)
	Runner.test("ShopLogic returns the same showcase for the same rotation seed", function()
		local first = ShopLogic.GetShowcase(GameConfig, MonsterCatalog, 12345)
		local second = ShopLogic.GetShowcase(GameConfig, MonsterCatalog, 12345)
		Runner.expectDeepEqual(second, first)
	end)

	Runner.test("ShopLogic changes showcase when the rotation seed changes", function()
		local first = ShopLogic.GetShowcase(GameConfig, MonsterCatalog, 12345)
		local second = ShopLogic.GetShowcase(GameConfig, MonsterCatalog, 12346)
		Runner.expectDeepNotEqual(second, first)
	end)
end
