--!strict
-- PlotService: выбор участка игроком, слоты аттракционов/монстров и сериализация
-- построек в профиль. Карта даёт Workspace.Plots с 8 моделями, Entrance,
-- ClaimPad и Slots/Slot1..Slot10. Если карты нет — работает без физического спавна.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PlotService = {}

export type PlotItem = {
	itemId: string, -- id аттракциона/декора
	slot: number, -- номер слота на участке
	monsterUid: string?, -- какой монстр приставлен (uid из профиля)
}

-- Колбэки «участок игрока изменился» (MonsterRuntime перестраивает спавны).
-- Колбэки вместо require — чтобы не создавать циклических зависимостей.
local changedCallbacks: { (player: Player) -> () } = {}

function PlotService.OnPlotChanged(callback: (player: Player) -> ())
	table.insert(changedCallbacks, callback)
end

function PlotService.NotifyChanged(player: Player)
	for _, callback in changedCallbacks do
		task.spawn(callback, player)
	end
end

local plotOwners: { [Instance]: Player } = {} -- участок → владелец
local playerPlots: { [Player]: Instance } = {} -- владелец → участок
local promptConnections: { RBXScriptConnection } = {}

local DEFAULT_ITEM_ID = "haunt_pedestal"

function PlotService.GetPlot(player: Player): Instance?
	return playerPlots[player]
end

function PlotService.GetOwner(plot: Instance): Player?
	return plotOwners[plot]
end

