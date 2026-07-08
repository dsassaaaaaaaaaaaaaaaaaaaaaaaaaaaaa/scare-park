--!strict
-- MapService: процедурный редизайн карты.
-- Строит читаемый scare-park: центральный хаб, 8 выбираемых участков,
-- 10 monster-slots на каждом участке и явные prompt'ы для выбора/расстановки.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MapService = {}

local PLOT_Z = { -135, -45, 45, 135 }
local PLOT_CENTER_X = 132
local PLOT_ENTRANCE_X = 88
local MAX_SLOTS = 10

local COLORS = {
	Floor = Color3.fromRGB(10, 10, 16),
	Carpet = Color3.fromRGB(38, 8, 56),
	CarpetEdge = Color3.fromRGB(184, 56, 255),
	PlotBase = Color3.fromRGB(30, 28, 42),
	PlotTrim = Color3.fromRGB(92, 41, 128),
	Claim = Color3.fromRGB(255, 180, 58),
	SlotLocked = Color3.fromRGB(50, 48, 62),
	SlotFree = Color3.fromRGB(55, 160, 220),
	SlotOccupied = Color3.fromRGB(180, 60, 235),
	Green = Color3.fromRGB(82, 255, 146),
	Red = Color3.fromRGB(218, 38, 64),
	Wall = Color3.fromRGB(16, 14, 24),
	Wood = Color3.fromRGB(76, 48, 33),
}

type PartOptions = {
	name: string?,
	parent: Instance?,
	cframe: CFrame?,
	size: Vector3?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	anchored: boolean?,
	shape: Enum.PartType?,
}

local function part(options: PartOptions): Part
	local created = Instance.new("Part")
	created.Name = options.name or "Part"
	created.Anchored = if options.anchored == nil then true else options.anchored
	created.CanCollide = if options.canCollide == nil then true else options.canCollide
	created.Size = options.size or Vector3.new(4, 1, 4)
	created.CFrame = options.cframe or CFrame.new()
	created.Color = options.color or Color3.new(1, 1, 1)
	created.Material = options.material or Enum.Material.SmoothPlastic
	created.Transparency = options.transparency or 0
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	if options.shape then
		created.Shape = options.shape
	end
	created.Parent = options.parent
	return created
end

