--!strict
-- Remotes: единая точка создания/получения RemoteEvent/RemoteFunction.
-- Сервер создаёт, клиент ждёт. Имена — только отсюда, никаких строк по коду.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

Remotes.Names = {
	-- RemoteFunction (клиент → сервер, с ответом)
	BuyShopSlot = "BuyShopSlot", -- (slotIndex) → {ok, err?}
	StartFusion = "StartFusion", -- ({uid1..uid4}) → {ok, finishAt?, err?}
	ClaimFusion = "ClaimFusion", -- () → {ok, monster?, err?}
	PlaceItem = "PlaceItem", -- (itemId, slot) → {ok, err?}
	AssignMonster = "AssignMonster", -- (slot, monsterUid) → {ok, err?}
	-- RemoteEvent (сервер → клиент)
	ShopRotation = "ShopRotation", -- (витрина, nextRotationAt)
	ProfileLoaded = "ProfileLoaded", -- (снапшот данных для HUD)
	CurrencyChanged = "CurrencyChanged", -- (currency, newValue)
}

local remoteFunctions = { "BuyShopSlot", "StartFusion", "ClaimFusion", "PlaceItem", "AssignMonster" }

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if folder == nil then
			folder = Instance.new("Folder")
			assert(folder)
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
			for _, name in remoteFunctions do
				local rf = Instance.new("RemoteFunction")
				rf.Name = name
				rf.Parent = folder
			end
			for name in Remotes.Names do
				if not table.find(remoteFunctions, name) then
					local re = Instance.new("RemoteEvent")
					re.Name = name
					re.Parent = folder
				end
			end
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.GetEvent(name: string): RemoteEvent
	local folder = getFolder()
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
	local folder = getFolder()
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
