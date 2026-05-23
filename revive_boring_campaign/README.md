# Revive Boring Campaign - Total War: Warhammer 3 Mod

## Project Overview

A mod to revive boring mid/late-game campaigns by allowing players to kill, resurrect, buff or debuff factions via MCT (Mod Configuration Tool).

**Problem:** In late game, some factions become too dominant (Reikland, Elves, Dwarfs) while interesting factions like Chaos demons are wiped out. The campaign becomes boring.

**Solution:** Give players tools to rebalance the campaign dynamically.

---

## Features Status

### Status Legend
| Status | Description |
|--------|-------------|
| `[DONE]` | Implemented and tested, works |
| `[TO TEST]` | Implemented, needs validation in game |
| `[WIP]` | Work in progress |
| `[TODO]` | Not started |
| `[BROKEN]` | Known to not work |

### Kill Faction
| Feature | Status | Notes |
|---------|--------|-------|
| Faction dropdown (~80 factions) | `[DONE]` | All playable factions included |
| Kill checkbox trigger | `[DONE]` | Kills faction leader |
| Checkbox auto-reset | `[DONE]` | Resets after execution |
| Anarchy Kill / Eshin-style kill | `[TO TEST]` | Alternative kill mode: destroy the faction but transfer its regions to same-subculture rebel factions instead of razing them |

### Revive Faction
| Feature | Status | Notes |
|---------|--------|-------|
| Faction dropdown | `[DONE]` | Same list as Kill |
| Revive checkbox trigger | `[DONE]` | |
| Region transfer to faction | `[DONE]` | Transfers full province when possible; skips player-owned regions |
| Province capital upgrade | `[DONE]` | Sets revived province capital primary slot to level 5, clamped by game max |
| Army spawning | `[DONE]` | Runtime roster generator + 25-turn free upkeep support |
| Checkbox auto-reset | `[DONE]` | Resets after execution |

### Buff Faction
| Feature | Status | Notes |
|---------|--------|-------|
| Faction dropdown | `[DONE]` | |
| Unlock All Technologies | `[DONE]` | |
| Free Upkeep (25 turns) | `[DONE]` | Uses effect bundle on army CQI |
| Give 50,000 Gold | `[DONE]` | |
| Spawn 5 Armies | `[DONE]` | Runtime roster generator + 25-turn free upkeep support |
| Execute Buff button | `[DONE]` | |
| All checkboxes auto-reset | `[DONE]` | |

### Debuff Faction
| Feature | Status | Notes |
|---------|--------|-------|
| Faction dropdown | `[DONE]` | |
| Drain 50% Treasury | `[DONE]` | |
| Kill All Armies | `[DONE]` | |
| Execute Debuff button | `[DONE]` | |
| All checkboxes auto-reset | `[DONE]` | |

### UI/UX
| Feature | Status | Notes |
|---------|--------|-------|
| MCT integration | `[DONE]` | 4 collapsible sections |
| Instructions in description | `[DONE]` | |
| Checkbox initial state reset | `[DONE]` | All MCT checkboxes forced false on UI load/init |

---

## Requirements

- **MCT v0.9 Beta** (Mod Configuration Tool) - Must be installed
- **Compatible with existing saves** - Not just new campaigns
- Works on **Immortal Empires / main_warhammer**
- Works on **Immortal Empires Extended** with runtime detection
- Works on **The Old World** (`cr_oldworld`)
- Works on **The Old World Classic** (`cr_oldworldclassic`)

---

## Folder Structure

```
revive_boring_campaign/
├── CLAUDE.md                              # This file
└── script/
    ├── campaign/
    │   └── mod/
    │       └── revive_boring_campaign.lua # Main logic
    └── mct/
        └── settings/
            └── revive_boring_campaign.lua # MCT UI definition
```

---

## Key API Functions

```lua
-- Kill a character
cm:kill_character(character_cqi, true, true)

-- Transfer region to faction
cm:transfer_region_to_faction(region_key, faction_key)

-- Spawn army
cm:create_force(faction_key, unit_list, region_key, x, y, agent_subtype, true)

-- Find spawn location (may fail, need fallback)
cm:find_valid_spawn_location_for_character_from_settlement(faction_key, region_key, false, true, radius)

-- Give gold
cm:treasury_mod(faction_key, amount)

-- Unlock all techs
cm:instantly_research_all_technologies(faction_key)

-- Apply effect bundle to army (NOT faction!)
cm:apply_effect_bundle_to_characters_force(bundle_key, character_cqi, duration)
```

---

## Build Process

