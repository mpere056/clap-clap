"""Rough pacing simulator for the clap economy (mirrors src/shared/Config.luau + Formulas.luau).

Simulates a player clicking at a steady rate and greedily buying the upgrade with the best
income gain per Applause spent. Prints when each stage breakthrough happens.

Usage: python tools/pacing_sim.py [clicks_per_second]
"""
import math
import sys

CPS = float(sys.argv[1]) if len(sys.argv) > 1 else 6.0
PERFECT_RATE = 0.35
COMBO = 2.6  # average sustained combo while actively clapping
PERFECT_BONUS = 2
AUTO_EFF = 0.5
FRENZY_FILL, FRENZY_CHAIN = 400, 8
OVATION_SHARE = 0.25  # fraction of time under a x2 Ovation (solo)

THRESHOLDS = [3, 6, 9]
TECHS = [(2, 5e3, 1), (2, 2.5e4, 1), (3, 1.2e5, 1), (10, 6e5, 2), (10, 3e7, 2), (10, 1.2e9, 2), (10, 2.5e11, 3), (10, 6e12, 3), (10, 9e13, 3)]
MATES = [(0.5, 40, 1), (3, 3e3, 1), (15, 2e5, 2), (80, 3e6, 2), (400, 3e8, 3), (2500, 4e9, 3)]
SH_BASE, SH_GROWTH, SH_DOUBLE = 15, 1.15, 10**9
MATE_GROWTH = 1.12

# frenzy: every FRENZY_FILL claps you get FRENZY_CHAIN claps worth sum(2^i) instead of FRENZY_CHAIN
FRENZY_FACTOR = (FRENZY_FILL + sum(2 ** i for i in range(1, FRENZY_CHAIN + 1))) / (FRENZY_FILL + FRENZY_CHAIN)
PERFECT_FACTOR = 1 + PERFECT_RATE * (PERFECT_BONUS - 1)
OVATION_FACTOR = 1 + OVATION_SHARE


def cp(sh, techs):
    v = (1 + sh) * 2 ** (sh // SH_DOUBLE)
    for i in range(techs):
        v *= TECHS[i][0]
    return v


def income(sh, techs, mates):
    auto = sum(MATES[i][0] * n for i, n in enumerate(mates))
    manual = CPS * COMBO * PERFECT_FACTOR * FRENZY_FACTOR
    return cp(sh, techs) * (manual + auto * AUTO_EFF) * OVATION_FACTOR


def main():
    t, money, sh, techs, mates, stage = 0.0, 0.0, 0, 0, [0] * len(MATES), 1
    dt = 0.5
    log = []
    while stage <= len(THRESHOLDS) and t < 3 * 3600:
        money += income(sh, techs, mates) * dt
        t += dt
        # greedy buy loop
        while True:
            base = income(sh, techs, mates)
            options = []
            c = SH_BASE * SH_GROWTH ** sh
            options.append((income(sh + 1, techs, mates) - base, c, "sh"))
            if techs < len(TECHS) and TECHS[techs][2] <= stage:
                options.append((income(sh, techs + 1, mates) - base, TECHS[techs][1], "tech"))
            for i, (mcps, mcost, mstage) in enumerate(MATES):
                if mstage <= stage:
                    m2 = mates.copy(); m2[i] += 1
                    options.append((income(sh, techs, m2) - base, mcost * MATE_GROWTH ** mates[i], ("mate", i)))
            options = [o for o in options if o[1] <= money]
            if not options:
                break
            techs_affordable = [o for o in options if o[2] == "tech"]
            gain, cost, what = techs_affordable[0] if techs_affordable else max(options, key=lambda o: o[0] / o[1])
            money -= cost
            if what == "sh":
                sh += 1
            elif what == "tech":
                techs += 1
            else:
                mates[what[1]] += 1
        if math.log10(cp(sh, techs) * COMBO) >= THRESHOLDS[stage - 1]:
            log.append((stage, t, sh, techs, list(mates)))
            stage += 1
    prev = 0
    for stage, tt, sh, techs, mates in log:
        print(f"Stage {stage} cleared at {tt/60:5.1f} min (+{(tt-prev)/60:4.1f})  hands={sh} techs={techs} mates={mates}")
        prev = tt
    if stage <= len(THRESHOLDS):
        print(f"Stuck in stage {stage} after {t/60:.0f} min")


if __name__ == "__main__":
    main()