local function addPrompt(parent: BasePart, name: string, action: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

local function addBillboard(parent: BasePart, title: string, subtitle: string?, color: Color3?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "MapBillboard"
	gui.Size = UDim2.fromOffset(240, if subtitle then 72 else 44)
	gui.StudsOffset = Vector3.new(0, parent.Size.Y / 2 + 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, if subtitle then 0.58 else 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color or Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.25
	titleLabel.Text = title
	titleLabel.Parent = gui

	if subtitle then
		local subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.Size = UDim2.new(1, 0, 0.42, 0)
		subtitleLabel.Position = UDim2.fromScale(0, 0.58)
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Font = Enum.Font.GothamBold
		subtitleLabel.TextScaled = true
		subtitleLabel.TextColor3 = Color3.fromRGB(220, 210, 240)
		subtitleLabel.TextStrokeTransparency = 0.35
		subtitleLabel.Text = subtitle
		subtitleLabel.Parent = gui
	end
	return gui
end

local function addSurfaceText(parent: BasePart, name: string, text: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 236, 255)
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.Parent = gui
	return label
end

local function clearPreviousMap()
	for _, name in { "ScareParkDecor", "Plots", "HubSpawn", "ScareParkSpawn" } do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	for _, child in Workspace.Terrain:GetChildren() do
		if child:IsA("Clouds") then
			child:Destroy()
		end
	end
	local oldAtmosphere = Lighting:FindFirstChild("ScareParkAtmosphere")
	if oldAtmosphere then
		oldAtmosphere:Destroy()
	end
end

local function createLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.4
	Lighting.Ambient = Color3.fromRGB(42, 32, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(24, 20, 48)
	Lighting.FogColor = Color3.fromRGB(18, 8, 32)
	Lighting.FogStart = 90
	Lighting.FogEnd = 430

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ScareParkAtmosphere"
	atmosphere.Color = Color3.fromRGB(82, 52, 120)
	atmosphere.Decay = Color3.fromRGB(18, 8, 32)
	atmosphere.Density = 0.44
	atmosphere.Haze = 2.6
	atmosphere.Glare = 0
	atmosphere.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Name = "ScareParkClouds"
	clouds.Color = Color3.fromRGB(70, 52, 100)
	clouds.Cover = 0.72
	clouds.Density = 0.35
	clouds.Parent = Workspace.Terrain
end

local function createHub(decor: Folder)
	part({
		name = "NightFloor",
		parent = decor,
		cframe = CFrame.new(0, -0.1, 0),
		size = Vector3.new(410, 0.2, 410),
		color = COLORS.Floor,
		material = Enum.Material.Slate,
	})
	part({
		name = "MainAisle",
		parent = decor,
		cframe = CFrame.new(0, 0.08, 0),
		size = Vector3.new(16, 0.26, 344),
		color = COLORS.Carpet,
		material = Enum.Material.Fabric,
	})
	part({
		name = "MainAisleGlow",
		parent = decor,
		cframe = CFrame.new(0, 0.24, 0),
		size = Vector3.new(18, 0.08, 346),
		color = COLORS.CarpetEdge,
		material = Enum.Material.Neon,
		transparency = 0.58,
		canCollide = false,
	})
	part({
		name = "HubPlaza",
		parent = decor,
		cframe = CFrame.new(0, 0.18, -24),
		size = Vector3.new(54, 0.35, 54),
		color = Color3.fromRGB(30, 16, 48),
		material = Enum.Material.Marble,
		shape = Enum.PartType.Cylinder,
	})

	local hubSpawn = part({
		name = "HubSpawn",
		parent = Workspace,
		cframe = CFrame.new(14, 0.6, -24),
		size = Vector3.new(8, 0.4, 8),
		color = Color3.fromRGB(68, 255, 168),
		material = Enum.Material.Neon,
		canCollide = false,
		transparency = 0.18,
	})
	addBillboard(hubSpawn, "ХАБ", "Выбери свободный участок у таблички", COLORS.Green)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ScareParkSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(-14, 0.6, -24)
	spawn.Color = Color3.fromRGB(112, 70, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.12
	spawn.Parent = Workspace
	addBillboard(spawn, "SPAWN", "Монстры ждут слоты", Color3.fromRGB(205, 170, 255))

	local gateLeft = part({
		name = "HubGateLeft",
		parent = decor,
		cframe = CFrame.new(-18, 10, -70),
		size = Vector3.new(5, 20, 5),
		color = COLORS.Wall,
		material = Enum.Material.Brick,
	})
	local gateRight = part({
		name = "HubGateRight",
		parent = decor,
		cframe = CFrame.new(18, 10, -70),
		size = Vector3.new(5, 20, 5),
		color = COLORS.Wall,
		material = Enum.Material.Brick,
	})
	part({
		name = "HubGateTop",
		parent = decor,
		cframe = CFrame.new(0, 21, -70),
		size = Vector3.new(42, 5, 5),
		color = COLORS.Wall,
		material = Enum.Material.Brick,
	})
	for _, pillar in { gateLeft, gateRight } do
		local light = Instance.new("PointLight")
		light.Name = "PurpleTorch"
		light.Brightness = 1.8
		light.Range = 22
		light.Color = COLORS.CarpetEdge
		light.Parent = pillar
	end
	local sign = part({
		name = "FableApprovedSign",
		parent = decor,
		cframe = CFrame.new(0, 24, -73),
		size = Vector3.new(34, 7, 1),
		color = Color3.fromRGB(34, 18, 46),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	addSurfaceText(sign, "FrontText", "SCARE PARK\nFABLE APPROVED", Enum.NormalId.Front)
end

local function addPlotTrim(plot: Model, center: Vector3)
	part({
		name = "NorthTrim",
		parent = plot,
		cframe = CFrame.new(center.X, 1.0, center.Z - 34),
		size = Vector3.new(80, 1.4, 2.4),
		color = COLORS.PlotTrim,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	part({
		name = "SouthTrim",
		parent = plot,
		cframe = CFrame.new(center.X, 1.0, center.Z + 34),
		size = Vector3.new(80, 1.4, 2.4),
		color = COLORS.PlotTrim,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	part({
		name = "BackTrim",
		parent = plot,
		cframe = CFrame.new(center.X + (if center.X > 0 then 40 else -40), 1.0, center.Z),
		size = Vector3.new(2.4, 1.4, 70),
		color = COLORS.PlotTrim,
		material = Enum.Material.Neon,
		canCollide = false,
	})
end

local function createSlot(plot: Model, slotsFolder: Folder, plotIndex: number, slotIndex: number, position: Vector3)
	local slotPart = part({
		name = `Slot{slotIndex}`,
		parent = slotsFolder,
		cframe = CFrame.new(position),
		size = Vector3.new(9, 0.35, 9),
		color = COLORS.SlotLocked,
		material = Enum.Material.Neon,
		transparency = 0.16,
		canCollide = false,
	})
	slotPart:SetAttribute("SlotIndex", slotIndex)
	slotPart:SetAttribute("PlotIndex", plotIndex)
	addPrompt(slotPart, "PlaceMonsterPrompt", "Поставить монстра", `Слот {slotIndex}`)

	local marker = Instance.new("BillboardGui")
	marker.Name = "SlotBillboard"
	marker.Size = UDim2.fromOffset(80, 26)
	marker.StudsOffset = Vector3.new(0, 1.2, 0)
	marker.AlwaysOnTop = false
	marker.Parent = slotPart
	local label = Instance.new("TextLabel")
	label.Name = "SlotText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextStrokeTransparency = 0.25
	label.Text = `S{slotIndex}`
	label.Parent = marker
end

local function createPlot(plots: Folder, decor: Folder, index: number, side: number, z: number)
	local center = Vector3.new(side * PLOT_CENTER_X, 0, z)
	local plot = Instance.new("Model")
	plot.Name = `Plot{index}`
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("Theme", if index % 2 == 0 then "Shadow Arcade" else "Toy Nightmare")
	plot.Parent = plots

	local base = part({
		name = "Base",
		parent = plot,
		cframe = CFrame.new(center + Vector3.new(0, 0.2, 0)),
		size = Vector3.new(80, 0.8, 70),
		color = COLORS.PlotBase,
		material = Enum.Material.Slate,
	})
	plot.PrimaryPart = base
	addPlotTrim(plot, center)

	local entrance = part({
		name = "Entrance",
		parent = plot,
		cframe = CFrame.new(side * PLOT_ENTRANCE_X, 0.55, z),
		size = Vector3.new(12, 0.45, 14),
		color = COLORS.CarpetEdge,
		material = Enum.Material.Neon,
		transparency = 0.18,
		canCollide = false,
	})
	entrance:SetAttribute("PlotIndex", index)

	part({
		name = "ConnectorPath",
		parent = decor,
		cframe = CFrame.new(side * 44, 0.11, z),
		size = Vector3.new(82, 0.22, 8),
		color = COLORS.Carpet,
		material = Enum.Material.Fabric,
	})
	part({
		name = "ConnectorGlow",
		parent = decor,
		cframe = CFrame.new(side * 44, 0.24, z),
		size = Vector3.new(84, 0.08, 9.5),
		color = COLORS.CarpetEdge,
		material = Enum.Material.Neon,
		transparency = 0.62,
		canCollide = false,
	})

	local claimPad = part({
		name = "ClaimPad",
		parent = plot,
		cframe = CFrame.new(side * 96, 0.85, z),
		size = Vector3.new(12, 0.45, 12),
		color = COLORS.Claim,
		material = Enum.Material.Neon,
		transparency = 0.08,
		canCollide = false,
	})
	claimPad:SetAttribute("PlotIndex", index)
	addPrompt(claimPad, "ClaimPlotPrompt", "Выбрать участок", `Plot {index}`)
	addBillboard(claimPad, `УЧАСТОК {index}`, "E — забрать себе", COLORS.Claim)

	local sign = part({
		name = "OwnerSign",
		parent = plot,
		cframe = CFrame.new(side * 103, 6, z + 11) * CFrame.Angles(0, if side > 0 then math.rad(90) else math.rad(-90), 0),
		size = Vector3.new(14, 7, 1),
		color = Color3.fromRGB(35, 18, 48),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	addBillboard(sign, "СВОБОДНО", "Выбери этот участок", COLORS.Green)

	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "Slots"
	slotsFolder.Parent = plot

	local monstersFolder = Instance.new("Folder")
	monstersFolder.Name = "Monsters"
	monstersFolder.Parent = plot

	for slotIndex = 1, MAX_SLOTS do
		local column = (slotIndex - 1) % 5
		local row = math.floor((slotIndex - 1) / 5)
		local slotX = center.X + (-24 + column * 12)
		local slotZ = center.Z + (-14 + row * 24)
		createSlot(plot, slotsFolder, index, slotIndex, Vector3.new(slotX, 1.0, slotZ))
	end

	-- Несколько модульных декоров на каждом участке: силуэты, арки, страшные игрушки.
	part({
		name = "ScareArchLeft",
		parent = plot,
		cframe = CFrame.new(side * 103, 5, z - 8),
		size = Vector3.new(3, 10, 3),
		color = COLORS.Wall,
		material = Enum.Material.Brick,
	})
	part({
		name = "ScareArchRight",
		parent = plot,
		cframe = CFrame.new(side * 103, 5, z + 8),
		size = Vector3.new(3, 10, 3),
		color = COLORS.Wall,
		material = Enum.Material.Brick,
	})
	part({
		name = "ScareArchTop",
		parent = plot,
		cframe = CFrame.new(side * 103, 11, z),
		size = Vector3.new(3, 3, 20),
		color = COLORS.Wall,
		material = Enum.Material.Brick,
	})
	for toy = 1, 3 do
		local offset = Vector3.new(side * (12 + toy * 5), 1.35, -28 + toy * 20)
		part({
			name = "BrokenToy",
			parent = plot,
			cframe = CFrame.new(center + offset) * CFrame.Angles(0, math.rad(18 * toy), math.rad(8)),
			size = Vector3.new(7, 1.2, 2.2),
			color = if toy % 2 == 0 then Color3.fromRGB(255, 80, 100) else Color3.fromRGB(70, 185, 255),
			material = Enum.Material.Plastic,
		})
	end
end

local function createBoundary(decor: Folder)
	local wallData = {
		{ CFrame.new(0, 11, -204), Vector3.new(420, 22, 4) },
		{ CFrame.new(0, 11, 204), Vector3.new(420, 22, 4) },
		{ CFrame.new(-204, 11, 0), Vector3.new(4, 22, 420) },
		{ CFrame.new(204, 11, 0), Vector3.new(4, 22, 420) },
	}
	for _, data in wallData do
		part({
			name = "BedroomWall",
			parent = decor,
			cframe = data[1],
			size = data[2],
			color = COLORS.Wall,
			material = Enum.Material.Brick,
		})
	end

	for i, z in PLOT_Z do
		for _, side in { -1, 1 } do
			local eye = part({
				name = "WatchingEye",
				parent = decor,
				cframe = CFrame.new(side * 190, 14 + (i % 2) * 4, z) * CFrame.Angles(0, math.rad(90), 0),
				size = Vector3.new(1.2, 7, 13),
				color = if i % 2 == 0 then COLORS.Red else COLORS.CarpetEdge,
				material = Enum.Material.Neon,
				canCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Name = "EyeLight"
			light.Brightness = 1
			light.Range = 28
			light.Color = eye.Color
			light.Parent = eye
		end
	end
end

function MapService.Build()
	clearPreviousMap()
	createLighting()

	Workspace:SetAttribute("ScareParkMapVersion", "redesign_v2_monster_slots")

	local decor = Instance.new("Folder")
	decor.Name = "ScareParkDecor"
	decor.Parent = Workspace

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots:SetAttribute("ManualClaimEnabled", true)
	plots.Parent = Workspace

	createHub(decor)
	createBoundary(decor)

	local index = 0
	for _, side in { -1, 1 } do
		for _, z in PLOT_Z do
			index += 1
			createPlot(plots, decor, index, side, z)
		end
	end

	print("[MapService] redesigned map built: hub + 8 claimable plots + monster slots")
end

function MapService.Init()
	MapService.Build()
end

return MapService
