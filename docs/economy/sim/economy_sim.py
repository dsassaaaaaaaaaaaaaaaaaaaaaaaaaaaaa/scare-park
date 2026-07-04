#!/usr/bin/env python3
"""Scare Park - симулятор экономики (30 дней, 3 архетипа игроков).

Модель повторяет механики из src/:
- Магазин: глобальная ротация каждые 5 мин, 5 позиций, редкость позиции - взвешенный ролл
  (ShopService). В текущем коде НЕТ лимита стока: одну позицию можно купить много раз.
- Фьюжн: 4 монстра -> 1; редкость результата = ceil(avg(index))+1 ("доминантная", FusionService);
  одна машина; таймер по редкости РЕЗУЛЬТАТА; таймер идёт офлайн; мутация роллится при клейме.
- Доход: сумма приставленных к слотам монстров (income/мин x множитель мутации), IncomeService.
- Офлайн: 50% от онлайн-ставки на момент выхода, кап 8 ч на окно отсутствия.
- Старт: 50 монет + 1 бесплатный Common (онбординг из 04-game-design.md).

Допущения (нет в коде/ТЗ - приняты для модели и вынесены в отчёт):
- Кривая цен слотов аттракционов 4..10 (в коде слоты захардкожены = 3).
- "Нормальный" игрок покупает каждую позицию витрины не больше 1 раза за ротацию.
- Жадная стратегия: покупаем слот/монстра, как только можем; фьюзим при 4 запасных.
"""
from __future__ import annotations

import argparse
import math
import os
import random
import statistics
from dataclasses import dataclass, field

RARITIES = ["Common", "Rare", "Epic", "Legendary", "Mythic", "Nightmare", "Secret"]
C, R, E, L, M, N, S = range(7)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


@dataclass
class Cfg:
    name: str
    price: dict             # tier -> цена в магазине (нет ключа = не продаётся)
    weight: dict            # tier -> вес в ротации
    income: dict            # tier -> монет/мин
    fusion_rule: str        # "ceil_avg_plus1" | "same_rarity"
    timer_min: dict         # tier результата -> таймер, мин
    fee: dict               # tier результата -> цена фьюжна в монетах
    mutations: list         # [(множитель, шанс)]
    slot_costs: list        # цены слотов 4..10
    shop_stock: int | None  # покупок с одной позиции витрины (None = безлимит, как в коде)
    daily_cap: dict | None = None  # tier -> макс покупок в день (персональный лимит лавки)
    machines_max: int = 1
    machine2_cost: int = 0
    shop_slots: int = 5
    rotation: int = 5
    start_slots: int = 3
    max_slots: int = 10
    offline_rate: float = 0.5
    offline_cap_min: int = 480          # кап на одно окно отсутствия (как в коде)
    offline_daily_cap_min: int | None = None  # суммарный кап офлайн-минут в день (новое)
    start_coins: int = 50

    def wsum(self):
        return sum(self.weight.values())


def cfg_bylo() -> Cfg:
    return Cfg(
        name="bylo",
        price={C: 25, R: 120, E: 600, L: 3500, M: 15000},
        weight={C: 100, R: 35, E: 10, L: 2, M: 0.4},
        income={C: 1, R: 3, E: 8, L: 20, M: 50, N: 243, S: 243},
        fusion_rule="ceil_avg_plus1",
        timer_min={C: 10, R: 10, E: 10, L: 30, M: 30, N: 120, S: 120},
        fee={t: 0 for t in range(7)},
        mutations=[(1.5, 0.10), (3, 0.04), (6, 0.015), (10, 0.005)],
        slot_costs=[400, 1500, 5000, 15000, 40000, 100000, 250000],
        shop_stock=None,
    )


def cfg_stalo() -> Cfg:
    return Cfg(
        name="stalo",
        price={C: 25, R: 140, E: 700, L: 4500},
        weight={C: 100, R: 18, E: 0.6, L: 0.2},
        income={C: 1, R: 3, E: 8, L: 20, M: 50, N: 130, S: 320},
        fusion_rule="same_rarity",
        timer_min={R: 5, E: 120, L: 360, M: 480, N: 480, S: 480},
        fee={R: 15, E: 250, L: 7500, M: 90000, N: 150000, S: 0},
        mutations=[(1.5, 0.10), (2.5, 0.04), (4, 0.015), (6, 0.005)],
        slot_costs=[400, 1500, 6000, 25000, 75000, 150000, 400000],
        shop_stock=1,
        daily_cap={C: 12, R: 5, E: 1, L: 1},
        machines_max=1,
        offline_daily_cap_min=480,
    )


