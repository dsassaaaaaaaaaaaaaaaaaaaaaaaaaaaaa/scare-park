local MonsterCatalog = require("../src/shared/MonsterCatalog")
local ScareMechanicLogic = require("../src/shared/logic/ScareMechanicLogic")

return function(Runner)
	Runner.test("Scare mechanic registry covers catalog mechanic ids", function()
		for id, def in pairs(MonsterCatalog) do
			Runner.expect(
				ScareMechanicLogic.IsKnown(def.scareMechanic),
				"unknown scare mechanic for " .. id .. ": " .. tostring(def.scareMechanic)
			)
		end
	end)

	Runner.test("Scare mechanic registry uses fallback for unknown ids", function()
		Runner.expectEqual(ScareMechanicLogic.Resolve("unknown_mechanic"), ScareMechanicLogic.FallbackId)
		Runner.expectEqual(ScareMechanicLogic.Resolve(nil), ScareMechanicLogic.FallbackId)
	end)

	Runner.test("Scare mechanic registry keeps bespoke sample mechanics implemented", function()
		local requiredImplemented = {
			"chase_pop",
			"blink_teleport",
			"lights_out_jump",
			"move_when_unseen",
			"approaching_laugh",
		}

		for _, mechanicId in ipairs(requiredImplemented) do
			Runner.expect(ScareMechanicLogic.IsImplemented(mechanicId), "mechanic must be implemented: " .. mechanicId)
			Runner.expectEqual(ScareMechanicLogic.Resolve(mechanicId), mechanicId)
		end
	end)
end
