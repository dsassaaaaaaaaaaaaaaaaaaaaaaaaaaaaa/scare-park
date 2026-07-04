--!strict
-- ShopUI: витрина ротации (5 слотов), таймер до следующей ротации, покупка.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local ShopUI = {}

local panel: Frame? = nil
local onPurchase: (() -> ())? = nil
local timerLabel: TextLabel? = nil
local slotsFolder: Frame? = nil
local currentShowcase: { { monsterId: string, price: number } } = {}
local nextRotationAt = 0

local function rebuildSlots()
	local container = slotsFolder
	if container == nil then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, slot in currentShowcase do
		local def = MonsterCatalog[slot.monsterId]
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 56)
		card.Position = UDim2.fromOffset(0, (i - 1) * 62)
		card.BackgroundColor3 = UiKit.Colors.PanelLight
		card.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card

		local name = UiKit.Label({
			text = if def then def.name else slot.monsterId,
			size = UDim2.new(1, -110, 0, 26),
			position = UDim2.fromOffset(10, 4),
			parent = card,
		})
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = if def then (UiKit.Colors.Rarity[def.rarity] or UiKit.Colors.Text) else UiKit.Colors.Text

		local rarity = UiKit.Label({
			text = if def then def.rarity else "?",
			size = UDim2.new(1, -110, 0, 20),
			position = UDim2.fromOffset(10, 30),
			parent = card,
			textSize = 13,
		})
		rarity.TextXAlignment = Enum.TextXAlignment.Left
		rarity.TextColor3 = UiKit.Colors.TextDim

		UiKit.Button({
			text = `🪙 {slot.price}`,
			size = UDim2.fromOffset(90, 36),
			position = UDim2.new(1, -100, 0.5, -18),
			parent = card,
			onClick = function()
				local result = Remotes.GetFunction(Remotes.Names.BuyShopSlot):InvokeServer(i)
				if result and result.ok then
					name.Text = `✅ {name.Text}`
					if onPurchase then
						onPurchase()
					end
				elseif result and result.err == "not_enough_coins" then
					name.Text = `❌ Не хватает монет`
					task.delay(1.5, rebuildSlots)
				end
			end,
		})
		card.Parent = container
	end
end

function ShopUI.Toggle()
	if panel then
		panel.Visible = not panel.Visible
	end
end

function ShopUI.Build(gui: ScreenGui, purchaseCallback: (() -> ())?)
	onPurchase = purchaseCallback
	panel = UiKit.Panel({
		size = UDim2.fromOffset(300, 400),
		position = UDim2.new(0, 12, 0.5, -200),
		parent = gui,
	})
	local p = panel :: Frame
	p.Visible = false

	UiKit.Label({
		text = "🛒 Магазин монстров",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 6),
		parent = p,
		textSize = 18,
	})
	timerLabel = UiKit.Label({
		text = "Ротация через …",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 36),
		parent = p,
		textSize = 13,
	})
	;(timerLabel :: TextLabel).TextColor3 = UiKit.Colors.TextDim

	slotsFolder = Instance.new("Frame")
	local sf = slotsFolder :: Frame
	sf.Size = UDim2.new(1, -20, 1, -70)
	sf.Position = UDim2.fromOffset(10, 62)
	sf.BackgroundTransparency = 1
	sf.Parent = p

	Remotes.GetEvent(Remotes.Names.ShopRotation).OnClientEvent:Connect(function(showcase, nextAt)
		currentShowcase = showcase
		nextRotationAt = nextAt
		rebuildSlots()
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local label = timerLabel
			if label and nextRotationAt > 0 then
				local left = math.max(0, nextRotationAt - os.time())
				label.Text = `Ротация через {math.floor(left / 60)}:{string.format("%02d", left % 60)}`
			end
		end
	end)
end

return ShopUI