local function teleportTo(player: Player, part: BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and part then
		root.CFrame = part.CFrame + Vector3.new(0, 4, 0)
	end
end

local function getPlotIndex(plot: Instance): number
	local attr = plot:GetAttribute("PlotIndex")
	if type(attr) == "number" then
		return attr
	end
	local parsed = tonumber(string.match(plot.Name, "%d+"))
	return parsed or 0
end

local function setBillboard(plot: Instance, title: string, subtitle: string, color: Color3)
	local sign = plot:FindFirstChild("OwnerSign")
	local target: Instance? = sign or plot
	local billboard = target and target:FindFirstChild("MapBillboard", true)
	if not (billboard and billboard:IsA("BillboardGui")) then
		return
	end
	local titleLabel = billboard:FindFirstChild("Title", true)
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = title
		titleLabel.TextColor3 = color
	end
	local subtitleLabel = billboard:FindFirstChild("Subtitle", true)
	if subtitleLabel and subtitleLabel:IsA("TextLabel") then
		subtitleLabel.Text = subtitle
	end
end

local function getSlotItem(data: any, slot: number): any?
	for _, item in data.plot :: { PlotItem } do
		if item.slot == slot then
			return item
		end
	end
	return nil
end

local function getMonsterByUid(data: any, uid: string): any?
	for _, monster in data.monsters do
		if monster.uid == uid then
			return monster
		end
	end
	return nil
end

local function isMonsterAssigned(data: any, uid: string, exceptSlot: number?): boolean
	for _, item in data.plot :: { PlotItem } do
		if item.monsterUid == uid and item.slot ~= exceptSlot then
			return true
		end
	end
	return false
end

local function renderPlot(plot: Instance, owner: Player?)
	if owner == nil then
		plot:SetAttribute("OwnerUserId", nil)
		plot:SetAttribute("OwnerName", nil)
		setBillboard(plot, "СВОБОДНО", `Участок {getPlotIndex(plot)} — нажми E`, Color3.fromRGB(82, 255, 146))
		local slotsFolder = plot:FindFirstChild("Slots")
		if slotsFolder then
			for _, child in slotsFolder:GetChildren() do
				if child:IsA("BasePart") then
					child.Color = Color3.fromRGB(50, 48, 62)
					child:SetAttribute("OccupiedBy", nil)
					local prompt = child:FindFirstChild("PlaceMonsterPrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						prompt.ObjectText = `Слот {child:GetAttribute("SlotIndex") or "?"}`
						prompt.ActionText = "Сначала выбери участок"
					end
					local label = child:FindFirstChild("SlotText", true)
					if label and label:IsA("TextLabel") then
						label.Text = `S{child:GetAttribute("SlotIndex") or "?"}`
						label.TextColor3 = Color3.fromRGB(180, 180, 195)
					end
				end
			end
		end
		return
	end

	local data = DataService.Get(owner)
	local slotCount = PlotService.GetSlotCount(owner)
	plot:SetAttribute("OwnerUserId", owner.UserId)
	plot:SetAttribute("OwnerName", owner.Name)
	setBillboard(plot, owner.Name, `Монстр-слотов: {slotCount}`, Color3.fromRGB(255, 180, 58))

	local slotsFolder = plot:FindFirstChild("Slots")
	if data == nil or slotsFolder == nil then
		return
	end
	for _, child in slotsFolder:GetChildren() do
		if child:IsA("BasePart") then
			local slot = child:GetAttribute("SlotIndex")
			local slotNumber = if type(slot) == "number" then slot else tonumber(string.match(child.Name, "%d+")) or 0
			local item = getSlotItem(data, slotNumber)
			local occupied = item and item.monsterUid ~= nil
			child:SetAttribute("OccupiedBy", occupied and item.monsterUid or nil)
			if slotNumber > slotCount then
				child.Color = Color3.fromRGB(50, 48, 62)
			elseif occupied then
				child.Color = Color3.fromRGB(180, 60, 235)
			else
				child.Color = Color3.fromRGB(55, 160, 220)
			end
			local prompt = child:FindFirstChild("PlaceMonsterPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.ObjectText = if slotNumber > slotCount
					then `Слот {slotNumber} закрыт`
					elseif occupied then `Слот {slotNumber} занят`
					else `Слот {slotNumber} свободен`
				prompt.ActionText = if occupied then "Заменить монстра" else "Поставить монстра"
			end
			local label = child:FindFirstChild("SlotText", true)
			if label and label:IsA("TextLabel") then
				label.Text = if slotNumber > slotCount then "🔒" elseif occupied then `M{slotNumber}` else `S{slotNumber}`
				label.TextColor3 = if slotNumber > slotCount
					then Color3.fromRGB(140, 140, 150)
					elseif occupied then Color3.fromRGB(255, 205, 255)
					else Color3.fromRGB(210, 245, 255)
			end
		end
	end
end

local function ensureStarterPlacement(player: Player)
	local data = DataService.Get(player)
	if data == nil or #data.plot > 0 then
		return
	end
	local starter = data.monsters[1]
	if starter then
		table.insert(data.plot, { itemId = DEFAULT_ITEM_ID, slot = 1, monsterUid = starter.uid })
	end
end

--- Кол-во доступных слотов: из профиля (старт 3, рост ТОЛЬКО за монеты — economy §4 п.10)
function PlotService.GetSlotCount(player: Player): number
	local data = DataService.Get(player)
	if data == nil then
		return GameConfig.Plot.StartAttractionSlots
	end
	return data.plotSlots or GameConfig.Plot.StartAttractionSlots
end

--- Купить следующий слот за монеты (лестница цен из конфига)
function PlotService.BuySlot(player: Player): (boolean, number?, string?)
	local data = DataService.Get(player)
	if data == nil then
		return false, nil, "no_profile"
	end
	local nextSlot = (data.plotSlots or GameConfig.Plot.StartAttractionSlots) + 1
	if nextSlot > GameConfig.Plot.MaxAttractionSlots then
		return false, nil, "max_slots"
	end
	local cost = GameConfig.Plot.SlotCosts[nextSlot]
	if cost == nil then
		return false, nil, "no_price"
	end
	if not DataService.AddCurrency(player, "coins", -cost) then
		return false, nil, "not_enough_coins"
	end
	data.plotSlots = nextSlot
	local plot = playerPlots[player]
	if plot then
		renderPlot(plot, player)
	end
	PlotService.NotifyChanged(player)
	return true, nextSlot, nil
end

--- Поставить предмет в слот (валидация: слот в диапазоне, не занят)
function PlotService.PlaceItem(player: Player, itemId: string, slot: number): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	if Workspace:FindFirstChild("Plots") ~= nil and playerPlots[player] == nil then
		return false
	end
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 then
		return false
	end
	if slot < 1 or slot > PlotService.GetSlotCount(player) then
		return false
	end
	for _, item in data.plot :: { PlotItem } do
		if item.slot == slot then
			return false -- занят
		end
	end
	table.insert(data.plot, { itemId = itemId, slot = slot })
	local plot = playerPlots[player]
	if plot then
		renderPlot(plot, player)
	end
	PlotService.NotifyChanged(player)
	return true
end

--- Приставить монстра к слоту
function PlotService.AssignMonster(player: Player, slot: number, monsterUid: string): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	if Workspace:FindFirstChild("Plots") ~= nil and playerPlots[player] == nil then
		return false
	end
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 then
		return false
	end
	if slot < 1 or slot > PlotService.GetSlotCount(player) then
		return false
	end
	-- монстр существует и принадлежит игроку?
	if getMonsterByUid(data, monsterUid) == nil then
		return false
	end
	-- монстр не приставлен к другому слоту?
	if isMonsterAssigned(data, monsterUid, slot) then
		return false
	end
	for _, item in data.plot :: { PlotItem } do
		if item.slot == slot then
			item.monsterUid = monsterUid
			local plot = playerPlots[player]
			if plot then
				renderPlot(plot, player)
			end
			PlotService.NotifyChanged(player)
			return true
		end
	end
	-- Если на слоте ещё нет аттракциона, создаём базовый pedestal автоматически.
	table.insert(data.plot, { itemId = DEFAULT_ITEM_ID, slot = slot, monsterUid = monsterUid })
	local plot = playerPlots[player]
	if plot then
		renderPlot(plot, player)
	end
	PlotService.NotifyChanged(player)
	return true
end

function PlotService.UnassignMonster(player: Player, monsterUid: string): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	local changed = false
	for _, item in data.plot :: { PlotItem } do
		if item.monsterUid == monsterUid then
			item.monsterUid = nil
			changed = true
		end
	end
	if changed then
		local plot = playerPlots[player]
		if plot then
			renderPlot(plot, player)
		end
		PlotService.NotifyChanged(player)
	end
	return changed
end

function PlotService.AutoAssignMonster(player: Player, slot: number): (boolean, string?)
	local data = DataService.Get(player)
	if data == nil then
		return false, "no_profile"
	end
	if playerPlots[player] == nil then
		return false, "no_plot"
	end
	if slot < 1 or slot > PlotService.GetSlotCount(player) then
		return false, "locked_slot"
	end
	for _, monster in data.monsters do
		if not isMonsterAssigned(data, monster.uid, slot) then
			if PlotService.AssignMonster(player, slot, monster.uid) then
				return true, nil
			end
		end
	end
	return false, "no_free_monsters"
end

function PlotService.ClaimPlot(player: Player, desiredPlot: Instance?): (boolean, string?)
	if playerPlots[player] then
		return true, "already_claimed"
	end
	if DataService.WaitFor(player, 10) == nil then
		return false, "no_profile"
	end
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if plotsFolder == nil then
		return false, "no_map"
	end
	local selected: Instance? = nil
	if desiredPlot ~= nil then
		if desiredPlot.Parent ~= plotsFolder then
			return false, "bad_plot"
		end
		selected = desiredPlot
	else
		for _, plot in plotsFolder:GetChildren() do
			if plotOwners[plot] == nil then
				selected = plot
				break
			end
		end
	end
	if selected == nil then
		return false, "full"
	end
	if plotOwners[selected] ~= nil then
		return false, "taken"
	end
	plotOwners[selected] = player
	playerPlots[player] = selected
	ensureStarterPlacement(player)
	renderPlot(selected, player)
	local entrance = selected:FindFirstChild("Entrance") :: BasePart?
	teleportTo(player, entrance)
	PlotService.NotifyChanged(player) -- спавн построек/монстров из data.plot
	return true, nil
end

local function releasePlot(player: Player)
	local plot = playerPlots[player]
	if plot then
		plotOwners[plot] = nil
		playerPlots[player] = nil
		local monsters = plot:FindFirstChild("Monsters")
		if monsters then
			monsters:ClearAllChildren()
		end
		renderPlot(plot, nil)
	end
end

local function setupPlotPrompts()
	for _, connection in promptConnections do
		connection:Disconnect()
	end
	table.clear(promptConnections)

	local plotsFolder = Workspace:FindFirstChild("Plots")
	if plotsFolder == nil then
		return
	end
	for _, plot in plotsFolder:GetChildren() do
		renderPlot(plot, plotOwners[plot])
		local claimPrompt = plot:FindFirstChild("ClaimPlotPrompt", true)
		if claimPrompt and claimPrompt:IsA("ProximityPrompt") then
			table.insert(promptConnections, claimPrompt.Triggered:Connect(function(player)
				local ok, err = PlotService.ClaimPlot(player, plot)
				if not ok then
					warn(`[PlotService] claim failed for {player.Name}: {err}`)
				end
			end))
		end
		local slotsFolder = plot:FindFirstChild("Slots")
		if slotsFolder then
			for _, slotPart in slotsFolder:GetChildren() do
				if slotPart:IsA("BasePart") then
					local prompt = slotPart:FindFirstChild("PlaceMonsterPrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						table.insert(promptConnections, prompt.Triggered:Connect(function(player)
							if plotOwners[plot] ~= player then
								return
							end
							local slot = slotPart:GetAttribute("SlotIndex")
							local slotNumber = if type(slot) == "number"
								then slot
								else tonumber(string.match(slotPart.Name, "%d+")) or 0
							local ok, err = PlotService.AutoAssignMonster(player, slotNumber)
							if not ok then
								warn(`[PlotService] auto assign failed for {player.Name}: {err}`)
							end
						end))
					end
				end
			end
		end
	end
end

function PlotService.Init()
	Remotes.GetFunction(Remotes.Names.PlaceItem).OnServerInvoke = function(player, itemId, slot)
		if type(itemId) ~= "string" then
			return { ok = false, err = "bad_args" }
		end
		return { ok = PlotService.PlaceItem(player, itemId, slot) }
	end
	Remotes.GetFunction(Remotes.Names.AssignMonster).OnServerInvoke = function(player, slot, monsterUid)
		if type(slot) ~= "number" or type(monsterUid) ~= "string" then
			return { ok = false, err = "bad_args" }
		end
		return { ok = PlotService.AssignMonster(player, slot, monsterUid) }
	end
	Remotes.GetFunction(Remotes.Names.BuyPlotSlot).OnServerInvoke = function(player)
		local ok, slots, err = PlotService.BuySlot(player)
		if ok then
			local data = DataService.Get(player)
			if data then
				Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
			end
		end
		return { ok = ok, slots = slots, err = err }
	end

	Players.PlayerAdded:Connect(function(player)
		if DataService.WaitFor(player) then
			local plotsFolder = Workspace:FindFirstChild("Plots")
			if plotsFolder == nil then
				PlotService.ClaimPlot(player, nil)
			end
		end
	end)
	Players.PlayerRemoving:Connect(releasePlot)
	setupPlotPrompts()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if DataService.WaitFor(player) then
				local plotsFolder = Workspace:FindFirstChild("Plots")
				if plotsFolder == nil then
					PlotService.ClaimPlot(player, nil)
				end
			end
		end)
	end
	print("[PlotService] init")
end

return PlotService