SCHEDULES = {
    "casual": [(8 * 60, 10), (20 * 60, 10)],
    "midcore": [(8 * 60 + 30, 20), (19 * 60, 40)],
    "hardcore": [(9 * 60, 60), (14 * 60, 60), (20 * 60 + 30, 60)],
}


@dataclass
class Run:
    milestones: dict = field(default_factory=dict)
    daily_balance: list = field(default_factory=list)
    daily_rate: list = field(default_factory=list)
    daily_earned: list = field(default_factory=list)
    robux: float = 0.0
    fusions: int = 0
    spent: dict = field(default_factory=lambda: {"shop": 0, "slots": 0, "fees": 0, "machine": 0})
    goal_wait: list = field(default_factory=list)


class Player:
    def __init__(self, cfg: Cfg, policy: str, rng: random.Random):
        self.cfg, self.policy, self.rng = cfg, policy, rng
        self.coins = cfg.start_coins
        self.inv: list[tuple[int, float]] = [(C, 1.0)]
        self.slots = cfg.start_slots
        self.machines = 1
        self.fusions: list[tuple[float, int]] = []
        self.run = Run()
        self.earned_today = 0.0
        self.daily_bought = [0] * 7

    def placed(self):
        inv = sorted(self.inv, key=lambda m: self.cfg.income[m[0]] * m[1], reverse=True)
        return inv[: self.slots]

    def rate(self) -> float:
        return sum(self.cfg.income[t] * mult for t, mult in self.placed())

    def worst_placed(self) -> int:
        p = self.placed()
        return -1 if len(p) < self.slots else min(t for t, _ in p)

    def gain(self, coins: float):
        self.coins += coins
        self.earned_today += coins

    def roll_mutation(self) -> float:
        roll, acc = self.rng.random(), 0.0
        for mult, chance in self.cfg.mutations:
            acc += chance
            if roll <= acc:
                return mult
        return 1.0

    def note_milestone(self, tier: int, now: float):
        if tier >= E and tier not in self.run.milestones:
            self.run.milestones[tier] = now / 1440

    def claim_fusions(self, now: float):
        for job in [j for j in self.fusions if now >= j[0]]:
            self.fusions.remove(job)
            self.inv.append((job[1], self.roll_mutation()))
            self.note_milestone(job[1], now)

    def start_fusion(self, inputs: list[int], result: int, now: float, whale: bool):
        for t in inputs:
            self.inv.remove(next(m for m in self.inv if m[0] == t))
        fee = self.cfg.fee.get(result, 0)
        self.coins -= fee
        self.run.spent["fees"] += fee
        self.run.fusions += 1
        timer = self.cfg.timer_min.get(result, 10)
        if whale:
            self.run.robux += math.ceil(timer / 3)
            self.inv.append((result, self.roll_mutation()))
            self.note_milestone(result, now)
        else:
            self.fusions.append((now + timer, result))

    def counts(self):
        c = [0] * 7
        for t, _ in self.inv:
            c[t] += 1
        return c

    def try_fusions(self, now: float):
        whale = self.policy == "whale"
        for _ in range(30):
            if len(self.fusions) >= self.machines and not whale:
                return
            cnt = self.counts()
            job = None
            if self.cfg.fusion_rule == "ceil_avg_plus1" and self.policy == "exploit":
                for t in range(M, C, -1):
                    if t + 1 <= S and cnt[t] >= 1 and cnt[t - 1] >= 3:
                        job = ([t, t - 1, t - 1, t - 1], t + 1)
                        break
            if job is None:
                for t in range(M, -1, -1):
                    if t + 1 > S or cnt[t] < 4:
                        continue
                    left = len(self.inv) - 4
                    if self.policy in ("exploit", "whale") or left >= self.slots - 1:
                        job = ([t] * 4, t + 1)
                        break
            if job is None or self.coins < self.cfg.fee.get(job[1], 0):
                return
            self.start_fusion(job[0], job[1], now, whale)
            if not whale and len(self.fusions) >= self.machines:
                return

    def buy_progress(self):
        cfg = self.cfg
        while self.slots < cfg.max_slots and self.coins >= cfg.slot_costs[self.slots - 3]:
            cost = cfg.slot_costs[self.slots - 3]
            self.coins -= cost
            self.run.spent["slots"] += cost
            self.slots += 1
        if (self.machines < cfg.machines_max and self.slots >= 6
                and self.coins >= cfg.machine2_cost > 0):
            self.coins -= cfg.machine2_cost
            self.run.spent["machine"] += cfg.machine2_cost
            self.machines += 1

    def shop_visit(self, showcase: list[int], now: float):
        cfg = self.cfg
        stock = {i: (10 ** 9 if cfg.shop_stock is None and self.policy == "exploit" else 1)
                 for i in range(len(showcase))}
        for _ in range(400):
            bought = False
            for i in sorted(range(len(showcase)), key=lambda i: -showcase[i]):
                t = showcase[i]
                if stock[i] <= 0 or self.coins < cfg.price[t]:
                    continue
                if cfg.daily_cap and self.daily_bought[t] >= cfg.daily_cap[t]:
                    continue
                cnt = self.counts()
                useful = t > self.worst_placed() or cnt[t] < (6 if self.policy == "exploit" else 4)
                if self.policy == "exploit" and t <= R:
                    useful = cnt[t] < 12
                if not useful:
                    continue
                self.coins -= cfg.price[t]
                self.run.spent["shop"] += cfg.price[t]
                self.inv.append((t, 1.0))
                self.note_milestone(t, now)
                stock[i] -= 1
                self.daily_bought[t] += 1
                bought = True
            if not bought:
                break

    def days_to_goal(self, net_day: float):
        cfg, goals = self.cfg, []
        if self.slots < cfg.max_slots:
            goals.append(cfg.slot_costs[self.slots - 3])
        wp = self.worst_placed()
        for t, p in cfg.price.items():
            if t > wp:
                goals.append(p)
        cnt = self.counts()
        for t in range(M, -1, -1):
            if t + 1 <= S and t in cfg.price:
                goals.append(max(0, 4 - cnt[t]) * cfg.price[t] + cfg.fee.get(t + 1, 0))
        if not goals:
            return None
        need = min(goals) - self.coins
        if need <= 0:
            return 0.0
        return need / net_day if net_day > 1 else float("inf")


