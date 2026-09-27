# Changes

## v1.5.0

- Added support for the 9.0 / DLC29 factions: Host of Nagash (`wh3_dlc29_nag_host_of_nagash`),
  The Lahmian Sisterhood / Neferata (`wh3_dlc29_vmp_neferata`), Clan Scruten / Thanquol
  (`wh3_dlc29_skv_clan_scruten`) and Host of the Triplets / Glottkin
  (`wh3_dlc29_chs_host_of_the_triplets`), in the vanilla Immortal Empires and IE Extended tables.
- Regenerated the runtime roster dataset from the 9.0 database dump. The new Undead Legions
  subculture (`wh3_dlc29_sc_nag_undead_legions`) resolves its own military group, so Nagash
  spawns armies mixing Tomb Kings, Vampire Counts, Vampire Coast and DLC29-exclusive units
  (Morghast Archai/Harbingers, Khemric Titan, Lahmian Handmaidens, Spirit Host, Coven Throne).
  All 53 military groups validate with no failures.
- Added a fallback army template and an Anarchy Kill rebel mapping for the Undead Legions subculture.
- Fixed faction capital capture: the dump helper recorded the faction leader's current position
  instead of the faction capital, which was wrong for any leader standing outside its own
  settlement. It now reads `faction:home_region()` first and tags every entry that falls back to
  leader position or owned-region order.
- Corrected 95 capitals in the vanilla Immortal Empires table and 86 in the IE Extended tables as a
  result, including Kislev (`zavastra` -> `kislev`), Naggarond (`har_kaldra` -> `naggarond`),
  Clan Skryre (`tobaro` -> `skavenblight`), Bretonnia (`languille` -> `couronne`),
  Middenland (`carroburg` -> `middenheim`) and Neferata (`blasted_expanse` -> `silver_pinnacle`).
  Regions claimed by more than one faction dropped from 48 to 15, all of them hordes camped on
  another faction's territory.
- Script-owned factions are now filtered out of the MCT dropdowns: vassal owners, confederation
  owners, separatists, summoned pools, quest-battle factions and the 206 `mixer_*` factions
  added in 9.0.
- IE Extended campaigns now read the generated IEE capital table instead of the inline copy in the
  campaign script, so the dropdown and the revive logic can no longer disagree. The inline table
  remains as a fallback.
- Campaign start-up logs now name the capital table in use (vanilla or IE Extended) instead of
  reporting "default".
- Renamed `deprecated_army_templates.lua` to `fallback_army_templates.lua`: the file is still on
  the live fallback path, the old name suggested it was dead code.
- Fixed the vanilla Immortal Empires capital table never loading. The file carried a UTF-8 BOM,
  which the game's Lua loader rejects (`unexpected symbol near '<BOM>'`), so the table had been
  silently absent since v1.1.0: vanilla IE campaigns fell back to the inline IE Extended table and
  the MCT dropdowns were built from the 107-entry hardcoded list instead of the 297-entry table.
- Updated MCT and campaign log version labels to `v1.5.0`.

## v1.4.1

- Rebuilt pack for compatibility with the latest Total War: Warhammer 3 game update. No functional changes.
- Updated MCT and campaign log version labels to `v1.4.1`.

## v1.4.0

- Added Nemesis feature: select a persistent faction to keep competitive throughout the campaign.
  - Initial activation (on selection): revives if dead, unlocks all technologies, gives 50k gold, spawns 5 armies.
  - Periodic boost every 10 turns: revives if dead; if not in top 10 factions by territory, gives 50k gold and spawns 5 armies.
  - Periodic confederation every 25 turns: confederates the largest same-subculture AI faction into the nemesis.
  - War declaration if at peace: on selection and every 10 turns, declares war on the weakest (fewest regions) adjacent faction with diplomatic attitude ≤ -50 towards the nemesis.
  - MCT info display shows nemesis territory count and rank, updated every turn.
  - Nemesis persists across save/reload via `cm:set_saved_value`; MCT dropdown synced on restore.
  - Nemesis starts as None on new campaigns (MCT registry not used as fallback).
- Fixed revive and capital lookup issues for Skeggi, Aislinn, Noctilus, and Caledor factions.
- Fixed capital lookup issue for the Skaeling faction.

## v1.3.0

- Added "Confederate All Same Subculture" buff option: forces all living AI factions of the same subculture to confederate into the selected faction.
- Added "Confederate Specific Faction" buff option: force-absorbs any single specific AI faction into the selected faction regardless of subculture.
- Added Confederate result feedback text field in MCT showing OK or KO after confederation attempt.

## v1.2.0

- Reviving a confederated faction now runs an experimental dummy-confederation workaround instead of hard-blocking: after the normal revive, the faction spawns and immediately confederates a temporary dead AI faction, then the inherited dummy army is killed.
- Removed the `is_dead()` early-return guard from `kill_faction` so it can clean up confederation-dead factions that still have regions or characters.

## v1.1.0

