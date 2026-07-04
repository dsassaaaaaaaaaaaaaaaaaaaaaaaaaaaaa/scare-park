# 🎢 Scare Park

Тайкун-парк ужасов для Roblox: фьюжн монстров, испуг живых посетителей, сезонная ранговая лестница.

| Документ | Что там |
| --- | --- |
| [docs/plan/](./docs/plan/README.md) | Дизайн-док, бизнес, маркетинг, гейм-дизайн, LiveOps, аналитика |
| [docs/economy/](./docs/economy/README.md) | Балансовая модель: симуляция 30 дней, 10 красных флагов, таблица «было→стало» (применена в коде) |
| [docs/CONTRACT.md](./docs/CONTRACT.md) | Контракт «код ↔ дизайн»: имена папок карты и моделей, чтобы код подхватывал их автоматически |

## Структура кода

```
default.project.json      — Rojo-маппинг src/ → дерево игры (StreamingEnabled включён)
src/
  shared/                 — ReplicatedStorage.Shared (видно клиенту — БЕЗ секретов)
    GameConfig.luau       — ВСЕ балансовые числа (цены, таймеры, платы, лимиты, флаги)
    MonsterCatalog.luau   — 15 базовых монстров + Nightmare-боссы (id, доход, механика испуга)
    Remotes.luau          — единая точка RemoteEvent/RemoteFunction
  server/                 — ServerScriptService.Server
    init.server.luau      — порядок инициализации сервисов
    lib/ProfileStore.luau — вендоренный ProfileStore (сейвы, session locking)
    config/SecretConfig.luau — 🔒 шансы мутаций, фьюжн-рецепты (только сервер!)
    services/
      DataService.luau    — профили: шаблон, миграции, SaveConfirmed (анти-дюп покупок)
      PlotService.luau    — участки, постройки, слоты за монеты (BuyPlotSlot)
      ShopService.luau    — ротация по сиду (5 мин), сток 1, дневные лимиты, rate-limit
      FusionService.luau  — 4 одной редкости → +1, платы монетами, секретные рецепты
      ScareService.luau   — храбрость (%), визиты, побег, очки страха, легенда монстров
      IncomeService.luau  — онлайн-тик + офлайн-доход (50%, кап 8 ч/сутки)
      MonsterRuntime.luau — физический спавн монстров, проксимити-испуг
      MonetizationService.luau — ProcessReceipt: идемпотентность + выдача после сейва
      AnalyticsService.luau — воронка онбординга, economy-события
  client/                 — StarterPlayerScripts.Client (только отображение!)
    init.client.luau      — снапшот профиля, подписки на ремоуты
    ui/                   — UiKit, Hud, ShopUI, FusionUI, VisitUI (шкала храбрости, скримеры)
```

## Инструменты

| Что | Как |
| --- | --- |
| Roblox Studio | https://create.roblox.com |
| Rokit (тулчейн) | https://github.com/rojo-rbx/rokit → `rokit install` в корне (ставит rojo, stylua, selene) |
| VS Code | расширения: Luau LSP, StyLua, Selene |

## Рабочий процесс

1. `git pull`
2. `rojo serve` в корне → в Studio плагин Rojo → Connect
3. Код правится ТОЛЬКО в VS Code (`src/`), карта и модели — в Studio
4. Перед коммитом: `stylua src` и `selene src`
5. Карту/билды в git не кладём (`*.rbxl` в .gitignore)

## Как проверить билд (Play в Studio)

- Output: `[DataService] init … mock=true` и остальные сервисы без ошибок
- HUD: 🪙 50 монет и 1 стартовый Бу-Шарик в фьюжн-панели
- Магазин: 5 позиций, таймер ротации тикает, повторная покупка позиции → «Распродано»
- Фьюжн: 4 РАЗНЫХ монстра → ошибка; 4 Common → таймер 5 мин (результат Rare)
- В Studio данные сохраняются в мок-стор (не в прод) — каждый Play с чистого профиля

## Жёсткие правила (полные — в docs/plan/02-programming.md)

- Клиенту не доверяем: каждый Remote валидируется на сервере (типы, диапазоны, кулдауны)
- Секреты (рецепты, шансы) — только `src/server/`, никогда в `shared/`
- Покупка выдаётся только после подтверждённого сохранения (`DataService.SaveConfirmed`)
- Схема данных — через шаблон + `dataVersion`; новые поля дозаполняет Reconcile
- Баланс — только в `GameConfig.luau`; менять числа = сначала свериться с docs/economy
- Крупные фичи — за feature-флагами (`GameConfig.Flags`)

## Статус (роадмап — docs/plan/00-design-doc.md §7)

- ✅ Этап 1 MVP — код: сейвы, участки, магазин, фьюжн, храбрость/визиты, офлайн-доход, HUD
- ✅ Баланс v1 применён из docs/economy (фьюжн-платы, лимиты магазина, суточный кап офлайна)
- 🔜 От дизайна: карта (хаб + 8 участков по CONTRACT.md), модели 15 монстров, звуки
- 🔜 Код дальше: механики испуга по монстрам, чекпоинты, Monetization ID-шники, Этап 2 (кража, ранги)