def simulate(cfg: Cfg, schedule, policy: str, seed: int, days: int = 30) -> Run:
    rng = random.Random(seed)
    pl = Player(cfg, policy, rng)
    tiers, weights = list(cfg.weight), list(cfg.weight.values())
    last_logout, logout_rate = 0.0, 0.0

    for day in range(days):
        pl.earned_today = 0.0
        pl.daily_bought = [0] * 7
        offline_left = cfg.offline_daily_cap_min if cfg.offline_daily_cap_min else 10 ** 9
        for start, dur in schedule:
            t0 = day * 1440 + start
            gap = t0 - last_logout
            paid = min(gap, cfg.offline_cap_min, offline_left)
            offline_left -= paid
            pl.gain(math.floor(logout_rate * paid * cfg.offline_rate))
            prev = t0
            points = [t for t in range(t0, t0 + dur + 1) if t % cfg.rotation == 0] or [t0]
            for t in points:
                pl.gain(pl.rate() * (t - prev))
                prev = t
                pl.claim_fusions(t)
                pl.buy_progress()
                pl.shop_visit(rng.choices(range(len(tiers)), weights=weights, k=cfg.shop_slots), t)
                pl.try_fusions(t)
            pl.gain(pl.rate() * (t0 + dur - prev))
            last_logout, logout_rate = t0 + dur, pl.rate()
        pl.run.daily_balance.append(pl.coins)
        pl.run.daily_rate.append(pl.rate())
        pl.run.daily_earned.append(pl.earned_today)
        pl.run.goal_wait.append(pl.days_to_goal(pl.earned_today))
    return pl.run


