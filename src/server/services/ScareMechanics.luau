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

export type SpawnedMonster = {
	model: Model,
	owner: Player,
	entry: any,
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
		sound:Play()
	end
end

local function applyScare(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart, mechanicId: string)
	local _escaped, applied = ScareService.ApplyScare(
		visitor,
		record.entry.uid,
		record.entry,
		root.Position,
		monsterPart.Position
	)
	if not applied then
		return
	end

	playScream(record.model, 1)
	Remotes.GetEvent(Remotes.Names.ScareEffect):FireClient(visitor, record.entry.id, mechanicId)
	Remotes.GetEvent(Remotes.Names.CourageChanged):FireClient(visitor, ScareService.GetCourage(visitor))
end

local function fallbackProximity(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	if (root.Position - monsterPart.Position).Magnitude <= PROXIMITY_RANGE then
		applyScare(record, visitor, root, monsterPart, ScareMechanicLogic.FallbackId)
	end
end

registry["generic_proximity"] = fallbackProximity

registry["chase_pop"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local offset = root.Position - monsterPart.Position
	if offset.Magnitude > CHASE_RANGE then
		return
	end
	if offset.Magnitude < 0.01 then
		applyScare(record, visitor, root, monsterPart, "chase_pop")
		return
	end

	local chaseDistance = math.max(offset.Magnitude - 4, 0)
	local popPosition = monsterPart.Position + offset.Unit * math.min(chaseDistance, 7)
	pivotFacing(record.model, Vector3.new(popPosition.X, monsterPart.Position.Y, popPosition.Z), root.Position)
	applyScare(record, visitor, root, record.model.PrimaryPart or monsterPart, "chase_pop")
end

registry["blink_teleport"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local offset = root.Position - monsterPart.Position
	if offset.Magnitude > BLINK_RANGE or not isLookingAt(root, monsterPart.Position) then
		return
	end

	local behind = root.Position - root.CFrame.LookVector * 6
	pivotFacing(record.model, Vector3.new(behind.X, monsterPart.Position.Y, behind.Z), root.Position)
	applyScare(record, visitor, root, record.model.PrimaryPart or monsterPart, "blink_teleport")
end

registry["lights_out_jump"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	if (root.Position - monsterPart.Position).Magnitude > LIGHTS_OUT_RANGE then
		return
	end

	local front = root.Position + root.CFrame.LookVector * 5
	pivotFacing(record.model, Vector3.new(front.X, monsterPart.Position.Y + 1.5, front.Z), root.Position)
	applyScare(record, visitor, root, record.model.PrimaryPart or monsterPart, "lights_out_jump")
end

registry["move_when_unseen"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local offset = root.Position - monsterPart.Position
	if offset.Magnitude > UNSEEN_RANGE or isLookingAt(root, monsterPart.Position) then
		return
	end
	if offset.Magnitude < 0.01 then
		applyScare(record, visitor, root, monsterPart, "move_when_unseen")
		return
	end

	local step = offset.Unit * math.min(3, math.max(offset.Magnitude - PROXIMITY_RANGE + 2, 0))
	local nextPosition = monsterPart.Position + step
	pivotFacing(record.model, Vector3.new(nextPosition.X, monsterPart.Position.Y, nextPosition.Z), root.Position)
	if (root.Position - nextPosition).Magnitude <= PROXIMITY_RANGE then
		applyScare(record, visitor, root, record.model.PrimaryPart or monsterPart, "move_when_unseen")
	end
end

registry["approaching_laugh"] = function(record: SpawnedMonster, visitor: Player, root: BasePart, monsterPart: BasePart)
	local distance = (root.Position - monsterPart.Position).Magnitude
	if distance > LAUGH_RANGE then
		return
	end

	local closeness = 1 - math.clamp(distance / LAUGH_RANGE, 0, 1)
	playScream(record.model, 0.2 + closeness * 0.8, 0.8 + closeness * 0.5)
	if distance <= PROXIMITY_RANGE then
		applyScare(record, visitor, root, monsterPart, "approaching_laugh")
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
