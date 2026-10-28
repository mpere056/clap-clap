"""Pacing simulator for the clap economy (mirrors src/shared/Config.luau + Formulas.luau).

Simulates a player clapping on the beat and greedily buying the upgrade with the best income
gain per Applause spent (techniques as soon as affordable). Also models Curtain Calls (prestige):
the "optimal" strategy tries several "call when the multiplier would grow by xN" rules and keeps
the fastest.

Usage:
  python tools/pacing_sim.py              # no-prestige run + optimal Curtain Call run
  python tools/pacing_sim.py --calibrate  # fit stage 4-9 costs to TARGET_CLEAR_MIN (no prestige)
  python tools/pacing_sim.py --sloppy     # a weaker rhythm player
"""
import math
import sys

# --- rhythm model --------------------------------------------------------------------------
BEAT = 0.6
GRADE_MULT = {"Perfect": 3, "Great": 2, "Good": 1}
MISS_PENALTY = 2
AUTO_EFF = 0.5
FRENZY_FILL, FRENZY_CHAIN = 150, 6
OVATION_SHARE = 0.25
PRACTICE_CLAPS = 10

PLAYERS = {
    "engaged": dict(hit=0.9, combo=2.6, mix={"Perfect": 0.4, "Great": 0.4, "Good": 0.2}),
    "sloppy": dict(hit=0.7, combo=2.0, mix={"Perfect": 0.15, "Great": 0.35, "Good": 0.5}),
}

# --- prestige ------------------------------------------------------------------------------
CURTAIN_STAGE = 4            # Curtain Call unlocks once you've broken through stage 3
BOUQUET_BASE = 9             # log10 power where Bouquets start (end of stage 3)
BOUQUET_SCALE = 5
BOUQUET_EXP = 0.18           # Bouquets = SCALE * 10^(EXP * (peak - BASE))
BOUQUET_BONUS = 0.1          # +10% clap power per Bouquet

# --- content -------------------------------------------------------------------------------
# log10 power to break through stage i (reaching Space = clearing stage 8)
THRESHOLDS = [3, 6, 9, 12.5, 16, 20, 24, 30]
# cumulative minutes without Curtain Calls (stages 1-3 quick, later stages much harder)
TARGET_CLEAR_MIN = [1.6, 5.3, 11.1, 46, 91, 146, 216, 300]
# Space is beaten by filling a meter: each on-beat clap adds grade x combo
SPACE_GOAL = 30000

# (multiplier, cost, stage)
TECHS = [
    (2, 1.7e+03, 1),
    (2, 1.3e+04, 1),
    (3, 5.5e+04, 1),
    (10, 1.5e+06, 2),
    (10, 9.5e+07, 2),
    (10, 1.9e+09, 2),
    (10, 1.2e+11, 3),
    (10, 5.3e+12, 3),
    (10, 1e+14, 3),
    (10, 1.7e+16, 4),
    (10, 4.5e+17, 4),
    (10, 7.7e+18, 4),
    (10, 3.4e+20, 5),
    (10, 6.1e+21, 5),
    (10, 9.7e+22, 5),
    (10, 3.9e+24, 6),
    (10, 4.8e+25, 6),
    (10, 7.1e+26, 6),
    (10, 1.2e+28, 6),
    (10, 5.8e+29, 7),
    (10, 7.1e+30, 7),
    (10, 1.1e+32, 7),
    (10, 1.7e+33, 7),
    (100, 9e+34, 8),
    (100, 1.9e+37, 8),
    (100, 3.1e+39, 8),
    (100, 1.4e+42, 9),
    (100, 3.3e+44, 9),
    (100, 2.4e+46, 9),
]
# (claps per second, cost, stage)
MATES = [
    (0.5, 25, 1),
    (3, 800, 1),
    (15, 4.3e4, 2),
    (80, 4.3e5, 2),
    (400, 3.5e9, 3),
    (2500, 3.5e10, 3),
    (1.5e4, 5.2e14, 4),
    (1e5, 1e19, 5),
    (8e5, 1.2e23, 6),
    (7e6, 1.7e28, 7),
    (6e7, 2.7e33, 8),
    (5e8, 4.4e40, 9),
]
SH_BASE, SH_GROWTH = 8, 1.15
MATE_GROWTH = 1.12


