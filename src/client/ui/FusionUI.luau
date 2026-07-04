--!strict
-- FusionUI: инвентарь монстров, выбор 4 для фьюжна, таймер, клейм результата.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local FusionUI = {}

local panel: Frame? = nil
local listFrame: ScrollingFrame? = nil
local statusLabel: TextLabel? = nil
local actionButton: TextButton? = nil

local monsters: { any } = {} -- локальная копия для отображения
local selected: { [string]: boolean } = {}
local selectedCount = 0
local fusionFinishAt = 0

local function refreshStatus()
	local label = statusLabel
	local button = actionButton
	if label == nil or button == nil then
		return
	end
	if fusionFinishAt > 0 then
		local left = fusionFinishAt - os.time()
		if left > 0 then
			label.Text = `⚗️ Варится… {math.floor(left / 60)}:{string.format("%02d", left % 60)}`
			button.Text = "Ждём…"
		else
			label.Text = "✨ Готово!"
			button.Text = "Забрать монстра"
		end
	else
		label.Text = `Выбрано {selectedCount}/{GameConfig.Fusion.SlotCount}`
		button.Text = "Запустить фьюжн"
	end
end

local function rebuildList()
	local container = listFrame
	if container == nil then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, monster in monsters do
		local def = MonsterCatalog[monster.id]
		local displayName = if def then def.name else monster.id
		local mutation = if monster.mutation then ` [{monster.mutation}]` else ""
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -8, 0, 36)
		button.Position = UDim2.fromOffset(0, (i - 1) * 40)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.Gotham
		button.TextSize = 14
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextColor3 = UiKit.Colors.Rarity[monster.rarity] or UiKit.Colors.Text
		button.Text = `  {displayName}{mutation} · {monster.rarity}`
		button.BackgroundColor3 = if selected[monster.uid] then UiKit.Colors.Accent else UiKit.Colors.PanelLight
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = button
		button.Activated:Connect(function()
			if selected[monster.uid] then
				selected[monster.uid] = nil
				selectedCount -= 1
			elseif selectedCount < GameConfig.Fusion.SlotCount then
				selected[monster.uid] = true
				selectedCount += 1
			end
			rebuildList()
			refreshStatus()
		end)
		button.Parent = container
	end
	container.CanvasSize = UDim2.fromOffset(0, #monsters * 40)
end

function FusionUI.SetMonsters(list: { any })
	monsters = list
	selected = {}
	selectedCount = 0
	rebuildList()
	refreshStatus()
end

function FusionUI.SetFusion(finishAt: number)
	fusionFinishAt = finishAt
	refreshStatus()
end

local function onAction()
	if fusionFinishAt > 0 then
		if os.time() < fusionFinishAt then
			return
		end
		local result = Remotes.GetFunction(Remotes.Names.ClaimFusion):InvokeServer()
		if result and result.ok then
			fusionFinishAt = 0
			table.insert(monsters, result.monster)
			rebuildList()
			refreshStatus()
		end
	else
		if selectedCount ~= GameConfig.Fusion.SlotCount then
			return
		end
		local uids: { string } = {}
		for uid in selected do
			table.insert(uids, uid)
		end
		local result = Remotes.GetFunction(Remotes.Names.StartFusion):InvokeServer(uids)
		if result and result.ok then
			fusionFinishAt = result.finishAt
			-- убрать сгоревших из локального списка
			local kept: { any } = {}
			for _, monster in monsters do
				if not selected[monster.uid] then
					table.insert(kept, monster)
				end
			end
			FusionUI.SetMonsters(kept)
			FusionUI.SetFusion(fusionFinishAt)
		end
	end
end

function FusionUI.Toggle()
	if panel then
		panel.Visible = not panel.Visible
	end
end

function FusionUI.Build(gui: ScreenGui)
	panel = UiKit.Panel({
		size = UDim2.fromOffset(320, 440),
		position = UDim2.new(1, -332, 0.5, -220),
		parent = gui,
	})
	local p = panel :: Frame
	p.Visible = false

	UiKit.Label({
		text = "⚗️ Фьюжн-машина",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 6),
		parent = p,
		textSize = 18,
	})
	statusLabel = UiKit.Label({
		text = "",
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 36),
		parent = p,
		textSize = 14,
	})

	listFrame = Instance.new("ScrollingFrame")
	local lf = listFrame :: ScrollingFrame
	lf.Size = UDim2.new(1, -20, 1, -130)
	lf.Position = UDim2.fromOffset(10, 64)
	lf.BackgroundTransparency = 1
	lf.BorderSizePixel = 0
	lf.ScrollBarThickness = 4
	lf.Parent = p

	actionButton = UiKit.Button({
		text = "Запустить фьюжн",
		size = UDim2.new(1, -20, 0, 44),
		position = UDim2.new(0, 10, 1, -54),
		parent = p,
		onClick = onAction,
	})

	task.spawn(function()
		while true do
			task.wait(1)
			if fusionFinishAt > 0 then
				refreshStatus()
			end
		end
	end)

	refreshStatus()
end

return FusionUI
