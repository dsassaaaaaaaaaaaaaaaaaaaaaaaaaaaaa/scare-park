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

	Runner.test("Scare mechanic roam offsets are clamped to home radius", function()
		local inside = ScareMechanicLogic.ClampRoamOffset(6, 8, 12)
		Runner.expectEqual(inside.clamped, false)
		Runner.expectEqual(inside.distance, 10)
		Runner.expectEqual(inside.x, 6)
		Runner.expectEqual(inside.z, 8)

		local outside = ScareMechanicLogic.ClampRoamOffset(30, 40, 10)
		Runner.expectEqual(outside.clamped, true)
		Runner.expectEqual(outside.distance, 10)
		Runner.expectEqual(outside.x, 6)
		Runner.expectEqual(outside.z, 8)
	end)
end
