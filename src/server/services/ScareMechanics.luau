--!strict
-- Server scare mechanic dispatcher. New mechanic ids should be added here, not in MonsterRuntime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScareMechanicLogic = require(ReplicatedStorage.Shared.logic.ScareMechanicLogic)
local ScareService = require(script.Parent.ScareService)

local ScareMechanics = {}

local PROXIMITY_RANGE = 14
local CHASE_RANGE = 20
local BLINK_RANGE = 26
local LIGHTS_OUT_RANGE = 18
local UNSEEN_RANGE = 34
local LAUGH_RANGE = 28
local UNSEEN_HOME_LIMIT = 12
local RETURN_HOME_DELAY = 1.2

export type SpawnedMonster = {
	model: Model,
	owner: Player,
	entry: any,
	homeCFrame: CFrame,
}

type MechanicFn = (SpawnedMonster, Player, BasePart, BasePart) -> ()

local registry: { [string]: MechanicFn } = {}

local function getRoot(visitor: Player): BasePart?
	local character = visitor.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isLookingAt(root: BasePart, targetPosition: Vector3): boolean
	local offset = targetPosition - root.Position
	if offset.Magnitude < 0.01 then
		return true
	end
	return root.CFrame.LookVector:Dot(offset.Unit) > 0.35
end

local function pivotFacing(model: Model, position: Vector3, lookAt: Vector3)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
end

local function playScream(model: Model, volume: number, playbackSpeed: number?)
	local sound = model:FindFirstChild("ScreamSound", true)
	if sound and sound:IsA("Sound") then
		sound.Volume = math.clamp(volume, 0, 1)
		sound.PlaybackSpeed = playbackSpeed or 1
		if not sound.IsPlaying then
			sound:Play()
		end
	end
end

local function returnHome(record: SpawnedMonster)
	task.delay(RETURN_HOME_DELAY, function()
		if record.model.Parent ~= nil and record.model.PrimaryPart ~= nil then
			record.model:PivotTo(record.homeCFrame)
		end
	end)
end

local function tryApplyScare(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart): boolean
	local _escaped, applied = ScareService.ApplyScare(
		visitor,
		record.entry.uid,
		record.entry,
		root.Position,
		monsterPart.Position
	)
	return applied
end

local function finishScare(record: SpawnedMonster, visitor: Player, mechanicId: string)
	playScream(record.model, 1)
	Remotes.GetEvent(Remotes.Names.ScareEffect):FireClient(visitor, record.entry.id, mechanicId)
	Remotes.GetEvent(Remotes.Names.CourageChanged):FireClient(visitor, ScareService.GetCourage(visitor))
	returnHome(record)
end

local function fallbackProximity(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	if (root.Position - monsterPart.Position).Magnitude <= PROXIMITY_RANGE
		and tryApplyScare(record, visitor, root, monsterPart)
	then
		finishScare(record, visitor, ScareMechanicLogic.FallbackId)
	end
end

registry["generic_proximity"] = fallbackProximity

registry["chase_pop"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local offset = root.Position - monsterPart.Position
	if offset.Magnitude > CHASE_RANGE then
		return
	end
	if not tryApplyScare(record, visitor, root, monsterPart) then
		return
	end
	if offset.Magnitude < 0.01 then
		finishScare(record, visitor, "chase_pop")
		return
	end

	local chaseDistance = math.max(offset.Magnitude - 4, 0)
	local popPosition = monsterPart.Position + offset.Unit * math.min(chaseDistance, 7)
	pivotFacing(record.model, Vector3.new(popPosition.X, monsterPart.Position.Y, popPosition.Z), root.Position)
	finishScare(record, visitor, "chase_pop")
end

registry["blink_teleport"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local offset = root.Position - monsterPart.Position
	if offset.Magnitude > BLINK_RANGE or not isLookingAt(root, monsterPart.Position) then
		return
	end
	if not tryApplyScare(record, visitor, root, monsterPart) then
		return
	end

	local behind = root.Position - root.CFrame.LookVector * 6
	pivotFacing(record.model, Vector3.new(behind.X, monsterPart.Position.Y, behind.Z), root.Position)
	finishScare(record, visitor, "blink_teleport")
end

registry["lights_out_jump"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	if (root.Position - monsterPart.Position).Magnitude > LIGHTS_OUT_RANGE then
		return
	end
	if not tryApplyScare(record, visitor, root, monsterPart) then
		return
	end

	local front = root.Position + root.CFrame.LookVector * 5
	pivotFacing(record.model, Vector3.new(front.X, monsterPart.Position.Y + 1.5, front.Z), root.Position)
	finishScare(record, visitor, "lights_out_jump")
end

registry["move_when_unseen"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local offset = root.Position - monsterPart.Position
	if offset.Magnitude > UNSEEN_RANGE or isLookingAt(root, monsterPart.Position) then
		return
	end
	if offset.Magnitude < 0.01 then
		if tryApplyScare(record, visitor, root, monsterPart) then
			finishScare(record, visitor, "move_when_unseen")
		end
		return
	end

	local step = offset.Unit * math.min(3, math.max(offset.Magnitude - PROXIMITY_RANGE + 2, 0))
	local desiredPosition = monsterPart.Position + step
	local homePosition = record.homeCFrame.Position
	local clampedOffset = ScareMechanicLogic.ClampRoamOffset(
		desiredPosition.X - homePosition.X,
		desiredPosition.Z - homePosition.Z,
		UNSEEN_HOME_LIMIT
	)
	local nextPosition = Vector3.new(homePosition.X + clampedOffset.x, monsterPart.Position.Y, homePosition.Z + clampedOffset.z)
	pivotFacing(record.model, nextPosition, root.Position)

	local currentPart = record.model.PrimaryPart or monsterPart
	if (root.Position - currentPart.Position).Magnitude <= PROXIMITY_RANGE
		and tryApplyScare(record, visitor, root, currentPart)
	then
		finishScare(record, visitor, "move_when_unseen")
	end
end

registry["approaching_laugh"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local distance = (root.Position - monsterPart.Position).Magnitude
	if distance > LAUGH_RANGE then
		return
	end

	local closeness = 1 - math.clamp(distance / LAUGH_RANGE, 0, 1)
	playScream(record.model, 0.2 + closeness * 0.8, 0.8 + closeness * 0.5)
	if distance <= PROXIMITY_RANGE and tryApplyScare(record, visitor, root, monsterPart) then
		finishScare(record, visitor, "approaching_laugh")
	end
end

function ScareMechanics.GetImplementation(mechanicId: string?): MechanicFn
	local resolved = ScareMechanicLogic.Resolve(mechanicId)
	local implementation = registry[resolved] or registry[ScareMechanicLogic.FallbackId]
	assert(implementation, "fallback scare mechanic is not registered")
	return implementation
end

function ScareMechanics.Tick(record: SpawnedMonster, visitor: Player)
	local primary = record.model.PrimaryPart
	local root = getRoot(visitor)
	if primary == nil or root == nil then
		return
	end

	local def = MonsterCatalog[record.entry.id]
	local mechanicId = if def then def.scareMechanic else nil
	ScareMechanics.GetImplementation(mechanicId)(record, visitor, root, primary)
end

return ScareMechanics
