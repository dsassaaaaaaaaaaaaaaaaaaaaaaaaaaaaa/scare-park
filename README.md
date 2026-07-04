# 🎢 Scare Park

Тайкун-парк ужасов для Roblox: фьюжн монстров, испуг живых посетителей, сезонная ранговая лестница.

Полная документация: [docs/plan/](./docs/plan/README.md)

## Структура

```
default.project.json   — Rojo-проект (маппинг src/ → дерево игры)
src/
  server/              — ServerScriptService (сервисы, секреты, рецепты)
    services/          — 8 сервисов (Data, Plot, Fusion, Scare, Rank, Shop, Monetization, Analytics)
    init.server.luau   — точка входа сервера
  client/              — StarterPlayerScripts (UI, эффекты скримеров)
    init.client.luau   — точка входа клиента
  shared/              — ReplicatedStorage.Shared (конфиг БЕЗ секретов, утилиты)
    GameConfig.luau    — все балансовые числа в одном месте
```

## Инструменты

| Что | Как поставить |
| --- | --- |
| Roblox Studio | https://create.roblox.com |
| Rokit (тулчейн-менеджер) | https://github.com/rojo-rbx/rokit → `rokit install` в корне репо |
| Rojo (синхронизация кода) | ставится через Rokit; плагин в Studio: Plugins → Rojo |
| VS Code | расширения: Luau LSP, StyLua, Selene |

## Рабочий процесс

1. `git pull`
2. `rojo serve` в корне репо
3. В Studio: плагин Rojo → Connect — код из `src/` синхронизируется в плейс
4. Правки кода — только в VS Code (файлы `src/`), не в Studio
5. Коммит + пуш; билды/карту храним отдельно (см. docs/plan/02-programming.md)

## Жёсткие правила (из 02-programming.md)

- Клиенту не доверяем: каждый RemoteEvent валидируется на сервере
- Секреты (рецепты, шансы) — только в `src/server/`, никогда в `shared/`
- Покупка выдаётся только после подтверждённого сохранения
- Схема данных — с полем `dataVersion` и миграциями
- Баланс — только в `GameConfig.luau`
