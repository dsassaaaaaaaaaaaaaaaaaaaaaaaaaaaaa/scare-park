--!strict
-- Pure scare mechanic registry metadata. Runtime implementations live on the server.

local ScareMechanicLogic = {}

ScareMechanicLogic.FallbackId = "generic_proximity"

export type RoamOffset = {
	x: number,
	z: number,
	distance: number,
	clamped: boolean,
}

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

function ScareMechanicLogic.ClampRoamOffset(dx: number, dz: number, maxDistance: number): RoamOffset
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance <= maxDistance or distance == 0 then
		return {
			x = dx,
			z = dz,
			distance = distance,
			clamped = false,
		}
	end

	if maxDistance <= 0 then
		return {
			x = 0,
			z = 0,
			distance = 0,
			clamped = true,
		}
	end

	local scale = maxDistance / distance
	return {
		x = dx * scale,
		z = dz * scale,
		distance = maxDistance,
		clamped = true,
	}
end

return ScareMechanicLogic
