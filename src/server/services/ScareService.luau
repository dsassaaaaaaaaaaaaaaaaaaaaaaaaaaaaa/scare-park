--!strict
-- ScareService: шкала храбрости и очки страха. Считает ТОЛЬКО сервер.
-- Урон — в % от максимума. Эффект скримера рисует клиент, урон применяет сервер.
-- Испуг валидируется: дистанция до монстра, кулдаун монстра, посетитель в чужом парке.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ScareService = {}

local MAX_COURAGE = 100 -- шкала в процентах
local COURAGE_REGEN_PER_SEC = 2 -- восстановление вне испугов
local SCARE_RANGE = 30 -- studs: максимум для валидации испуга
local MONSTER_COOLDOWN = 8 -- сек между срабатываниями одного монстра по одному посетителю

export type VisitState = {
	hostPlot: Instance?, -- какой парк посещает
	hostPlayer: Player?,
	courage: number, -- 0..100
	startedAt: number,
	progress: number, -- 0..1 — доля пройденного (для правила "сбежал до середины")
	scareCooldowns: { [string]: number }, -- monsterUid → os.clock() последнего испуга
}

local visits: { [Player]: VisitState } = {}

--- Начать визит в чужой парк
function ScareService.StartVisit(visitor: Player, host: Player): boolean
	if visitor == host then
		return false
	end
	local hostPlot = PlotService.GetPlot(host)
	local data = DataService.Get(visitor)
	if data == nil then
		return false
	end
	visits[visitor] = {
		hostPlot = hostPlot,
		hostPlayer = host,
		courage = MAX_COURAGE,
		startedAt = os.time(),
		progress = 0,
		scareCooldowns = {},
	}
	data.stats.visits += 1
	if data.stats.visits == 1 then
		AnalyticsService.LogOnboardingStep(visitor, AnalyticsService.OnboardingSteps.FirstVisit, "FirstVisit")
	end
	AnalyticsService.LogEvent(visitor, "visit_started")
	return true
end

--- Урон храбрости в % от монстра. Вызывается СЕРВЕРНОЙ логикой монстра (триггеры),
--- НЕ клиентом напрямую. Возвращает true, если посетитель сбежал.
function ScareService.ApplyScare(
	visitor: Player,
	ownerUid: string,
	monsterEntry: any,
	visitorPosition: Vector3?,
	monsterPosition: Vector3?
): boolean
	local visit = visits[visitor]
	if visit == nil then
		return false
	end

	-- кулдаун монстра по этому посетителю
	local last = visit.scareCooldowns[ownerUid]
	if last and os.clock() - last < MONSTER_COOLDOWN then
		return false
	end
	-- валидация дистанции (если есть физические позиции)
	if visitorPosition and monsterPosition and (visitorPosition - monsterPosition).Magnitude > SCARE_RANGE then
		return false
	end
	visit.scareCooldowns[ownerUid] = os.clock()

	local def = MonsterCatalog[monsterEntry.id]
	local baseScare = if def then def.baseScare else 30
	-- урон: % от максимума, зависит от редкости (baseScare/5 ≈ 1..36%)
	local damagePct = math.clamp(baseScare / 5, 1, 60)

	-- множители мутации и престижа
	local mutation = monsterEntry.mutation and GameConfig.Mutations[monsterEntry.mutation]
	local mutationMult = if mutation then mutation.multiplier else 1
	local prestigeMult = 1 + (monsterEntry.primeStars or 0) * GameConfig.Prestige.ScareBonusPerStar

	-- экскурсионный режим: пол храбрости 10%
	local visitorData = DataService.Get(visitor)
	local floor = 0
	if visitorData and visitorData.stats.visits <= GameConfig.Scare.TourModeVisits then
		floor = MAX_COURAGE * GameConfig.Scare.TourModeCourageFloor
	end

	visit.courage = math.max(floor, visit.courage - damagePct)

	-- очки страха владельцу
	local host = visit.hostPlayer
	if host then
		local hostData = DataService.Get(host)
		if hostData then
			local points = math.floor(baseScare * mutationMult * prestigeMult)
			-- TODO Этап 2: множитель тиров (жертва сильно ниже → ×0.1) через RankService
			hostData.stats.scares += 1
			-- легенда монстра
			monsterEntry.legendPoints += points
			monsterEntry.primeStars = math.floor(monsterEntry.legendPoints / GameConfig.Prestige.LegendPerPrimeStar)
			-- TODO Этап 2: RankService.AddPoints(host, points)
		end
	end

	if visit.courage <= 0 then
		ScareService.EndVisit(visitor, true)
		return true
	end
	return false
