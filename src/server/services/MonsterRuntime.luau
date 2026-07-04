--!strict
-- MonsterRuntime: физическое присутствие монстров на участках.
-- Модели берутся из ServerStorage.MonsterModels[monsterId] (контракт с дизайном —
-- docs/CONTRACT.md). Нет модели → плейсхолдер-часть, код работает без арта.
-- Испуг: проксимити-петля на сервере → ScareService.ApplyScare → эффект на клиент.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local ScareService = require(script.Parent.ScareService)

local MonsterRuntime = {}

local TRIGGER_RANGE = 14 -- studs: дистанция срабатывания испуга (меньше SCARE_RANGE валидации)
local CHECK_INTERVAL = 0.5

export type SpawnedMonster = {
	model: Model,
	owner: Player,
	entry: any, -- MonsterEntry из профиля
}

local spawned: { [string]: SpawnedMonster } = {} -- monsterUid → спавн

local function makePlaceholder(monsterId: string): Model
	local def = MonsterCatalog[monsterId]
	local model = Instance.new("Model")
	model.Name = monsterId
	local part = Instance.new("Part")
	part.Name = "Body"
	part.Size = Vector3.new(2, 4, 2)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(90, 30, 120)
	part.Parent = model
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = if def then def.name else monsterId
	label.Parent = billboard
	billboard.Parent = part
	model.PrimaryPart = part
	return model
end

local function getModel(monsterId: string): Model
	local folder = ServerStorage:FindFirstChild("MonsterModels")
	local template = folder and folder:FindFirstChild(monsterId)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		if clone.PrimaryPart == nil then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
		end
		return clone
	end
	return makePlaceholder(monsterId)
end

--- Заспавнить монстра на слоте участка. slotPart — точка из папки Slots (или nil → безкарточный режим)
function MonsterRuntime.Spawn(owner: Player, entry: any, slotPart: BasePart?)
	MonsterRuntime.Despawn(entry.uid)
	if slotPart == nil then
		return -- карты нет — физический спавн невозможен
	end
	local model = getModel(entry.id)
	model:PivotTo(slotPart.CFrame + Vector3.new(0, 3, 0))
	model:SetAttribute("MonsterUid", entry.uid)
	model:SetAttribute("OwnerUserId", owner.UserId)
	model.Parent = slotPart.Parent
	spawned[entry.uid] = { model = model, owner = owner, entry = entry }
end

function MonsterRuntime.Despawn(monsterUid: string)
	local record = spawned[monsterUid]
	if record then
		record.model:Destroy()
		spawned[monsterUid] = nil
	end
end

function MonsterRuntime.DespawnAllFor(owner: Player)
	for uid, record in spawned do
		if record.owner == owner then
			MonsterRuntime.Despawn(uid)
		end
	end
end

--- Перестроить всех монстров участка по данным профиля (вызывать после Place/Assign/Fusion)
function MonsterRuntime.RefreshPlot(owner: Player)
	MonsterRuntime.DespawnAllFor(owner)
	local data = DataService.Get(owner)
	local plot = PlotService.GetPlot(owner)
	if data == nil or plot == nil then
		return
	end
	local slotsFolder = plot:FindFirstChild("Slots")
	if slotsFolder == nil then
		return
	end
	for _, item in data.plot do
		if item.monsterUid then
			local slotPart = slotsFolder:FindFirstChild(`Slot{item.slot}`)
			if slotPart and slotPart:IsA("BasePart") then
				for _, monster in data.monsters do
					if monster.uid == item.monsterUid then
						MonsterRuntime.Spawn(owner, monster, slotPart)
						break
					end
				end
			end
		end
	end
end

-- Проксимити-петля: монстр пугает посетителей рядом
local function scareLoop()
	while true do
		task.wait(CHECK_INTERVAL)
		for uid, record in spawned do
			local primary = record.model.PrimaryPart
			if primary == nil then
				continue
			end
			local monsterPosition = primary.Position
			-- пугаем только посетителей ЭТОГО парка
			local plot = PlotService.GetPlot(record.owner)
			for _, visitor in ScareService.GetVisitorsOf(record.owner) do
				local character = visitor.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root == nil then
					continue
				end
				if (root.Position - monsterPosition).Magnitude <= TRIGGER_RANGE then
					local escaped = ScareService.ApplyScare(visitor, uid, record.entry, root.Position, monsterPosition)
					local def = MonsterCatalog[record.entry.id]
					Remotes.GetEvent(Remotes.Names.ScareEffect)
						:FireClient(visitor, record.entry.id, if def then def.scareMechanic else "generic")
					local courage = ScareService.GetCourage(visitor)
					Remotes.GetEvent(Remotes.Names.CourageChanged):FireClient(visitor, courage)
					local _ = escaped -- телепорт при побеге делает ScareService.EndVisit
					local _2 = plot
				end
			end
		end
	end
end

function MonsterRuntime.Init()
	PlotService.OnPlotChanged(MonsterRuntime.RefreshPlot)
	game:GetService("Players").PlayerRemoving:Connect(MonsterRuntime.DespawnAllFor)
	task.spawn(scareLoop)
	print("[MonsterRuntime] init")
end

return MonsterRuntime
