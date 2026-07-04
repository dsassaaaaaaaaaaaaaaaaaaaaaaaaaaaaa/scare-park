--!strict
-- ShopService: детерминированная ротация магазина.
-- Сид = floor(os.time() / 300) → одинаковая витрина на ВСЕХ серверах, обновление каждые 5 минут.
-- Цена и содержимое витрины пересчитываются на сервере при покупке — клиенту не верим.

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

-- Цены покупки по редкости (баланс — тюнить)
local PRICE_BY_RARITY: { [string]: number } = {
	Common = 25,
	Rare = 120,
	Epic = 600,
	Legendary = 3500,
	Mythic = 15000,
}

-- Веса появления в ротации
local WEIGHT_BY_RARITY: { [string]: number } = {
	Common = 100,
	Rare = 35,
	Epic = 10,
	Legendary = 2,
	Mythic = 0.4,
}

-- Пул: только базовые монстры из каталога (Nightmare/Secret — не продаются)
local pool: { { id: string, weight: number } } = {}
local totalWeight = 0
for id, def in MonsterCatalog do
	local weight = WEIGHT_BY_RARITY[def.rarity]
	if weight then
		table.insert(pool, { id = id, weight = weight })
		totalWeight += weight
	end
end
table.sort(pool, function(a, b)
	return a.id < b.id -- детерминированный порядок пула на всех серверах
end)

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
		table.insert(showcase, { monsterId = picked, price = PRICE_BY_RARITY[def.rarity] })
	end
	return showcase
end

--- Покупка слота витрины. Всё валидируется на сервере.
function ShopService.Buy(player: Player, slotIndex: number): (boolean, string?)
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

	local showcase = ShopService.GetShowcase(ShopService.GetCurrentSeed())
	local slot = showcase[slotIndex]
	local def = MonsterCatalog[slot.monsterId]

	if not DataService.AddCurrency(player, "coins", -slot.price) then
		return false, "not_enough_coins"
	end

	table.insert(data.monsters, {
		uid = DataService.NextMonsterUid(data),
		id = def.id,
		rarity = def.rarity,
		mutation = nil,
		legendPoints = 0,
		primeStars = 0,
	})

	Remotes.GetEvent(Remotes.Names.CurrencyChanged):FireClient(player, "coins", data.coins)
	AnalyticsService.LogEconomy(player, "Sink", "coins", slot.price, `buy_{def.id}`)
	if #data.monsters == 1 then
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
		return { ok = ok, err = err }
	end

	-- Пуш витрины: новым игрокам сразу, всем — на границе ротации
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		Remotes.GetEvent(Remotes.Names.ShopRotation):FireClient(
			player,
			ShopService.GetShowcase(ShopService.GetCurrentSeed()),
			ShopService.GetNextRotationAt()
		)
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
