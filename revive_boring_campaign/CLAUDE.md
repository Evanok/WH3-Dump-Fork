# Revive Boring Campaign — Total War: Warhammer 3 Mod

A campaign mod that lets the player manipulate AI factions from the MCT (Mod
Configuration Tool) UI: kill, anarchy-kill, revive, buff, debuff, and set a
persistent "nemesis" faction.

- **Author:** Evanok
- **Current version:** 1.4.1 (see `CHANGES.md` for the full changelog)
- **Requires:** MCT v0.9 Beta or later

---

## Repository layout

This directory (`revive_boring_campaign/`) is the source of truth for the mod.
It lives inside the `WH3-Dump-Fork` git repo.

```
revive_boring_campaign/
├── CLAUDE.md                     -- this file
├── CHANGES.md                    -- version changelog (keep updated per release)
├── README.md                     -- user-facing documentation
├── STEAM_DESCRIPTION.md          -- Steam Workshop description
├── revive_boring_campaign.png    -- mod thumbnail
├── db/                           -- effect-bundle table folders (currently empty locally)
└── script/
    ├── _lib/mod/
    │   ├── runtime_roster_unit_data.lua              -- generated roster dataset (from WH3 dump tables)
    │   ├── lib_runtime_army_template_generator.lua   -- builds lord + 19-unit force from the dataset
    │   └── deprecated_army_templates.lua             -- fallback army templates by subculture
    ├── campaign/mod/
    │   ├── revive_boring_campaign.lua                -- main mod logic (~2400 lines)
    │   ├── revive_boring_campaign_vanilla_capitals.lua        -- main_warhammer vanilla IE capitals
    │   ├── revive_boring_campaign_iee_capitals.lua            -- IE Extended capitals
    │   ├── revive_boring_campaign_oldworld_capitals.lua       -- cr_oldworld capitals
    │   └── revive_boring_campaign_oldworldclassic_capitals.lua-- cr_oldworldclassic capitals
    └── mct/settings/
        └── revive_boring_campaign.lua                -- MCT UI definition + listeners
```

**Built pack:** `revive_boring_campaign.pack` (output lives one level up, in
`mode_warhammer3/`, and is not tracked by git).

---

## Features (as exposed in the MCT UI)

The UI has five collapsible sections. The action sections use a
**"select faction in dropdown → tick option checkboxes → tick Apply"** pattern,
and all checkboxes auto-reset after execution.

### 1. Kill Faction
Dropdown + two action checkboxes sharing the same dropdown:
- **Kill** — abandons all the faction's regions (→ ruins), removes foreign
  slots, and kills every character. `kill_faction()`
- **Anarchy Kill** — transfers all regions to a single "sink" rebel faction
  (`wh2_main_def_hag_graef_separatists`) instead of ruining them, cripples the
  sink with army-cap / growth / income penalty bundles, drains its treasury,
  downgrades the settlements, and forces it to war with every active faction.
  Falls back to ruins if the sink is unusable. `anarchy_kill_faction()`

### 2. Revive Faction
Dropdown + **Revive** checkbox. Transfers a capital province back to the dead
faction (skipped for regionless factions — Nakai, Changeling, Aislinn), upgrades
the province capital, grants 50,000 gold, and spawns 5 armies. If the faction
died via confederation, runs an experimental dummy-confederation workaround.
`revive_faction()`

### 3. Buff Faction
Dropdown + option checkboxes → **Execute Buff**. `boost_faction(faction, options)`:
- **Unlock All Technologies** — `cm:instantly_research_all_technologies()`
- **Free Upkeep (25 turns)** — per-army `apply_effect_bundle_to_characters_force`
- **Give 50,000 Gold** — `cm:treasury_mod()`
- **Spawn 5 Armies** at the faction capital
- **Confederate All Same Subculture** — force-confederates every living
  same-subculture AI faction into the target
- **Confederate Specific Faction** — dropdown to absorb one named faction;
  result reported in the "Confederate Result" text field

### 4. Debuff Faction
Dropdown + option checkboxes → **Execute Debuff**. `nerf_faction(faction, options)`:
- **Drain 50% Treasury**
- **Kill All Armies**
- (A morale-penalty path exists in `nerf_faction` but is **not** wired to a UI
  checkbox — dead code unless re-exposed.)

### 5. Nemesis
Dropdown only — **no Apply needed**, takes effect on selection. `set_nemesis()`:
- **On selection:** revive if dead, unlock techs, +50k gold, spawn 5 armies,
  declare war on the weakest adjacent hostile faction.
- **Every 10 turns:** revive if dead; if not top-10 by territory, +50k gold and
  5 armies; declare war if at peace.
- **Every 25 turns:** confederate the largest same-subculture AI faction into it.
- Info fields show live territory count and rank.
- **Persists** across save/reload via `cm:set_saved_value("rbc_nemesis_faction_key", …)`.
  Starts as None on new campaigns (the MCT registry is deliberately NOT used as a
  fallback, since it would leak across campaigns).

---

## Architecture notes

### Campaign variants & capital tables
Both vanilla Immortal Empires and IE Extended report the campaign key
`main_warhammer`, so the mod distinguishes them at runtime with a sentinel
(`cr_kho_servants_of_the_blood_nagas` / region `cr_combi_region_soglap`).
`get_active_faction_capitals()` picks the table per campaign:

