--!strict
-- MonsterRuntime: физическое присутствие монстров на участках.
-- Модели берутся из ServerStorage.MonsterModels[monsterId] (контракт с дизайном —
-- docs/CONTRACT.md). Нет модели → фабрика создаёт программный плейсхолдер.
-- Испуг: диспетчер механик на сервере → ScareService.ApplyScare → эффект на клиент.

local DataService = require(script.Parent.DataService)
local MonsterModelFactory = require(script.Parent.MonsterModelFactory)
local PlotService = require(script.Parent.PlotService)
local ScareMechanics = require(script.Parent.ScareMechanics)
local ScareService = require(script.Parent.ScareService)

local MonsterRuntime = {}

local CHECK_INTERVAL = 0.5

export type SpawnedMonster = {
	model: Model,
	owner: Player,
	entry: any, -- MonsterEntry из профиля
	homeCFrame: CFrame,
}

local spawned: { [string]: SpawnedMonster } = {} -- monsterUid → спавн

--- Заспавнить монстра на слоте участка. slotPart — точка из папки Slots (или nil → безкарточный режим)
function MonsterRuntime.Spawn(owner: Player, entry: any, slotPart: BasePart?)
	MonsterRuntime.Despawn(entry.uid)
	if slotPart == nil then
		return -- карты нет — физический спавн невозможен
	end
	local model = MonsterModelFactory.GetModel(entry.id)
	local homeCFrame = slotPart.CFrame + Vector3.new(0, 3, 0)
	model:PivotTo(homeCFrame)
	model:SetAttribute("MonsterUid", entry.uid)
	model:SetAttribute("OwnerUserId", owner.UserId)
	model.Parent = slotPart.Parent
	spawned[entry.uid] = { model = model, owner = owner, entry = entry, homeCFrame = homeCFrame }
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

-- Серверная петля: диспетчер механик пугает только посетителей ЭТОГО парка.
local function scareLoop()
	while true do
		task.wait(CHECK_INTERVAL)
		for _, record in spawned do
			for _, visitor in ScareService.GetVisitorsOf(record.owner) do
				ScareMechanics.Tick(record, visitor)
			end
		end
	end
end

function MonsterRuntime.Init()
	MonsterModelFactory.EnsureAll()
	PlotService.OnPlotChanged(MonsterRuntime.RefreshPlot)
	game:GetService("Players").PlayerRemoving:Connect(MonsterRuntime.DespawnAllFor)
	task.spawn(scareLoop)
	print("[MonsterRuntime] init")
end

return MonsterRuntime
