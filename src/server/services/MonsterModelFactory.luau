--!strict
-- Procedural placeholder monster models. Existing authored models are never modified.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local MonsterVisualLogic = require(ReplicatedStorage.Shared.logic.MonsterVisualLogic)

local MonsterModelFactory = {}

local FOLDER_NAME = "MonsterModels"

local SHAPE_BY_RARITY: { [string]: Enum.PartType } = {
	Common = Enum.PartType.Block,
	Rare = Enum.PartType.Ball,
	Epic = Enum.PartType.Cylinder,
	Legendary = Enum.PartType.Block,
	Mythic = Enum.PartType.Ball,
	Nightmare = Enum.PartType.Cylinder,
	Secret = Enum.PartType.Block,
}

local function getFolder(): Folder
	local folder = ServerStorage:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = ServerStorage
	return created
end

local function addBillboard(body: BasePart, displayName: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameBillboard"
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = Vector3.new(0, body.Size.Y / 2 + 1.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Name = "DisplayName"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Font = Enum.Font.Creepster
	label.Text = displayName
	label.Parent = billboard
end

function MonsterModelFactory.CreatePlaceholder(monsterId: string, def: any?): Model
	local model = Instance.new("Model")
	model.Name = monsterId

	local color = MonsterVisualLogic.ColorFromId(monsterId)
	local rarity = if def then def.rarity else "Common"
	local size = MonsterVisualLogic.SizeForRarity(rarity)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = SHAPE_BY_RARITY[rarity] or Enum.PartType.Block
	body.Size = Vector3.new(size.x, size.y, size.z)
	body.Anchored = true
	body.CanCollide = false
	body.Color = Color3.fromRGB(color.r, color.g, color.b)
	body.Parent = model

	local screamSound = Instance.new("Sound")
	screamSound.Name = "ScreamSound"
	screamSound.Volume = 0.7
	screamSound.RollOffMaxDistance = 45
	screamSound.Parent = body

	addBillboard(body, if def then def.name else monsterId)

	model.PrimaryPart = body
	return model
end

function MonsterModelFactory.EnsureAll()
	local folder = getFolder()
	for monsterId, def in MonsterCatalog do
		if folder:FindFirstChild(monsterId) == nil then
			MonsterModelFactory.CreatePlaceholder(monsterId, def).Parent = folder
		end
	end
end

function MonsterModelFactory.GetModel(monsterId: string): Model
	local folder = getFolder()
	local template = folder:FindFirstChild(monsterId)
	if template == nil then
		local def = MonsterCatalog[monsterId]
		template = MonsterModelFactory.CreatePlaceholder(monsterId, def)
		template.Parent = folder
	end

	if template:IsA("Model") then
		local clone = template:Clone()
		if clone.PrimaryPart == nil then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
		end
		return clone
	end

	local def = MonsterCatalog[monsterId]
	return MonsterModelFactory.CreatePlaceholder(monsterId, def)
end

return MonsterModelFactory
