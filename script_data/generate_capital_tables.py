#!/usr/bin/env python3
"""
Convert a faction_capital_capture dump into a revive_boring_campaign capitals table.

The capture mod (faction_capture.pack, script v4) writes
`<game install dir>\faction_capitals_dump.txt`. Lines sourced from something
other than faction:home_region() carry a `-- (leader_position)` /
`-- (region_list)` tag: those are hordes and factions that own nothing at
turn 1, kept on purpose but reported so they can be eyeballed.

Usage:
    python generate_capital_tables.py --dump <dump.txt> --variant vanilla
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_SCRIPT_DIR = ROOT / "revive_boring_campaign" / "script" / "campaign" / "mod"

VARIANTS = {
    "vanilla": ("revive_boring_campaign_vanilla_capitals.lua",
                "revive_boring_campaign_vanilla_faction_capitals",
                "main_warhammer (vanilla)"),
    "iee": ("revive_boring_campaign_iee_capitals.lua",
            "revive_boring_campaign_iee_faction_capitals",
            "main_warhammer (IE Extended)"),
    "oldworld": ("revive_boring_campaign_oldworld_capitals.lua",
                 "revive_boring_campaign_oldworld_faction_capitals",
                 "cr_oldworld"),
    "oldworldclassic": ("revive_boring_campaign_oldworldclassic_capitals.lua",
                        "revive_boring_campaign_oldworldclassic_faction_capitals",
                        "cr_oldworldclassic"),
}

# Script-owned factions that must never reach the MCT dropdowns. The capture
# script filters these too; this is the second line of defence for dumps
# produced by older versions of it.
EXCLUDED = (
    "rebel", "separatist", "qb_", "mixer_", "wh3_main_rogue",
    "_vassal_owner", "_confederation_owner", "summoned_verminlord",
    "thanquol_machinations",
)

ENTRY_RE = re.compile(r'\s*\["([^"]+)"\]\s*=\s*"([^"]+)"\s*,?\s*(?:--\s*\((\w+)\))?')
QB_RE = re.compile(r"_qb\d*$")


def is_excluded(key: str) -> bool:
    return QB_RE.search(key) is not None or any(p in key for p in EXCLUDED)


def parse_dump(path: Path):
    entries, tags, campaign, turn = [], {}, None, None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("CAMPAIGN_TYPE:"):
            campaign = line.split(":", 1)[1].strip()
            continue
        if line.startswith("TURN_NUMBER:"):
            turn = line.split(":", 1)[1].strip()
            continue
        m = ENTRY_RE.match(line)
        if not m:
            continue
        key, region, source = m.group(1), m.group(2), m.group(3) or "home_region"
        if is_excluded(key):
            continue
        entries.append((key, region))
        tags[key] = source
    return entries, tags, campaign, turn


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, required=True)
    parser.add_argument("--variant", choices=sorted(VARIANTS), required=True)
    parser.add_argument("--out-dir", type=Path, default=MOD_SCRIPT_DIR)
    args = parser.parse_args()

    filename, var_name, campaign_label = VARIANTS[args.variant]
    entries, tags, campaign, turn = parse_dump(args.dump)

    if not entries:
        print(f"ERROR: no entries parsed from {args.dump}", file=sys.stderr)
        return 1

    if turn is not None and turn != "1":
        print(f"WARNING: dump taken at turn {turn}, not turn 1 - "
              f"capitals may reflect conquests instead of start positions")

    out_path = args.out_dir / filename
    lines = [f"-- Auto-generated from {args.dump.name} for campaign {campaign_label}",
             f"-- Source campaign key: {campaign}, turn: {turn}",
             f"{var_name} = {{}}"]
    lines[2] = f"{var_name} = {{"
    for key, region in entries:
        lines.append(f'    ["{key}"] = "{region}",')
    lines.append("}")

    # No BOM: the game's Lua loader rejects it with
    # "unexpected symbol near '<BOM>'" and the table silently never loads.
    body = "\r\n".join(lines) + "\r\n"
    out_path.write_bytes(body.encode("utf-8"))

    by_source = defaultdict(int)
    for source in tags.values():
        by_source[source] += 1
    regions = defaultdict(list)
    for key, region in entries:
        regions[region].append(key)
    dups = {r: ks for r, ks in regions.items() if len(ks) > 1}

    print(f"Wrote {out_path}")
    print(f"  entries:         {len(entries)}")
    for source in sorted(by_source):
        print(f"  from {source:<16} {by_source[source]}")
    print(f"  shared regions:  {len(dups)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