```bash
cd "/c/Users/User/work/mode_warhammer3"

# Remove old pack
rm -f "./revive_boring_campaign.pack"

# Create new pack
./rpfm-v4.7.4-x86_64-pc-windows-msvc/rpfm_cli.exe --game warhammer_3 pack create \
  --pack-path "./revive_boring_campaign.pack"

# Add script files
./rpfm-v4.7.4-x86_64-pc-windows-msvc/rpfm_cli.exe --game warhammer_3 pack add \
  --pack-path "./revive_boring_campaign.pack" \
  --folder-path "./revive_boring_campaign/script;script"

# Copy to game data folder
cp "./revive_boring_campaign.pack" "/c/Program Files (x86)/Steam/steamapps/common/Total War WARHAMMER III/data/"
```

---

## Important Notes

- **Effect bundles for armies**: Use `cm:apply_effect_bundle_to_characters_force()` NOT `cm:apply_effect_bundle()`. The latter applies to factions, not individual armies.
- **Spawn location fallback**: If `find_valid_spawn_location_for_character_from_settlement()` fails, use settlement coordinates directly.
- **Logging**: Search for `[RBC_DEBUG]` in `lua_mod_log.txt` after launching the game. `out()` writes there when script logging is enabled; `io.open()` is sandboxed in WH3 scripts.
- **Hot reload does NOT work** - pack file required, must restart game
- **MCT cache**: Delete `mct_registry.lua` if UI changes don't appear
- **Campaign table selection**:
  - `cr_oldworld` uses the dedicated Old World dump table
  - `cr_oldworldclassic` uses the dedicated Old World Classic dump table
  - `main_warhammer` is split at runtime between vanilla and IEE because both share the same campaign key
- **IEE detection**: the mod detects Immortal Empires Extended by checking for Extended-only faction/region sentinels, then selects the IEE capital table and MCT dropdown source

---

## Resources

### External References

| Resource | URL | Notes |
|----------|-----|-------|
| TW Autogen | https://github.com/chadvandy/tw_autogen | Generated Total War scripting/API reference source. |
| Total War Modding Wiki | https://tw-modding.com/index.php/Main_Page | General Total War modding documentation and guides. |
| TW Modding Resources | https://chadvandy.github.io/tw_modding_resources/index.html | Chadvandy's Total War modding resources and generated docs. |

### Logs

| Resource | Location | Notes |
|----------|----------|-------|
| Lua mod log | `C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\lua_mod_log.txt` | Main file to check. Search for `ReviveBoringCampaign` or `[RBC_DEBUG]`. |
| Game logs folder | `%APPDATA%\The Creative Assembly\Warhammer3\logs\` | Contains general WH3 logs like `modified.log`, `gfx.log.txt`, and `mp_log.txt`. |
| Faction capital dumps | `C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\` | The dump helper writes files like `faction_capitals_dump.txt` in the game root, not in AppData. |

### Script Copies / Cache

| Resource | Location | Notes |
|----------|----------|-------|
| Campaign loose script copy | `%APPDATA%\The Creative Assembly\Warhammer3\scripts\campaign\mod\revive_boring_campaign.lua` | Can contain an old copied version of the mod script. Check this if logs do not match source code. |
| MCT loose script copy | `%APPDATA%\The Creative Assembly\Warhammer3\scripts\mct\settings\revive_boring_campaign.lua` | Can contain an old copied version of the MCT settings. |
| MCT registry | `%APPDATA%\The Creative Assembly\Warhammer3\scripts\mct_registry.lua` | Delete if MCT UI changes do not appear. |

### Installed Pack

| Resource | Location | Notes |
|----------|----------|-------|
| Source pack build | `C:\Users\User\work\mode_warhammer3\revive_boring_campaign.pack` | Local rebuilt pack. |
| Installed game pack | `C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\data\revive_boring_campaign.pack` | WH3 loads this file. Close the game/launcher before replacing it because it can be locked. |

---

## File Locations

| File | Location |
|------|----------|
| Source code | `C:\Users\User\work\mode_warhammer3\revive_boring_campaign\` |
| Pack file | `C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\data\` |
| MCT cache | `%APPDATA%\The Creative Assembly\Warhammer3\scripts\mct_registry.lua` |
| Mod load log | `C:\Program Files (x86)\Steam\steamapps\common\Total War WARHAMMER III\lua_mod_log.txt` |

---

## References

- **MCT v0.9 Beta**: Workshop ID 2927211547
- **Dynamic Disasters**: Workshop ID 2856219244 (reference)
- **RPFM**: https://github.com/Frodo45127/rpfm
