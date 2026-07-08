local GameConfig = require("../src/shared/GameConfig")
local MonsterCatalog = require("../src/shared/MonsterCatalog")
local SecretConfig = require("../src/server/config/SecretConfig")

return function(Runner)
	Runner.test("MonsterCatalog has exactly 17 public monsters with valid ids", function()
		local rarityAllowed = {}
		for _, rarity in ipairs(GameConfig.Rarities) do
			rarityAllowed[rarity] = true
		end

		local count = 0
		local seen = {}
		for key, def in pairs(MonsterCatalog) do
			count += 1
			Runner.expectEqual(def.id, key, "catalog key must match monster id")
			Runner.expect(not seen[def.id], "duplicate monster id: " .. def.id)
			seen[def.id] = true
			Runner.expect(def.id:match("^[a-z][a-z0-9_]*$") ~= nil, "monster id must be snake_case: " .. def.id)
			Runner.expect(def.id:find("__", 1, true) == nil, "monster id must not contain repeated underscores: " .. def.id)
			Runner.expect(rarityAllowed[def.rarity] == true, "invalid rarity for " .. def.id .. ": " .. tostring(def.rarity))
			Runner.expect(def.baseIncome > 0, "baseIncome must be positive for " .. def.id)
		end

		Runner.expectEqual(count, 17)
	end)

	Runner.test("MonsterCatalog contains every secret fusion recipe result", function()
		for _, resultId in pairs(SecretConfig.FusionRecipes) do
			Runner.expect(MonsterCatalog[resultId] ~= nil, "secret fusion recipe result must exist in catalog")
		end
	end)
end
