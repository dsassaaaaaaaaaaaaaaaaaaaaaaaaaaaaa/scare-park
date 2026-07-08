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

local function addAccentPart(model: Model, name: string, body: BasePart, offset: Vector3, size: Vector3, color: Color3, shape: Enum.PartType?)
	local accent = Instance.new("Part")
	accent.Name = name
	accent.Anchored = true
	accent.CanCollide = false
	accent.Size = size
	accent.CFrame = body.CFrame * CFrame.new(offset)
	accent.Color = color
	accent.Material = Enum.Material.Neon
	accent.TopSurface = Enum.SurfaceType.Smooth
	accent.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		accent.Shape = shape
	end
	accent.Parent = model
	return accent
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
	local bodySize = Vector3.new(size.x, size.y, size.z)
	body.Size = bodySize
	body.Anchored = true
	body.CanCollide = false
	body.Color = Color3.fromRGB(color.r, color.g, color.b)
	body.Material = if rarity == "Nightmare" or rarity == "Secret" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.Parent = model

	local eyeY = math.max(0.35, bodySize.Y * 0.15)
	local eyeZ = -bodySize.Z / 2 - 0.06
	addAccentPart(
		model,
		"LeftEye",
		body,
		Vector3.new(-bodySize.X * 0.18, eyeY, eyeZ),
		Vector3.new(0.28, 0.28, 0.12),
		Color3.fromRGB(255, 245, 205),
		Enum.PartType.Ball
	)
	addAccentPart(
		model,
		"RightEye",
		body,
		Vector3.new(bodySize.X * 0.18, eyeY, eyeZ),
		Vector3.new(0.28, 0.28, 0.12),
		Color3.fromRGB(255, 245, 205),
		Enum.PartType.Ball
	)
	addAccentPart(
		model,
		"MouthGlow",
		body,
		Vector3.new(0, -bodySize.Y * 0.1, eyeZ),
		Vector3.new(bodySize.X * 0.42, 0.12, 0.1),
		Color3.fromRGB(28, 0, 42),
		nil
	)

	local aura = Instance.new("PointLight")
	aura.Name = "MonsterAura"
	aura.Color = body.Color
	aura.Brightness = 0.75
	aura.Range = 14
	aura.Parent = body

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "FearMotes"
	particles.Rate = if rarity == "Common" then 3 else 8
	particles.Lifetime = NumberRange.new(0.8, 1.8)
	particles.Speed = NumberRange.new(0.4, 1.2)
	particles.SpreadAngle = Vector2.new(60, 60)
	particles.Color = ColorSequence.new(body.Color)
	particles.LightEmission = 0.35
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = body

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
