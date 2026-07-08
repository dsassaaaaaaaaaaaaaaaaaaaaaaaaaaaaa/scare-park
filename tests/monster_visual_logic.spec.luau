local MonsterVisualLogic = require("../src/shared/logic/MonsterVisualLogic")

return function(Runner)
	Runner.test("Monster placeholder colors are deterministic by id", function()
		local first = MonsterVisualLogic.ColorFromId("boo_balloon")
		local second = MonsterVisualLogic.ColorFromId("boo_balloon")
		local other = MonsterVisualLogic.ColorFromId("stalker_gnome")

		Runner.expectDeepEqual(first, second)
		Runner.expectDeepNotEqual(first, other)
	end)

	Runner.test("Monster placeholder sizes scale by rarity", function()
		local common = MonsterVisualLogic.SizeForRarity("Common")
		local nightmare = MonsterVisualLogic.SizeForRarity("Nightmare")

		Runner.expect(nightmare.x > common.x, "Nightmare placeholder should be wider than Common")
		Runner.expect(nightmare.y > common.y, "Nightmare placeholder should be taller than Common")
	end)
end