- Added campaign-aware capital table selection using `cm:get_campaign_name()`.
- Added a dedicated `cr_oldworld` faction-to-start-region table generated from the in-game dump.
- Added a dedicated `cr_oldworldclassic` faction-to-start-region table generated from the in-game dump.
- Added a dedicated `main_warhammer` vanilla faction-to-start-region table generated from the in-game dump.
- Added `main_warhammer` vanilla vs `IEE` runtime detection using Extended-only sentinels, because both campaigns share the same campaign key.
- `main_warhammer` now uses the IEE table when Extended content is present, otherwise it falls back to the vanilla table.
- Revive and boost capital lookups now use the active campaign table instead of assuming Immortal Empires keys.
- Added `The Old World` MCT faction list support by building the dropdown from the dedicated `cr_oldworld` capital table.
- Added `The Old World Classic` MCT faction list support by building the dropdown from the dedicated `cr_oldworldclassic` capital table.
- Added `main_warhammer` MCT campaign-variant detection so vanilla and IEE use different dropdown sources.
- MCT faction dropdowns now prefer localized faction names instead of mixed hardcoded labels.
- Updated MCT and campaign log version labels to `v1.1.0`.

## v1.0.4

- Added Tiger Warriors (`wh3_cp1_cth_tiger_warriors`) faction from patch 8.0 / Bhashiva Content Pack — starts at `vale_of_titans`.
- Added Aislinn (`wh3_dlc27_hef_aislinn`) High Elf faction missing from DLC27 — treated as regionless revive (no region ownership, army spawned near anchor).
- Fixed Blood Guzzlers starting region: `fire_mouth` → `vale_of_titans` following patch 8.0 Cathay rework repositioning.
- Updated MCT and campaign log version labels to `v1.0.4`.

## v1.0.3

- Anarchy Kill now uses `wh2_main_def_hag_graef_separatists` as the universal rebel sink, which is reliably registered in Immortal Empires campaigns.
- Fixed Anarchy Kill sink faction detection: dead/inactive rebel factions (is_null_interface) are now accepted as valid transfer targets.
- Anarchy Kill now downgrades all transferred regions to settlement level 2 after the transfer.
- Anarchy Kill sink lock now applies permanent growth, income, and construction cost penalties using existing game effect bundles (no DB modifications).
- Hidden the Validation Test MCT button before public release (code preserved, button commented out).
- Fixed pack build to always source scripts from `WH3-Dump-Fork/` to avoid packaging stale copies.
- Fixed kill and Anarchy Kill for factions with hidden/foreign-slot settlements, including the Changeling, by removing their foreign slots before killing characters.
- Fixed revive handling for regionless factions, including Nakai and the Changeling, by spawning armies around an anchor region without forcing province ownership or settlement upgrades.
- Filtered Extended-only factions out of the MCT faction list unless those faction keys exist in the active campaign.
- Updated MCT and campaign log version labels to `v1.0.3`.

## v1.0.2

- Fixed Tomb Kings runtime army generation for Khemri and Arkhan-related Tomb Kings rosters.
- Added the missing generic Tomb King lord (`wh2_dlc09_tmb_cha_tomb_king_0`) to the Tomb Kings runtime roster supplements.
- Khemri should now use the runtime generator path with `create_force_with_general` instead of falling back to the deprecated subculture template.
- Fixed Vampire Coast runtime army generation for Noctilus and Sartosa military groups.
- Added missing generic Vampire Fleet Admiral lord units to the Vampire Coast runtime roster supplements.
- Fixed additional runtime roster gaps for Lizardmen, Leaf-Cutterz, Savage Orcs, Prologue Kislev, and TEB.
- Added a validation mode to the runtime army preview script and verified all 48 generated military groups can produce complete armies.
- Fixed Anarchy Kill fallback behavior when CA's generic rebel faction key is not available in the active campaign.
- Anarchy Kill now tries explicit rebel/invasion candidates and then scans same-subculture rebel/separatist/invasion factions before falling back to ruins.
- Anarchy Kill now rejects rebel candidates that already have regions or armies on the campaign map.
- Anarchy Kill now forces transferred rebel factions into war with every active faction so they can be cleared and resettled naturally.
- Fixed Vampire Counts MCT labels: The Barrow Legion is Heinrich Kemmler, and Caravan of Blue Roses is Helman Ghorst.
- Updated MCT and campaign log version labels to `v1.0.2`.

## v1.0.1

- Added visible version information to the MCT interface.
- MCT title now displays `Revive Boring Campaign v1.0.1`.
- MCT description now starts with `Version: 1.0.1`.
- MCT internal `mod:set_version()` and MCT log prefix now use the shared `mod_version` value.
- Added Anarchy Kill / Eshin-style kill option in MCT.
- Anarchy Kill destroys the selected faction and transfers its regions to same-subculture rebel factions when available.
- If no usable rebel faction exists, Anarchy Kill falls back to abandoning the target regions.

## v1.0.0

- Initial playable version of Revive Boring Campaign.
- Added MCT interface with Kill, Revive, Buff, and Debuff sections.
- Added faction dropdowns for supported major/playable factions.
- Added Kill Faction action to destroy selected AI factions.
- Added Revive Faction action with region transfer, province capital upgrade, army spawning, and temporary free upkeep support.
- Added Buff Faction options: unlock technologies, apply free upkeep support, give gold, and spawn five armies.
- Added Debuff Faction options: drain treasury and kill all armies.
- Added runtime roster army generation backed by generated WH3 roster data.
- Added deprecated hardcoded army templates as fallback when runtime roster generation cannot resolve a faction.
- Added automatic reset for MCT execution checkboxes after actions run.
