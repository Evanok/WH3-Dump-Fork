# Runtime Army Generation Notes

This repository now contains a small toolchain to build and test runtime-generated Warhammer 3 armies from database-driven roster permissions.

The goal is:
- extract a clean runtime roster dataset from the dumped DB tables
- derive roster overlap dynamically from `military_group` permissions instead of hardcoding special cases
- keep unit pools grouped by `military_group`
- map `faction -> military_group`
- include only generic or safely repeatable `lord` and `hero` candidates
- generate armies at runtime in Lua using explicit composition rules and fallbacks
- preview the results offline from a CLI before integrating into the actual mod repo


## What Was Added

### 1. Legacy unit dataset generator

File:
- [script_data/generate_army_template_data.py](/home/soundskrit/work/WH3-Dump/script_data/generate_army_template_data.py:1)

Purpose:
- reads exported TSV tables from `db/` and `text/db/`
- groups recruitable units by race/culture
- excludes Regiments of Renown
- can include or exclude characters
- when characters are included for runtime use, excludes legendary lords, legendary heroes, and unique named characters
- writes JSON and Lua outputs

Important outputs:
- [script_data/external_json_files/army_template_units.json](/home/soundskrit/work/WH3-Dump/script_data/external_json_files/army_template_units.json:1)
- [script_data/external_json_files/army_template_units_with_characters.json](/home/soundskrit/work/WH3-Dump/script_data/external_json_files/army_template_units_with_characters.json:1)
- [script/_lib/mod/army_template_unit_data.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/army_template_unit_data.lua:1)

Status:
- still useful for quick inspection
- no longer the preferred runtime source

For runtime generation, the preferred source is now the `military_group` dataset described below.

The legacy character-inclusive dataset also filters out legendary lords, legendary heroes, and unique named characters so that repeated runtime spawning does not create character collisions.


### 2. Runtime roster dataset generator

File:
- [script_data/generate_runtime_roster_data.py](/home/soundskrit/work/WH3-Dump/script_data/generate_runtime_roster_data.py:1)

Purpose:
- builds the actual runtime dataset used by the current workflow
- groups units by `military_group`
- builds a `faction -> military_group` mapping
- derives roster overlap dynamically from CA's own permissions tables
- filters out legendary, unique, and named characters that should not be duplicated
- deduplicates technical `main` / `pro` / similar character variants by display name

Important outputs:
- [script_data/external_json_files/runtime_roster_unit_data.json](/home/soundskrit/work/WH3-Dump/script_data/external_json_files/runtime_roster_unit_data.json:1)
- [script/_lib/mod/runtime_roster_unit_data.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/runtime_roster_unit_data.lua:1)

This is now the recommended dataset for runtime generation.


### 3. Runtime Lua generator bridge

File:
- [script/_lib/mod/lib_runtime_army_template_generator.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/lib_runtime_army_template_generator.lua:1)

Purpose:
- consumes the generated runtime roster Lua dataset
- builds army pools by `military_group`
- can also resolve a roster dynamically from a faction key
- selects a `lord` separately
- produces the remaining `19` units as a campaign force list
- can register the generated stack into CA's existing [`random_army_manager`](/home/soundskrit/work/WH3-Dump/script/_lib/lib_campaign_random_army.lua:1)

Why `19` units and not `20`:
- CA's `random_army_manager` hard-caps generated force size to `19`
- the `lord` is handled separately during campaign force creation
- full army = `1 lord + 19 units`


### 4. Offline preview CLI

File:
- [script_data/preview_runtime_army.py](/home/soundskrit/work/WH3-Dump/script_data/preview_runtime_army.py:1)

Purpose:
- simulates the same runtime logic as the Lua helper
- lets you test rosters from a faction key or a `military_group`
- lets you inspect generated armies without touching the actual mod repo


### 5. Optional offline template generator

File:
- [script_data/generate_army_templates.py](/home/soundskrit/work/WH3-Dump/script_data/generate_army_templates.py:1)

Purpose:
- generates pre-baked template armies

Status:
- optional only
- not needed for the current runtime-first approach


## Why Military Groups Matter

The important design change is that runtime army generation is no longer based primarily on `culture` or a hand-maintained notion of "race roster".

It is now based on CA's own:
- `faction -> military_group`
- `unit -> military_group permissions`

This is important because many Warhammer 3 rosters overlap:
- monogod factions may receive marked Chaos units
- marked Warriors of Chaos factions may receive daemon-side or god-marked units
- some factions share partial roster access without sharing a full culture roster

Examples:
- monogod Khorne and Valkia do not use the exact same roster
- Valkia can access some Khorne-marked Chaos units and some Khorne-side units
- generic Warriors of Chaos do not automatically get the full daemon rosters of all four gods

By using `military_group`, roster overlap is no longer hardcoded in the tools. It is inherited directly from the DB export.


## Why This Produces Better Variety

Using `military_group` improves army generation quality in several ways:
- roster overlap is preserved automatically when CA grants it in the DB
- different factions that share a culture but not the same actual recruitment permissions can now generate different armies
- marked Warriors of Chaos factions can feel distinct from monogod factions
- future patch changes in unit permissions are picked up by data regeneration instead of requiring manual maintenance
- the generated armies reflect the real recruitable pool more closely, which increases variety without inventing fake access rules

In short:
- `culture` is too coarse for some WH3 use cases
- `military_group` is the correct runtime roster abstraction


## Runtime Composition Rules

