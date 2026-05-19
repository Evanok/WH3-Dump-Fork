--[[-------------------------------------------------------------------------------------------------------------
    Revive Boring Campaign - MCT Settings

    Defines the Mod Configuration Tool interface for the mod.
    Requires MCT v0.9 Beta or later.

    Author: Created with Claude AI assistance
]]---------------------------------------------------------------------------------------------------------------

local mct = get_mct()
local mod_version = "1.0.3"
local rbc_mct_log_prefix = "[RBC_DEBUG][mct][v" .. mod_version .. "]"

local function rbc_mct_log(message)
    local msg = rbc_mct_log_prefix .. " " .. tostring(message)
    if ModLog then
        ModLog(msg)
    end
    out(msg)
end

if not mct then
    rbc_mct_log("MCT not found, skipping UI setup")
    return
end

local mod = mct:register_mod("revive_boring_campaign")

local checkbox_option_keys = {
    "kill_execute",
    "anarchy_kill_execute",
    "validation_test_execute",
    "revive_execute",
    "boost_unlock_tech",
    "boost_free_upkeep",
    "boost_give_gold",
    "boost_spawn_armies",
    "boost_execute",
    "nerf_drain_treasury",
    "nerf_kill_armies",
    "nerf_execute"
}

local function force_all_checkboxes_false()
    local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
    if not mct_mod then
        return
    end

    for i = 1, #checkbox_option_keys do
        local option = mct_mod:get_option_by_key(checkbox_option_keys[i])
        if option then
            option:set_selected_setting(false)
            if option.set_finalized_setting then
                option:set_finalized_setting(false)
            end
        end
    end
end

mod:set_author("Evanok")
mod:set_title("Revive Boring Campaign v" .. mod_version)
mod:set_description("Version: " .. mod_version .. "\n\n" ..
    "Kill, revive, buff or debuff factions to make your campaign more interesting!\n\n" ..
    "Features:\n" ..
    "- Kill Faction: Destroy the faction leader\n" ..
    "- Anarchy Kill: Destroy a faction and hand its regions to same-culture rebels\n" ..
    "- Revive Faction: Bring back a dead faction with armies\n" ..
    "- Buff Faction: Unlock techs, free upkeep, gold, spawn armies\n" ..
    "- Debuff Faction: Drain treasury, morale penalty, kill armies\n\n" ..
    "Instructions:\n" ..
    "1. Select a faction from the dropdown\n" ..
    "2. Check the options you want\n" ..
    "3. Check Apply to execute (all checkboxes will reset)")

if mct.get_version and (mct:get_version() == "0.9-beta" or mct:get_version() == "0.9") then
    mod:set_workshop_id("0000000000") -- Update when published
    mod:set_version(mod_version)
end

--[[-------------------------------------------------------------------------------------------------------------
    Build faction list for dropdowns

    We build two lists:
    1. All factions (for Kill)
    2. Dead factions only (for Revive)
]]---------------------------------------------------------------------------------------------------------------

-- Store faction data for dynamic updates
local all_factions_data = {}
local dead_factions_data = {}

-- Function to refresh faction lists (called when game state might have changed)
local function refresh_faction_lists()
    all_factions_data = {}
    dead_factions_data = {}

    -- Only populate if we're in campaign
    if not cm or not cm:get_campaign_name() then
        return
    end

    local faction_list = cm:model():world():faction_list()

    for i = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(i)
        if faction and not faction:is_null_interface() then
            local faction_key = faction:name()

            -- Skip rebel factions and special factions
            if not string.find(faction_key, "rebel") and
               not string.find(faction_key, "qb_") and
               not string.find(faction_key, "wh3_main_rogue") then

                -- All factions (except player)
                if not faction:is_human() then
                    table.insert(all_factions_data, {
                        key = faction_key,
                        is_dead = faction:is_dead()
                    })

                    -- Dead factions only
                    if faction:is_dead() then
                        table.insert(dead_factions_data, faction_key)
                    end
                end
            end
        end
    end

    -- Sort alphabetically
    table.sort(all_factions_data, function(a, b) return a.key < b.key end)
    table.sort(dead_factions_data)
end

--[[-------------------------------------------------------------------------------------------------------------
    SECTION: Kill Faction
]]---------------------------------------------------------------------------------------------------------------

