#!/usr/bin/env python3
"""
Generate runtime roster data keyed by military_group, with faction -> military_group mapping.

This is the dynamic, non-hardcoded source intended for runtime army generation.
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
DEFAULT_JSON_OUTPUT = ROOT / "script_data" / "external_json_files" / "runtime_roster_unit_data.json"
DEFAULT_LUA_OUTPUT = ROOT / "script" / "_lib" / "mod" / "runtime_roster_unit_data.lua"

# Some recruitable character units are not listed in military permissions because their
# recruitment is governed by faction-specific systems. Add them here so runtime army
# generation can still use a valid create_force_with_general subtype.
CHARACTER_UNIT_MILITARY_GROUP_SUPPLEMENTS = {
    "wh2_dlc09_tmb_cha_tomb_king_0": [
        "wh2_dlc09_tomb_kings",
        "wh2_dlc09_tomb_kings_arkhan",
    ],
}


@dataclass(frozen=True)
class UnitRecord:
    unit_key: str
    land_unit_key: str
    agent_subtype: str
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
    parser.add_argument("--include-rogue", action="store_true", help="Include rogue factions and military groups")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)
    if rows and any(str(value).startswith("#") for value in rows[0].values()):
        rows = rows[1:]
    return rows


def read_loc_map(path: Path, prefixes: list[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for row in read_tsv(path):
        key = row.get("key", "")
        text = row.get("text", "").strip()
        if not text:
            continue
        for prefix in prefixes:
            if key.startswith(prefix):
                result.setdefault(key[len(prefix) :], text)
                break
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


def character_dedupe_score(record: UnitRecord) -> tuple[int, int, str]:
    key = record.unit_key
    penalty = 0
    if "_pro_" in key:
        penalty += 100
    if "_survival_" in key:
        penalty += 100
    if "_spawned_" in key:
        penalty += 100
    return (penalty, len(key), key)


def build_unit_record(
    unit_key: str,
    main_unit: dict[str, str],
    land_units: dict[str, dict[str, str]],
    unit_names: dict[str, str],
    character_unit_to_agent_subtype: dict[str, str],
) -> UnitRecord:
    land_unit_key = main_unit.get("land_unit", "").strip()
    land_unit = land_units.get(land_unit_key)
    category, category_raw = normalize_category(main_unit, land_unit)
    return UnitRecord(
        unit_key=unit_key,
        land_unit_key=land_unit_key,
        agent_subtype=character_unit_to_agent_subtype.get(unit_key, ""),
        name=unit_names.get(land_unit_key, unit_key),
        category=category,
        category_raw=category_raw,
        caste=main_unit.get("caste", "").strip(),
        is_ror=main_unit.get("is_renown", "").strip().lower() == "true",
        is_naval=main_unit.get("is_naval", "").strip().lower() == "true",
    )


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


def main() -> int:
    args = parse_args()

    cultures_by_subculture = {
        row["subculture"]: row["culture"]
        for row in read_tsv(DB_DIR / "cultures_subcultures_tables" / "data__.tsv")
        if row.get("subculture") and row.get("culture")
    }

    culture_names = read_loc_map(TEXT_DB_DIR / "cultures__.loc.tsv", ["cultures_name_"])
    faction_names = read_loc_map(TEXT_DB_DIR / "factions__.loc.tsv", ["factions_screen_name_", "factions_name_"])
    unit_names = read_loc_map(TEXT_DB_DIR / "land_units__.loc.tsv", ["land_units_onscreen_name_"])

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

    unique_agent_subtypes = {
        row["agent_subtype"]
        for row in read_tsv(DB_DIR / "unique_agents_tables" / "data__.tsv")
        if row.get("agent_subtype")
    }

    valid_runtime_character_units: set[str] = set()
    character_unit_to_agent_subtype: dict[str, str] = {}
    for row in read_tsv(DB_DIR / "agent_subtypes_tables" / "data__.tsv"):
        unit_key = row.get("associated_unit_override", "").strip()
        if not unit_key:
            continue
        subtype_key = row.get("key", "").strip()
        if subtype_key in unique_agent_subtypes:
            continue
        recruitment_category = row.get("recruitment_category", "").strip()
        if recruitment_category in {"legendary_lords", "legendary_heroes"}:
            continue
        if row.get("auto_generate", "").strip().lower() != "true":
            continue
        if row.get("show_in_ui", "").strip().lower() != "true":
            continue
        if row.get("recruitable", "").strip().lower() != "true":
            continue
        if row.get("contributes_to_agent_cap", "").strip().lower() != "true":
            continue
        valid_runtime_character_units.add(unit_key)
        character_unit_to_agent_subtype.setdefault(unit_key, subtype_key)

    factions_payload: dict[str, dict[str, Any]] = {}
    military_groups_to_factions: dict[str, list[str]] = defaultdict(list)
    factions_rows = read_tsv(DB_DIR / "factions_tables" / "data__.tsv")
    for row in factions_rows:
        faction_key = row.get("key", "").strip()
        if not faction_key:
            continue
        military_group = row.get("military_group", "").strip()
        subculture = row.get("subculture", "").strip()
        culture = cultures_by_subculture.get(subculture, "")
        if not args.include_rogue and culture == "wh2_main_rogue":
            continue
        factions_payload[faction_key] = {
            "key": faction_key,
            "name": faction_names.get(faction_key, faction_key),
            "subculture": subculture,
            "culture": culture,
            "culture_name": culture_names.get(culture, culture) if culture else "",
            "military_group": military_group,
        }
        if military_group:
            military_groups_to_factions[military_group].append(faction_key)

    units_by_military_group: dict[str, dict[str, UnitRecord]] = defaultdict(dict)
    for row in read_tsv(DB_DIR / "units_to_groupings_military_permissions_tables" / "data__.tsv"):
        unit_key = row.get("unit", "").strip()
        military_group = row.get("military_group", "").strip()
        main_unit = main_units.get(unit_key)
        if not military_group or not main_unit:
            continue

        is_ror = main_unit.get("is_renown", "").strip().lower() == "true"
        if is_ror:
            continue

        caste = main_unit.get("caste", "").strip()
        if caste in {"lord", "hero"} and unit_key not in valid_runtime_character_units:
            continue

        record = build_unit_record(unit_key, main_unit, land_units, unit_names, character_unit_to_agent_subtype)
        units_by_military_group[military_group][unit_key] = record

    for unit_key, military_groups in CHARACTER_UNIT_MILITARY_GROUP_SUPPLEMENTS.items():
        main_unit = main_units.get(unit_key)
        if not main_unit or main_unit.get("is_renown", "").strip().lower() == "true":
            continue
        if unit_key not in valid_runtime_character_units:
            continue
        record = build_unit_record(unit_key, main_unit, land_units, unit_names, character_unit_to_agent_subtype)
        for military_group in military_groups:
            if military_group:
                units_by_military_group[military_group].setdefault(unit_key, record)

    military_groups_payload: dict[str, Any] = {}
    for military_group in sorted(units_by_military_group):
        if not args.include_rogue and military_group not in military_groups_to_factions:
            continue
        records = list(units_by_military_group[military_group].values())
        deduped_character_records: dict[tuple[str, str], UnitRecord] = {}
        non_character_records: list[UnitRecord] = []
        for record in records:
            if record.category in {"character_lord", "character_hero"}:
                dedupe_key = (record.category, record.name)
                existing = deduped_character_records.get(dedupe_key)
                if existing is None or character_dedupe_score(record) < character_dedupe_score(existing):
                    deduped_character_records[dedupe_key] = record
            else:
                non_character_records.append(record)
        records = sorted(non_character_records + list(deduped_character_records.values()), key=lambda item: (item.category, item.name, item.unit_key))

        units_payload = [
            {
                "unit_key": record.unit_key,
                "land_unit_key": record.land_unit_key,
                "agent_subtype": record.agent_subtype,
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

        faction_keys = sorted(military_groups_to_factions.get(military_group, []))
        military_groups_payload[military_group] = {
            "military_group": military_group,
            "faction_keys": faction_keys,
            "faction_names": [factions_payload[key]["name"] for key in faction_keys if key in factions_payload],
            "culture_names": sorted({factions_payload[key]["culture_name"] for key in faction_keys if key in factions_payload and factions_payload[key]["culture_name"]}),
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
                "db/agent_subtypes_tables/data__.tsv",
                "db/unique_agents_tables/data__.tsv",
                "text/db/cultures__.loc.tsv",
                "text/db/factions__.loc.tsv",
                "text/db/land_units__.loc.tsv",
            ],
        },
        "filters": {
            "exclude_ror": True,
            "exclude_legendary_and_unique_characters": True,
            "exclude_rogue_culture": not args.include_rogue,
            "dedupe_character_variants_by_name": True,
            "character_unit_military_group_supplements": CHARACTER_UNIT_MILITARY_GROUP_SUPPLEMENTS,
        },
        "faction_count": len(factions_payload),
        "military_group_count": len(military_groups_payload),
        "factions": dict(sorted(factions_payload.items())),
        "military_groups": military_groups_payload,
    }

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.lua_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.lua_out.write_text("return " + to_lua(payload) + "\n", encoding="utf-8")

    print(f"Wrote JSON: {args.json_out}")
    print(f"Wrote Lua:  {args.lua_out}")
    print(f"Factions:   {len(factions_payload)}")
    print(f"Groups:     {len(military_groups_payload)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
