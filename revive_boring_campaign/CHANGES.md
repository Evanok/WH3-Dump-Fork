# Changes

## v1.0.2 - In progress

- Fixed Tomb Kings runtime army generation for Khemri and Arkhan-related Tomb Kings rosters.
- Added the missing generic Tomb King lord (`wh2_dlc09_tmb_cha_tomb_king_0`) to the Tomb Kings runtime roster supplements.
- Khemri should now use the runtime generator path with `create_force_with_general` instead of falling back to the deprecated subculture template.
- Fixed Vampire Coast runtime army generation for Noctilus and Sartosa military groups.
- Added missing generic Vampire Fleet Admiral lord units to the Vampire Coast runtime roster supplements.
- Fixed Vampire Counts MCT labels: The Barrow Legion is Heinrich Kemmler, and Caravan of Blue Roses is Helman Ghorst.
- Updated campaign log prefix to `v1.0.1` to match the visible MCT version while this work is being validated.

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