| Campaign (`cm:get_campaign_name()`) | Capital table |
|---|---|
| `main_warhammer` + IEE sentinel present | IEE table (inline `faction_capitals` in main script) |
| `main_warhammer` vanilla | `revive_boring_campaign_vanilla_faction_capitals` |
| `cr_oldworld` | `revive_boring_campaign_oldworld_faction_capitals` |
| `cr_oldworldclassic` | `revive_boring_campaign_oldworldclassic_faction_capitals` |

`find_region_for_revive()` fallback order: mapped capital (if abandoned or
AI-owned) → any abandoned region → any AI-owned region. Player-owned regions are
never taken.

### Runtime army generation
`get_army_for_faction()` first asks `runtime_army_template_generator` (fed by the
generated `runtime_roster_unit_data`) for a lord subtype + 19-unit force built
from CA military-group roster permissions. If that can't resolve a faction, it
falls back to `deprecated_army_templates[subculture]`, then to a default. Armies
spawned by the mod get 25 turns of free upkeep so revived/buffed AI don't instantly
go bankrupt.

### Entry point
`cm:add_first_tick_callback` → `revive_boring_campaign:initialize()`, which
selects the capital table, restores the saved nemesis, and registers a
`FactionTurnEnd` (human) listener for `nemesis_periodic_check()`. The MCT script
registers all the option listeners under an `MctInitialized` listener.

---

## Key API functions (and gotchas)

```lua
-- Kill a character AND its army (use this, not cm:kill_character)
cm:kill_character_and_commanded_unit(cm:char_lookup_str(cqi), true, true)

-- Effect bundles: FACTION vs ARMY are different calls
cm:apply_effect_bundle(bundle_key, faction_key, turns)                      -- faction-wide
cm:apply_effect_bundle_to_characters_force(bundle_key, character_cqi, turns) -- one army  ← for upkeep/morale

-- Regions
cm:transfer_region_to_faction(region_key, faction_key)
cm:set_region_abandoned(region_key)
cm:instantly_set_settlement_primary_slot_level(settlement, 5)  -- CA clamps to chain max

-- Forces
cm:create_force(faction, units, region, x, y, false, callback)
cm:create_force_with_general(faction, units, region, x, y, "general", agent_subtype, "", "", "", "", false, callback)
cm:find_valid_spawn_location_for_character_from_settlement(faction, region, false, true, radius)

-- Diplomacy / confederation
cm:force_confederation(absorbing_faction, absorbed_faction)   -- wrap in pcall; can fail
cm:force_declare_war(a, b, false, false)

-- Persistence (survives save/reload; per-campaign)
cm:set_saved_value(key, value) / cm:get_saved_value(key)
```

- **Spawn fallback:** if `find_valid_spawn_location…` fails, fall back to the
  settlement's own `logical_position_x/y()` with small offsets (see
  `get_spawn_location_near_settlement`).
- Wrap `force_confederation` in `pcall` — it throws on some faction states.

---

## Building the pack

Uses the RPFM CLI (`../rpfm-v4.7.4-x86_64-pc-windows-msvc/rpfm_cli.exe`, relative
to `mode_warhammer3/`). Source of truth is this folder's `script/`.

```bash
cd "/c/Users/User/work/mode_warhammer3"

rm -f "./revive_boring_campaign.pack"

./rpfm-v4.7.4-x86_64-pc-windows-msvc/rpfm_cli.exe --game warhammer_3 pack create \
  --pack-path "./revive_boring_campaign.pack"

./rpfm-v4.7.4-x86_64-pc-windows-msvc/rpfm_cli.exe --game warhammer_3 pack add \
  --pack-path "./revive_boring_campaign.pack" \
  --folder-path "./WH3-Dump-Fork/revive_boring_campaign/script;script"

cp "./revive_boring_campaign.pack" \
  "/c/Program Files (x86)/Steam/steamapps/common/Total War WARHAMMER III/data/"
```

---

## Development notes

- **No hot reload.** Loose AppData script files are not loaded by the game; a
  `.pack` is required. Rebuild the pack and restart the game for any code change.
- **Logging:** `out()` writes to both the in-game console and
  `…/Total War WARHAMMER III/lua_mod_log.txt`. Filter on `[RBC_DEBUG]`. The log is
  overwritten on each launch. `io.open()` is blocked by the game sandbox.
- **MCT cache:** if UI changes don't appear, close the game and delete
  `%APPDATA%\The Creative Assembly\Warhammer3\scripts\mct_registry.lua`, then
  rebuild/reinstall and restart.

---

## File locations

| What | Where |
|---|---|
| Source code | `…\WH3-Dump-Fork\revive_boring_campaign\` (this folder) |
| Built pack (install) | `…\Total War WARHAMMER III\data\revive_boring_campaign.pack` |
| Runtime log | `…\Total War WARHAMMER III\lua_mod_log.txt` (filter `[RBC_DEBUG]`) |
| MCT settings cache | `%APPDATA%\The Creative Assembly\Warhammer3\scripts\mct\settings\` |
| MCT registry | `%APPDATA%\The Creative Assembly\Warhammer3\scripts\mct_registry.lua` |
| RPFM CLI | `…\mode_warhammer3\rpfm-v4.7.4-x86_64-pc-windows-msvc\rpfm_cli.exe` |

---

## Known issues

1. Some DLC / IE-Extended faction and region keys are best-effort; revive falls
   back to abandoned/AI regions when a mapped capital isn't present in the campaign.
2. Confederated-faction revive uses an experimental dummy workaround and may not
   always succeed.
3. Changes only take effect while a campaign is loaded and the action is applied
   in the MCT.
