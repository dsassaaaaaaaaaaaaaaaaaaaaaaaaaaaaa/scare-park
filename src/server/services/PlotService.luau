--!strict
-- PlotService: выдача участков (8 по кругу вокруг хаба), сохранение/загрузка построек.
-- Постройки сериализуются в таблицу (id, позиция, ротация) — инстансы не хранятся.

local PlotService = {}

function PlotService.Init()
	-- TODO Неделя 1:
	-- 1. Найти 8 точек-участков в Workspace (папка Plots)
	-- 2. PlayerAdded → занять свободный участок, загрузить plot из профиля
	-- 3. PlayerRemoving → сериализовать участок в профиль, освободить
	print("[PlotService] init")
end

return PlotService
