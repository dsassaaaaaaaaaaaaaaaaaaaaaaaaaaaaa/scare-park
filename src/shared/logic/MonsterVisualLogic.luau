--!strict
-- Pure visual placeholder helpers. Safe to run in Lune tests: no Roblox services required.

local MonsterVisualLogic = {}

export type RgbColor = {
	r: number,
	g: number,
	b: number,
}

export type Size3 = {
	x: number,
	y: number,
	z: number,
}

local SIZE_BY_RARITY: { [string]: Size3 } = {
	Common = { x = 1.8, y = 2.4, z = 1.8 },
	Rare = { x = 2.1, y = 3.0, z = 2.1 },
	Epic = { x = 2.5, y = 3.8, z = 2.5 },
	Legendary = { x = 3.0, y = 4.8, z = 3.0 },
	Mythic = { x = 3.4, y = 5.6, z = 3.4 },
	Nightmare = { x = 4.2, y = 6.8, z = 4.2 },
	Secret = { x = 4.6, y = 7.2, z = 4.6 },
}

function MonsterVisualLogic.HashId(id: string): number
	local hash = 2166136261
	for i = 1, #id do
		hash = (hash * 16777619 + string.byte(id, i)) % 4294967296
	end
	return hash
end

function MonsterVisualLogic.ColorFromId(id: string): RgbColor
	local hash = MonsterVisualLogic.HashId(id)
	return {
		r = 60 + (hash % 176),
		g = 60 + (math.floor(hash / 256) % 176),
		b = 60 + (math.floor(hash / 65536) % 176),
	}
end

function MonsterVisualLogic.SizeForRarity(rarity: string): Size3
	local size = SIZE_BY_RARITY[rarity] or SIZE_BY_RARITY.Common
	return {
		x = size.x,
		y = size.y,
		z = size.z,
	}
end

return MonsterVisualLogic
