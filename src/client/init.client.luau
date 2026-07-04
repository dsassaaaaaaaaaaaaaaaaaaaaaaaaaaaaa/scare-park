--!strict
-- Точка входа клиента: UI, эффекты скримеров, звук.
-- Правило: клиент только ОТОБРАЖАЕТ. Валюты, инвентарь, результаты испугов — сервер.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- TODO Неделя 2–3:
-- 1. HUD: монеты, храбрость, таймер фьюжна, таймер ротации магазина
-- 2. Клиентские эффекты скримеров (плавность) — результат считает сервер
-- 3. Экран магазина с ротацией

print(`[Client] Scare Park loaded, shop rotation {GameConfig.Shop.RotationSeconds}s`)
