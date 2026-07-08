--!strict
-- Pure scare mechanic registry metadata. Runtime implementations live on the server.

local ScareMechanicLogic = {}

ScareMechanicLogic.FallbackId = "generic_proximity"

local implemented: { [string]: boolean } = {
	generic_proximity = true,
	chase_pop = true,
	blink_teleport = true,
	lights_out_jump = true,
	move_when_unseen = true,
	approaching_laugh = true,
}

-- TODO: Known design ids that intentionally use the fallback until their bespoke behavior ships.
local todoFallback: { [string]: boolean } = {
	clumsy_rattle = true,
	fake_npc_follow = true,
	ceiling_splat = true,
	hidden_in_group = true,
	kind_bait = true,
	whisper_nickname = true,
	avatar_copy = true,
	sync_scream_volley = true,
	total_darkness_eyes = true,
	boss_carousel = true,
}

function ScareMechanicLogic.IsImplemented(mechanicId: string): boolean
	return implemented[mechanicId] == true
end

function ScareMechanicLogic.IsKnown(mechanicId: string): boolean
	return implemented[mechanicId] == true or todoFallback[mechanicId] == true
end

function ScareMechanicLogic.Resolve(mechanicId: string?): string
	if mechanicId and implemented[mechanicId] then
		return mechanicId
	end
	return ScareMechanicLogic.FallbackId
end

function ScareMechanicLogic.GetKnownMechanicIds(): { string }
	local ids: { string } = {}
	for id in implemented do
		table.insert(ids, id)
	end
	for id in todoFallback do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return ScareMechanicLogic