local kill_section = mod:add_new_section("kill_faction_section", "Kill Faction")
if mct.get_version and (mct:get_version() == "0.9-beta" or mct:get_version() == "0.9") then
    kill_section:set_is_collapsible(true)
    kill_section:set_visibility(true)
end

-- Dropdown to select faction to kill
local kill_faction_dropdown = mod:add_new_option("kill_faction_select", "dropdown")
kill_faction_dropdown:set_text("Select Faction to Kill")
kill_faction_dropdown:set_tooltip_text("Choose which faction you want to destroy. All their settlements will become ruins.")

-- Add ALL playable factions as dropdown values
-- This list will show even if not in campaign
local major_factions = {
    -- Daemons
    {"wh3_main_dae_daemon_prince", "Daemon Prince"},

    -- Khorne
    {"wh3_main_kho_exiles_of_khorne", "Exiles of Khorne (Skarbrand)"},
    {"wh3_dlc26_kho_skulltaker", "Skulltaker"},
    {"wh3_dlc26_kho_arbaal", "Arbaal"},

    -- Nurgle
    {"wh3_main_nur_poxmakers_of_nurgle", "Poxmakers (Ku'gath)"},
    {"wh3_dlc25_nur_tamurkhan", "Tamurkhan"},
    {"wh3_dlc25_nur_epidemius", "Epidemius"},

    -- Slaanesh
    {"wh3_main_sla_seducers_of_slaanesh", "Seducers (N'Kari)"},
    {"wh3_dlc27_sla_masque_of_slaanesh", "The Masque"},
    {"wh3_dlc27_sla_the_tormentors", "The Tormentors"},

    -- Tzeentch
    {"wh3_main_tze_oracles_of_tzeentch", "Oracles (Kairos)"},
    {"wh3_dlc24_tze_the_deceivers", "The Changeling"},
    {"wh3_main_tze_sarthoraels_watchers", "Sarthorael"},

    -- Warriors of Chaos
    {"wh_main_chs_chaos", "Chaos (Archaon)"},
    {"wh3_dlc20_chs_kholek", "Kholek Suneater"},
    {"wh3_dlc20_chs_sigvald", "Sigvald"},
    {"wh3_dlc20_chs_azazel", "Azazel"},
    {"wh3_dlc20_chs_festus", "Festus"},
    {"wh3_dlc20_chs_valkia", "Valkia"},
    {"wh3_dlc20_chs_vilitch", "Vilitch"},
    {"wh3_main_chs_shadow_legion", "Be'lakor"},

    -- Kislev
    {"wh3_main_ksl_the_ice_court", "Ice Court (Katarin)"},
    {"wh3_main_ksl_the_great_orthodoxy", "Orthodoxy (Kostaltyn)"},
    {"wh3_main_ksl_ursun_revivalists", "Ursun Revivalists (Boris)"},
    {"wh3_dlc24_ksl_daughters_of_the_forest", "Mother Ostankya"},

    -- Cathay
    {"wh3_main_cth_the_northern_provinces", "Northern Provinces (Miao Ying)"},
    {"wh3_main_cth_the_western_provinces", "Western Provinces (Zhao Ming)"},
    {"wh3_dlc24_cth_the_celestial_court", "Yuan Bo"},

    -- Ogre Kingdoms
    {"wh3_main_ogr_goldtooth", "Goldtooth (Greasus)"},
    {"wh3_main_ogr_disciples_of_the_maw", "Disciples (Skrag)"},
    {"wh3_dlc26_ogr_golgfag", "Golgfag"},

    -- Chaos Dwarfs
    {"wh3_dlc23_chd_astragoth", "Astragoth"},
    {"wh3_dlc23_chd_legion_of_azgorh", "Drazhoath"},
    {"wh3_dlc23_chd_zhatan", "Zhatan"},

    -- Empire
    {"wh_main_emp_empire", "Reikland (Karl Franz)"},
    {"wh_main_emp_wissenland", "Wissenland & Nuln (Elspeth)"},
    {"wh_main_emp_averland", "Averland"},
    {"wh_main_emp_middenland", "Middenland (Boris Todbringer)"},
    {"wh2_dlc13_emp_the_huntmarshals_expedition", "Markus Wulfhart"},
    {"wh2_dlc13_emp_golden_order", "Golden Order (Gelt)"},
    {"wh3_main_emp_cult_of_sigmar", "Volkmar"},

    -- Dwarfs
    {"wh_main_dwf_dwarfs", "Karaz-a-Karak (Thorgrim)"},
    {"wh_main_dwf_karak_kadrin", "Karak Kadrin (Ungrim)"},
    {"wh_main_dwf_karak_izor", "Belegar"},
    {"wh2_dlc17_dwf_thorek_ironbrow", "Thorek Ironbrow"},
    {"wh3_dlc25_dwf_malakai", "Malakai Makaisson"},
    {"wh3_main_dwf_the_ancestral_throng", "Grombrindal"},

    -- Greenskins
    {"wh_main_grn_greenskins", "Greenskins (Grimgor)"},
    {"wh_main_grn_crooked_moon", "Crooked Moon (Skarsnik)"},
    {"wh2_dlc15_grn_bonerattlaz", "Wurrzag"},
    {"wh_main_grn_orcs_of_the_bloody_hand", "Azhag"},
    {"wh2_dlc15_grn_broken_axe", "Grom the Paunch"},
    {"wh3_dlc26_grn_gorbad_ironclaw", "Gorbad Ironclaw"},

    -- Vampire Counts
    {"wh_main_vmp_vampire_counts", "Vampire Counts (Mannfred)"},
    {"wh_main_vmp_schwartzhafen", "Vlad von Carstein"},
    {"wh2_dlc11_vmp_the_barrow_legion", "The Barrow Legion (Heinrich Kemmler)"},
    {"wh3_main_vmp_caravan_of_blue_roses", "Caravan of Blue Roses (Helman Ghorst)"},

    -- High Elves
    {"wh2_main_hef_eataine", "Eataine (Tyrion)"},
    {"wh2_main_hef_nagarythe", "Nagarythe (Alith Anar)"},
    {"wh2_main_hef_avelorn", "Avelorn (Alarielle)"},
    {"wh2_main_hef_yvresse", "Yvresse (Eltharion)"},
    {"wh2_main_hef_order_of_loremasters", "Teclis"},
    {"wh2_dlc15_hef_imrik", "Imrik"},

    -- Dark Elves
    {"wh2_main_def_naggarond", "Naggarond (Malekith)"},
    {"wh2_main_def_cult_of_pleasure", "Cult of Pleasure (Morathi)"},
    {"wh2_main_def_har_ganeth", "Har Ganeth (Hellebron)"},
    {"wh2_main_def_hag_graef", "Hag Graef (Malus)"},
    {"wh2_dlc11_def_the_blessed_dread", "Lokhir Fellheart"},
    {"wh2_twa03_def_rakarth", "Rakarth"},

    -- Lizardmen
    {"wh2_main_lzd_hexoatl", "Hexoatl (Mazdamundi)"},
    {"wh2_main_lzd_last_defenders", "Last Defenders (Kroq-Gar)"},
    {"wh2_main_lzd_itza", "Itza (Gor-Rok)"},
    {"wh2_main_lzd_tlaqua", "Tlaqua (Tiktaq'to)"},
    {"wh2_dlc12_lzd_cult_of_sotek", "Cult of Sotek (Tehenhauin)"},
    {"wh2_dlc13_lzd_spirits_of_the_jungle", "Nakai"},
    {"wh2_dlc17_lzd_oxyotl", "Oxyotl"},

    -- Skaven
    {"wh2_main_skv_clan_mors", "Clan Mors (Queek)"},
    {"wh2_main_skv_clan_skryre", "Clan Skryre (Ikit Claw)"},
    {"wh2_main_skv_clan_pestilens", "Clan Pestilens (Skrolk)"},
    {"wh2_main_skv_clan_moulder", "Clan Moulder (Throt)"},
    {"wh2_main_skv_clan_eshin", "Clan Eshin (Snikch)"},
    {"wh2_dlc09_skv_clan_rictus", "Clan Rictus (Tretch)"},

    -- Tomb Kings
    {"wh2_dlc09_tmb_khemri", "Khemri (Settra)"},
    {"wh2_dlc09_tmb_lybaras", "Lybaras (Khalida)"},
    {"wh2_dlc09_tmb_exiles_of_nehek", "Exiles of Nehek (Khatep)"},
    {"wh2_dlc09_tmb_followers_of_nagash", "Followers of Nagash (Arkhan)"},

    -- Vampire Coast
    {"wh2_dlc11_cst_vampire_coast", "Vampire Coast (Harkon)"},
    {"wh2_dlc11_cst_noctilus", "Noctilus"},
    {"wh2_dlc11_cst_the_drowned", "The Drowned (Cylostra)"},
    {"wh2_dlc11_cst_pirates_of_sartosa", "Aranessa Saltspite"},

    -- Bretonnia
    {"wh_main_brt_bretonnia", "Bretonnia (Louen)"},
    {"wh_main_brt_carcassonne", "Carcassonne (Fay Enchantress)"},
    {"wh_main_brt_bordeleaux", "Bordeleaux (Alberic)"},
    {"wh2_dlc14_brt_chevaliers_de_lyonesse", "Repanse de Lyonesse"},

    -- Norsca
    {"wh_dlc08_nor_norsca", "Norsca (Wulfrik)"},
    {"wh_dlc08_nor_wintertooth", "Wintertooth (Throgg)"},
    {"wh3_dlc27_nor_sayl", "Sayl the Faithless"},

    -- Wood Elves
    {"wh_dlc05_wef_wood_elves", "Wood Elves (Orion)"},
    {"wh_dlc05_wef_argwylon", "Argwylon (Durthu)"},
    {"wh2_dlc16_wef_sisters_of_twilight", "Sisters of Twilight"},
    {"wh2_dlc16_wef_drycha", "Drycha"},

    -- Beastmen
    {"wh_dlc03_bst_beastmen", "Beastmen (Khazrak)"},
    {"wh_dlc05_bst_morghur_herd", "Morghur"},
    {"wh2_dlc17_bst_malagor", "Malagor"},
    {"wh2_dlc17_bst_taurox", "Taurox"},
}

