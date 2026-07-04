--!strict
-- FusionService: фьюжн 4 монстров → монстр более высокой редкости.
-- Таймеры от os.time() (работают офлайн). Рецепты и шансы мутаций — SecretConfig (только сервер).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local SecretConfig = require(script.Parent.Parent.config.SecretConfig)

local FusionService = {}

local RARITY_INDEX: { [string]: number } = {}
for i, rarity in GameConfig.Rarities do
	RARITY_INDEX[rarity] = i
end

local rng = Random.new()

function FusionService.RecipeKey(monsterIds: { string }): string
	local sorted = table.clone(monsterIds)
	table.sort(sorted)
	return table.concat(sorted, "+")
end

--- Доминантная редкость: среднее индексов 4 монстров, округление вверх, +1 ступень
local function resultRarity(monsters: { any }): string
	local sum = 0
	for _, monster in monsters do
		sum += RARITY_INDEX[monster.rarity] or 1
	end
	local avg = math.ceil(sum / #monsters)
	local idx = math.min(avg + 1, #GameConfig.Rarities)
	return GameConfig.Rarities[idx]
end

local function rollMutation(): string?
	local roll = rng:NextNumber()
	local acc = 0
	for mutation, chance in SecretConfig.MutationChances :: { [string]: number } do
		acc += chance
		if roll <= acc then
			return mutation
		end
	end
	return nil
end

--- Случайный монстр каталога данной редкости (для результата фьюжна)
local function pickMonsterOfRarity(rarity: string): string
	local candidates: { string } = {}
	for id, def in MonsterCatalog do
		if def.rarity == rarity then
			table.insert(candidates, id)
		end
	end
	table.sort(candidates)
	if #candidates == 0 then
		-- редкость выше Mythic пока без каталога → отдаём Mythic
		return pickMonsterOfRarity("Mythic")
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

function FusionService.Start(player: Player, uids: { string }): (boolean, number?, string?)
	if not GameConfig.Flags.FusionEnabled then
		return false, nil, "disabled"
	end
	if type(uids) ~= "table" or #uids ~= GameConfig.Fusion.SlotCount then
		return false, nil, "bad_args"
	end
	local data = DataService.Get(player)
	if data == nil then
		return false, nil, "no_profile"
	end
	if data.fusion.finishAt ~= 0 then
		return false, nil, "fusion_busy"
	end

	-- игрок владеет всеми 4, без дублей uid
	local selected: { any } = {}
	local seen: { [string]: boolean } = {}
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return false, nil, "bad_args"
		end
		seen[uid] = true
		for _, monster in data.monsters do
			if monster.uid == uid then
				table.insert(selected, monster)
				break
			end
		end
	end
	if #selected ~= GameConfig.Fusion.SlotCount then
		return false, nil, "not_owned"
	end
	-- престижных не сжигаем? Нет: сжигать МОЖНО (дилемма из дизайна), переманивать нельзя.

	-- Секретный рецепт или обычный фьюжн
	local ids: { string } = {}
	for _, monster in selected do
		table.insert(ids, monster.id)
	end
	local recipeResult = SecretConfig.FusionRecipes[FusionService.RecipeKey(ids)]
	local rarity = if recipeResult then "Nightmare" else resultRarity(selected)

	-- Забрать 4 монстров из инвентаря (сгорают сразу — иначе дюп через выход из игры)
	for _, uid in uids do
		for i, monster in data.monsters do
			if monster.uid == uid then
				table.remove(data.monsters, i)
				break
			end
		end
		-- снять с участка, если был приставлен
		for _, item in data.plot do
			if item.monsterUid == uid then
				item.monsterUid = nil
			end
		end
	end

	PlotService.NotifyChanged(player) -- сгоревшие монстры сняты со слотов

	AnalyticsService.LogEvent(player, "fusion_started")

	local timer = GameConfig.Fusion.TimersByRarity[rarity] or GameConfig.Fusion.TimersByRarity.Common
	local finishAt = os.time() + timer
	data.fusion = {
		slots = uids,
		finishAt = finishAt,
		-- результат фиксируем при старте — клейм не переролливается перезаходом
		resultUid = recipeResult or pickMonsterOfRarity(rarity),
	}
	return true, finishAt, nil
end

function FusionService.Claim(player: Player): (boolean, any?, string?)
	local data = DataService.Get(player)
	if data == nil then
		return false, nil, "no_profile"
	end
	if data.fusion.finishAt == 0 then
		return false, nil, "no_fusion"
	end
	if os.time() < data.fusion.finishAt then
		return false, nil, "not_ready"
	end

	local monsterId = data.fusion.resultUid
	local def = MonsterCatalog[monsterId]
	local rarity = if def then def.rarity else "Nightmare" -- секретные боссы не в публичном каталоге

	local newMonster = {
		uid = DataService.NextMonsterUid(data),
		id = monsterId,
		rarity = rarity,
		mutation = rollMutation(),
		legendPoints = 0,
		primeStars = 0,
	}
	table.insert(data.monsters, newMonster)
	data.fusion = { slots = {}, finishAt = 0, resultUid = "" }
	AnalyticsService.LogEvent(player, `fusion_claimed_{rarity}`)
	return true, newMonster, nil
end

function FusionService.Init()
	Remotes.GetFunction(Remotes.Names.StartFusion).OnServerInvoke = function(player, uids)
		local ok, finishAt, err = FusionService.Start(player, uids)
		return { ok = ok, finishAt = finishAt, err = err }
	end
	Remotes.GetFunction(Remotes.Names.ClaimFusion).OnServerInvoke = function(player)
		local ok, monster, err = FusionService.Claim(player)
		return { ok = ok, monster = monster, err = err }
	end
	print("[FusionService] init")
end

return FusionService
