--!strict
-- Pure income logic. Safe to run in Lune tests: no Roblox services required.

local IncomeLogic = {}

local function utcDay(atTime: number): number
	return math.floor(atTime / 86400)
end

function IncomeLogic.GetIncomePerMinute(data: any, config: any, catalog: any): number
	local total = 0
	for _, item in data.plot do
		if item.monsterUid then
			for _, monster in data.monsters do
				if monster.uid == item.monsterUid then
					local def = catalog[monster.id]
					local base = if def then def.baseIncome else 1
					local mutation = monster.mutation and config.Mutations[monster.mutation]
					local mult = if mutation then mutation.multiplier else 1
					total += base * mult
					break
				end
			end
		end
	end
	return total
end

function IncomeLogic.Credit(data: any, rawAmount: number): number
	local withRemainder = rawAmount + data.income.remainder
	local whole = math.floor(withRemainder)
	data.income.remainder = withRemainder - whole
	if whole > 0 then
		data.coins += whole
	end
	return whole
end

function IncomeLogic.GrantOffline(data: any, config: any, catalog: any, now: number): any
	if data.lastSeenAt == 0 then
		return { payableSeconds = 0, raw = 0, credited = 0 }
	end

	local awaySeconds = math.max(0, now - data.lastSeenAt)
	if awaySeconds == 0 then
		return { payableSeconds = 0, raw = 0, credited = 0 }
	end

	local today = utcDay(now)
	if data.income.offlineDay ~= today then
		data.income.offlineDay = today
		data.income.offlinePaidSeconds = 0
	end

	local capSeconds = config.Income.OfflineDailyCapHours * 3600
	local remainingSeconds = math.max(0, capSeconds - data.income.offlinePaidSeconds)
	local payableSeconds = math.min(awaySeconds, remainingSeconds)
	if payableSeconds <= 0 then
		return { payableSeconds = 0, raw = 0, credited = 0 }
	end

	data.income.offlinePaidSeconds += payableSeconds

	local raw = IncomeLogic.GetIncomePerMinute(data, config, catalog)
		* (payableSeconds / 60)
		* config.Income.OfflineRate
	local credited = IncomeLogic.Credit(data, raw)
	return { payableSeconds = payableSeconds, raw = raw, credited = credited }
end

return IncomeLogic