local extended_major_factions = {
    {"cr_kho_servants_of_the_blood_nagas", "Servants of the Blood Nagas"},
    {"cr_nur_tide_of_pestilence", "Tide of Pestilence"},
    {"cr_sla_loeshs_indulgence", "Loesh's Indulgence"},
    {"cr_tze_cult_of_tsien_tsin", "Cult of Tsien-Tsin"},
    {"cr_tze_sliding_terror", "Sliding Terror"},
    {"cr_ksl_rota_of_the_dawn", "Rota of the Dawn"},
    {"cr_ogr_deathtoll", "Deathtoll"},
    {"cr_ogr_snakebiter_tribe", "Snakebiter Tribe"},
    {"cr_ogr_suneaters", "Suneaters"},
    {"cr_ogr_shellcrackers", "Shellcrackers"},
    {"cr_cth_okumoto_clan", "Okumoto Clan"},
    {"cr_cth_sanyo_clan", "Sanyo Clan"},
    {"cr_cth_the_chosen", "The Chosen"},
    {"cr_cth_agents_of_the_moon", "Agents of the Moon"},
    {"cr_hef_gate_guards", "Gate Guards"},
    {"cr_hef_tor_elithis", "Tor Elithis"},
    {"cr_hef_the_starguided", "The Starguided"},
    {"cr_lzd_scions_of_xholankhas", "Scions of Xholankha"},
    {"cr_lzd_one_hundred_thousand", "One Hundred Thousand"},
    {"cr_def_corsairs_of_spite", "Corsairs of Spite"},
    {"cr_def_harbingers_of_pain", "Harbingers of Pain"},
    {"cr_def_cult_of_anath_raema", "Cult of Anath Raema"},
    {"cr_skv_eshin_clan_nest", "Eshin Clan Nest"},
    {"cr_skv_clan_rikek", "Clan Rikek"},
    {"cr_skv_clan_festerlingus", "Clan Festerlingus"},
    {"cr_skv_clan_crooktail", "Clan Crooktail"},
    {"cr_tmb_sons_of_ptra", "Sons of Ptra"},
    {"cr_cst_rotten_knot", "Rotten Knot"},
    {"cr_emp_guests_of_the_raja", "Guests of the Raja"},
    {"cr_dwf_firebeards_excavators", "Firebeards Excavators"},
    {"cr_grn_speaking_trees", "Speaking Trees"},
    {"cr_grn_nag_rippers", "Nag Rippers"},
    {"cr_grn_grag_a_mugar_clan", "Grag A Mugar Clan"},
    {"cr_grn_blackwolf_clan", "Blackwolf Clan"},
    {"cr_grn_withered_eye_tribe", "Withered Eye Tribe"},
    {"rhox_vmp_the_everliving", "The Everliving"},
    {"cr_chs_po_hai", "Po Hai"},
    {"cr_chs_the_scourgeborn", "The Scourgeborn"},
    {"cr_chs_tsavags", "Tsavags"},
    {"rhox_chs_the_deathswords", "The Deathswords"},
    {"cr_chs_iron_wolves", "Iron Wolves"},
    {"cr_chs_death_eaters", "Death Eaters"},
    {"cr_bst_apehorn", "Apehorn"},
    {"cr_bst_warherd_of_kug", "Warherd of Kug"},
    {"cr_bst_orobagor_warherd", "Orobagor Warherd"},
    {"cr_bst_skullfest_warherd", "Skullfest Warherd"},
    {"cr_wef_lotus_flower", "Lotus Flower"},
    {"rhox_wef_far_away_forest", "Far Away Forest"},
    {"cr_brt_leofrics_fellowship", "Leofric's Fellowship"},
    {"rhox_brt_reveller_of_domance", "Reveller of Domance"},
    {"cr_chd_slaves_of_the_black_dwarf", "Slaves of the Black Dwarf"},
    {"cr_chd_skullstack", "Skullstack"},
    {"cr_nor_tokmars", "Tokmars"},
    {"rhox_nor_khazags", "Khazags"},
    {"cr_nor_wei_tu", "Wei Tu"},
    {"cr_nor_stormravens", "Stormravens"},
    {"rhox_nor_ravenblessed", "Ravenblessed"},
}

