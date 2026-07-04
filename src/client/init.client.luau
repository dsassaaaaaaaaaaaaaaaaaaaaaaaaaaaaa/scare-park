--!strict
-- Точка входа клиента. Клиент только отображает — вся логика на сервере.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hud = require(script.ui.Hud)
local ShopUI = require(script.ui.ShopUI)
local FusionUI = require(script.ui.FusionUI)
local VisitUI = require(script.ui.VisitUI)

local gui = Hud.Build({
	onShop = ShopUI.Toggle,
	onFusion = FusionUI.Toggle,
})
ShopUI.Build(gui, function()
	local snapshot = Remotes.GetFunction(Remotes.Names.GetSnapshot):InvokeServer()
	if snapshot then
		FusionUI.SetMonsters(snapshot.monsters)
	end
end)
FusionUI.Build(gui)
VisitUI.Build(gui)

local function applySnapshot(snapshot: any)
	Hud.SetCurrency("coins", snapshot.coins)
	Hud.SetCurrency("courage", snapshot.courage)
	FusionUI.SetMonsters(snapshot.monsters)
	if snapshot.fusion and snapshot.fusion.finishAt ~= 0 then
		FusionUI.SetFusion(snapshot.fusion.finishAt)
	end
end

-- Снапшот: пуш от сервера + собственный запрос (решает гонку загрузки)
Remotes.GetEvent(Remotes.Names.ProfileLoaded).OnClientEvent:Connect(applySnapshot)
task.spawn(function()
	while true do
		local snapshot = Remotes.GetFunction(Remotes.Names.GetSnapshot):InvokeServer()
		if snapshot then
			applySnapshot(snapshot)
			break
		end
		task.wait(1)
	end
end)

Remotes.GetEvent(Remotes.Names.CurrencyChanged).OnClientEvent:Connect(Hud.SetCurrency)

print("[Client] Scare Park loaded")
