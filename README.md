# Runtime Army Generation Notes

This repository now contains a small toolchain to build and test runtime-generated Warhammer 3 armies by race.

The goal is:
- extract a clean unit dataset from the dumped DB tables
- keep unit pools grouped by race and category
- include `lord` and `hero` candidates
- generate armies at runtime in Lua using explicit composition rules and fallbacks
- preview the results offline from a CLI before integrating into the actual mod repo


## What Was Added

### 1. Unit dataset generator

File:
- [script_data/generate_army_template_data.py](/home/soundskrit/work/WH3-Dump/script_data/generate_army_template_data.py:1)

Purpose:
- reads exported TSV tables from `db/` and `text/db/`
- groups recruitable units by race/culture
- excludes Regiments of Renown
- can include or exclude characters
- writes JSON and Lua outputs

Important outputs:
- [script_data/external_json_files/army_template_units.json](/home/soundskrit/work/WH3-Dump/script_data/external_json_files/army_template_units.json:1)
- [script_data/external_json_files/army_template_units_with_characters.json](/home/soundskrit/work/WH3-Dump/script_data/external_json_files/army_template_units_with_characters.json:1)
- [script/_lib/mod/army_template_unit_data.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/army_template_unit_data.lua:1)

The Lua dataset in `script/_lib/mod/` is the one intended to be `require()`-ed later by the mod.


### 2. Runtime Lua generator bridge

File:
- [script/_lib/mod/lib_runtime_army_template_generator.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/lib_runtime_army_template_generator.lua:1)

Purpose:
- consumes the generated Lua dataset
- builds army pools by race and category
- selects a `lord` separately
- produces the remaining `19` units as a campaign force list
- can register the generated stack into CA's existing [`random_army_manager`](/home/soundskrit/work/WH3-Dump/script/_lib/lib_campaign_random_army.lua:1)

Why `19` units and not `20`:
- CA's `random_army_manager` hard-caps generated force size to `19`
- the `lord` is handled separately during campaign force creation
- full army = `1 lord + 19 units`


### 3. Offline preview CLI

File:
- [script_data/preview_runtime_army.py](/home/soundskrit/work/WH3-Dump/script_data/preview_runtime_army.py:1)

Purpose:
- simulates the same runtime logic as the Lua helper
- lets you test races and inspect generated armies without touching the actual mod repo


### 4. Optional offline template generator

File:
- [script_data/generate_army_templates.py](/home/soundskrit/work/WH3-Dump/script_data/generate_army_templates.py:1)

Purpose:
- generates pre-baked template armies

Status:
- optional only
- not needed for the current runtime-first approach


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

Generate the character-inclusive JSON plus the Lua dataset used by the runtime generator:

```bash
python3 script_data/generate_army_template_data.py \
  --include-characters \
  --lua-out script/_lib/mod/army_template_unit_data.lua \
  --json-out script_data/external_json_files/army_template_units_with_characters.json
```

Generate the non-character dataset:

```bash
python3 script_data/generate_army_template_data.py
```


## How To Test With The CLI

List available races:

```bash
python3 script_data/preview_runtime_army.py --list-races
```

Preview one army:

```bash
python3 script_data/preview_runtime_army.py wh3_main_kho_khorne
```

Preview a race with a fixed seed:

```bash
python3 script_data/preview_runtime_army.py wh_main_emp_empire --seed 7
```

Preview multiple armies for the same race:

```bash
python3 script_data/preview_runtime_army.py wh3_main_sla_slaanesh --count 3
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
- run `--list-races` and confirm the race key you want
- preview 5 to 20 armies for the same race using different seeds
- check whether category balance looks coherent
- inspect fallback-heavy races such as Khorne
- check whether some races produce too many duplicates
- decide whether some category mappings need refinement


## Remaining Work In The Actual Mod Repo

This repo is now only the preparation and test environment. Final integration still needs to be done in your mod repo.

What remains:
- copy or mirror [script/_lib/mod/army_template_unit_data.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/army_template_unit_data.lua:1) into the mod repo
- copy or mirror [script/_lib/mod/lib_runtime_army_template_generator.lua](/home/soundskrit/work/WH3-Dump/script/_lib/mod/lib_runtime_army_template_generator.lua:1) into the mod repo
- load both files from your campaign bootstrap
- call the generator with a target race key
- spawn the selected `lord` separately
- pass the generated `force_list` to your chosen campaign spawning API

Typical runtime flow in the mod:
1. `require()` the generated dataset
2. `require()` the runtime generator helper
3. call `get_force_list(dataset, race_key)`
4. receive `lord_key`, `force_list`, and the full generated metadata
5. spawn the army in campaign using `lord_key` + `force_list`


## Integration Notes

The current Lua helper supports two patterns:

1. Direct force list generation
- best if your mod already knows how to create a force from `lord_key` + `force_list`

2. Registration into `random_army_manager`
- useful if you want to reuse CA's existing random army infrastructure
- in this case the helper fills the generated `19` units as mandatory entries

The direct `force_list` path is usually simpler.


## Current Limitations

- no in-game integration has been done yet in the real mod repo
- no battle/campaign live validation was run here
- no Lua parser (`luac`) was available in this environment for syntax checking
- duplicate unit picks are allowed by design when a category pool is small
- weights, tier filtering, and elite/basic balancing are not implemented yet


## Possible Next Improvements

- add per-race weighting to reduce bad duplicates
- add tier-based or building-based filtering
- separate `flying`, `anti_large`, `shielded`, `AP`, or `flanker` sub-archetypes
- add race-specific composition overrides
- generate “themes” such as infantry-heavy, cavalry-heavy, monster-heavy, siege-heavy
- add a CLI mode that outputs only `lord_key` and `force_list`

