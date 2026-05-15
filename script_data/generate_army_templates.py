#!/usr/bin/env python3
"""
Generate reusable 20-slot army templates from the exported WH3 unit dataset.

Default composition per template:
- 1 lord
- 1 hero
- 6 infantry
- 3 artillery
- 3 cavalry
- 3 ranged
- 3 monsters

Fallback rules:
- missing artillery/cavalry/monster slots are replaced by a mix of infantry/ranged
- missing ranged slots are replaced by infantry
- if a race has no ranged at all, fallback is infantry only
"""

from __future__ import annotations

import argparse
import json
import random
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "script_data" / "external_json_files" / "army_template_units_with_characters.json"
DEFAULT_JSON_OUTPUT = ROOT / "script_data" / "external_json_files" / "army_templates.json"
DEFAULT_LUA_OUTPUT = ROOT / "script_data" / "external_json_files" / "army_templates.lua"

TEMPLATE_COMPOSITION = {
    "character_lord": 1,
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
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input unit dataset JSON path")
    parser.add_argument("--json-out", type=Path, default=DEFAULT_JSON_OUTPUT, help="JSON output path")
    parser.add_argument("--lua-out", type=Path, default=DEFAULT_LUA_OUTPUT, help="Lua output path")
    parser.add_argument("--templates-per-race", type=int, default=12, help="Number of templates to generate per race")
    parser.add_argument("--seed", type=int, default=1337, help="Random seed")
    return parser.parse_args()


def to_lua(value: Any, indent: int = 0) -> str:
    space = " " * indent
    next_indent = indent + 2
    next_space = " " * next_indent

    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    if isinstance(value, list):
        if not value:
            return "{}"
        items = ",\n".join(f"{next_space}{to_lua(item, next_indent)}" for item in value)
        return "{\n" + items + "\n" + space + "}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = []
        for key, item in value.items():
            lua_key = key if isinstance(key, str) and key.isidentifier() else f'["{key}"]'
            items.append(f"{next_space}{lua_key} = {to_lua(item, next_indent)}")
        return "{\n" + ",\n".join(items) + "\n" + space + "}"
    raise TypeError(f"Unsupported Lua type: {type(value)!r}")


def load_units(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def build_group_pools(units: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    pools: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for unit in units:
        category = unit["category"]
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


def mixed_fallback_pool(pools: dict[str, list[dict[str, Any]]], non_character_units: list[dict[str, Any]]) -> list[dict[str, Any]]:
    infantry = pools.get("infantry", [])
    ranged = pools.get("ranged", [])

    if infantry and ranged:
        return infantry + ranged
    if infantry:
        return infantry
    if ranged:
        return ranged
    return non_character_units


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
        return mixed_fallback_pool(pools, non_character_units), "fallback_mix"

    if slot in {"artillery", "cavalry", "monster", "infantry"}:
        return mixed_fallback_pool(pools, non_character_units), "fallback_mix"

    return [], "missing"


def generate_template_for_race(race_key: str, race: dict[str, Any], rng: random.Random, template_index: int) -> dict[str, Any]:
    units = race["units"]
    pools = build_group_pools(units)
    non_character_units = [unit for unit in units if not unit["category"].startswith("character_")]
    usage: Counter[str] = Counter()

    if not pools.get("character_lord"):
        raise ValueError(f"{race_key} has no lord candidates")
    if not pools.get("character_hero"):
        raise ValueError(f"{race_key} has no hero candidates")

    picks: list[dict[str, Any]] = []
    source_breakdown: Counter[str] = Counter()

    for slot, count in TEMPLATE_COMPOSITION.items():
        for _ in range(count):
            pool, source = slot_pool(slot, pools, non_character_units)
            if not pool:
                raise ValueError(f"{race_key} has no available units for slot '{slot}'")
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

    category_counts = Counter(pick["category"] for pick in picks)
    slot_counts = Counter(pick["slot"] for pick in picks)

    return {
        "template_key": f"{race_key}_template_{template_index:02d}",
        "race": race_key,
        "race_name": race["name"],
        "unit_count": len(picks),
        "slots": picks,
        "unit_keys": [pick["unit_key"] for pick in picks],
        "slot_counts": dict(sorted(slot_counts.items())),
        "picked_category_counts": dict(sorted(category_counts.items())),
        "source_breakdown": dict(sorted(source_breakdown.items())),
    }


def main() -> int:
    args = parse_args()
    data = load_units(args.input)
    rng = random.Random(args.seed)

    races_payload: dict[str, Any] = {}
    for race_key, race in sorted(data["races"].items()):
        templates = [
            generate_template_for_race(race_key, race, rng, template_index=i + 1)
            for i in range(args.templates_per_race)
        ]
        races_payload[race_key] = {
            "name": race["name"],
            "template_count": len(templates),
            "templates": templates,
        }

    payload = {
        "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source_dataset": str(args.input),
        "seed": args.seed,
        "templates_per_race": args.templates_per_race,
        "composition": TEMPLATE_COMPOSITION,
        "category_groups": {key: sorted(value) for key, value in CATEGORY_GROUPS.items()},
        "race_count": len(races_payload),
        "races": races_payload,
    }

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.lua_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.lua_out.write_text("return " + to_lua(payload) + "\n", encoding="utf-8")

    print(f"Wrote JSON: {args.json_out}")
    print(f"Wrote Lua:  {args.lua_out}")
    print(f"Races:      {len(races_payload)}")
    print(f"Templates:  {sum(item['template_count'] for item in races_payload.values())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