end

--- Обновить прогресс прохождения (0..1) — вызывается чекпоинтами аттракциона
function ScareService.SetProgress(visitor: Player, progress: number)
	local visit = visits[visitor]
	if visit then
		visit.progress = math.clamp(progress, visit.progress, 1) -- только вперёд
	end
end

local teleportTo: (Player, BasePart?) -> ()

--- Завершение визита. escaped=true → побег.
function ScareService.EndVisit(visitor: Player, escaped: boolean)
	local visit = visits[visitor]
	if visit == nil then
		return
	end
	visits[visitor] = nil

	local data = DataService.Get(visitor)
	if data == nil then
		return
	end

	local reward = 0
	if escaped then
		data.stats.escapes += 1
		-- «смелость» пропорционально пройденной дистанции — побег не пустой
		reward = math.floor(20 * visit.progress)
		-- Правило анти-непроходимых парков: сбежал до середины → владельцу 0 очков
		-- (реализуется в начислении ранговых очков на Этапе 2; stats.scares уже засчитан)
		-- TODO: клиентская анимация паники (забавная — поражение = мем)
	else
		reward = 50 -- прошёл до конца: полная награда; TODO: трофей парка
	end
	if reward > 0 then
		DataService.AddCurrency(visitor, "courage", reward)
		Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(visitor, "courage", data.courage)
	end

	-- телепорт обратно в хаб
	local hubSpawn = game:GetService("Workspace"):FindFirstChild("HubSpawn") :: BasePart?
	teleportTo(visitor, hubSpawn)
	Remotes.GetEvent(Remotes.Names.CourageChanged):FireClient(visitor, nil)
	Remotes.GetEvent(Remotes.Names.VisitEnded):FireClient(visitor, escaped, reward)
end

function ScareService.GetCourage(visitor: Player): number?
	local visit = visits[visitor]
	return visit and visit.courage or nil
end

--- Все посетители, находящиеся сейчас в парке host
function ScareService.GetVisitorsOf(host: Player): { Player }
	local result: { Player } = {}
	for visitor, visit in visits do
		if visit.hostPlayer == host then
			table.insert(result, visitor)
		end
	end
	return result
end

--- Телепорт персонажа к части (если есть)
teleportTo = function(player: Player, part: BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and part then
		root.CFrame = part.CFrame + Vector3.new(0, 4, 0)
	end
end

--- Визит в случайный чужой парк на этом сервере
function ScareService.RequestVisit(visitor: Player): (boolean, string?, string?)
	if visits[visitor] then
		return false, nil, "already_visiting"
	end
	-- кандидаты: игроки с участком, кроме самого посетителя
	local candidates: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player ~= visitor and PlotService.GetPlot(player) ~= nil then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		return false, nil, "no_parks" -- TODO Этап 2: NPC-заглушка / телепорт на другой сервер
	end
	local host = candidates[math.random(#candidates)]
	if not ScareService.StartVisit(visitor, host) then
		return false, nil, "failed"
	end
	local plot = PlotService.GetPlot(host)
	local entrance = plot and plot:FindFirstChild("Entrance") :: BasePart?
	teleportTo(visitor, entrance)
	Remotes.GetEvent(Remotes.Names.CourageChanged):FireClient(visitor, MAX_COURAGE)
	return true, host.Name, nil
end

function ScareService.Init()
	Remotes.GetFunction(Remotes.Names.RequestVisit).OnServerInvoke = function(visitor)
		local ok, hostName, err = ScareService.RequestVisit(visitor)
		return { ok = ok, hostName = hostName, err = err }
	end
	Remotes.GetFunction(Remotes.Names.LeaveVisit).OnServerInvoke = function(visitor)
		if visits[visitor] == nil then
			return { ok = false }
		end
		ScareService.EndVisit(visitor, true) -- добровольный выход = побег (награда за прогресс)
		return { ok = true }
	end

	-- восстановление храбрости
	task.spawn(function()
		while true do
			task.wait(1)
			for _, visit in visits do
				visit.courage = math.min(MAX_COURAGE, visit.courage + COURAGE_REGEN_PER_SEC)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)

	print("[ScareService] init")
end

return ScareService
