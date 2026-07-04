--!strict
-- ShopService: детерминированная ротация магазина.
-- Сид = floor(os.time()/300) → одинаковая витрина на ВСЕХ серверах.
-- Баланс и анти-эксплойт: docs/economy/README.md (§4 п.1–4, флаг №2):
--   сток 1 на позицию за ротацию, дневные лимиты по редкости, серверный rate-limit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ShopService = {}

export type ShopSlot = {
	monsterId: string,
	price: number,
}

-- Пул ротации: только редкости с весом в конфиге (Mythic не продаётся)
local pool: { { id: string, weight: number } } = {}
local totalWeight = 0
for id, def in MonsterCatalog do
	local weight = GameConfig.Shop.WeightByRarity[def.rarity]
	if weight then
		table.insert(pool, { id = id, weight = weight })
	end
end
table.sort(pool, function(a, b)
	return a.id < b.id -- детерминированный порядок пула на всех серверах
end)
for _, entry in pool do
	totalWeight += entry.weight
end

local lastBuyAt: { [Player]: number } = {} -- rate-limit

local function utcDay(): number
	return math.floor(os.time() / 86400)
end

function ShopService.GetCurrentSeed(): number
	return math.floor(os.time() / GameConfig.Shop.RotationSeconds)
end

function ShopService.GetNextRotationAt(): number
	return (ShopService.GetCurrentSeed() + 1) * GameConfig.Shop.RotationSeconds
end

--- Витрина для сида: детерминированная на всех серверах
function ShopService.GetShowcase(seed: number): { ShopSlot }
	local rng = Random.new(seed)
	local showcase: { ShopSlot } = {}
	for _ = 1, GameConfig.Shop.SlotCount do
		local roll = rng:NextNumber() * totalWeight
		local acc = 0
		local picked = pool[#pool].id
		for _, entry in pool do
			acc += entry.weight
			if roll <= acc then
				picked = entry.id
				break
			end
		end
		local def = MonsterCatalog[picked]
		table.insert(showcase, { monsterId = picked, price = GameConfig.Shop.PriceByRarity[def.rarity] })
	end
	return showcase
end

--- Сбросить счётчики стока/лимитов, если началась новая ротация/новый день
local function refreshShopState(data: any)
	local seed = ShopService.GetCurrentSeed()
	if data.shopState.rotationSeed ~= seed then
		data.shopState.rotationSeed = seed
		data.shopState.boughtSlots = {}
	end
	local day = utcDay()
	if data.shopState.day ~= day then
		data.shopState.day = day
		data.shopState.boughtByRarity = {}
	end
end

--- Остатки для UI: {slotIndex → осталось}, {rarity → осталось сегодня}
function ShopService.GetLimits(player: Player): any?
	local data = DataService.Get(player)
	if data == nil then
		return nil
	end
	refreshShopState(data)
	local slotsLeft: { [string]: number } = {}
	for i = 1, GameConfig.Shop.SlotCount do
		local key = tostring(i)
		slotsLeft[key] = GameConfig.Shop.StockPerSlot - (data.shopState.boughtSlots[key] or 0)
	end
	local dailyLeft: { [string]: number } = {}
	for rarity, cap in GameConfig.Shop.DailyBuyCap do
		dailyLeft[rarity] = cap - (data.shopState.boughtByRarity[rarity] or 0)
	end
	return { slotsLeft = slotsLeft, dailyLeft = dailyLeft }
end

--- Покупка слота витрины. Всё валидируется на сервере.
function ShopService.Buy(player: Player, slotIndex: number): (boolean, string?)
	-- rate-limit (анти-спам клиента)
	local now = os.clock()
	local last = lastBuyAt[player]
	if last and now - last < GameConfig.Shop.BuyCooldownSeconds then
		return false, "too_fast"
	end
	lastBuyAt[player] = now

	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
		return false, "bad_args"
	end
	if slotIndex < 1 or slotIndex > GameConfig.Shop.SlotCount then
		return false, "bad_slot"
	end
	local data = DataService.Get(player)
	if data == nil then
		return false, "no_profile"
	end

	refreshShopState(data)

	-- сток позиции (флаг №2)
	local slotKey = tostring(slotIndex)
	if (data.shopState.boughtSlots[slotKey] or 0) >= GameConfig.Shop.StockPerSlot then
		return false, "sold_out"
	end

	local showcase = ShopService.GetShowcase(ShopService.GetCurrentSeed())
	local slot = showcase[slotIndex]
	local def = MonsterCatalog[slot.monsterId]

	-- дневной лимит редкости (economy §4 п.4)
	local cap = GameConfig.Shop.DailyBuyCap[def.rarity]
	if cap == nil then
		return false, "not_for_sale"
	end
	local boughtToday = data.shopState.boughtByRarity[def.rarity] or 0
	if boughtToday >= cap then
		return false, "daily_cap"
	end

	if not DataService.AddCurrency(player, "coins", -slot.price) then
		return false, "not_enough_coins"
	end

	data.shopState.boughtSlots[slotKey] = (data.shopState.boughtSlots[slotKey] or 0) + 1
	data.shopState.boughtByRarity[def.rarity] = boughtToday + 1

	table.insert(data.monsters, {
		uid = DataService.NextMonsterUid(data),
		id = def.id,
		rarity = def.rarity,
		mutation = nil, -- мутации ТОЛЬКО из фьюжна (economy флаг №10)
		legendPoints = 0,
		primeStars = 0,
	})

	Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
	AnalyticsService.LogEconomy(player, "Sink", "coins", slot.price, `buy_{def.id}`)
	if #data.monsters == 2 then -- первый купленный (m1 — стартовый подарок)
		AnalyticsService.LogOnboardingStep(player, AnalyticsService.OnboardingSteps.FirstMonsterBought, "FirstMonsterBought")
	end
	return true
end

local function broadcastRotation()
	local seed = ShopService.GetCurrentSeed()
	local showcase = ShopService.GetShowcase(seed)
	local nextAt = ShopService.GetNextRotationAt()
	Remotes.GetEvent(Remotes.Names.ShopRotation):FireAllClients(showcase, nextAt)
end

function ShopService.Init()
	Remotes.GetFunction(Remotes.Names.BuyShopSlot).OnServerInvoke = function(player, slotIndex)
		local ok, err = ShopService.Buy(player, slotIndex)
		return { ok = ok, err = err, limits = ShopService.GetLimits(player) }
	end

	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		Remotes.GetEvent(Remotes.Names.ShopRotation):FireClient(
			player,
			ShopService.GetShowcase(ShopService.GetCurrentSeed()),
			ShopService.GetNextRotationAt()
		)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuyAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(ShopService.GetNextRotationAt() - os.time() + 0.5)
			broadcastRotation()
		end
	end)

	print(`[ShopService] init, seed={ShopService.GetCurrentSeed()}, pool={#pool}`)
end

return ShopService