def bouquets_for(peak):
    if peak < BOUQUET_BASE:
        return 0
    return math.floor(BOUQUET_SCALE * 10 ** (BOUQUET_EXP * (peak - BOUQUET_BASE)))


def simulate(techs, mates, player="engaged", mult=1.0, until=None, prestige_ratio=None, bouquets=0, max_minutes=600):
    """One run from the ceremony. Ends on reaching stage `until`, on a Curtain Call, or timeout.

    Returns (minutes, tech_times, clears, peak, ended)."""
    until = until or len(THRESHOLDS) + 1
    p = PLAYERS[player]
    beats_per_s = 1 / BEAT
    grade_avg = sum(GRADE_MULT[g] * w for g, w in p["mix"].items())
    frenzy = (FRENZY_FILL + sum(2 ** i for i in range(1, FRENZY_CHAIN + 1))) / (FRENZY_FILL + FRENZY_CHAIN)
    manual_mult = beats_per_s * (p["hit"] * grade_avg * p["combo"] * frenzy - (1 - p["hit"]) * MISS_PENALTY)
    good_per_s = beats_per_s * p["hit"]
    current_mult = 1 + BOUQUET_BONUS * bouquets

    t, money, sh, n_tech, owned, stage = 0.0, 0.0, 0, 0, [0] * len(mates), 1
    tech_times, clears = [None] * len(techs), []
    peak = 0.0

    def cp(sh_, nt):
        v = (1 + sh_ + int(good_per_s * t / PRACTICE_CLAPS)) * mult
        for i in range(nt):
            v *= techs[i][0]
        return v

    def income(sh_, nt, own):
        auto = sum(mates[i][0] * n for i, n in enumerate(own))
        return cp(sh_, nt) * (manual_mult + auto * AUTO_EFF) * (1 + OVATION_SHARE)

    dt = 1.0
    while t < max_minutes * 60:
        money += income(sh, n_tech, owned) * dt
        t += dt
        while True:
            base = income(sh, n_tech, owned)
            options = [(income(sh + 1, n_tech, owned) - base, SH_BASE * SH_GROWTH ** sh, "sh")]
            if n_tech < len(techs) and techs[n_tech][2] <= stage:
                options.append((income(sh, n_tech + 1, owned) - base, techs[n_tech][1], "tech"))
            for i, (mcps, mcost, mstage) in enumerate(mates):
                if mstage <= stage:
                    o2 = owned.copy()
                    o2[i] += 1
                    options.append((income(sh, n_tech, o2) - base, mcost * MATE_GROWTH ** owned[i], i))
            options = [o for o in options if o[1] <= money]
            if not options:
                break
            tech = [o for o in options if o[2] == "tech"]
            _, cost, what = tech[0] if tech else max(options, key=lambda o: o[0] / o[1])
            money -= cost
            if what == "sh":
                sh += 1
            elif what == "tech":
                tech_times[n_tech] = t / 60
                n_tech += 1
            else:
                owned[what] += 1
        power = math.log10(cp(sh, n_tech) * p["combo"])
        peak = max(peak, power)
        while stage <= len(THRESHOLDS) and power >= THRESHOLDS[stage - 1]:
            clears.append(t / 60)
            stage += 1
        if stage >= until:
            return t / 60, tech_times, clears, peak, "goal"
        if prestige_ratio and stage >= CURTAIN_STAGE:
            gain = bouquets_for(peak)
            if (current_mult + BOUQUET_BONUS * gain) / current_mult >= prestige_ratio:
                return t / 60, tech_times, clears, peak, "prestige"
    return t / 60, tech_times, clears, peak, "timeout"