The current runtime composition is:
- `1` lord
- `1` hero
- `6` infantry
- `3` artillery
- `3` cavalry
- `3` ranged
- `3` monster

The `19` non-lord slots are therefore:
- `1 hero + 6 infantry + 3 artillery + 3 cavalry + 3 ranged + 3 monster`


## Category Mapping

The runtime generator uses gameplay-oriented buckets instead of raw DB categories.

Current mapping:
- `infantry` = `melee_infantry`, `monstrous_infantry`
- `ranged` = `missile_infantry`
- `artillery` = `artillery`, `war_machine`
- `cavalry` = `melee_cavalry`, `missile_cavalry`, `monstrous_cavalry`, `chariot`, `missile_chariot`
- `monster` = `monster`, `war_beast`
- `lord` = `character_lord`
- `hero` = `character_hero`

This means special categories such as chariots, war beasts, war machines, and monstrous cavalry are already handled and do not need separate logic right now.


## Fallback Rules

If a requested category is missing:
- missing `ranged` falls back to `infantry`
- missing `artillery`, `cavalry`, `monster`, or `infantry` falls back to a mixed `infantry/ranged` pool
- if a race has no `ranged` at all, fallback becomes infantry-only
- if neither infantry nor ranged exists, fallback uses any non-character unit

This is designed to cover races such as Khorne or other races with weak or missing ranged/artillery coverage.


## How To Regenerate The Data

Generate the current runtime roster JSON plus the Lua dataset used by the runtime generator:

```bash
python3 script_data/generate_runtime_roster_data.py
```

Generate the legacy character-inclusive dataset:

```bash
python3 script_data/generate_army_template_data.py \
  --include-characters \
  --lua-out script/_lib/mod/army_template_unit_data.lua \
  --json-out script_data/external_json_files/army_template_units_with_characters.json
```

Generate the legacy non-character dataset:

```bash
python3 script_data/generate_army_template_data.py
```


## How To Test With The CLI

List available factions:

```bash
python3 script_data/preview_runtime_army.py --list-factions
```

List available military groups:

```bash
python3 script_data/preview_runtime_army.py --list-military-groups
```

Preview one army from a faction:

```bash
python3 script_data/preview_runtime_army.py --faction wh3_main_kho_khorne
```

Preview one army directly from a military group:

```bash
python3 script_data/preview_runtime_army.py --military-group wh3_main_kho
```

Preview a faction with a fixed seed:

```bash
python3 script_data/preview_runtime_army.py --faction wh3_dlc20_chs_valkia --seed 7
```

Preview multiple armies for the same faction:

```bash
python3 script_data/preview_runtime_army.py --faction wh3_main_kho_khorne --count 3
```

What the CLI prints:
- selected lord
- the `19` generated units
- slot type used for each pick
- actual chosen category
- fallback source when applicable
- final comma-separated `force_list`


## Expected Testing Workflow

Recommended validation steps:
- run `--list-factions` or `--list-military-groups`
- confirm whether you want to test by faction or directly by military group
- preview 5 to 20 armies for the same target using different seeds
- check whether category balance looks coherent
- compare overlapping rosters such as monogod Khorne vs Valkia
- inspect fallback-heavy targets such as Khorne
- check whether some races produce too many duplicates
- decide whether some category mappings or character deduping rules need refinement


## Remaining Work In The Actual Mod Repo

This repo is now only the preparation and test environment. Final integration still needs to be done in your mod repo.

What remains:
- copy or mirror [script/_lib/mod/runtime_roster_unit_data.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/runtime_roster_unit_data.lua:1) into the mod repo
- copy or mirror [script/_lib/mod/lib_runtime_army_template_generator.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/lib_runtime_army_template_generator.lua:1) into the mod repo
- load both files from your campaign bootstrap
- call the generator with either a faction key or a military group key
- spawn the selected `lord` separately
- pass the generated `force_list` to your chosen campaign spawning API

Typical runtime flow in the mod:
1. `require()` the generated dataset
2. `require()` the runtime generator helper
3. call either:
   - `get_force_list(dataset, military_group_key)`
   - `get_force_list_for_faction(dataset, faction_key)`
4. receive `lord_key`, `force_list`, and the full generated metadata
5. spawn the army in campaign using `lord_key` + `force_list`


## Integration Notes

The current Lua helper supports three useful patterns:

1. Direct force list generation from a military group
- best if your mod already knows how to create a force from `lord_key` + `force_list`

2. Direct force list generation from a faction key
- best if you want roster overlap to follow the faction's actual `military_group`

3. Registration into `random_army_manager`
- useful if you want to reuse CA's existing random army infrastructure
- in this case the helper fills the generated `19` units as mandatory entries

The direct `force_list` path is usually simpler.


## Current Limitations

- no in-game integration has been done yet in the real mod repo
- no battle/campaign live validation was run here
- no Lua parser (`luac`) was available in this environment for syntax checking
- duplicate unit picks are allowed by design when a category pool is small
- weights, tier filtering, and elite/basic balancing are not implemented yet
- some faction rosters may still deserve faction-specific weighting later, even if the overlap source is now fully dynamic


## Possible Next Improvements

- add per-race weighting to reduce bad duplicates
- add tier-based or building-based filtering
- separate `flying`, `anti_large`, `shielded`, `AP`, or `flanker` sub-archetypes
- add race-specific composition overrides
- generate “themes” such as infantry-heavy, cavalry-heavy, monster-heavy, siege-heavy
- add a CLI mode that outputs only `lord_key` and `force_list`
