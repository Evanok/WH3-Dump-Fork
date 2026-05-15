#!/usr/bin/env python3
"""
Preview runtime-generated armies from the generated WH3 runtime roster dataset.

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
DEFAULT_INPUT = ROOT / "script_data" / "external_json_files" / "runtime_roster_unit_data.json"

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
    parser.add_argument("target", nargs="?", help="Faction key or military group key")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input dataset JSON")
    parser.add_argument("--seed", type=int, default=1337, help="Random seed")
    parser.add_argument("--count", type=int, default=1, help="How many armies to preview")
    parser.add_argument("--faction", action="store_true", help="Interpret target as a faction key")
    parser.add_argument("--military-group", action="store_true", help="Interpret target as a military group key")
    parser.add_argument("--list-factions", action="store_true", help="List available faction keys and exit")
    parser.add_argument("--list-military-groups", action="store_true", help="List available military group keys and exit")
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


def generate_army(roster_key: str, roster_name: str, roster: dict[str, Any], rng: random.Random) -> dict[str, Any]:
    units = roster["units"]
    pools = build_pools(units)
    non_character_units = [unit for unit in units if not unit["category"].startswith("character_")]
    usage: Counter[str] = Counter()

    if not pools.get("character_lord"):
        raise ValueError(f"{roster_key} has no lord candidates")
    if not pools.get("character_hero"):
        raise ValueError(f"{roster_key} has no hero candidates")

    lord = select_unit(pools["character_lord"], usage, rng)
    picks: list[dict[str, Any]] = []
    source_breakdown: Counter[str] = Counter()

    for slot, count in sorted(COMPOSITION.items()):
        for _ in range(count):
            pool, source = slot_pool(slot, pools, non_character_units)
            if not pool:
                raise ValueError(f"{roster_key} has no pool for slot {slot}")
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
        "roster_key": roster_key,
        "roster_name": roster_name,
        "lord": lord,
        "units": picks,
        "force_list": ",".join(pick["unit_key"] for pick in picks),
        "source_breakdown": dict(sorted(source_breakdown.items())),
    }


def resolve_target(data: dict[str, Any], args: argparse.Namespace) -> tuple[str, str, dict[str, Any]]:
    if args.target is None:
        raise SystemExit("target argument required unless --list-factions or --list-military-groups is used")

    if args.faction and args.military_group:
        raise SystemExit("use either --faction or --military-group, not both")

    if args.faction:
        faction = data["factions"].get(args.target)
        if not faction:
            raise SystemExit(f"unknown faction: {args.target}")
        group_key = faction["military_group"]
        group = data["military_groups"].get(group_key)
        if not group:
            raise SystemExit(f"faction {args.target} maps to missing military group: {group_key}")
        return group_key, f"{faction['name']} [{args.target}]", group

    if args.military_group:
        group = data["military_groups"].get(args.target)
        if not group:
            raise SystemExit(f"unknown military group: {args.target}")
        return args.target, args.target, group

    faction = data["factions"].get(args.target)
    if faction:
        group_key = faction["military_group"]
        group = data["military_groups"].get(group_key)
        if not group:
            raise SystemExit(f"faction {args.target} maps to missing military group: {group_key}")
        return group_key, f"{faction['name']} [{args.target}]", group

    group = data["military_groups"].get(args.target)
    if group:
        return args.target, args.target, group

    raise SystemExit(f"unknown target: {args.target}")


def main() -> int:
    args = parse_args()
    data = json.loads(args.input.read_text(encoding="utf-8"))

    if args.list_factions:
        for faction_key, faction in sorted(data["factions"].items()):
            print(f"{faction_key}\t{faction['name']}\t{faction['military_group']}")
        return 0

    if args.list_military_groups:
        for group_key, group in sorted(data["military_groups"].items()):
            print(f"{group_key}\tunits={group['unit_count']}\tfactions={len(group['faction_keys'])}")
        return 0

    roster_key, roster_name, roster = resolve_target(data, args)

    rng = random.Random(args.seed)
    for index in range(args.count):
        army = generate_army(roster_key, roster_name, roster, rng)
        counts = Counter(unit["category"] for unit in army["units"])

        print(f"Army {index + 1}: {army['roster_name']} ({army['roster_key']})")
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
