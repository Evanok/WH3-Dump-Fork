#!/usr/bin/env python3
"""
Preview runtime-generated armies from the generated WH3 unit dataset.

This mirrors the Lua runtime generator behavior:
- 1 lord selected separately
- 19-unit force list generated from category quotas and fallbacks
"""

from __future__ import annotations

import argparse
import json
import random
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "script_data" / "external_json_files" / "army_template_units_with_characters.json"

COMPOSITION = {
    "character_hero": 1,
    "infantry": 6,
    "artillery": 3,
    "cavalry": 3,
    "ranged": 3,
    "monster": 3,
}

CATEGORY_GROUPS = {
    "character_lord": {"character_lord"},
    "character_hero": {"character_hero"},
    "infantry": {"melee_infantry", "monstrous_infantry"},
    "ranged": {"missile_infantry"},
    "artillery": {"artillery", "war_machine"},
    "cavalry": {"melee_cavalry", "missile_cavalry", "monstrous_cavalry", "chariot", "missile_chariot"},
    "monster": {"monster", "war_beast"},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("race", nargs="?", help="Race/culture key, e.g. wh3_main_kho_khorne")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input dataset JSON")
    parser.add_argument("--seed", type=int, default=1337, help="Random seed")
    parser.add_argument("--count", type=int, default=1, help="How many armies to preview")
    parser.add_argument("--list-races", action="store_true", help="List available race keys and exit")
    return parser.parse_args()


def build_pools(units: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    pools: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for unit in units:
        category = unit["category"]
        if not category.startswith("character_"):
            pools["non_character"].append(unit)
        for group_key, categories in CATEGORY_GROUPS.items():
            if category in categories:
                pools[group_key].append(unit)
    return dict(pools)


def select_unit(pool: list[dict[str, Any]], usage: Counter[str], rng: random.Random) -> dict[str, Any]:
    min_usage = min(usage[unit["unit_key"]] for unit in pool)
    candidates = [unit for unit in pool if usage[unit["unit_key"]] == min_usage]
    choice = rng.choice(candidates)
    usage[choice["unit_key"]] += 1
    return choice


def mixed_fallback_pool(pools: dict[str, list[dict[str, Any]]], non_character_units: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], str]:
    infantry = pools.get("infantry", [])
    ranged = pools.get("ranged", [])
    if infantry and ranged:
        return infantry + ranged, "fallback_mix"
    if infantry:
        return infantry, "fallback_infantry"
    if ranged:
        return ranged, "fallback_ranged"
    return non_character_units, "fallback_any_non_character"


def slot_pool(
    slot: str,
    pools: dict[str, list[dict[str, Any]]],
    non_character_units: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], str]:
    primary = pools.get(slot, [])
    if primary:
        return primary, slot

    if slot == "ranged":
        infantry = pools.get("infantry", [])
        if infantry:
            return infantry, "fallback_infantry"
        return mixed_fallback_pool(pools, non_character_units)

    if slot in {"artillery", "cavalry", "monster", "infantry"}:
        return mixed_fallback_pool(pools, non_character_units)

    return [], "missing"


def generate_army(race_key: str, race: dict[str, Any], rng: random.Random) -> dict[str, Any]:
    units = race["units"]
    pools = build_pools(units)
    non_character_units = [unit for unit in units if not unit["category"].startswith("character_")]
    usage: Counter[str] = Counter()

    if not pools.get("character_lord"):
        raise ValueError(f"{race_key} has no lord candidates")
    if not pools.get("character_hero"):
        raise ValueError(f"{race_key} has no hero candidates")

    lord = select_unit(pools["character_lord"], usage, rng)
    picks: list[dict[str, Any]] = []
    source_breakdown: Counter[str] = Counter()

    for slot, count in sorted(COMPOSITION.items()):
        for _ in range(count):
            pool, source = slot_pool(slot, pools, non_character_units)
            if not pool:
                raise ValueError(f"{race_key} has no pool for slot {slot}")
            unit = select_unit(pool, usage, rng)
            picks.append(
                {
                    "slot": slot,
                    "source": source,
                    "unit_key": unit["unit_key"],
                    "name": unit["name"],
                    "category": unit["category"],
                }
            )
            source_breakdown[source] += 1

    return {
        "race_key": race_key,
        "race_name": race["name"],
        "lord": lord,
        "units": picks,
        "force_list": ",".join(pick["unit_key"] for pick in picks),
        "source_breakdown": dict(sorted(source_breakdown.items())),
    }


def main() -> int:
    args = parse_args()
    data = json.loads(args.input.read_text(encoding="utf-8"))

    if args.list_races:
        for race_key, race in sorted(data["races"].items()):
            print(f"{race_key}\t{race['name']}")
        return 0

    if not args.race:
        raise SystemExit("race argument required unless --list-races is used")

    race = data["races"].get(args.race)
    if not race:
        raise SystemExit(f"unknown race: {args.race}")

    rng = random.Random(args.seed)
    for index in range(args.count):
        army = generate_army(args.race, race, rng)
        counts = Counter(unit["category"] for unit in army["units"])

        print(f"Army {index + 1}: {army['race_name']} ({army['race_key']})")
        print(f"Lord: {army['lord']['unit_key']} | {army['lord']['name']} | {army['lord']['category']}")
        print("Units:")
        for slot_index, unit in enumerate(army["units"], start=1):
            print(
                f"{slot_index:02d}. {unit['slot']:>14} | {unit['category']:<20} | "
                f"{unit['unit_key']} | {unit['name']} | {unit['source']}"
            )
        print("Category counts:", dict(sorted(counts.items())))
        print("Fallback/source breakdown:", army["source_breakdown"])
        print("Force list:")
        for unit in army["units"]:
            print(f"[{unit['category']}] {unit['unit_key']}")
        if index + 1 < args.count:
            print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
