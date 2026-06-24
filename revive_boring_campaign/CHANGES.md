# Changes

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
