--!strict
-- Pure shop rotation logic. Safe to run in Lune tests: no Roblox services required.

local ShopLogic = {}

export type ShopSlot = {
	monsterId: string,
	price: number,
}

local function createDeterministicRandom(seed: number): any
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end

	local random = {}

	function random:NextNumber(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end

	function random:NextInteger(min: number, max: number): number
		return min + math.floor(self:NextNumber() * (max - min + 1))
	end

	return random
end

function ShopLogic.BuildPool(config: any, catalog: any): ({ { id: string, weight: number } }, number)
	local pool: { { id: string, weight: number } } = {}
	local totalWeight = 0

	for id, def in catalog do
		local weight = config.Shop.WeightByRarity[def.rarity]
		if weight then
			table.insert(pool, { id = id, weight = weight })
			totalWeight += weight
		end
	end

	table.sort(pool, function(a, b)
		return a.id < b.id
	end)

	return pool, totalWeight
end

function ShopLogic.GetShowcase(config: any, catalog: any, seed: number, rngFactory: ((number) -> any)?): { ShopSlot }
	local pool, totalWeight = ShopLogic.BuildPool(config, catalog)
	local rng = if rngFactory then rngFactory(seed) else createDeterministicRandom(seed)
	local showcase: { ShopSlot } = {}

	for _ = 1, config.Shop.SlotCount do
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

		local def = catalog[picked]
		table.insert(showcase, { monsterId = picked, price = config.Shop.PriceByRarity[def.rarity] })
	end

	return showcase
end

return ShopLogic