def aggregate(cfg: Cfg, arch: str, policy: str, reps: int, days: int = 30):
    runs = [simulate(cfg, SCHEDULES[arch], policy, seed=1000 + i, days=days) for i in range(reps)]

    def q(vals, p):
        vals = sorted(vals)
        return vals[min(len(vals) - 1, int(p * len(vals)))]

    miles = {}
    for tier in (E, L, M, N, S):
        hit = [r.milestones[tier] for r in runs if tier in r.milestones]
        miles[RARITIES[tier]] = {
            "hit%": round(100 * len(hit) / reps),
            "p50": round(statistics.median(hit), 1) if hit else None,
            "p10": round(q(hit, 0.10), 1) if hit else None,
            "p90": round(q(hit, 0.90), 1) if hit else None,
        }
    daily = {
        "balance": [statistics.median(r.daily_balance[d] for r in runs) for d in range(days)],
        "rate": [statistics.median(r.daily_rate[d] for r in runs) for d in range(days)],
        "earned": [statistics.median(r.daily_earned[d] for r in runs) for d in range(days)],
    }
    stall_days = []
    for d in range(days):
        vals = []
        for r in runs:
            g = r.goal_wait[d]
            vals.append(99 if g == float("inf") else (0 if g is None else g))
        if statistics.median(vals) > 2:
            stall_days.append(d + 1)
    sinks_gone = next((d + 1 for d in range(days)
                       if sum(1 for r in runs if r.goal_wait[d] is None) > reps / 2), None)
    return {
        "cfg": cfg.name, "arch": arch, "policy": policy,
        "milestones": miles, "daily": daily, "stall_days": stall_days,
        "sinks_exhausted_day": sinks_gone,
        "robux_p50": round(statistics.median(r.robux for r in runs)),
        "fusions_p50": round(statistics.median(r.fusions for r in runs)),
        "spent": {k: round(statistics.median(r.spent[k] for r in runs)) for k in runs[0].spent},
    }


