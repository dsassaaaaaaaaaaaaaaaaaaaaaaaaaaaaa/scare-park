--!strict
-- PlacementUI: простой экран расстановки монстров по слотам участка.
-- В мире то же самое можно делать через ProximityPrompt на слотах.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local PlacementUI = {}

local panel: Frame? = nil
local monsterList: Frame? = nil
local slotGrid: Frame? = nil
local statusLabel: TextLabel? = nil
local selectedUid: string? = nil
local currentSnapshot: any? = nil

local function monsterName(uid: string?): string
	if uid == nil or currentSnapshot == nil then
		return "—"
	end
	for _, monster in currentSnapshot.monsters do
		if monster.uid == uid then
			local def = MonsterCatalog[monster.id]
			return if def then def.name else monster.id
		end
	end
	return uid
end

local function assignedUidBySlot(slot: number): string?
	if currentSnapshot == nil then
		return nil
	end
	for _, item in currentSnapshot.plot do
		if item.slot == slot then
			return item.monsterUid
		end
	end
	return nil
end

local function usedMonsterMap(): { [string]: boolean }
	local used: { [string]: boolean } = {}
	if currentSnapshot == nil then
		return used
	end
	for _, item in currentSnapshot.plot do
		if item.monsterUid then
			used[item.monsterUid] = true
		end
	end
	return used
end

local function firstUnassignedMonster(): string?
	if currentSnapshot == nil then
		return nil
	end
	local used = usedMonsterMap()
	for _, monster in currentSnapshot.monsters do
		if not used[monster.uid] then
			return monster.uid
		end
	end
	return nil
end

local function setStatus(text: string)
	if statusLabel then
		statusLabel.Text = text
	end
end

local function clearGuiObjects(container: Frame?)
	if container == nil then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function refreshFromServer()
	local snapshot = Remotes.GetFunction(Remotes.Names.GetSnapshot):InvokeServer()
	if snapshot then
		PlacementUI.SetSnapshot(snapshot)
	end
end

local function rebuild()
	clearGuiObjects(monsterList)
	clearGuiObjects(slotGrid)
	local snapshot = currentSnapshot
	if snapshot == nil then
		setStatus("Ждём профиль…")
		return
	end

	local used = usedMonsterMap()
	local list = monsterList
	if list then
		for i, monster in snapshot.monsters do
			if i > 8 then
				break
			end
			local def = MonsterCatalog[monster.id]
			local button = UiKit.Button({
				text = `{if used[monster.uid] then "📍" else "👻"} {if def then def.name else monster.id}`,
				size = UDim2.new(1, 0, 0, 30),
				position = UDim2.fromOffset(0, (i - 1) * 34),
				parent = list,
				onClick = function()
					selectedUid = monster.uid
					setStatus(`Выбран: {monsterName(monster.uid)}`)
					rebuild()
				end,
			})
			if def then
				button.BackgroundColor3 = UiKit.Colors.Rarity[def.rarity] or UiKit.Colors.Accent
			end
			if selectedUid == monster.uid then
				button.Text = `✅ {button.Text}`
			end
		end
	end

	local grid = slotGrid
	local unlockedSlots = snapshot.plotSlots or 3
	if grid then
		for slot = 1, 10 do
			local row = math.floor((slot - 1) / 2)
			local column = (slot - 1) % 2
			local uid = assignedUidBySlot(slot)
			local unlocked = slot <= unlockedSlots
			local buttonText = if not unlocked
				then `🔒 S{slot}`
				elseif uid then `S{slot}: {monsterName(uid)}`
				else `S{slot}: +`
			local button = UiKit.Button({
				text = buttonText,
				size = UDim2.new(0.5, -5, 0, 34),
				position = UDim2.new(column * 0.5, column * 5, 0, row * 38),
				parent = grid,
				onClick = function()
					if not unlocked then
						setStatus("Этот слот ещё закрыт — купи расширение.")
						return
					end
					local uidToPlace = selectedUid or firstUnassignedMonster()
					if uidToPlace == nil then
						setStatus("Нет свободных монстров. Купи монстра в магазине.")
						return
					end
					local result = Remotes.GetFunction(Remotes.Names.AssignMonster):InvokeServer(slot, uidToPlace)
					if result and result.ok then
						selectedUid = uidToPlace
						setStatus(`Поставлен: {monsterName(uidToPlace)} → S{slot}`)
						refreshFromServer()
					else
						setStatus("Не удалось поставить: слот занят/монстр уже стоит.")
					end
				end,
			})
			button.BackgroundColor3 = if not unlocked
				then Color3.fromRGB(60, 58, 70)
				elseif uid then Color3.fromRGB(148, 66, 192)
				else Color3.fromRGB(45, 118, 165)
		end
	end
	setStatus(`Выбери участок на карте, затем монстра и слот. Слотов: {unlockedSlots}/10`)
end

function PlacementUI.Toggle()
	if panel then
		panel.Visible = not panel.Visible
		if panel.Visible then
			refreshFromServer()
		end
	end
end

function PlacementUI.SetSnapshot(snapshot: any)
	currentSnapshot = snapshot
	if selectedUid == nil then
		selectedUid = firstUnassignedMonster()
	end
	rebuild()
end

function PlacementUI.Build(gui: ScreenGui)
	panel = UiKit.Panel({
		size = UDim2.fromOffset(360, 440),
		position = UDim2.new(1, -372, 0.5, -220),
		parent = gui,
	})
	local p = panel :: Frame
	p.Visible = false

	UiKit.Label({
		text = "🧩 Расстановка парка",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.fromOffset(0, 8),
		parent = p,
		textSize = 18,
	})

	statusLabel = UiKit.Label({
		text = "Выбери участок на карте.",
		size = UDim2.new(1, -20, 0, 42),
		position = UDim2.fromOffset(10, 42),
		parent = p,
		textSize = 13,
	})
	;(statusLabel :: TextLabel).TextColor3 = UiKit.Colors.TextDim
	;(statusLabel :: TextLabel).TextWrapped = true

	monsterList = Instance.new("Frame")
	local ml = monsterList :: Frame
	ml.Name = "MonsterList"
	ml.Size = UDim2.new(1, -20, 0, 136)
	ml.Position = UDim2.fromOffset(10, 88)
	ml.BackgroundTransparency = 1
	ml.Parent = p

	slotGrid = Instance.new("Frame")
	local sg = slotGrid :: Frame
	sg.Name = "SlotGrid"
	sg.Size = UDim2.new(1, -20, 0, 190)
	sg.Position = UDim2.fromOffset(10, 232)
	sg.BackgroundTransparency = 1
	sg.Parent = p

	UiKit.Button({
		text = "➕ Купить слот",
		size = UDim2.fromOffset(130, 32),
		position = UDim2.new(1, -140, 1, -40),
		parent = p,
		onClick = function()
			local result = Remotes.GetFunction(Remotes.Names.BuyPlotSlot):InvokeServer()
			if result and result.ok then
				setStatus(`Открыт слот {result.slots}`)
				refreshFromServer()
			elseif result and result.err == "not_enough_coins" then
				setStatus("Не хватает монет на слот.")
			else
				setStatus("Слот не куплен.")
			end
		end,
	})

	rebuild()
end

return PlacementUI
