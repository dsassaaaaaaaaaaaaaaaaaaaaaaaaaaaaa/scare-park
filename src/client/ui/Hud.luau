--!strict
-- Hud: валюты + кнопки открытия магазина/фьюжна. Только отображение — данные с сервера.

local Players = game:GetService("Players")

local UiKit = require(script.Parent.UiKit)

local Hud = {}

local coinsLabel: TextLabel? = nil
local courageLabel: TextLabel? = nil

function Hud.SetCurrency(currency: string, value: number)
	if currency == "coins" and coinsLabel then
		coinsLabel.Text = `🪙 {value}`
	elseif currency == "courage" and courageLabel then
		courageLabel.Text = `💪 {value}`
	end
end

function Hud.Build(callbacks: { onShop: () -> (), onFusion: () -> () }): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScareParkHud"
	gui.ResetOnSpawn = false

	-- Валюты сверху слева
	local currencyPanel = UiKit.Panel({
		size = UDim2.fromOffset(180, 70),
		position = UDim2.fromOffset(12, 12),
		parent = gui,
	})
	coinsLabel = UiKit.Label({
		text = "🪙 …",
		size = UDim2.new(1, -16, 0, 30),
		position = UDim2.fromOffset(8, 4),
		parent = currencyPanel,
		textSize = 18,
	})
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	courageLabel = UiKit.Label({
		text = "💪 …",
		size = UDim2.new(1, -16, 0, 30),
		position = UDim2.fromOffset(8, 34),
		parent = currencyPanel,
		textSize = 18,
	})
	courageLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Кнопки снизу
	UiKit.Button({
		text = "🛒 Магазин",
		size = UDim2.fromOffset(130, 44),
		position = UDim2.new(0.5, -140, 1, -56),
		parent = gui,
		onClick = callbacks.onShop,
	})
	UiKit.Button({
		text = "⚗️ Фьюжн",
		size = UDim2.fromOffset(130, 44),
		position = UDim2.new(0.5, 10, 1, -56),
		parent = gui,
		onClick = callbacks.onFusion,
	})

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

return Hud