def optimal(techs, mates, until, player="engaged", rebirth_mult=1.0, limit=600):
    """Best total time to reach stage `until` using Curtain Calls; tries several call rules."""
    best = None
    for ratio in [1.5, 2, 3, 4, 6, 10, 20, 50, 200]:
        total, bouquets, calls = 0.0, 0, 0
        while total < limit:
            mult = rebirth_mult * (1 + BOUQUET_BONUS * bouquets)
            minutes, _, _, peak, ended = simulate(techs, mates, player, mult, until, ratio, bouquets, limit - total)
            total += minutes
            if ended == "goal":
                if best is None or total < best[0]:
                    best = (total, ratio, calls, bouquets)
                break
            if ended == "timeout":
                break
            bouquets += bouquets_for(peak)
            calls += 1
    return best


def tech_targets():
    targets, prev = [], 0.0
    for stage, clear in enumerate(TARGET_CLEAR_MIN, start=1):
        n = sum(1 for tc in TECHS if tc[2] == stage)
        spots = [0.25, 0.55, 0.85] if n == 3 else [0.2, 0.4, 0.6, 0.85]
        targets.extend(prev + (clear - prev) * spots[k] for k in range(n))
        prev = clear
    return targets


def calibrate():
    """Fit stage 4+ technique and classmate costs so a no-prestige run hits TARGET_CLEAR_MIN."""
    techs = [list(t) for t in TECHS]
    mates = [list(m) for m in MATES]
    targets = tech_targets()
    first_late = next(i for i, t in enumerate(techs) if t[2] >= 4)
    last_timed = max(i for i, t in enumerate(techs) if t[2] <= len(TARGET_CLEAR_MIN))
    for _ in range(80):
        for m in mates:
            if m[2] >= 4:
                first = next(t for t in techs if t[2] == m[2])
                m[1] = first[1] * 0.03
        _, times, _, _, _ = simulate([tuple(t) for t in techs], [tuple(m) for m in mates], max_minutes=TARGET_CLEAR_MIN[-1] + 60)
        worst = 0
        for i in range(first_late, last_timed + 1):
            cur = times[i] if times[i] is not None else 2000
            ratio = targets[i] / max(cur, 0.02)
            worst = max(worst, abs(ratio - 1))
            techs[i][1] *= ratio ** 1.2
            techs[i][1] = max(techs[i][1], techs[i - 1][1] * 2)
        if worst < 0.03:
            break
    print("TECHS costs:", ", ".join(f"{t[1]:.2g}" for t in techs))
    print("MATES costs:", ", ".join(f"{m[1]:.2g}" for m in mates))
    return [tuple(t) for t in techs], [tuple(m) for m in mates]


def report(techs, mates, player):
    minutes, _, clears, _, _ = simulate(techs, mates, player, max_minutes=900)
    prev = 0
    print(f"[{player}, no Curtain Calls]")
    for stage, c in enumerate(clears, start=1):
        label = "reach Space" if stage == len(THRESHOLDS) else f"stage {stage} cleared"
        print(f"  {label:14} at {c:6.1f} min (+{c - prev:5.1f})")
        prev = c
    space = optimal(techs, mates, until=len(THRESHOLDS) + 1)
    if space:
        print(f"[{player}, optimal Curtain Calls] reach Space: {space[0]:.0f} min "
              f"(call when x{space[1]} stronger, {space[2]} calls, {space[3]} Bouquets)")
    p = PLAYERS[player]
    per_second = (1 / BEAT) * p["hit"] * sum(GRADE_MULT[g] * w for g, w in p["mix"].items()) * p["combo"]
    print(f"[{player}] beating Space (escape velocity {SPACE_GOAL}): {SPACE_GOAL / per_second / 60:.0f} min of clapping")


if __name__ == "__main__":
    techs, mates = TECHS, MATES
    if "--calibrate" in sys.argv:
        techs, mates = calibrate()
    report(techs, mates, "sloppy" if "--sloppy" in sys.argv else "engaged")
