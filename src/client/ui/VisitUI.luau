--!strict
-- VisitUI: кнопка «Посетить парк», шкала храбрости, эффект скримера, итог визита.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MonsterCatalog = require(ReplicatedStorage.Shared.MonsterCatalog)
local UiKit = require(script.Parent.UiKit)

local VisitUI = {}

local visitButton: TextButton? = nil
local courageBar: Frame? = nil
local courageFill: Frame? = nil
local flashFrame: Frame? = nil
local inVisit = false

local function setVisiting(visiting: boolean)
	inVisit = visiting
	if visitButton then
		visitButton.Text = if visiting then "🚪 Сбежать" else "👻 Посетить парк"
	end
	if courageBar then
		courageBar.Visible = visiting
	end
end

local function onVisitButton()
	if inVisit then
		Remotes.GetFunction(Remotes.Names.LeaveVisit):InvokeServer()
		-- VisitEnded придёт с сервера и сбросит состояние
	else
		local result = Remotes.GetFunction(Remotes.Names.RequestVisit):InvokeServer()
		if result and result.ok then
			setVisiting(true)
		elseif result and result.err == "no_parks" and visitButton then
			visitButton.Text = "😴 Нет парков…"
			task.delay(2, function()
				if not inVisit and visitButton then
					visitButton.Text = "👻 Посетить парк"
				end
			end)
		end
	end
end

--- Вспышка скримера: затемнение + имя монстра. Урон уже применён сервером.
local function playScareEffect(monsterId: string, _mechanic: string)
	local flash = flashFrame
	if flash == nil then
		return
	end
	local def = MonsterCatalog[monsterId]
	local label = flash:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = if def then `😱 {def.name}!` else "😱"
	end
	flash.BackgroundTransparency = 0.3
	flash.Visible = true
	TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		flash.Visible = false
	end)
	-- TODO: звук скримера (60% испуга!) — SoundId из каталога, когда появятся ассеты
end

function VisitUI.Build(gui: ScreenGui)
	visitButton = UiKit.Button({
		text = "👻 Посетить парк",
		size = UDim2.fromOffset(160, 44),
		position = UDim2.new(0.5, 160, 1, -56),
		parent = gui,
		onClick = onVisitButton,
	})

	-- шкала храбрости (видна только в визите)
	courageBar = UiKit.Panel({
		size = UDim2.fromOffset(300, 26),
		position = UDim2.new(0.5, -150, 0, 12),
		parent = gui,
	})
	local bar = courageBar :: Frame
	bar.Visible = false
	courageFill = Instance.new("Frame")
	local fill = courageFill :: Frame
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = UiKit.Colors.Good
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 10)
	fillCorner.Parent = fill
	fill.Parent = bar
	UiKit.Label({
		text = "ХРАБРОСТЬ",
		size = UDim2.fromScale(1, 1),
		parent = bar,
		textSize = 13,
	})

	-- полноэкранная вспышка скримера
	flashFrame = Instance.new("Frame")
	local flash = flashFrame :: Frame
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(0, 0, 0)
	flash.BackgroundTransparency = 1
	flash.Visible = false
	flash.ZIndex = 100
	local scareName = Instance.new("TextLabel")
	scareName.Size = UDim2.fromScale(1, 0.2)
	scareName.Position = UDim2.fromScale(0, 0.4)
	scareName.BackgroundTransparency = 1
	scareName.Font = Enum.Font.Creepster
	scareName.TextScaled = true
	scareName.TextColor3 = Color3.fromRGB(200, 30, 30)
	scareName.ZIndex = 101
	scareName.Text = ""
	scareName.Parent = flash
	flash.Parent = gui

	Remotes.GetEvent(Remotes.Names.CourageChanged).OnClientEvent:Connect(function(courage: number?)
		if courage == nil then
			setVisiting(false)
			return
		end
		setVisiting(true)
		local f = courageFill
		if f then
			local alpha = math.clamp(courage / 100, 0, 1)
			f.Size = UDim2.fromScale(alpha, 1)
			f.BackgroundColor3 = if alpha > 0.5 then UiKit.Colors.Good elseif alpha > 0.25 then Color3.fromRGB(230, 180, 60) else UiKit.Colors.Bad
		end
	end)

	Remotes.GetEvent(Remotes.Names.ScareEffect).OnClientEvent:Connect(playScareEffect)

	Remotes.GetEvent(Remotes.Names.VisitEnded).OnClientEvent:Connect(function(escaped: boolean, reward: number)
		setVisiting(false)
		local button = visitButton
		if button then
			button.Text = if escaped then `🏃 Сбежал! +{reward} 💪` else `🏆 Прошёл! +{reward} 💪`
			task.delay(2.5, function()
				if not inVisit and button then
					button.Text = "👻 Посетить парк"
				end
			end)
		end
	end)
end

return VisitUI