local function faction_exists_in_campaign(faction_key)
    if not cm or not cm.get_faction then
        return false
    end

    local ok, faction = pcall(function()
        return cm:get_faction(faction_key)
    end)

    return ok and faction and not faction:is_null_interface()
end

local function build_available_major_factions()
    local available_factions = {}

    for _, faction_data in ipairs(major_factions) do
        table.insert(available_factions, faction_data)
    end

    local extended_added = 0
    for _, faction_data in ipairs(extended_major_factions) do
        if faction_exists_in_campaign(faction_data[1]) then
            table.insert(available_factions, faction_data)
            extended_added = extended_added + 1
        end
    end

    rbc_mct_log("Faction dropdown list built: vanilla=" .. #major_factions .. ", extended=" .. extended_added)

    return available_factions
end

local available_major_factions = build_available_major_factions()

-- Add dropdown values
kill_faction_dropdown:add_dropdown_value("", "-- Select Faction --", "Select a faction from the list")
for _, faction_data in ipairs(available_major_factions) do
    kill_faction_dropdown:add_dropdown_value(faction_data[1], faction_data[2], "Kill " .. faction_data[2])
end

-- Checkbox to execute kill
local kill_execute = mod:add_new_option("kill_execute", "checkbox")
kill_execute:set_text("Kill")
kill_execute:set_tooltip_text("Check this box to kill the selected faction. All their settlements will become ruins. The checkbox will reset after execution.")
kill_execute:set_default_value(false)

-- Checkbox to execute anarchy kill
local anarchy_kill_execute = mod:add_new_option("anarchy_kill_execute", "checkbox")
anarchy_kill_execute:set_text("Anarchy Kill")
anarchy_kill_execute:set_tooltip_text("Check this box to destroy the selected faction and transfer its settlements to matching rebel factions instead of ruins. The checkbox will reset after execution.")
anarchy_kill_execute:set_default_value(false)

-- HIDDEN before release: uncomment to re-enable the Validation Test button
-- local validation_test_execute = mod:add_new_option("validation_test_execute", "checkbox")
-- validation_test_execute:set_text("Validation Test")
-- validation_test_execute:set_tooltip_text("Destructive test mode. Runs Kill, Revive, then Anarchy Kill for every faction in this dropdown using the real feature code.")
-- validation_test_execute:set_default_value(false)

--[[-------------------------------------------------------------------------------------------------------------
    SECTION: Revive Faction
]]---------------------------------------------------------------------------------------------------------------

local revive_section = mod:add_new_section("revive_faction_section", "Revive Faction")
if mct.get_version and (mct:get_version() == "0.9-beta" or mct:get_version() == "0.9") then
    revive_section:set_is_collapsible(true)
    revive_section:set_visibility(true)
end

-- Dropdown to select faction to revive
local revive_faction_dropdown = mod:add_new_option("revive_faction_select", "dropdown")
revive_faction_dropdown:set_text("Select Faction to Revive")
revive_faction_dropdown:set_tooltip_text("Choose which faction you want to bring back to life. They will receive their capital and 5 armies.")

-- Use same faction list (will only work on dead factions in practice)
revive_faction_dropdown:add_dropdown_value("", "-- Select Faction --", "Select a dead faction to revive")
for _, faction_data in ipairs(available_major_factions) do
    revive_faction_dropdown:add_dropdown_value(faction_data[1], faction_data[2], "Revive " .. faction_data[2])
end

-- Checkbox to execute revive
local revive_execute = mod:add_new_option("revive_execute", "checkbox")
revive_execute:set_text("Revive")
revive_execute:set_tooltip_text("Check this box to revive the selected faction. They will get their capital (or an abandoned region) and 5 armies. The checkbox will reset after execution.")
revive_execute:set_default_value(false)

--[[-------------------------------------------------------------------------------------------------------------
    SECTION: Boost Faction
]]---------------------------------------------------------------------------------------------------------------

local boost_section = mod:add_new_section("boost_faction_section", "Buff Faction")
if mct.get_version and (mct:get_version() == "0.9-beta" or mct:get_version() == "0.9") then
    boost_section:set_is_collapsible(true)
    boost_section:set_visibility(true)
end

-- Dropdown to select faction to boost
local boost_faction_dropdown = mod:add_new_option("boost_faction_select", "dropdown")
boost_faction_dropdown:set_text("Select Faction")
boost_faction_dropdown:set_tooltip_text("Choose which faction you want to buff.")

-- Use same faction list
boost_faction_dropdown:add_dropdown_value("", "-- Select Faction --", "Select a faction")
for _, faction_data in ipairs(available_major_factions) do
    boost_faction_dropdown:add_dropdown_value(faction_data[1], faction_data[2], faction_data[2])
end

-- Option checkboxes
local boost_unlock_tech = mod:add_new_option("boost_unlock_tech", "checkbox")
boost_unlock_tech:set_text("Unlock All Technologies")
boost_unlock_tech:set_tooltip_text("Instantly unlock all technologies for this faction.")
boost_unlock_tech:set_default_value(false)

local boost_free_upkeep = mod:add_new_option("boost_free_upkeep", "checkbox")
boost_free_upkeep:set_text("Free Upkeep (25 turns)")
boost_free_upkeep:set_tooltip_text("All armies get free upkeep for 25 turns.")
boost_free_upkeep:set_default_value(false)

local boost_give_gold = mod:add_new_option("boost_give_gold", "checkbox")
boost_give_gold:set_text("Give 50,000 Gold")
boost_give_gold:set_tooltip_text("Add 50,000 gold to faction treasury.")
boost_give_gold:set_default_value(false)

local boost_spawn_armies = mod:add_new_option("boost_spawn_armies", "checkbox")
boost_spawn_armies:set_text("Spawn 5 Armies")
boost_spawn_armies:set_tooltip_text("Spawn 5 full armies at the faction's capital.")
boost_spawn_armies:set_default_value(false)

-- Checkbox to execute boost
local boost_execute = mod:add_new_option("boost_execute", "checkbox")
boost_execute:set_text("Execute Buff")
boost_execute:set_tooltip_text("Check this box to apply the selected buffs to the faction.")
boost_execute:set_default_value(false)

--[[-------------------------------------------------------------------------------------------------------------
    SECTION: Nerf Faction
]]---------------------------------------------------------------------------------------------------------------

local nerf_section = mod:add_new_section("nerf_faction_section", "Debuff Faction")
if mct.get_version and (mct:get_version() == "0.9-beta" or mct:get_version() == "0.9") then
    nerf_section:set_is_collapsible(true)
    nerf_section:set_visibility(true)
end

-- Dropdown to select faction to nerf
local nerf_faction_dropdown = mod:add_new_option("nerf_faction_select", "dropdown")
nerf_faction_dropdown:set_text("Select Faction")
nerf_faction_dropdown:set_tooltip_text("Choose which faction you want to debuff.")

-- Use same faction list
nerf_faction_dropdown:add_dropdown_value("", "-- Select Faction --", "Select a faction")
for _, faction_data in ipairs(available_major_factions) do
    nerf_faction_dropdown:add_dropdown_value(faction_data[1], faction_data[2], faction_data[2])
end

-- Option checkboxes
local nerf_drain_treasury = mod:add_new_option("nerf_drain_treasury", "checkbox")
nerf_drain_treasury:set_text("Drain 50% Treasury")
nerf_drain_treasury:set_tooltip_text("Remove half of the faction's gold.")
nerf_drain_treasury:set_default_value(false)

local nerf_kill_armies = mod:add_new_option("nerf_kill_armies", "checkbox")
nerf_kill_armies:set_text("Kill All Armies")
nerf_kill_armies:set_tooltip_text("Destroy all armies of the faction.")
nerf_kill_armies:set_default_value(false)

-- Checkbox to execute nerf
local nerf_execute = mod:add_new_option("nerf_execute", "checkbox")
nerf_execute:set_text("Execute Debuff")
nerf_execute:set_tooltip_text("Check this box to apply the selected debuffs to the faction.")
nerf_execute:set_default_value(false)

force_all_checkboxes_false()

--[[-------------------------------------------------------------------------------------------------------------
    LISTENERS - Execute actions when checkboxes are checked
]]---------------------------------------------------------------------------------------------------------------

-- Wait for campaign to be loaded
core:add_listener(
    "ReviveBoringCampaign_MCT_Init",
    "MctInitialized",
    true,
    function(context)
        rbc_mct_log("MCT Initialized")
        force_all_checkboxes_false()

        -- Listener for Kill execution
        core:add_listener(
            "ReviveBoringCampaign_Kill_Execute",
            "MctOptionSelectedSettingSet",
            function(context)
                return context:option():get_key() == "kill_execute"
            end,
            function(context)
                local value = context:option():get_selected_setting()
                if value == true then
                    -- Get selected faction
                    local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                    local dropdown = mct_mod:get_option_by_key("kill_faction_select")
                    local faction_key = dropdown:get_selected_setting()

                    if faction_key and faction_key ~= "" then
                        rbc_mct_log("Executing kill on " .. faction_key)

                        -- Execute kill through main script
                        if revive_boring_campaign then
                            revive_boring_campaign:process_pending_kill(faction_key)
                        end
                    else
                        rbc_mct_log("No faction selected for kill")
                    end

                    -- Reset checkbox after a short delay
                    cm:callback(function()
                        context:option():set_selected_setting(false)
                    end, 1)
                end
            end,
            true
        )

        -- Listener for Anarchy Kill execution
        core:add_listener(
            "ReviveBoringCampaign_Anarchy_Kill_Execute",
            "MctOptionSelectedSettingSet",
            function(context)
                return context:option():get_key() == "anarchy_kill_execute"
            end,
            function(context)
                local value = context:option():get_selected_setting()
                if value == true then
                    local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                    local dropdown = mct_mod:get_option_by_key("kill_faction_select")
                    local faction_key = dropdown:get_selected_setting()

                    if faction_key and faction_key ~= "" then
                        rbc_mct_log("Executing anarchy kill on " .. faction_key)

                        if revive_boring_campaign then
                            revive_boring_campaign:process_pending_anarchy_kill(faction_key)
                        end
                    else
                        rbc_mct_log("No faction selected for anarchy kill")
                    end

                    cm:callback(function()
                        context:option():set_selected_setting(false)
                    end, 1)
                end
            end,
            true
        )

        core:add_listener(
            "ReviveBoringCampaign_Validation_Test_Execute",
            "MctOptionSelectedSettingSet",
            function(context)
                return context:option():get_key() == "validation_test_execute"
            end,
            function(context)
                local value = context:option():get_selected_setting()
                if value == true then
                    local faction_keys = {}
                    for _, faction_data in ipairs(available_major_factions) do
                        table.insert(faction_keys, faction_data[1])
                    end

                    rbc_mct_log("Executing validation test for " .. #faction_keys .. " factions")

                    if revive_boring_campaign then
                        revive_boring_campaign:process_pending_validation_test(faction_keys)
                    end

                    cm:callback(function()
                        context:option():set_selected_setting(false)
                    end, 1)
                end
            end,
            true
        )

        -- Listener for Revive execution
        core:add_listener(
            "ReviveBoringCampaign_Revive_Execute",
            "MctOptionSelectedSettingSet",
            function(context)
                return context:option():get_key() == "revive_execute"
            end,
            function(context)
                local value = context:option():get_selected_setting()
                if value == true then
                    -- Get selected faction
                    local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                    local dropdown = mct_mod:get_option_by_key("revive_faction_select")
                    local faction_key = dropdown:get_selected_setting()

                    if faction_key and faction_key ~= "" then
                        rbc_mct_log("Executing revive on " .. faction_key)

                        -- Execute revive through main script
                        if revive_boring_campaign then
                            revive_boring_campaign:process_pending_revive(faction_key)
                        end
                    else
                        rbc_mct_log("No faction selected for revive")
                    end

                    -- Reset checkbox after a short delay
                    cm:callback(function()
                        context:option():set_selected_setting(false)
                    end, 1)
                end
            end,
            true
        )

        -- Listener for Boost execution
        core:add_listener(
            "ReviveBoringCampaign_Boost_Execute",
            "MctOptionSelectedSettingSet",
            function(context)
                return context:option():get_key() == "boost_execute"
            end,
            function(context)
                local value = context:option():get_selected_setting()
                if value == true then
                    -- Get selected faction
                    local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                    local dropdown = mct_mod:get_option_by_key("boost_faction_select")
                    local faction_key = dropdown:get_selected_setting()

                    if faction_key and faction_key ~= "" then
                        -- Get all boost options
                        local unlock_tech = mct_mod:get_option_by_key("boost_unlock_tech"):get_selected_setting()
                        local free_upkeep = mct_mod:get_option_by_key("boost_free_upkeep"):get_selected_setting()
                        local give_gold = mct_mod:get_option_by_key("boost_give_gold"):get_selected_setting()
                        local spawn_armies = mct_mod:get_option_by_key("boost_spawn_armies"):get_selected_setting()

                        rbc_mct_log("Executing boost on " .. faction_key)

                        -- Execute boost through main script
                        if revive_boring_campaign then
                            revive_boring_campaign:process_pending_boost(faction_key, {
                                unlock_tech = unlock_tech,
                                free_upkeep = free_upkeep,
                                give_gold = give_gold,
                                spawn_armies = spawn_armies
                            })
                        end
                    else
                        rbc_mct_log("No faction selected for boost")
                    end

                    -- Reset ALL checkboxes after a short delay
                    cm:callback(function()
                        local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                        mct_mod:get_option_by_key("boost_execute"):set_selected_setting(false)
                        mct_mod:get_option_by_key("boost_unlock_tech"):set_selected_setting(false)
                        mct_mod:get_option_by_key("boost_free_upkeep"):set_selected_setting(false)
                        mct_mod:get_option_by_key("boost_give_gold"):set_selected_setting(false)
                        mct_mod:get_option_by_key("boost_spawn_armies"):set_selected_setting(false)
                    end, 1)
                end
            end,
            true
        )

        -- Listener for Nerf execution
        core:add_listener(
            "ReviveBoringCampaign_Nerf_Execute",
            "MctOptionSelectedSettingSet",
            function(context)
                return context:option():get_key() == "nerf_execute"
            end,
            function(context)
                local value = context:option():get_selected_setting()
                if value == true then
                    -- Get selected faction
                    local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                    local dropdown = mct_mod:get_option_by_key("nerf_faction_select")
                    local faction_key = dropdown:get_selected_setting()

                    if faction_key and faction_key ~= "" then
                        -- Get all nerf options
                        local drain_treasury = mct_mod:get_option_by_key("nerf_drain_treasury"):get_selected_setting()
                        local kill_armies = mct_mod:get_option_by_key("nerf_kill_armies"):get_selected_setting()

                        rbc_mct_log("Executing nerf on " .. faction_key)

                        -- Execute nerf through main script
                        if revive_boring_campaign then
                            revive_boring_campaign:process_pending_nerf(faction_key, {
                                drain_treasury = drain_treasury,
                                kill_armies = kill_armies
                            })
                        end
                    else
                        rbc_mct_log("No faction selected for nerf")
                    end

                    -- Reset ALL checkboxes after a short delay
                    cm:callback(function()
                        local mct_mod = mct:get_mod_by_key("revive_boring_campaign")
                        mct_mod:get_option_by_key("nerf_execute"):set_selected_setting(false)
                        mct_mod:get_option_by_key("nerf_drain_treasury"):set_selected_setting(false)
                        mct_mod:get_option_by_key("nerf_kill_armies"):set_selected_setting(false)
                    end, 1)
                end
            end,
            true
        )

        rbc_mct_log("Listeners registered")
    end,
    true
)

rbc_mct_log("Settings script loaded")
