--!strict
-- UiKit: минимальные фабрики UI. Стиль полишим позже — сейчас функциональность.

local UiKit = {}

UiKit.Colors = {
	Panel = Color3.fromRGB(24, 20, 32),
	PanelLight = Color3.fromRGB(38, 32, 50),
	Accent = Color3.fromRGB(170, 60, 220), -- фиолетовый хоррор-акцент
	Text = Color3.fromRGB(235, 230, 245),
	TextDim = Color3.fromRGB(150, 145, 165),
	Good = Color3.fromRGB(80, 200, 120),
	Bad = Color3.fromRGB(220, 80, 80),
	Rarity = {
		Common = Color3.fromRGB(160, 160, 160),
		Rare = Color3.fromRGB(80, 150, 255),
		Epic = Color3.fromRGB(170, 60, 220),
		Legendary = Color3.fromRGB(255, 170, 40),
		Mythic = Color3.fromRGB(255, 70, 70),
		Nightmare = Color3.fromRGB(20, 0, 40),
		Secret = Color3.fromRGB(0, 0, 0),
	} :: { [string]: Color3 },
}

function UiKit.Panel(props: { size: UDim2, position: UDim2, parent: Instance, anchor: Vector2? }): Frame
	local frame = Instance.new("Frame")
	frame.Size = props.size
	frame.Position = props.position
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.BackgroundColor3 = UiKit.Colors.Panel
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = props.parent
	return frame
end

function UiKit.Label(props: { text: string, size: UDim2, position: UDim2?, parent: Instance, textSize: number? }): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = props.size
	label.Position = props.position or UDim2.new()
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = props.textSize or 16
	label.TextColor3 = UiKit.Colors.Text
	label.Text = props.text
	label.Parent = props.parent
	return label
end

function UiKit.Button(props: { text: string, size: UDim2, position: UDim2?, parent: Instance, onClick: () -> () }): TextButton
	local button = Instance.new("TextButton")
	button.Size = props.size
	button.Position = props.position or UDim2.new()
	button.BackgroundColor3 = UiKit.Colors.Accent
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = UiKit.Colors.Text
	button.Text = props.text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Activated:Connect(props.onClick)
	button.Parent = props.parent
	return button
end

return UiKit
