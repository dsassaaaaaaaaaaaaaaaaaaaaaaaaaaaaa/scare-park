--!strict
-- PlotService: выдача 8 участков вокруг хаба, сериализация построек в профиль.
-- Требование к карте: Workspace.Plots — папка с 8 моделями-участками,
-- в каждой PrimaryPart "Base" и папка "Slots" с частями-точками аттракционов.
-- Пока карты нет — сервис работает в "безкарточном" режиме и просто хранит данные.

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

function PlotService.GetPlot(player: Player): Instance?
	return playerPlots[player]
end

function PlotService.GetOwner(plot: Instance): Player?
	return plotOwners[plot]
end

--- Кол-во доступных слотов: старт 3, растёт гриндом/gamepass (хранить в профиле позже)
function PlotService.GetSlotCount(_player: Player): number
	return GameConfig.Plot.StartAttractionSlots
end

--- Поставить предмет в слот (валидация: слот в диапазоне, не занят)
function PlotService.PlaceItem(player: Player, itemId: string, slot: number): boolean
	local data = DataService.Get(player)
	if data == nil then
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
	PlotService.NotifyChanged(player)
	return true
end

--- Приставить монстра к слоту
function PlotService.AssignMonster(player: Player, slot: number, monsterUid: string): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	-- монстр существует и принадлежит игроку?
	local owns = false
	for _, monster in data.monsters do
		if monster.uid == monsterUid then
			owns = true
			break
		end
	end
	if not owns then
		return false
	end
	-- монстр не приставлен к другому слоту?
	for _, item in data.plot :: { PlotItem } do
		if item.monsterUid == monsterUid and item.slot ~= slot then
			return false
		end
	end
	for _, item in data.plot :: { PlotItem } do
		if item.slot == slot then
			item.monsterUid = monsterUid
			PlotService.NotifyChanged(player)
			return true
		end
	end
	return false
end

local function claimPlot(player: Player)
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if plotsFolder == nil then
		return -- карты ещё нет — безкарточный режим
	end
	for _, plot in plotsFolder:GetChildren() do
		if plotOwners[plot] == nil then
			plotOwners[plot] = player
			playerPlots[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			PlotService.NotifyChanged(player) -- спавн построек/монстров из data.plot
			return
		end
	end
	warn(`[PlotService] нет свободного участка для {player.Name} (максимум {GameConfig.Server.MaxPlayers})`)
end

local function releasePlot(player: Player)
	local plot = playerPlots[player]
	if plot then
		plotOwners[plot] = nil
		playerPlots[player] = nil
		plot:SetAttribute("OwnerUserId", nil)
		-- TODO: убрать заспавненные модели построек
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

	Players.PlayerAdded:Connect(function(player)
		if DataService.WaitFor(player) then
			claimPlot(player)
		end
	end)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if DataService.WaitFor(player) then
				claimPlot(player)
			end
		end)
	end
	print("[PlotService] init")
end

return PlotService
