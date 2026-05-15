#!/usr/bin/env python3
"""
Generate a reusable unit dataset for Lua army templates.

Default behavior:
- groups units by culture ("race")
- excludes Regiments of Renown
- excludes character entries (lords/heroes)
- emits both JSON and Lua outputs
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DB_DIR = ROOT / "db"
TEXT_DB_DIR = ROOT / "text" / "db"
DEFAULT_JSON_OUTPUT = ROOT / "script_data" / "external_json_files" / "army_template_units.json"
DEFAULT_LUA_OUTPUT = ROOT / "script_data" / "external_json_files" / "army_template_units.lua"


@dataclass(frozen=True)
class UnitRecord:
    unit_key: str
    land_unit_key: str
    name: str
    category: str
    category_raw: str
    caste: str
    is_ror: bool
    is_naval: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-out", type=Path, default=DEFAULT_JSON_OUTPUT, help="JSON output path")
    parser.add_argument("--lua-out", type=Path, default=DEFAULT_LUA_OUTPUT, help="Lua output path")
    parser.add_argument(
        "--include-characters",
        action="store_true",
        help="Include lords and heroes in the generated dataset",
    )
    parser.add_argument(
        "--include-rogue",
        action="store_true",
        help="Include rogue cultures such as wh2_main_rogue",
    )
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    # CA exports contain a metadata row after the header.
    if rows and any(str(value).startswith("#") for value in rows[0].values()):
        rows = rows[1:]

    return rows


def read_loc_map(path: Path, prefix: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for row in read_tsv(path):
        key = row.get("key", "")
        if not key.startswith(prefix):
            continue
        text = row.get("text", "").strip()
        if not text:
            continue
        result[key[len(prefix) :]] = text
    return result


def normalize_category(main_unit: dict[str, str], land_unit: dict[str, str] | None) -> tuple[str, str]:
    caste = main_unit.get("caste", "").strip()
    land_category = (land_unit or {}).get("category", "").strip()
    ar_unit_category = (land_unit or {}).get("ar_unit_category", "").strip()

    if caste == "chariot":
        if ar_unit_category == "artillery":
            return "artillery", ar_unit_category
        if ar_unit_category == "skirmish":
            return "missile_chariot", ar_unit_category
        return "chariot", ar_unit_category or land_category or caste

    mapping = {
        "melee_infantry": "melee_infantry",
        "missile_infantry": "missile_infantry",
        "melee_cavalry": "melee_cavalry",
        "missile_cavalry": "missile_cavalry",
        "monstrous_infantry": "monstrous_infantry",
        "monstrous_cavalry": "monstrous_cavalry",
        "monster": "monster",
        "war_beast": "war_beast",
        "chariot": "chariot",
        "warmachine": "war_machine",
        "lord": "character_lord",
        "hero": "character_hero",
    }

    if caste in mapping:
        return mapping[caste], land_category or caste

    fallback = {
        "inf_melee": "melee_infantry",
        "inf_ranged": "missile_infantry",
        "cavalry": "melee_cavalry",
        "artillery": "artillery",
        "war_machine": "war_machine",
        "war_beast": "war_beast",
    }
    if land_category in fallback:
        return fallback[land_category], land_category

    return "other", land_category or caste or "unknown"


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
            lua_key = key if key.isidentifier() else f'["{key}"]'
            items.append(f"{next_space}{lua_key} = {to_lua(item, next_indent)}")
        return "{\n" + ",\n".join(items) + "\n" + space + "}"
    raise TypeError(f"Unsupported Lua type: {type(value)!r}")


def main() -> int:
    args = parse_args()

    cultures_by_subculture = {
        row["subculture"]: row["culture"]
        for row in read_tsv(DB_DIR / "cultures_subcultures_tables" / "data__.tsv")
        if row.get("subculture") and row.get("culture")
    }

    culture_names = read_loc_map(TEXT_DB_DIR / "cultures__.loc.tsv", "cultures_name_")
    unit_names = read_loc_map(TEXT_DB_DIR / "land_units__.loc.tsv", "land_units_onscreen_name_")

    military_group_to_culture: dict[str, str] = {}
    for row in read_tsv(DB_DIR / "factions_tables" / "data__.tsv"):
        military_group = row.get("military_group", "").strip()
        subculture = row.get("subculture", "").strip()
        culture = cultures_by_subculture.get(subculture)
        if not military_group or not culture:
            continue
        military_group_to_culture.setdefault(military_group, culture)

    main_units = {
        row["unit"]: row
        for row in read_tsv(DB_DIR / "main_units_tables" / "data__.tsv")
        if row.get("unit")
    }
    land_units = {
        row["key"]: row
        for row in read_tsv(DB_DIR / "land_units_tables" / "data__.tsv")
        if row.get("key")
    }

    units_by_culture: dict[str, dict[str, UnitRecord]] = defaultdict(dict)
    military_groups_by_culture: dict[str, set[str]] = defaultdict(set)

    for row in read_tsv(DB_DIR / "units_to_groupings_military_permissions_tables" / "data__.tsv"):
        unit_key = row.get("unit", "").strip()
        military_group = row.get("military_group", "").strip()
        culture = military_group_to_culture.get(military_group)
        main_unit = main_units.get(unit_key)

        if not culture or not main_unit:
            continue

        if not args.include_rogue and culture == "wh2_main_rogue":
            continue

        is_ror = main_unit.get("is_renown", "").strip().lower() == "true"
        if is_ror:
            continue

        caste = main_unit.get("caste", "").strip()
        if not args.include_characters and caste in {"lord", "hero"}:
            continue

        is_naval = main_unit.get("is_naval", "").strip().lower() == "true"
        land_unit_key = main_unit.get("land_unit", "").strip()
        land_unit = land_units.get(land_unit_key)
        category, category_raw = normalize_category(main_unit, land_unit)

        record = UnitRecord(
            unit_key=unit_key,
            land_unit_key=land_unit_key,
            name=unit_names.get(land_unit_key, unit_key),
            category=category,
            category_raw=category_raw,
            caste=caste,
            is_ror=is_ror,
            is_naval=is_naval,
        )

        units_by_culture[culture][unit_key] = record
        military_groups_by_culture[culture].add(military_group)

    races: dict[str, Any] = {}
    for culture in sorted(units_by_culture):
        records = sorted(units_by_culture[culture].values(), key=lambda item: (item.category, item.name, item.unit_key))
        units_payload = [
            {
                "unit_key": record.unit_key,
                "land_unit_key": record.land_unit_key,
                "name": record.name,
                "category": record.category,
                "category_raw": record.category_raw,
                "caste": record.caste,
            }
            for record in records
        ]
        units_by_category: dict[str, list[str]] = defaultdict(list)
        for record in records:
            units_by_category[record.category].append(record.unit_key)

        races[culture] = {
            "name": culture_names.get(culture, culture),
            "culture": culture,
            "military_groups": sorted(military_groups_by_culture[culture]),
            "unit_count": len(units_payload),
            "units": units_payload,
            "units_by_category": dict(sorted(units_by_category.items())),
        }

    payload = {
        "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source": {
            "repo_root": str(ROOT),
            "tables": [
                "db/cultures_subcultures_tables/data__.tsv",
                "db/factions_tables/data__.tsv",
                "db/main_units_tables/data__.tsv",
                "db/land_units_tables/data__.tsv",
                "db/units_to_groupings_military_permissions_tables/data__.tsv",
                "text/db/cultures__.loc.tsv",
                "text/db/land_units__.loc.tsv",
            ],
        },
        "filters": {
            "exclude_ror": True,
            "exclude_characters": not args.include_characters,
            "exclude_rogue_culture": not args.include_rogue,
        },
        "race_count": len(races),
        "races": races,
    }

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.lua_out.parent.mkdir(parents=True, exist_ok=True)

    args.json_out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.lua_out.write_text("return " + to_lua(payload) + "\n", encoding="utf-8")

    print(f"Wrote JSON: {args.json_out}")
    print(f"Wrote Lua:  {args.lua_out}")
    print(f"Races:      {len(races)}")
    print(f"Units:      {sum(race['unit_count'] for race in races.values())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
