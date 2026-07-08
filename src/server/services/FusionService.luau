--!strict
-- FusionService: фьюжн 4 монстров → монстр более высокой редкости.
-- Таймеры от os.time() (работают офлайн). Рецепты и шансы мутаций — SecretConfig (только сервер).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local FusionLogic = require(ReplicatedStorage.Shared.logic.FusionLogic)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local SecretConfig = require(script.Parent.Parent.config.SecretConfig)

local FusionService = {}

local rng = Random.new()

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

function FusionService.RecipeKey(monsterIds: { string }): string
	return FusionLogic.RecipeKey(monsterIds)
end

function FusionService.Start(player: Player, uids: { string }): (boolean, number?, string?)
	if not GameConfig.Flags.FusionEnabled then
		return false, nil, "disabled"
	end

	local data = DataService.Get(player)
	if data == nil then
		return false, nil, "no_profile"
	end

	local ok, result, err = FusionLogic.StartFusion(data, GameConfig, MonsterCatalog, uids, {
		recipes = SecretConfig.FusionRecipes,
		now = os.time(),
		rng = rng,
	})
	if not ok then
		return false, nil, err
	end

	PlotService.NotifyChanged(player) -- сгоревшие монстры сняты со слотов

	local currencyEvent = Remotes.GetEvent(Remotes.Names.CurrencyChanged)
	currencyEvent:FireClient(player, "coins", data.coins)
	if result.fee > 0 then
		AnalyticsService.LogEconomy(player, "Sink", "coins", result.fee, `fusion_fee_{result.rarity}`)
	end
	AnalyticsService.LogEvent(player, "fusion_started")

	return true, result.finishAt, nil
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