def sanity_checks():
    b = cfg_bylo()
    w = b.wsum()
    p_epic = b.weight[E] / w
    assert abs(p_epic - 0.0678) < 0.001
    assert abs(4 * 5 * p_epic - 1.357) < 0.01
    cost = {C: 25, R: 120}
    cost[E] = cost[R] + 3 * cost[C]
    cost[L] = cost[E] + 3 * cost[R]
    cost[M] = cost[L] + 3 * cost[E]
    cost[N] = cost[M] + 3 * cost[L]
    assert (cost[E], cost[L], cost[M], cost[N]) == (195, 555, 1140, 2805)
    assert math.floor(10 * min(16 * 60, 480) * 0.5) == 2400
    assert 4 * 3500 < 15000 and 256 * 25 == 6400
    print("[ok] аналитические кросс-чеки сошлись")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reps", type=int, default=240)
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--charts", action="store_true")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    sanity_checks()

    scenarios = []
    for arch in ("casual", "midcore", "hardcore"):
        scenarios.append((cfg_bylo(), arch, "normal"))
        scenarios.append((cfg_stalo(), arch, "normal"))
    scenarios += [
        (cfg_bylo(), "casual", "exploit"), (cfg_bylo(), "hardcore", "exploit"),
        (cfg_bylo(), "midcore", "whale"), (cfg_bylo(), "hardcore", "whale"),
        (cfg_stalo(), "midcore", "whale"), (cfg_stalo(), "hardcore", "whale"),
        (cfg_stalo(), "hardcore", "exploit"), (cfg_stalo(), "casual", "whale"),
    ]

    results = []
    for cfg, arch, policy in scenarios:
        res = aggregate(cfg, arch, policy, args.reps, args.days)
        results.append(res)
        m = res["milestones"]
        print(f"\n=== {cfg.name} / {arch} / {policy} ===")
        for r_name, v in m.items():
            if v["hit%"] > 0:
                print(f"  {r_name:10s} p50 день {v['p50']} [{v['p10']}-{v['p90']}], получили {v['hit%']}%")
        print(f"  доход/мин д7={res['daily']['rate'][6]:.0f} д14={res['daily']['rate'][13]:.0f} "
              f"д30={res['daily']['rate'][args.days-1]:.0f}; фьюжнов={res['fusions_p50']}; "
              f"стоп-дни>2: {res['stall_days'] or '-'}; синки кончились: {res['sinks_exhausted_day'] or '-'}"
              + (f"; R$={res['robux_p50']}" if policy == "whale" else ""))

    import json
    with open(os.path.join(OUT, "results.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1)
    import csv as _csv
    with open(os.path.join(OUT, "daily.csv"), "w", newline="", encoding="utf-8") as f:
        wcsv = _csv.writer(f)
        wcsv.writerow(["config", "archetype", "policy", "day", "rate_med", "balance_med", "earned_med"])
        for res in results:
            for d in range(args.days):
                wcsv.writerow([res["cfg"], res["arch"], res["policy"], d + 1,
                               round(res["daily"]["rate"][d], 1), round(res["daily"]["balance"][d]),
                               round(res["daily"]["earned"][d])])
    print(f"\n[ok] out: {OUT}/results.json, daily.csv")
    if args.charts:
        make_charts(results, args.days)


def make_charts(results, days):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    img = os.path.normpath(os.path.join(OUT, "..", "..", "img"))
    os.makedirs(img, exist_ok=True)
    x = range(1, days + 1)
    key = {(r["cfg"], r["arch"], r["policy"]): r for r in results}
    colors = {"casual": "#4c9be8", "midcore": "#e8a54c", "hardcore": "#d95555"}

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), sharey=True)
    for ax, cfgname, title in ((axes[0], "bylo", "Черновые числа (было)"),
                               (axes[1], "stalo", "Скорректированные (стало)")):
        for arch in colors:
            r = key[(cfgname, arch, "normal")]
            ax.plot(x, r["daily"]["rate"], label=arch, color=colors[arch], lw=2)
        ax.set_title(title); ax.set_xlabel("день"); ax.grid(alpha=0.3)
        ax.set_yscale("log")
    axes[0].set_ylabel("доход, монет/мин (медиана, log)"); axes[0].legend()
    fig.tight_layout(); fig.savefig(os.path.join(img, "income_rate.png"), dpi=140); plt.close(fig)

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    for ax, cfgname, title in ((axes[0], "bylo", "Баланс монет (было)"),
                               (axes[1], "stalo", "Баланс монет (стало)")):
        for arch in colors:
            r = key[(cfgname, arch, "normal")]
            ax.plot(x, r["daily"]["balance"], label=arch, color=colors[arch], lw=2)
        ax.set_title(title); ax.set_xlabel("день"); ax.grid(alpha=0.3); ax.set_yscale("log")
    axes[0].set_ylabel("монет на конец дня (медиана, log)"); axes[0].legend()
    fig.tight_layout(); fig.savefig(os.path.join(img, "balance.png"), dpi=140); plt.close(fig)

    fig, ax = plt.subplots(figsize=(10, 4.5))
    ax.plot(x, key[("bylo", "hardcore", "normal")]["daily"]["rate"], label="хардкор: честная игра", color="#888", lw=2)
    ax.plot(x, key[("bylo", "hardcore", "exploit")]["daily"]["rate"], label="хардкор: ЭКСПЛОЙТ (скупка + микс-фьюжн)", color="#d92222", lw=2.5)
    ax.plot(x, key[("bylo", "casual", "exploit")]["daily"]["rate"], label="казуал: эксплойт", color="#e88", lw=2, ls="--")
    ax.set_yscale("log"); ax.set_xlabel("день"); ax.set_ylabel("доход, монет/мин (log)")
    ax.set_title("Было: взлом экономики микс-фьюжном ceil(avg)+1 и безлимитной скупкой")
    ax.grid(alpha=0.3); ax.legend()
    fig.tight_layout(); fig.savefig(os.path.join(img, "exploit.png"), dpi=140); plt.close(fig)

    fig, ax = plt.subplots(figsize=(11, 5))
    rows, labels, y = [], [], 0
    for arch in ("casual", "midcore", "hardcore"):
        for tier in ("Epic", "Legendary", "Mythic"):
            for cfgname, color in (("bylo", "#aaaaaa"), ("stalo", "#7a4cd9")):
                mi = key[(cfgname, arch, "normal")]["milestones"][tier]
                if mi["p50"] is not None:
                    rows.append((y, mi["p10"], mi["p50"], mi["p90"], color))
                y += 1
            labels.append((y - 1, f"{arch} - {tier}"))
            y += 0.6
    for yy, p10, p50, p90, color in rows:
        ax.plot([p10, p90], [yy, yy], color=color, lw=3, alpha=0.5)
        ax.plot([p50], [yy], "o", color=color, ms=7)
    ax.set_yticks([yy - 0.5 for yy, _ in labels])
    ax.set_yticklabels([lab for _, lab in labels])
    ax.invert_yaxis(); ax.set_xlabel("день первого получения (точка=медиана, линия=p10-p90)")
    ax.set_title("Вехи прогресса: серым - было, фиолетовым - стало")
    ax.grid(alpha=0.3, axis="x")
    fig.tight_layout(); fig.savefig(os.path.join(img, "milestones.png"), dpi=140); plt.close(fig)
    print(f"[ok] charts: {img}")


if __name__ == "__main__":
    main()
