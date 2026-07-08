--!strict
-- Pure fusion planning/state transition logic. Safe to run in Lune tests: no Roblox services required.

local FusionLogic = {}

export type StartOptions = {
	now: number?,
	recipes: { [string]: string }?,
	rng: any?,
}

local function buildRarityIndex(config: any): { [string]: number }
	local rarityIndex: { [string]: number } = {}
	for i, rarity in config.Rarities do
		rarityIndex[rarity] = i
	end
	return rarityIndex
end

function FusionLogic.RecipeKey(monsterIds: { string }): string
	local sorted = table.clone(monsterIds)
	table.sort(sorted)
	return table.concat(sorted, "+")
end

function FusionLogic.GetRegularResultRarity(config: any, monsters: { any }): (string?, string?)
	local rarityIndex = buildRarityIndex(config)
	local rarity = monsters[1].rarity

	for _, monster in monsters do
		if monster.rarity ~= rarity then
			return nil, "mixed_rarities"
		end
	end

	local maxIdx = rarityIndex[config.Fusion.MaxRegularResultRarity]
	local idx = rarityIndex[rarity] or 1
	if idx >= maxIdx then
		return nil, "max_rarity"
	end

	return config.Rarities[idx + 1], nil
end

function FusionLogic.PickMonsterOfRarity(catalog: any, rarity: string, rng: any?): string
	local candidates: { string } = {}
	for id, def in catalog do
		if def.rarity == rarity then
			table.insert(candidates, id)
		end
	end
	table.sort(candidates)

	if #candidates == 0 then
		if rarity ~= "Mythic" then
			return FusionLogic.PickMonsterOfRarity(catalog, "Mythic", rng)
		end
		error("no monster candidates for rarity " .. rarity)
	end

	local index = if rng then rng:NextInteger(1, #candidates) else 1
	return candidates[index]
end

local function findSelected(data: any, uids: { string }, slotCount: number): ({ any }?, string?)
	if type(uids) ~= "table" or #uids ~= slotCount then
		return nil, "bad_args"
	end

	local ownedByUid: { [string]: any } = {}
	for _, monster in data.monsters do
		ownedByUid[monster.uid] = monster
	end

	local selected: { any } = {}
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return nil, "bad_args"
		end
		seen[uid] = true

		local monster = ownedByUid[uid]
		if monster == nil then
			return nil, "not_owned"
		end
		table.insert(selected, monster)
	end

	return selected, nil
end

function FusionLogic.StartFusion(
	data: any,
	config: any,
	catalog: any,
	uids: { string },
	options: StartOptions?
): (boolean, any?, string?)
	if data.fusion.finishAt ~= 0 then
		return false, nil, "fusion_busy"
	end

	local selected, selectedErr = findSelected(data, uids, config.Fusion.SlotCount)
	if selected == nil then
		return false, nil, selectedErr
	end

	local ids: { string } = {}
	for _, monster in selected do
		table.insert(ids, monster.id)
	end

	local recipes = if options and options.recipes then options.recipes else {}
	local recipeResult = recipes[FusionLogic.RecipeKey(ids)]
	local rarity: string
	if recipeResult then
		local def = catalog[recipeResult]
		rarity = if def then def.rarity else "Nightmare"
	else
		local regularRarity, rarityErr = FusionLogic.GetRegularResultRarity(config, selected)
		if regularRarity == nil then
			return false, nil, rarityErr
		end
		rarity = regularRarity
	end

	local fee = config.Fusion.FeesByRarity[rarity] or 0
	if fee > 0 and data.coins < fee then
		return false, nil, "not_enough_coins"
	end

	-- Pure testable logic mutates the in-memory profile table directly; runtime services remain the
	-- single place that obtains profiles and notifies clients around DataService-owned currency changes.
	data.coins -= fee

	local selectedUids: { [string]: boolean } = {}
	for _, uid in uids do
		selectedUids[uid] = true
	end

	for i = #data.monsters, 1, -1 do
		if selectedUids[data.monsters[i].uid] then
			table.remove(data.monsters, i)
		end
	end

	for _, item in data.plot do
		if item.monsterUid and selectedUids[item.monsterUid] then
			item.monsterUid = nil
		end
	end

	local now = if options and options.now then options.now else os.time()
	local timer = config.Fusion.TimersByRarity[rarity] or config.Fusion.TimersByRarity.Rare
	local resultUid = recipeResult
		or FusionLogic.PickMonsterOfRarity(catalog, rarity, if options then options.rng else nil)
	local finishAt = now + timer

	data.fusion = {
		slots = table.clone(uids),
		finishAt = finishAt,
		resultUid = resultUid,
	}

	return true, {
		finishAt = finishAt,
		fee = fee,
		rarity = rarity,
		resultUid = resultUid,
	}, nil
end

return FusionLogic
