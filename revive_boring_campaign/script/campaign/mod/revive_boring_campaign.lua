--[[-------------------------------------------------------------------------------------------------------------
    Revive Boring Campaign - Main Script

    Allows players to kill or revive factions via MCT interface.
    Compatible with existing saves.

    Author: Created with Claude AI assistance
]]---------------------------------------------------------------------------------------------------------------

-- Module definition
revive_boring_campaign = {
    name = "revive_boring_campaign",
    log_prefix = "[RBC_DEBUG][campaign][v1.0.4]",

    -- State tracking (will be saved)
    settings = {
        pending_kill = nil,      -- Faction key to kill
        pending_revive = nil,    -- Faction key to revive
    },

    anarchy_rebel_sink_faction = "wh2_main_def_hag_graef_separatists",

    -- These factions should be revived around an anchor region without trying to own or upgrade it.
    -- Nakai uses a horde flow and the Changeling uses foreign slots/hidden settlements instead of normal ownership.
    regionless_revive_factions = {
        ["wh2_dlc13_lzd_spirits_of_the_jungle"] = true,
        ["wh3_dlc24_tze_the_deceivers"] = true,
        ["wh3_dlc27_hef_aislinn"] = true,
    },

    -- Preferred rebel factions per subculture for Anarchy Kill.
    -- Not every rebel key exists in every campaign, so Anarchy Kill also scans same-subculture candidates at runtime.
    rebel_factions_by_subculture = {
        ["wh_dlc03_sc_bst_beastmen"] = "wh_dlc03_bst_beastmen_rebels",
        ["wh_dlc05_sc_wef_wood_elves"] = "wh_dlc05_wef_wood_elves_rebels",
        ["wh_dlc08_sc_nor_norsca"] = "wh_main_nor_norsca_rebels",
        ["wh_main_sc_brt_bretonnia"] = "wh_main_brt_bretonnia_rebels",
        ["wh_main_sc_chs_chaos"] = "wh_main_chs_chaos_rebels",
        ["wh_main_sc_dwf_dwarfs"] = "wh_main_dwf_dwarf_rebels",
        ["wh_main_sc_emp_empire"] = "wh_main_emp_empire_rebels",
        ["wh_main_sc_grn_greenskins"] = "wh_main_grn_greenskins_rebels",
        ["wh_main_sc_vmp_vampire_counts"] = "wh_main_vmp_vampire_rebels",
        ["wh2_dlc09_sc_tmb_tomb_kings"] = "wh2_dlc09_tmb_tomb_kings_rebels",
        ["wh2_dlc11_sc_cst_vampire_coast"] = "wh2_dlc11_cst_vampire_coast_rebellion_rebels",
        ["wh2_main_sc_def_dark_elves"] = "wh2_main_def_dark_elves_rebels",
        ["wh2_main_sc_hef_high_elves"] = "wh2_main_hef_high_elves_rebels",
        ["wh2_main_sc_lzd_lizardmen"] = "wh2_main_lzd_lizardmen_rebels",
        ["wh2_main_sc_skv_skaven"] = "wh2_main_skv_skaven_rebels",
        ["wh3_dlc23_sc_chd_chaos_dwarfs"] = "wh3_dlc23_chd_chaos_dwarfs_rebels",
        ["wh3_main_sc_cth_cathay"] = "wh3_main_cth_cathay_rebels",
        ["wh3_main_sc_dae_daemons"] = "wh_main_chs_chaos_rebels",
        ["wh3_main_sc_kho_khorne"] = "wh3_main_kho_khorne_rebels",
        ["wh3_main_sc_ksl_kislev"] = "wh3_main_ksl_kislev_rebels",
        ["wh3_main_sc_nur_nurgle"] = "wh3_main_nur_nurgle_rebels",
        ["wh3_main_sc_ogr_ogre_kingdoms"] = "wh3_main_ogr_ogre_rebels",
        ["wh3_main_sc_sla_slaanesh"] = "wh3_main_sla_slaanesh_rebels",
        ["wh3_main_sc_tze_tzeentch"] = "wh3_main_tze_tzeentch_rebels",
    },

    anarchy_candidate_factions_by_subculture = {
        ["wh_main_sc_vmp_vampire_counts"] = {
            "wh3_dlc25_vmp_vampire_counts_invasion",
            "wh3_dlc21_vmp_jiangshi_rebels",
            "wh_main_vmp_waldenhof",
            "wh_main_vmp_rival_sylvanian_vamps",
        },
    },

    -- Faction to capital region mapping
    -- Works for both Vanilla Immortal Empires and IE Extended
    -- Vanilla IE regions: wh3_main_combi_region_* (284 factions)
    -- IE Extended adds: cr_combi_region_* regions (343 total)
    -- Note: Extended-only regions are validated at runtime - if not found,
    -- the mod falls back to finding abandoned or AI-owned regions
    faction_capitals = {
        -- DAEMON PRINCE
        ["wh3_main_dae_daemon_prince"] = "wh3_main_combi_region_volcanos_heart",

        -- KHORNE
        ["wh3_main_kho_exiles_of_khorne"] = "wh3_main_combi_region_agrul_migdhal",
        ["wh3_dlc26_kho_skulltaker"] = "wh3_main_combi_region_hualotal",
        ["wh3_dlc26_kho_arbaal"] = "wh3_main_combi_region_pillar_of_skulls",
        ["wh3_main_kho_bloody_sword"] = "wh3_main_combi_region_the_tower_of_torment",
        ["wh3_main_kho_brazen_throne"] = "wh3_main_combi_region_the_never_ending_chasm",
        ["wh3_main_kho_crimson_skull"] = "wh3_main_combi_region_infernius",
        ["cr_kho_servants_of_the_blood_nagas"] = "cr_combi_region_soglap",
        ["wh3_main_kho_karneths_sons"] = "cr_combi_region_ihan_3_3",

        -- NURGLE
        ["wh3_main_nur_poxmakers_of_nurgle"] = "wh3_main_combi_region_shattered_stone_isle",
        ["wh3_dlc25_nur_tamurkhan"] = "wh3_main_combi_region_zanbaijin",
        ["wh3_dlc25_nur_epidemius"] = "wh3_main_combi_region_bilious_cliffs",
        ["wh3_main_nur_bubonic_swarm"] = "wh3_main_combi_region_the_lost_palace",
        ["wh3_main_nur_maggoth_kin"] = "wh3_main_combi_region_kraka_drak",
        ["wh3_dlc20_nur_pallid_nurslings"] = "wh3_main_combi_region_quetza",
        ["cr_nur_tide_of_pestilence"] = "cr_combi_region_chi_an_encampment",

        -- SLAANESH
        ["wh3_main_sla_seducers_of_slaanesh"] = "wh3_main_combi_region_tor_achare",
        ["wh3_dlc27_sla_the_tormentors"] = "wh3_main_combi_region_hidden_landing",
        ["wh3_main_sla_exquisite_pain"] = "wh3_main_combi_region_the_writhing_fortress",
        ["wh3_main_sla_rapturous_excess"] = "wh3_main_combi_region_okkams_forever_maze",
        ["wh3_main_sla_subtle_torture"] = "wh3_main_combi_region_the_twisted_towers",
        ["wh3_dlc20_sla_keepers_of_bliss"] = "wh3_main_combi_region_macu_peaks",
        ["cr_sla_loeshs_indulgence"] = "cr_combi_region_santiaogou",
        ["wh3_dlc27_sla_masque_of_slaanesh"] = "wh3_main_combi_region_pillars_of_unseen_constellations",

        -- TZEENTCH
        ["wh3_main_tze_oracles_of_tzeentch"] = "wh3_main_combi_region_the_lost_palace",
        ["wh3_dlc24_tze_the_deceivers"] = "wh3_main_combi_region_niedling",
        ["wh3_main_tze_all_seeing_eye"] = "wh3_main_combi_region_the_crystal_spires",
        ["wh3_main_tze_broken_wheel"] = "wh3_main_combi_region_cliff_of_beasts",
        ["wh3_main_tze_flaming_scribes"] = "wh3_main_combi_region_daemons_gate",
        ["wh3_dlc20_tze_the_sightless"] = "wh3_main_combi_region_konquata",
        ["wh3_dlc20_tze_apostles_of_change"] = "wh3_main_combi_region_chaqua",
        ["wh3_main_tze_sarthoraels_watchers"] = "wh3_main_combi_region_dawns_light",
        ["cr_tze_cult_of_tsien_tsin"] = "cr_combi_region_nippon_2_1",
        ["cr_tze_sliding_terror"] = "cr_combi_region_lantern_of_lies",

        -- KISLEV
        ["wh3_main_ksl_the_ice_court"] = "wh3_main_combi_region_zavastra",
        ["wh3_main_ksl_the_great_orthodoxy"] = "wh3_main_combi_region_erengrad",
        ["wh3_main_ksl_ursun_revivalists"] = "wh3_main_combi_region_the_tower_of_torment",
        ["wh3_dlc24_ksl_daughters_of_the_forest"] = "wh3_main_combi_region_bleak_hold_fortress",
        ["wh3_main_ksl_ropsmenn_clan"] = "wh3_main_combi_region_praag",
        ["wh3_main_ksl_brotherhood_of_the_bear"] = "wh3_main_combi_region_the_tower_of_khrakk",
        ["wh3_main_ksl_druzhina_enclave"] = "wh3_main_combi_region_fort_straghov",
        ["wh3_main_ksl_ungol_kindred"] = "wh3_main_combi_region_zoishenk",
        ["cr_ksl_rota_of_the_dawn"] = "cr_combi_region_great_rasputia",

        -- OGRE KINGDOMS
        ["wh3_main_ogr_goldtooth"] = "wh3_main_combi_region_great_hall_of_greasus",
        ["wh3_main_ogr_disciples_of_the_maw"] = "wh3_main_combi_region_matorca",
        ["wh3_dlc26_ogr_golgfag"] = "wh3_main_combi_region_norden",
        ["wh3_main_ogr_blood_guzzlers"] = "wh3_main_combi_region_vale_of_titans",
        ["wh3_main_ogr_bloodmaw"] = "wh3_main_combi_region_temple_avenue_of_gold",
        ["wh3_main_ogr_crossed_clubs"] = "wh3_main_combi_region_the_maw_gate",
        ["wh3_main_ogr_eyebiter"] = "wh3_main_combi_region_the_sentinels",
        ["wh3_main_ogre_sharktooth"] = "wh3_main_combi_region_port_reaver",
        ["wh3_main_ogre_stoneshatter"] = "wh3_main_combi_region_qiang",
        ["wh3_main_ogre_flamegullets"] = "wh3_main_combi_region_shroktak_mount",
        ["wh3_main_ogre_the_famished"] = "wh3_main_combi_region_great_desert_of_araby",
        ["wh3_main_ogr_feastmaster"] = "wh3_main_combi_region_bitterstone_mine",
        ["wh3_main_ogr_fleshgreeders"] = "wh3_main_combi_region_the_challenge_stone",
        ["wh3_main_ogr_fulg"] = "wh3_main_combi_region_gorger_rock",
        ["wh3_main_ogr_lazarghs"] = "wh3_main_combi_region_pillar_of_skulls",
        ["wh3_main_ogr_loose_tooth"] = "wh3_main_combi_region_zhanshi",
        ["wh3_main_ogr_mountaineaters"] = "wh3_main_combi_region_yhetee_peak",
        ["wh3_main_ogr_rock_skulls"] = "wh3_main_combi_region_karak_ungor",
        ["wh3_main_ogr_sabreskin"] = "wh3_main_combi_region_sabre_mountain",
        ["wh3_main_ogr_sons_of_the_mountain"] = "wh3_main_combi_region_amblepeak",
        ["wh3_main_ogr_thunderguts"] = "wh3_main_combi_region_pigbarter",
        ["wh3_main_ogr_treehammers"] = "wh3_main_combi_region_krugenheim",
        ["cr_ogr_deathtoll"] = "cr_combi_region_himaranya",
        ["cr_ogr_snakebiter_tribe"] = "cr_combi_region_dhaygon",
        ["cr_ogr_suneaters"] = "cr_combi_region_monkeys_altar",
        ["cr_ogr_shellcrackers"] = "cr_combi_region_lumbria_1_1",

        -- CHAOS DWARFS
        ["wh3_dlc23_chd_astragoth"] = "wh3_main_combi_region_uzkulak",
        ["wh3_dlc23_chd_legion_of_azgorh"] = "wh3_main_combi_region_black_fortress",
        ["wh3_dlc23_chd_zhatan"] = "wh3_main_combi_region_fortress_of_eyes",
        ["wh3_dlc23_chd_conclave"] = "wh3_main_combi_region_zharr_naggrund",
        ["wh3_dlc23_chd_minor_faction"] = "wh3_main_combi_region_tower_of_gorgoth",
        ["cr_chd_slaves_of_the_black_dwarf"] = "cr_combi_region_gahhuks_encampment",
        ["cr_chd_skullstack"] = "cr_combi_region_varindapur",

        -- GRAND CATHAY
        ["wh3_main_cth_the_northern_provinces"] = "wh3_main_combi_region_nan_gau",
        ["wh3_main_cth_the_western_provinces"] = "wh3_main_combi_region_qiang",
        ["wh3_dlc24_cth_the_celestial_court"] = "wh3_main_combi_region_isle_of_the_crimson_skull",
        ["wh3_cp1_cth_tiger_warriors"] = "wh3_main_combi_region_vale_of_titans",
        ["wh3_main_cth_burning_wind_nomads"] = "wh3_main_combi_region_temple_of_elemental_winds",
        ["wh3_main_cth_celestial_loyalists"] = "wh3_main_combi_region_wei_jin",
        ["wh3_main_cth_dissenter_lords_of_jinshen"] = "wh3_main_combi_region_shang_yang",
        ["wh3_main_cth_eastern_river_lords"] = "wh3_main_combi_region_li_zhu",
        ["wh3_main_cth_imperial_wardens"] = "wh3_main_combi_region_red_fortress",
        ["wh3_main_cth_the_jade_custodians"] = "wh3_main_combi_region_zhanshi",
        ["cr_cth_okumoto_clan"] = "cr_combi_region_nippon_3_1",
        ["cr_cth_sanyo_clan"] = "cr_combi_region_nippon_4_2",
        ["cr_cth_the_chosen"] = "cr_combi_region_ihan_2_1",
        ["cr_cth_agents_of_the_moon"] = "cr_combi_region_dai_loa",

        -- HIGH ELVES
        ["wh2_main_hef_eataine"] = "wh3_main_combi_region_lothern",
        ["wh3_dlc27_hef_aislinn"] = "wh3_main_combi_region_tor_koruali",
        ["wh2_main_hef_order_of_loremasters"] = "wh3_main_combi_region_dawns_light",
        ["wh2_main_hef_avelorn"] = "wh3_main_combi_region_gaean_vale",
        ["wh2_main_hef_nagarythe"] = "wh3_main_combi_region_the_monoliths",
        ["wh2_main_hef_yvresse"] = "wh3_main_combi_region_tor_yvresse",
        ["wh2_dlc15_hef_imrik"] = "wh3_main_combi_region_the_bone_gulch",
        ["wh2_main_hef_chrace"] = "wh3_main_combi_region_tor_achare",
        ["wh2_main_hef_citadel_of_dusk"] = "wh3_main_combi_region_citadel_of_dusk",
        ["wh2_main_hef_cothique"] = "wh3_main_combi_region_tor_koruali",
        ["wh2_main_hef_ellyrion"] = "wh3_main_combi_region_tor_elyr",
        ["wh2_main_hef_saphery"] = "wh3_main_combi_region_white_tower_of_hoeth",
        ["wh2_main_hef_tiranoc"] = "wh3_main_combi_region_tor_anroc",
        ["cr_hef_gate_guards"] = "cr_combi_region_gates_of_calith_1",
        ["cr_hef_tor_elithis"] = "cr_combi_region_elithis_1_1",
        ["cr_hef_the_starguided"] = "cr_combi_region_city_of_spires",

        -- LIZARDMEN
        ["wh2_dlc17_lzd_oxyotl"] = "wh3_main_combi_region_the_godless_crater",
        ["wh2_main_lzd_hexoatl"] = "wh3_main_combi_region_hexoatl",
        ["wh2_main_lzd_last_defenders"] = "wh3_main_combi_region_teotiqua",
        ["wh2_dlc12_lzd_cult_of_sotek"] = "wh3_main_combi_region_kaiax",
        ["wh2_main_lzd_tlaqua"] = "wh3_main_combi_region_deaths_head_monoliths",
        ["wh2_dlc13_lzd_spirits_of_the_jungle"] = "wh3_main_combi_region_tower_of_ashung",
        ["wh2_main_lzd_itza"] = "wh3_main_combi_region_itza",
        ["wh2_main_lzd_sentinels_of_xeti"] = "wh3_main_combi_region_sentinels_of_xeti",
        ["wh2_main_lzd_southern_sentinels"] = "wh3_main_combi_region_mangrove_coast",
        ["wh3_main_lzd_tepoks_spawn"] = "wh3_main_combi_region_shattered_cove",
        ["wh2_main_lzd_tlaxtlan"] = "wh3_main_combi_region_temple_of_tlencan",
        ["wh2_dlc16_lzd_wardens_of_the_living_pools"] = "wh3_main_combi_region_the_sacred_pools",
        ["wh2_main_lzd_xlanhuapec"] = "wh3_main_combi_region_xlanhuapec",
        ["wh2_main_lzd_zlatan"] = "wh3_main_combi_region_zlatlan",
        ["cr_lzd_scions_of_xholankhas"] = "cr_combi_region_nagara_ishsva",
        ["cr_lzd_one_hundred_thousand"] = "cr_combi_region_temple_of_brahmir",

        -- DARK ELVES
        ["wh2_main_def_naggarond"] = "wh3_main_combi_region_har_kaldra",
        ["wh2_main_def_cult_of_pleasure"] = "wh3_main_combi_region_ancient_city_of_quintex",
        ["wh2_main_def_har_ganeth"] = "wh3_main_combi_region_har_ganeth",
        ["wh2_dlc11_def_the_blessed_dread"] = "wh3_main_combi_region_zhizhu",
        ["wh2_main_def_hag_graef"] = "wh3_main_combi_region_black_rock",
        ["wh2_twa03_def_rakarth"] = "wh3_main_combi_region_great_turtle_isle",
        ["wh2_main_def_bleak_holds"] = "wh3_main_combi_region_arnheim",
        ["wh2_main_def_blood_hall_coven"] = "wh3_main_combi_region_pillars_of_unseen_constellations",
        ["wh2_main_def_clar_karond"] = "wh3_main_combi_region_circle_of_destruction",
        ["wh2_main_def_cult_of_excess"] = "wh3_main_combi_region_shrine_of_asuryan",
        ["wh2_main_def_deadwood_sentinels"] = "wh3_main_combi_region_fortress_of_the_damned",
        ["wh2_main_def_ghrond"] = "wh3_main_combi_region_dagraks_end",
        ["wh2_main_def_karond_kar"] = "wh3_main_combi_region_karond_kar",
        ["wh2_main_def_scourge_of_khaine"] = "wh3_main_combi_region_tor_anlec",
        ["wh2_main_def_ssildra_tor"] = "wh3_main_combi_region_petrified_forest",
        ["wh2_main_def_drackla_coven"] = "wh3_main_combi_region_hag_hall",
        ["wh2_main_def_the_forgebound"] = "wh3_main_combi_region_the_black_forests",
        ["cr_def_corsairs_of_spite"] = "cr_combi_region_pubjiwanpur",
        ["cr_def_harbingers_of_pain"] = "cr_combi_region_elithis_1_3",
        ["cr_def_cult_of_anath_raema"] = "cr_combi_region_shrine_of_ellinill",

        -- SKAVEN
        ["wh2_main_skv_clan_mors"] = "wh3_main_combi_region_kradtommen",
        ["wh2_main_skv_clan_pestilens"] = "wh3_main_combi_region_oyxl",
        ["wh2_dlc09_skv_clan_rictus"] = "wh3_main_combi_region_crookback_mountain",
        ["wh2_main_skv_clan_skryre"] = "wh3_main_combi_region_tobaro",
        ["wh2_main_skv_clan_moulder"] = "wh3_main_combi_region_hell_pit",
        ["wh2_main_skv_clan_eshin"] = "wh3_main_combi_region_village_of_the_moon",
        ["wh3_main_skv_clan_carrion"] = "wh3_main_combi_region_nagashizzar",
        ["wh2_dlc16_skv_clan_gritus"] = "wh3_main_combi_region_tyrant_peak",
        ["wh2_dlc15_skv_clan_kreepus"] = "wh3_main_combi_region_mordheim",
        ["wh3_main_skv_clan_krizzor"] = "wh3_main_combi_region_xen_wu",
        ["wh2_dlc12_skv_clan_mange"] = "wh3_main_combi_region_monument_of_izzatal",
        ["wh3_main_skv_clan_morbidus"] = "wh3_main_combi_region_temple_avenue_of_gold",
        ["wh2_main_skv_clan_mordkin"] = "wh3_main_combi_region_temple_of_skulls",
        ["wh2_main_skv_clan_septik"] = "wh3_main_combi_region_rackdo_gorge",
        ["wh3_main_skv_clan_skrat"] = "wh3_main_combi_region_kaiax",
        ["wh2_main_skv_clan_spittel"] = "wh3_main_combi_region_altar_of_the_horned_rat",
        ["wh3_main_skv_clan_verms"] = "wh3_main_combi_region_dragonhorn_mines",
        ["wh2_dlc15_skv_clan_volkn"] = "wh3_main_combi_region_spitepeak",
        ["wh3_main_skv_clan_treecherik"] = "wh3_main_combi_region_gnobbly_gorge",
        ["cr_skv_eshin_clan_nest"] = "cr_combi_region_nippon_2_3",
        ["cr_skv_clan_rikek"] = "cr_combi_region_kasar",
        ["cr_skv_clan_festerlingus"] = "cr_combi_region_pituhiccha",
        ["cr_skv_clan_crooktail"] = "cr_combi_region_haemorrhagia",

        -- TOMB KINGS
        ["wh2_dlc09_tmb_khemri"] = "wh3_main_combi_region_khemri",
        ["wh2_dlc09_tmb_lybaras"] = "wh3_main_combi_region_lybaras",
        ["wh2_dlc09_tmb_exiles_of_nehek"] = "wh3_main_combi_region_clarak_spire",
        ["wh2_dlc09_tmb_followers_of_nagash"] = "wh3_main_combi_region_lashiek",
        ["wh3_main_tmb_deserters_of_khatep"] = "wh3_main_combi_region_the_golden_colossus",
        ["wh2_dlc09_tmb_dune_kingdoms"] = "wh3_main_combi_region_bhagar",
        ["wh2_dlc09_tmb_numas"] = "wh3_main_combi_region_numas",
        ["wh2_dlc09_tmb_rakaph_dynasty"] = "wh3_main_combi_region_black_tower_of_arkhan",
        ["wh2_dlc09_tmb_the_sentinels"] = "wh3_main_combi_region_black_pyramid_of_nagash",
        ["cr_tmb_sons_of_ptra"] = "cr_combi_region_nippon_5_2",

        -- VAMPIRE COAST
        ["wh2_dlc11_cst_vampire_coast"] = "wh3_main_combi_region_the_awakening",
        ["wh2_dlc11_cst_noctilus"] = "wh3_main_combi_region_the_galleons_graveyard",
        ["wh2_dlc11_cst_the_drowned"] = "wh3_main_combi_region_the_twisted_glade",
        ["wh2_dlc11_cst_pirates_of_sartosa"] = "wh3_main_combi_region_luccini",
        ["wh3_dlc21_cst_dead_flag_fleet"] = "wh3_main_combi_region_beichai",
        ["cr_cst_rotten_knot"] = "cr_combi_region_sanmal",

        -- EMPIRE
        ["wh_main_emp_empire"] = "wh3_main_combi_region_altdorf",
        ["wh2_dlc13_emp_golden_order"] = "wh3_main_combi_region_temple_of_elemental_winds",
        ["wh3_main_emp_cult_of_sigmar"] = "wh3_main_combi_region_sudenburg",
        ["wh2_dlc13_emp_the_huntmarshals_expedition"] = "wh3_main_combi_region_temple_of_kara",
        ["wh_main_emp_wissenland"] = "wh3_main_combi_region_nuln",
        ["wh_main_emp_averland"] = "wh3_main_combi_region_averheim",
        ["wh_main_emp_hochland"] = "wh3_main_combi_region_hergig",
        ["wh_main_emp_marienburg"] = "wh3_main_combi_region_marienburg",
        ["wh_main_emp_middenland"] = "wh3_main_combi_region_middenheim",
        ["wh2_main_emp_new_world_colonies"] = "wh3_main_combi_region_port_reaver",
        ["wh_main_emp_nordland"] = "wh3_main_combi_region_salzenmund",
        ["wh_main_emp_ostermark"] = "wh3_main_combi_region_bechafen",
        ["wh_main_emp_ostland"] = "wh3_main_combi_region_wolfenburg",
        ["wh_main_emp_stirland"] = "wh3_main_combi_region_wurtbad",
        ["wh_main_emp_talabecland"] = "wh3_main_combi_region_talabheim",
        ["cr_emp_guests_of_the_raja"] = "cr_combi_region_somnagiri",

        -- DWARFS
        ["wh_main_dwf_dwarfs"] = "wh3_main_combi_region_karaz_a_karak",
        ["wh_main_dwf_karak_kadrin"] = "wh3_main_combi_region_karak_kadrin",
        ["wh_main_dwf_karak_izor"] = "wh3_main_combi_region_karak_bhufdar",
        ["wh3_main_dwf_the_ancestral_throng"] = "wh3_main_combi_region_drackla_spire",
        ["wh2_dlc17_dwf_thorek_ironbrow"] = "wh3_main_combi_region_karak_zorn",
        ["wh3_dlc25_dwf_malakai"] = "wh3_main_combi_region_kraka_drak",
        ["wh_main_dwf_barak_varr"] = "wh3_main_combi_region_barak_varr",
        ["wh2_dlc15_dwf_clan_helhein"] = "wh3_main_combi_region_the_bone_gulch",
        ["wh2_main_dwf_greybeards_prospectors"] = "wh3_main_combi_region_eye_of_the_panther",
        ["wh3_main_dwf_karak_azorn"] = "wh3_main_combi_region_karak_azorn",
        ["wh_main_dwf_karak_azul"] = "wh3_main_combi_region_karak_azul",
        ["wh_main_dwf_karak_hirn"] = "wh3_main_combi_region_karak_hirn",
        ["wh_main_dwf_karak_norn"] = "wh3_main_combi_region_karak_norn",
        ["wh_main_dwf_karak_ziflin"] = "wh3_main_combi_region_karak_ziflin",
        ["wh2_main_dwf_spine_of_sotek_dwarfs"] = "wh3_main_combi_region_mine_of_the_bearded_skulls",
        ["wh_main_dwf_zhufbar"] = "wh3_main_combi_region_zhufbar",
        ["cr_dwf_firebeards_excavators"] = "cr_combi_region_nandakshi",

        -- GREENSKINS
        ["wh_main_grn_greenskins"] = "wh3_main_combi_region_eagle_eyries",
        ["wh_main_grn_crooked_moon"] = "wh3_main_combi_region_mount_gunbad",
        ["wh2_dlc15_grn_bonerattlaz"] = "wh3_main_combi_region_khazid_irkulaz",
        ["wh_main_grn_orcs_of_the_bloody_hand"] = "wh3_main_combi_region_sun_tree_glades",
        ["wh2_dlc15_grn_broken_axe"] = "wh3_main_combi_region_quenelles",
        ["wh3_dlc26_grn_gorbad_ironclaw"] = "wh3_main_combi_region_iron_rock",
        ["wh2_main_grn_arachnos"] = "wh3_main_combi_region_lost_plateau",
        ["wh_main_grn_black_venom"] = "wh3_main_combi_region_steingart",
        ["wh_main_grn_bloody_spearz"] = "wh3_main_combi_region_karaz_a_karak",
        ["wh2_main_grn_blue_vipers"] = "wh3_main_combi_region_pahuax",
        ["wh2_dlc16_grn_naggaroth_orcs"] = "wh3_main_combi_region_rothkar_spire",
        ["wh_main_grn_broken_nose"] = "wh3_main_combi_region_karak_bhufdar",
        ["wh2_dlc16_grn_creeping_death"] = "wh3_main_combi_region_forest_of_gloom",
        ["wh3_dlc26_grn_cluster_eye_tribe"] = "wh3_main_combi_region_gateway_to_khuresh",
        ["wh_main_grn_necksnappers"] = "wh3_main_combi_region_karak_eight_peaks",
        ["wh3_main_grn_da_cage_breakaz"] = "wh3_main_combi_region_nagrar",
        ["wh3_main_grn_dark_land_orcs"] = "wh3_main_combi_region_the_sentinels",
        ["wh3_main_grn_dimned_sun"] = "wh3_main_combi_region_kunlan",
        ["wh3_main_grn_drippin_fangs"] = "wh3_main_combi_region_howling_rock",
        ["wh2_dlc12_grn_leaf_cutterz_tribe"] = "wh3_main_combi_region_deaths_head_monoliths",
        ["wh3_main_grn_moon_howlerz"] = "wh3_main_combi_region_mount_silverspear",
        ["wh2_dlc14_grn_red_cloud"] = "wh3_main_combi_region_castle_carcassonne",
        ["wh_main_grn_red_eye"] = "wh3_main_combi_region_fallen_king_mountain",
        ["wh_main_grn_red_fangs"] = "wh3_main_combi_region_crooked_fang_fort",
        ["wh_main_grn_scabby_eye"] = "wh3_main_combi_region_dok_karaz",
        ["wh_main_grn_skull-takerz"] = "wh3_main_combi_region_fort_soll",
        ["wh2_dlc15_grn_skull_crag"] = "wh3_main_combi_region_tralinia",
        ["wh_main_grn_skullsmasherz"] = "wh3_main_combi_region_grung_zint",
        ["wh3_main_grn_slaves_of_zharr"] = "wh3_main_combi_region_great_skull_lakes",
        ["wh_main_grn_teef_snatchaz"] = "wh3_main_combi_region_ekrund",
        ["wh_dlc03_grn_black_pit"] = "wh3_main_combi_region_the_black_pit",
        ["wh_main_grn_top_knotz"] = "wh3_main_combi_region_stormhenge",
        ["wh3_main_grn_tusked_sunz"] = "wh3_main_combi_region_blizzardpeak",
        ["cr_grn_speaking_trees"] = "cr_combi_region_skon_basin",
        ["cr_grn_nag_rippers"] = "cr_combi_region_monolith_of_uzelek",
        ["cr_grn_grag_a_mugar_clan"] = "cr_combi_region_hobhome",
        ["cr_grn_blackwolf_clan"] = "cr_combi_region_veh_kung_encampment",
        ["cr_grn_withered_eye_tribe"] = "cr_combi_region_city_of_splinters",

        -- VAMPIRE COUNTS
        ["wh_main_vmp_vampire_counts"] = "wh3_main_combi_region_ka_sabar",
        ["wh2_dlc11_vmp_the_barrow_legion"] = "wh3_main_combi_region_blackstone_post",
        ["wh3_main_vmp_caravan_of_blue_roses"] = "wh3_main_combi_region_gnobbly_gorge",
        ["wh_main_vmp_schwartzhafen"] = "wh3_main_combi_region_castle_drakenhof",
        ["wh3_main_vmp_lahmian_sisterhood"] = "wh3_main_combi_region_silver_pinnacle",
        ["wh_main_vmp_mousillon"] = "wh3_main_combi_region_mousillon",
        ["wh2_main_vmp_necrarch_brotherhood"] = "wh3_main_combi_region_springs_of_eternal_life",
        ["wh3_main_ie_vmp_sires_of_mourkain"] = "wh3_main_combi_region_morgheim",
        ["wh2_main_vmp_strygos_empire"] = "wh3_main_combi_region_copher",
        ["wh_main_vmp_rival_sylvanian_vamps"] = "wh3_main_combi_region_castle_templehof",
        ["wh2_main_vmp_the_silver_host"] = "wh3_main_combi_region_lahmia",
        ["wh3_dlc25_vmp_the_court_of_night"] = "wh3_main_combi_region_dotternbach",
        ["rhox_vmp_the_everliving"] = "cr_combi_region_tarangnagar",

        -- WARRIORS OF CHAOS
        ["wh_main_chs_chaos"] = "wh3_main_combi_region_the_writhing_fortress",
        ["wh3_dlc20_chs_kholek"] = "wh3_main_combi_region_the_challenge_stone",
        ["wh3_dlc20_chs_sigvald"] = "wh3_main_combi_region_fortress_of_the_damned",
        ["wh3_dlc20_chs_azazel"] = "wh3_main_combi_region_bay_of_blades",
        ["wh3_dlc20_chs_festus"] = "wh3_main_combi_region_hergig",
        ["wh3_dlc20_chs_valkia"] = "wh3_main_combi_region_dagraks_end",
        ["wh3_dlc20_chs_vilitch"] = "wh3_main_combi_region_red_fortress",
        ["wh3_main_chs_shadow_legion"] = "wh3_main_combi_region_isle_of_wights",
        ["wh3_main_chs_khazag"] = "wh3_main_combi_region_bloodwind_keep",
        ["cr_chs_po_hai"] = "cr_combi_region_ihan_1_1",
        ["cr_chs_the_scourgeborn"] = "cr_combi_region_tarangnagar",
        ["cr_chs_tsavags"] = "cr_combi_region_tsavags_forge",
        ["rhox_chs_the_deathswords"] = "cr_combi_region_ihan_1_1",
        ["cr_chs_iron_wolves"] = "cr_combi_region_wo_camp",
        ["cr_chs_death_eaters"] = "cr_combi_region_starmetal_cemetery",

        -- BEASTMEN
        ["wh_dlc03_bst_beastmen"] = "wh3_main_combi_region_the_black_pit",
        ["wh2_dlc17_bst_malagor"] = "wh3_main_combi_region_sunken_khernarch",
        ["wh_dlc05_bst_morghur_herd"] = "wh3_main_combi_region_montenas",
        ["wh2_dlc17_bst_taurox"] = "wh3_main_combi_region_storag_kor",
        ["wh_dlc03_bst_jagged_horn"] = "wh3_main_combi_region_weng_chang",
        ["wh2_main_bst_manblight"] = "wh3_main_combi_region_the_moon_shard",
        ["wh_dlc03_bst_redhorn"] = "wh3_main_combi_region_wurtbad",
        ["wh2_main_bst_ripper_horn"] = "wh3_main_combi_region_rackdo_gorge",
        ["wh2_main_bst_shadowgor"] = "wh3_main_combi_region_tyrant_peak",
        ["cr_bst_apehorn"] = "cr_combi_region_eye_of_the_tiger",
        ["cr_bst_warherd_of_kug"] = "cr_combi_region_the_grey",
        ["cr_bst_orobagor_warherd"] = "cr_combi_region_sartorn",
        ["cr_bst_skullfest_warherd"] = "cr_combi_region_shrine_of_the_last_smile",

        -- WOOD ELVES
        ["wh_dlc05_wef_wood_elves"] = "wh3_main_combi_region_kings_glade",
        ["wh_dlc05_wef_argwylon"] = "wh3_main_combi_region_karak_norn",
        ["wh2_dlc16_wef_sisters_of_twilight"] = "wh3_main_combi_region_the_witchwood",
        ["wh2_dlc16_wef_drycha"] = "wh3_main_combi_region_mordheim",
        ["wh2_main_wef_bowmen_of_oreon"] = "wh3_main_combi_region_oreons_camp",
        ["wh3_main_wef_laurelorn"] = "wh3_main_combi_region_laurelorn_forest",
        ["wh3_dlc21_wef_spirits_of_shanlin"] = "wh3_main_combi_region_jungles_of_chian",
        ["wh_dlc05_wef_torgovann"] = "wh3_main_combi_region_vauls_anvil_loren",
        ["wh_dlc05_wef_wydrioth"] = "wh3_main_combi_region_crag_halls_of_findol",
        ["cr_wef_lotus_flower"] = "cr_combi_region_aranyas_glade",
        ["rhox_wef_far_away_forest"] = "cr_combi_region_elithis_2_1",

        -- BRETONNIA
        ["wh_main_brt_bretonnia"] = "wh3_main_combi_region_languille",
        ["wh_main_brt_carcassonne"] = "wh3_main_combi_region_castle_carcassonne",
        ["wh_main_brt_bordeleaux"] = "wh3_main_combi_region_temple_of_tlencan",
        ["wh2_dlc14_brt_chevaliers_de_lyonesse"] = "wh3_main_combi_region_copher",
        ["wh_main_brt_artois"] = "wh3_main_combi_region_gisoreux",
        ["wh_main_brt_bastonne"] = "wh3_main_combi_region_castle_bastonne",
        ["wh3_main_brt_aquitaine"] = "wh3_main_combi_region_aquitaine",
        ["wh2_main_brt_knights_of_origo"] = "wh3_main_combi_region_zandri",
        ["wh2_main_brt_knights_of_the_flame"] = "wh3_main_combi_region_lashiek",
        ["wh_main_brt_lyonesse"] = "wh3_main_combi_region_lyonesse",
        ["wh_main_brt_parravon"] = "wh3_main_combi_region_castle_carcassonne",
        ["wh2_main_brt_thegans_crusaders"] = "wh3_main_combi_region_martek",
        ["cr_brt_leofrics_fellowship"] = "cr_combi_region_junkselon",
        ["rhox_brt_reveller_of_domance"] = "cr_combi_region_suryapuri",

        -- NORSCA
        ["wh_dlc08_nor_norsca"] = "wh3_main_combi_region_monolith_of_borkill_the_bloody_handed",
        ["wh_dlc08_nor_wintertooth"] = "wh3_main_combi_region_altar_of_spawns",
        ["wh3_dlc27_nor_sayl"] = "wh3_main_combi_region_dark_tower",
        ["wh_main_nor_aesling"] = "wh3_main_combi_region_altar_of_spawns",
        ["wh2_main_nor_aghol"] = "wh3_main_combi_region_shard_bastion",
        ["wh_main_nor_baersonling"] = "wh3_main_combi_region_fort_jakova",
        ["wh_main_nor_bjornling"] = "wh3_main_combi_region_monolith_of_borkill_the_bloody_handed",
        ["wh3_dlc27_the_narj"] = "wh3_main_combi_region_the_gallows_tree",
        ["wh_dlc08_nor_goromadny_tribe"] = "wh3_main_combi_region_karak_vlag",
        ["wh_main_nor_graeling"] = "wh3_main_combi_region_graeling_moot",
        ["wh3_dlc20_nor_kuj"] = "cr_combi_region_kuj_encampment",
        ["wh3_dlc20_nor_kul"] = "wh3_main_combi_region_the_bleeding_spire",
        ["wh2_main_nor_mung"] = "wh3_dlc20_combi_region_glacier_encampment",
        ["wh_dlc08_nor_naglfarlings"] = "wh3_main_combi_region_naglfari_plain",
        ["wh_main_nor_sarl"] = "wh3_main_combi_region_sarl_encampment",
        ["wh_dlc08_nor_vanaheimlings"] = "wh3_main_combi_region_isle_of_wights",
        ["wh_main_nor_varg"] = "wh3_main_combi_region_varg_camp",
        ["wh3_dlc21_nor_wyrmkins"] = "wh3_main_combi_region_tower_of_ashung",
        ["wh3_dlc20_nor_yusak"] = "wh3_main_combi_region_foundry_of_bones",
        ["wh3_dlc27_nor_avags"] = "wh3_main_combi_region_desolation_ridge",
        ["cr_nor_tokmars"] = "cr_combi_region_tokmars_encampment",
        ["rhox_nor_khazags"] = "wh3_main_combi_region_rotten_stone",
        ["cr_nor_wei_tu"] = "cr_combi_region_wei_tu_encampment",
        ["cr_nor_stormravens"] = "cr_combi_region_melay",
        ["rhox_nor_ravenblessed"] = "cr_combi_region_muhaks_encampment",

        -- SOUTHERN REALMS / BORDER PRINCES
        ["wh_main_teb_border_princes"] = "wh3_main_combi_region_zvorak",
        ["wh_main_teb_estalia"] = "wh3_main_combi_region_magritta",
        ["wh_main_teb_tilea"] = "wh3_main_combi_region_miragliano",
    },
}

local runtime_roster_unit_data = require("script._lib.mod.runtime_roster_unit_data")
local deprecated_army_templates = require("script._lib.mod.deprecated_army_templates")
require("script._lib.mod.lib_runtime_army_template_generator")

--[[-------------------------------------------------------------------------------------------------------------
    Logging helper.

    Search for [RBC_DEBUG] in lua_mod_log.txt:
    Total War WARHAMMER III/lua_mod_log.txt
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:log(message)
    local msg = self.log_prefix .. " " .. tostring(message)

    -- Use ModLog if available (from glib or other logging frameworks)
    if ModLog then
        ModLog(msg)
    end

    -- Always use out()
    out(msg)
end

--[[-------------------------------------------------------------------------------------------------------------
    Get all factions in the game (for dropdown)
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:get_all_factions()
    local factions = {}
    local faction_list = cm:model():world():faction_list()

    for i = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(i)
        if faction and not faction:is_null_interface() then
            -- Skip rebel factions and special factions
            local faction_key = faction:name()
            if not string.find(faction_key, "rebel") and
               not string.find(faction_key, "qb_") and
               not string.find(faction_key, "wh3_main_rogue") then
                table.insert(factions, {
                    key = faction_key,
                    name = faction:name(),
                    is_dead = faction:is_dead(),
                    is_human = faction:is_human(),
                })
            end
        end
    end

    return factions
end

--[[-------------------------------------------------------------------------------------------------------------
    Find the single Anarchy Kill transfer target.
    We intentionally use one stable sink faction instead of culture-specific rebel factions. The sink gets a
    permanent crippling economy bundle and is forced into war with every active faction after each transfer.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:get_anarchy_transfer_target(target_faction_key, subculture)
    local candidate_key = self.anarchy_rebel_sink_faction
    if not candidate_key or candidate_key == "" or candidate_key == target_faction_key then
        return false
    end

    local candidate = cm:get_faction(candidate_key)
    -- nil = key not registered in this campaign at all
    if not candidate then
        self:log("Anarchy sink faction not registered in this campaign: " .. tostring(candidate_key))
        return false
    end
    -- is_null_interface = dead rebel faction; cm:transfer_region_to_faction still works on them
    if not candidate:is_null_interface() and candidate:is_human() then
        self:log("Anarchy sink faction is human, refusing: " .. candidate_key)
        return false
    end

    return candidate_key
end

function revive_boring_campaign:apply_anarchy_rebel_sink_lock(rebel_faction_key)
    if not rebel_faction_key or rebel_faction_key == "" then
        return
    end

    -- Reduce army capacity using existing game bundles (persistent, no DB required)
    local sink_bundles = {
        -- army cap -1 each (x8 = -8 total, prevents recruitment)
        "wh2_dlc09_decrease_army_cap_1",
        "wh2_dlc09_decrease_army_cap_2",
        "wh2_dlc09_decrease_army_cap_3",
        "wh2_dlc09_decrease_army_cap_4",
        "wh2_dlc09_decrease_army_cap_5",
        "wh2_dlc09_decrease_army_cap_6",
        "wh2_dlc09_decrease_army_cap_7",
        "wh2_dlc09_decrease_army_cap_8",
        -- growth penalties (prevents settlement upgrades)
        "wh2_main_payload_growth_negative_all_province",   -- -10 growth
        "wh2_dlc13_bundle_imperial_authority_2",           -- -5 growth
        "wh2_dlc13_wulfhart_growth_decrease",              -- -3 growth
        -- income penalty (keeps faction broke)
        "wh2_main_incident_all_gdp_down",                  -- -10% income
        -- construction cost penalty (discourages building)
        "wh2_main_incident_all_construction_cost_up",      -- +15% construction cost
    }
    for _, bundle in ipairs(sink_bundles) do
        cm:apply_effect_bundle(bundle, rebel_faction_key, 0)
    end

    -- Drain treasury immediately so they cannot recruit on the first turn
    local faction = cm:get_faction(rebel_faction_key)
    if faction and not faction:is_null_interface() then
        local t = faction:treasury()
        if t > 0 then
            cm:treasury_mod(rebel_faction_key, -t)
        end
    end

    self:log("Applied sink lock to " .. rebel_faction_key)
end

--[[-------------------------------------------------------------------------------------------------------------
    Make a newly revived Anarchy rebel faction hostile to every active faction.
    This keeps the transfer temporary: nearby major factions should be able to destroy the rebels and resettle.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:make_anarchy_rebels_world_hostile(rebel_faction_key)
    if not rebel_faction_key then
        return 0
    end

    local rebel_faction = cm:get_faction(rebel_faction_key)
    if not rebel_faction or rebel_faction:is_null_interface() then
        self:log("WARNING: Cannot set Anarchy wars; rebel faction not found: " .. tostring(rebel_faction_key))
        return 0
    end

    local wars_declared = 0
    local faction_list = cm:model():world():faction_list()

    cm:disable_event_feed_events(true, "", "", "diplomacy_war_declared")
    for i = 0, faction_list:num_items() - 1 do
        local other_faction = faction_list:item_at(i)
        if other_faction and not other_faction:is_null_interface() then
            local other_key = other_faction:name()
            if other_key ~= rebel_faction_key and not other_faction:is_dead() and not rebel_faction:at_war_with(other_faction) then
                cm:force_declare_war(rebel_faction_key, other_key, false, false)
                wars_declared = wars_declared + 1
            end
        end
    end
    cm:callback(function() cm:disable_event_feed_events(false, "", "", "diplomacy_war_declared") end, 0.2)

    self:log("Anarchy rebels " .. rebel_faction_key .. " set hostile to " .. wars_declared .. " active factions")
    return wars_declared
end

--[[-------------------------------------------------------------------------------------------------------------
    Get army composition for a faction.
    Preferred path uses CA military_group roster permissions generated from WH3-Dump-Fork.
    Falls back to old subculture templates if the generated dataset cannot resolve a faction.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:get_army_for_faction(faction_key)
    if runtime_roster_unit_data and runtime_army_template_generator then
        local lord_key, force_list, generated_army = runtime_army_template_generator:get_force_list_for_faction(
            runtime_roster_unit_data,
            faction_key
        )

        if lord_key and force_list then
            local roster_name = generated_army and generated_army.roster_name or "unknown roster"
            self:log("Generated runtime army for " .. faction_key .. " using roster " .. tostring(roster_name))
            self:log("Generated lord: " .. tostring(lord_key))
            return force_list, lord_key, generated_army
        end
    end

    local faction = cm:get_faction(faction_key)
    if not faction or faction:is_null_interface() then
        return deprecated_army_templates.default, false, nil
    end

    local subculture = faction:subculture()
    if deprecated_army_templates[subculture] then
        self:log("Using fallback subculture army template for " .. faction_key .. ": " .. tostring(subculture))
        return deprecated_army_templates[subculture], false, nil
    end

    self:log("Using default fallback army template for " .. faction_key)
    return deprecated_army_templates.default, false, nil
end

--[[-------------------------------------------------------------------------------------------------------------
    Apply support to armies spawned by this mod so revived/buffed AI factions do not immediately bankrupt.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:apply_spawned_army_support(faction_key, character_cqi)
    if not character_cqi then
        self:log("WARNING: Cannot support spawned army for " .. tostring(faction_key) .. " without character CQI")
        return
    end

    local support_duration = 25
    cm:apply_effect_bundle_to_characters_force("wh_main_bundle_military_upkeep_free_force_endgame", character_cqi, support_duration)
    self:log("Applied spawned army free-upkeep support to CQI " .. tostring(character_cqi) .. " for " .. support_duration .. " turns")
end

--[[-------------------------------------------------------------------------------------------------------------
    Spawn a force. Runtime-generated armies use create_force_with_general() so the selected lord subtype is used.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:spawn_force(faction_key, unit_list, region_key, x, y, generated_army, success_callback)
    local lord = generated_army and generated_army.lord
    local agent_subtype = lord and lord.agent_subtype
    local wrapped_success_callback = function(cqi)
        self:apply_spawned_army_support(faction_key, cqi)
        if success_callback then
            success_callback(cqi)
        end
    end

    if agent_subtype and agent_subtype ~= "" then
        self:log("Spawning generated lord subtype: " .. agent_subtype)
        cm:create_force_with_general(
            faction_key,
            unit_list,
            region_key,
            x,
            y,
            "general",
            agent_subtype,
            "",
            "",
            "",
            "",
            false,
            wrapped_success_callback
        )
        return
    end

    self:log("Spawning with default create_force general")
    cm:create_force(
        faction_key,
        unit_list,
        region_key,
        x,
        y,
        false,
        wrapped_success_callback
    )
end

--[[-------------------------------------------------------------------------------------------------------------
    Transfer the target region's province to a revived faction.
    Player-owned regions are left untouched; abandoned and AI-owned regions are transferred.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:transfer_province_to_faction(target_region, faction_key)
    if not target_region or target_region:is_null_interface() then
        self:log("ERROR: transfer_province_to_faction() called without a valid target region")
        return 0
    end

    local province = target_region:province()
    if not province or province:is_null_interface() then
        self:log("Province interface unavailable, transferring only target region " .. target_region:name())
        cm:transfer_region_to_faction(target_region:name(), faction_key)
        return 1
    end

    local province_regions = province:regions()
    local transferred_count = 0

    for i = 0, province_regions:num_items() - 1 do
        local province_region = province_regions:item_at(i)
        if province_region and not province_region:is_null_interface() then
            local region_key = province_region:name()
            local should_transfer = false

            if province_region:is_abandoned() then
                should_transfer = true
                self:log("Province transfer: taking abandoned region " .. region_key)
            else
                local owner = province_region:owning_faction()
                if owner and not owner:is_null_interface() then
                    if owner:name() == faction_key then
                        self:log("Province transfer: already owned by revived faction " .. region_key)
                    elseif owner:is_human() then
                        self:log("Province transfer: skipping player-owned region " .. region_key)
                    else
                        should_transfer = true
                        self:log("Province transfer: taking AI-owned region " .. region_key .. " from " .. owner:name())
                    end
                end
            end

            if should_transfer then
                cm:transfer_region_to_faction(region_key, faction_key)
                transferred_count = transferred_count + 1
            end
        end
    end

    if transferred_count == 0 then
        self:log("Province transfer moved no regions; forcing target region transfer " .. target_region:name())
        cm:transfer_region_to_faction(target_region:name(), faction_key)
        transferred_count = 1
    end

    return transferred_count
end

--[[-------------------------------------------------------------------------------------------------------------
    Upgrade the capital settlement of the target province to its maximum primary-slot level.
    Passing 5 is safe: CA's API clamps it to the chain maximum.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:upgrade_province_capital_to_max(target_region, faction_key)
    if not target_region or target_region:is_null_interface() then
        self:log("ERROR: upgrade_province_capital_to_max() called without a valid target region")
        return false
    end

    local province = target_region:province()
    local capital_region = target_region

    if province and not province:is_null_interface() then
        local province_regions = province:regions()
        for i = 0, province_regions:num_items() - 1 do
            local province_region = province_regions:item_at(i)
            if province_region and not province_region:is_null_interface() and province_region:is_province_capital() then
                capital_region = province_region
                break
            end
        end
    end

    if capital_region:is_abandoned() then
        self:log("Cannot upgrade province capital because it is abandoned: " .. capital_region:name())
        return false
    end

    local owner = capital_region:owning_faction()
    if not owner or owner:is_null_interface() or owner:name() ~= faction_key then
        self:log("Cannot upgrade province capital because revived faction does not own it: " .. capital_region:name())
        return false
    end

    local settlement = capital_region:settlement()
    if not settlement or settlement:is_null_interface() then
        self:log("Cannot upgrade province capital because settlement interface is invalid: " .. capital_region:name())
        return false
    end

    local target_level = 5
    local building = cm:instantly_set_settlement_primary_slot_level(settlement, target_level)
    cm:callback(function()
        cm:heal_garrison(capital_region:cqi())
    end, 0.5)

    self:log("Upgraded province capital " .. capital_region:name() .. " primary slot toward level " .. target_level)
    return building
end

function revive_boring_campaign:downgrade_regions_to_level(region_keys, faction_key, target_level)
    cm:callback(function()
        for _, region_key in ipairs(region_keys) do
            local region = cm:get_region(region_key)
            if not region or region:is_null_interface() then goto continue end
            if region:is_abandoned() then goto continue end

            local owner = region:owning_faction()
            if not owner or owner:is_null_interface() or owner:name() ~= faction_key then goto continue end

            local settlement = region:settlement()
            if not settlement or settlement:is_null_interface() then goto continue end

            cm:instantly_set_settlement_primary_slot_level(settlement, target_level)
            self:log("Downgraded region " .. region_key .. " primary slot to level " .. target_level)

            ::continue::
        end
    end, 0.5)
end

function revive_boring_campaign:is_regionless_revive_faction(faction_key)
    return self.regionless_revive_factions[faction_key] == true
end

function revive_boring_campaign:remove_faction_foreign_slots(faction)
    if not faction or faction:is_null_interface() then
        self:log("ERROR: remove_faction_foreign_slots() called without a valid faction")
        return 0
    end

    local faction_cqi = faction:command_queue_index()
    local foreign_slot_managers = faction:foreign_slot_managers()
    if not foreign_slot_managers then
        self:log("Foreign slot manager list unavailable for " .. faction:name())
        return 0
    end

    local regions_to_clear = {}
    for i = 0, foreign_slot_managers:num_items() - 1 do
        local manager = foreign_slot_managers:item_at(i)
        if manager and not manager:is_null_interface() then
            local region = manager:region()
            if region and not region:is_null_interface() then
                table.insert(regions_to_clear, {
                    key = region:name(),
                    cqi = region:cqi()
                })
            end
        end
    end

    self:log("Found " .. #regions_to_clear .. " foreign slot regions to clear for " .. faction:name())

    for _, region_data in ipairs(regions_to_clear) do
        self:log("Removing foreign slots for " .. faction:name() .. " in region " .. region_data.key)
        cm:remove_faction_foreign_slots_from_region(faction_cqi, region_data.cqi)
    end

    return #regions_to_clear
end

--[[-------------------------------------------------------------------------------------------------------------
    Find a spawn point near a settlement and avoid stacking scripted armies on the same pixel.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:get_spawn_location_near_settlement(faction_key, region_key, base_x, base_y, army_index, used_positions)
    local function position_key(x, y)
        return tostring(x) .. ":" .. tostring(y)
    end

    local search_radii = {
        5 + (army_index * 5),
        10 + (army_index * 8),
        20 + (army_index * 10),
        35 + (army_index * 10)
    }

    for i = 1, #search_radii do
        local pos_x, pos_y = cm:find_valid_spawn_location_for_character_from_settlement(
            faction_key,
            region_key,
            false,
            true,
            search_radii[i]
        )

        if pos_x and pos_y and pos_x ~= -1 and pos_y ~= -1 then
            local key = position_key(pos_x, pos_y)
            if not used_positions[key] then
                used_positions[key] = true
                self:log("Found valid spawn location at radius " .. search_radii[i] .. ": " .. pos_x .. ", " .. pos_y)
                return pos_x, pos_y
            end
        end
    end

    local fallback_offsets = {
        {0, 0},
        {4, 0},
        {-4, 0},
        {0, 4},
        {0, -4},
        {4, 4},
        {-4, 4},
        {4, -4},
        {-4, -4},
        {8, 0},
        {-8, 0},
        {0, 8},
        {0, -8}
    }
    local offset = fallback_offsets[((army_index - 1) % #fallback_offsets) + 1]
    local fallback_x = base_x + offset[1]
    local fallback_y = base_y + offset[2]
    used_positions[position_key(fallback_x, fallback_y)] = true

    self:log("find_valid_spawn failed or returned duplicate, using offset fallback: " .. fallback_x .. ", " .. fallback_y)
    return fallback_x, fallback_y
end

--[[-------------------------------------------------------------------------------------------------------------
    KILL FACTION

    Abandons all regions and kills all armies, completely destroying the faction.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:kill_faction(faction_key)
    self:log("Attempting to kill faction: " .. tostring(faction_key))

    local faction = cm:get_faction(faction_key)
    if not faction or faction:is_null_interface() then
        self:log("ERROR: Faction not found: " .. tostring(faction_key))
        return false
    end

    if faction:is_human() then
        self:log("ERROR: Cannot kill player faction!")
        return false
    end

    if faction:is_dead() then
        self:log("Faction is already dead: " .. faction_key)
        return false
    end

    -- Get all regions owned by this faction
    local region_list = faction:region_list()
    local regions_to_abandon = {}

    for i = 0, region_list:num_items() - 1 do
        local region = region_list:item_at(i)
        if region and not region:is_null_interface() then
            table.insert(regions_to_abandon, region:name())
        end
    end

    self:log("Found " .. #regions_to_abandon .. " regions to abandon")

    -- Abandon each region (turns them into ruins)
    for _, region_key in ipairs(regions_to_abandon) do
        self:log("Abandoning region: " .. region_key)
        cm:set_region_abandoned(region_key)
    end

    local removed_foreign_slots = self:remove_faction_foreign_slots(faction)

    -- Kill all characters/armies of this faction
    local char_list = faction:character_list()
    local characters_to_kill = {}

    for i = 0, char_list:num_items() - 1 do
        local character = char_list:item_at(i)
        if character and not character:is_null_interface() then
            table.insert(characters_to_kill, character:cqi())
        end
    end

    self:log("Found " .. #characters_to_kill .. " characters to kill")

    -- Kill each character (this removes their armies too)
    for _, cqi in ipairs(characters_to_kill) do
        self:log("Killing character CQI: " .. cqi)
        cm:kill_character_and_commanded_unit(cm:char_lookup_str(cqi), true, true)
    end

    self:log("Faction killed successfully: " .. faction_key .. " (removed_foreign_slot_regions=" .. removed_foreign_slots .. ")")
    return true
end

--[[-------------------------------------------------------------------------------------------------------------
    ANARCHY KILL FACTION

    Transfers all regions to a matching rebel faction, then kills all target faction characters.
    If no usable rebel faction exists in this campaign, regions fall back to ruins.
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:anarchy_kill_faction(faction_key)
    self:log("Attempting anarchy kill on faction: " .. tostring(faction_key))

    local faction = cm:get_faction(faction_key)
    if not faction or faction:is_null_interface() then
        self:log("ERROR: Faction not found for anarchy kill: " .. tostring(faction_key))
        return false
    end

    if faction:is_human() then
        self:log("ERROR: Cannot anarchy kill player faction!")
        return false
    end

    if faction:is_dead() then
        self:log("Faction is already dead, cannot anarchy kill: " .. faction_key)
        return false
    end

    local subculture = faction:subculture()
    local rebel_faction_key = self:get_anarchy_transfer_target(faction_key, subculture)
    local can_transfer_to_rebels = rebel_faction_key ~= false

    if can_transfer_to_rebels then
        self:log("Anarchy kill rebel target for " .. faction_key .. ": " .. rebel_faction_key .. " (subculture " .. tostring(subculture) .. ")")
    else
        self:log("WARNING: No usable rebel target for " .. faction_key .. " (subculture " .. tostring(subculture) .. "), falling back to ruins")
    end

    local region_list = faction:region_list()
    local regions_to_process = {}
    for i = 0, region_list:num_items() - 1 do
        local region = region_list:item_at(i)
        if region and not region:is_null_interface() then
            table.insert(regions_to_process, region:name())
        end
    end

    local char_list = faction:character_list()
    local characters_to_kill = {}
    for i = 0, char_list:num_items() - 1 do
        local character = char_list:item_at(i)
        if character and not character:is_null_interface() then
            table.insert(characters_to_kill, character:cqi())
        end
    end

    self:log("Anarchy kill found " .. #regions_to_process .. " regions and " .. #characters_to_kill .. " characters")

    local transferred_regions = 0
    local abandoned_regions = 0
    local wars_declared = 0
    local removed_foreign_slots = self:remove_faction_foreign_slots(faction)
    for _, region_key in ipairs(regions_to_process) do
        if can_transfer_to_rebels then
            self:log("Anarchy transferring region " .. region_key .. " to " .. rebel_faction_key)
            cm:transfer_region_to_faction(region_key, rebel_faction_key)
            transferred_regions = transferred_regions + 1
        else
            self:log("Anarchy fallback abandoning region: " .. region_key)
            cm:set_region_abandoned(region_key)
            abandoned_regions = abandoned_regions + 1
        end
    end

    if transferred_regions > 0 then
        self:downgrade_regions_to_level(regions_to_process, rebel_faction_key, 2)
        self:apply_anarchy_rebel_sink_lock(rebel_faction_key)
        wars_declared = self:make_anarchy_rebels_world_hostile(rebel_faction_key)
    end

    for _, cqi in ipairs(characters_to_kill) do
        self:log("Anarchy killing character CQI: " .. cqi)
        cm:kill_character_and_commanded_unit(cm:char_lookup_str(cqi), true, true)
    end

    self:log(
        "Anarchy kill completed for " .. faction_key ..
        ": transferred_regions=" .. transferred_regions ..
        ", abandoned_regions=" .. abandoned_regions ..
        ", wars_declared=" .. wars_declared ..
        ", removed_foreign_slot_regions=" .. removed_foreign_slots ..
        ", killed_characters=" .. #characters_to_kill
    )
    return true
end

--[[-------------------------------------------------------------------------------------------------------------
    REVIVE FACTION

    Gives the faction a region and spawns armies.
    Strategy:
    1. Try hardcoded capital if available and not owned by player
    2. Try to find any abandoned region (ruins)
    3. Take a region from a non-player AI faction
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:revive_faction(faction_key, num_armies)
    self:log("Attempting to revive faction: " .. tostring(faction_key))

    num_armies = num_armies or 5

    local faction = cm:get_faction(faction_key)
    if not faction or faction:is_null_interface() then
        self:log("ERROR: Faction not found: " .. tostring(faction_key))
        return false
    end

    -- Check if faction is already alive
    if not faction:is_dead() then
        self:log("Faction is already alive: " .. faction_key .. " (has " .. faction:region_list():num_items() .. " regions)")
        return false
    end

    -- Find a suitable region for the faction
    local target_region_key = self:find_region_for_revive(faction_key)

    if not target_region_key then
        self:log("ERROR: Could not find any valid region to revive faction " .. faction_key)
        return false
    end

    local region = cm:get_region(target_region_key)
    if not region or region:is_null_interface() then
        self:log("ERROR: Region object not found: " .. tostring(target_region_key))
        return false
    end

    local transferred_regions = 0
    if self:is_regionless_revive_faction(faction_key) then
        self:log("Regionless revive anchor for " .. faction_key .. ": " .. target_region_key .. " (skipping province transfer and settlement upgrade)")
    else
        -- Transfer the whole province when possible, without taking regions from the player.
        self:log("Transferring revive province around " .. target_region_key .. " to " .. faction_key)
        transferred_regions = self:transfer_province_to_faction(region, faction_key)
        self:upgrade_province_capital_to_max(region, faction_key)
    end

    local revive_treasury = 50000
    self:log("Giving revive treasury support: " .. revive_treasury .. " gold to " .. faction_key)
    cm:treasury_mod(faction_key, revive_treasury)

    -- Show debug message on screen
    cm:show_message_event(
        cm:get_local_faction_name(true),
        "event_feed_strings_text_debug_title",
        "REVIVE DEBUG: Reviving " .. faction_key,
        "Transferred " .. transferred_regions .. " regions. Now spawning " .. num_armies .. " armies at " .. target_region_key,
        true,
        1
    )

    -- Get army composition for this faction
    local unit_list, lord_key, generated_army = self:get_army_for_faction(faction_key)
    self:log("Army composition: " .. unit_list)

    -- Get settlement coordinates directly
    local settlement = region:settlement()
    local base_x = settlement:logical_position_x()
    local base_y = settlement:logical_position_y()
    self:log("Settlement position: " .. base_x .. ", " .. base_y)

    -- Spawn armies IMMEDIATELY
    local used_spawn_positions = {}
    for i = 1, num_armies do
        self:log("Spawning army " .. i .. " of " .. num_armies)

        local pos_x, pos_y = self:get_spawn_location_near_settlement(
            faction_key,
            target_region_key,
            base_x,
            base_y,
            i,
            used_spawn_positions
        )

        self:log("Spawning at position: " .. pos_x .. ", " .. pos_y)
        self:spawn_force(
            faction_key,
            unit_list,
            target_region_key,
            pos_x,
            pos_y,
            generated_army,
            function(cqi)
                self:log("Army " .. i .. " spawned with CQI " .. tostring(cqi))
            end
        )
    end

    self:log("Faction revive initiated: " .. faction_key)
    return true
end

--[[-------------------------------------------------------------------------------------------------------------
    Find a valid region for reviving a faction
    Strategy:
    1. Try hardcoded capital if available and usable
    2. Find any abandoned region
    3. Find a region from a non-player AI faction
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:find_region_for_revive(faction_key)
    -- Step 1: Try hardcoded capital
    local capital_key = self.faction_capitals[faction_key]
    if capital_key then
        local capital = cm:get_region(capital_key)
        if capital and not capital:is_null_interface() then
            -- Check if usable (abandoned or owned by AI)
            if capital:is_abandoned() then
                self:log("Using hardcoded capital (abandoned): " .. capital_key)
                return capital_key
            end
            local owner = capital:owning_faction()
            if owner and not owner:is_null_interface() and not owner:is_human() then
                self:log("Using hardcoded capital (will take from AI): " .. capital_key)
                return capital_key
            end
            self:log("Hardcoded capital owned by player, looking for alternative")
        else
            -- Region doesn't exist - likely an IE Extended region in vanilla IE campaign
            if string.find(capital_key, "cr_combi_region") then
                self:log("IE Extended capital region not found in this campaign: " .. tostring(capital_key) .. " (this is normal in vanilla IE)")
            else
                self:log("Hardcoded capital region not found: " .. tostring(capital_key))
            end
        end
    else
        self:log("No hardcoded capital for faction: " .. faction_key)
    end

    -- Step 2: Find any abandoned region
    local region_list = cm:model():world():region_manager():region_list()
    for i = 0, region_list:num_items() - 1 do
        local region = region_list:item_at(i)
        if region and not region:is_null_interface() and region:is_abandoned() then
            self:log("Found abandoned region: " .. region:name())
            return region:name()
        end
    end

    -- Step 3: Find a region from a non-player AI faction
    self:log("No abandoned regions, looking for AI-owned region")
    for i = 0, region_list:num_items() - 1 do
        local region = region_list:item_at(i)
        if region and not region:is_null_interface() then
            local owner = region:owning_faction()
            if owner and not owner:is_null_interface() and not owner:is_human() then
                self:log("Found AI-owned region: " .. region:name() .. " (owned by " .. owner:name() .. ")")
                return region:name()
            end
        end
    end

    self:log("ERROR: Could not find any valid region for revive")
    return nil
end

--[[-------------------------------------------------------------------------------------------------------------
    BOOST FACTION

    Gives a faction major advantages:
    - Unlock all technologies
    - Free upkeep for 25 turns
    - Spawn 5 armies at capital
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:boost_faction(faction_key, options)
    self:log("Attempting to boost faction: " .. tostring(faction_key))

    options = options or {}
    local buff_duration = 25

    local faction = cm:get_faction(faction_key)
    if not faction or faction:is_null_interface() then
        self:log("ERROR: Faction not found: " .. tostring(faction_key))
        return false
    end

    if faction:is_dead() then
        self:log("ERROR: Cannot boost dead faction: " .. faction_key)
        return false
    end

    -- 1. Unlock all technologies
    if options.unlock_tech then
        self:log("Unlocking all technologies for " .. faction_key)
        cm:instantly_research_all_technologies(faction_key)
    end

    -- 2. Apply free upkeep buff to ALL armies of the faction
    if options.free_upkeep then
        self:log("Applying free upkeep buff to all armies for " .. buff_duration .. " turns")
        local char_list = faction:character_list()
        for i = 0, char_list:num_items() - 1 do
            local character = char_list:item_at(i)
            if character and not character:is_null_interface() and character:has_military_force() then
                local cqi = character:cqi()
                cm:apply_effect_bundle_to_characters_force("wh_main_bundle_military_upkeep_free_force_endgame", cqi, buff_duration)
                self:log("Applied upkeep buff to army CQI: " .. cqi)
            end
        end
    end

    -- 3. Give gold
    if options.give_gold then
        local gold_amount = 50000
        self:log("Giving " .. gold_amount .. " gold to " .. faction_key)
        cm:treasury_mod(faction_key, gold_amount)
    end

    -- 4. Spawn armies at capital (if faction has regions)
    if options.spawn_armies and faction:region_list():num_items() > 0 then
        local num_armies = 5
        local capital_region = faction:region_list():item_at(0)
        local capital_region_key = capital_region:name()

        -- Try to use their actual capital from our table
        if self.faction_capitals[faction_key] then
            local mapped_capital = cm:get_region(self.faction_capitals[faction_key])
            if mapped_capital and not mapped_capital:is_null_interface() then
                local owner = mapped_capital:owning_faction()
                if owner and owner:name() == faction_key then
                    capital_region_key = self.faction_capitals[faction_key]
                end
            end
        end

        local unit_list, lord_key, generated_army = self:get_army_for_faction(faction_key)
        local region = cm:get_region(capital_region_key)
        local settlement = region:settlement()
        local base_x = settlement:logical_position_x()
        local base_y = settlement:logical_position_y()

        local used_spawn_positions = {}
        for i = 1, num_armies do
            self:log("Spawning army " .. i .. " of " .. num_armies)

            local pos_x, pos_y = self:get_spawn_location_near_settlement(
                faction_key,
                capital_region_key,
                base_x,
                base_y,
                i,
                used_spawn_positions
            )

            self:spawn_force(
                faction_key,
                unit_list,
                capital_region_key,
                pos_x,
                pos_y,
                generated_army,
                function(cqi)
                    self:log("Army " .. i .. " spawned successfully")
                end
            )
        end
    end

    self:log("Faction boosted successfully: " .. faction_key)
    return true
end

--[[-------------------------------------------------------------------------------------------------------------
    NERF FACTION

    Applies penalties to a faction:
    - Drain 50% treasury
    - Apply morale penalty for 25 turns
    - Optionally kill all armies
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:nerf_faction(faction_key, options)
    self:log("Attempting to nerf faction: " .. tostring(faction_key))

    options = options or {}
    local debuff_duration = 25

    local faction = cm:get_faction(faction_key)
    if not faction or faction:is_null_interface() then
        self:log("ERROR: Faction not found: " .. tostring(faction_key))
        return false
    end

    if faction:is_dead() then
        self:log("ERROR: Cannot nerf dead faction: " .. faction_key)
        return false
    end

    -- 1. Drain treasury
    if options.drain_treasury then
        local treasury_drain = math.floor(faction:treasury() * 0.5)
        if treasury_drain > 0 then
            self:log("Draining " .. treasury_drain .. " gold from " .. faction_key)
            cm:treasury_mod(faction_key, -treasury_drain)
        end
    end

    -- 2. Apply morale penalty to all armies
    if options.morale_penalty then
        self:log("Applying morale penalty to all armies for " .. debuff_duration .. " turns")
        local char_list = faction:character_list()
        for i = 0, char_list:num_items() - 1 do
            local character = char_list:item_at(i)
            if character and not character:is_null_interface() and character:has_military_force() then
                local cqi = character:cqi()
                cm:apply_effect_bundle_to_characters_force("wh_main_bundle_military_morale_penalty", cqi, debuff_duration)
                self:log("Applied morale penalty to army CQI: " .. cqi)
            end
        end
    end

    -- 3. Kill all armies if option is checked
    if options.kill_armies then
        self:log("Killing all armies of " .. faction_key)

        local char_list = faction:character_list()
        local characters_to_kill = {}

        for i = 0, char_list:num_items() - 1 do
            local character = char_list:item_at(i)
            if character and not character:is_null_interface() then
                table.insert(characters_to_kill, character:cqi())
            end
        end

        self:log("Found " .. #characters_to_kill .. " characters to kill")

        for _, cqi in ipairs(characters_to_kill) do
            cm:kill_character_and_commanded_unit(cm:char_lookup_str(cqi), true, true)
        end
    end

    self:log("Faction nerfed successfully: " .. faction_key)
    return true
end

--[[-------------------------------------------------------------------------------------------------------------
    Process pending actions (called from MCT listener)
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:process_pending_kill(faction_key)
    if faction_key and faction_key ~= "" then
        cm:callback(function()
            self:kill_faction(faction_key)
        end, 0.5)
    end
end

function revive_boring_campaign:process_pending_anarchy_kill(faction_key)
    if faction_key and faction_key ~= "" then
        cm:callback(function()
            self:anarchy_kill_faction(faction_key)
        end, 0.5)
    end
end

function revive_boring_campaign:process_pending_validation_test(faction_keys)
    if not faction_keys or #faction_keys == 0 then
        self:log("Validation test skipped: no factions provided")
        return
    end

    self:log("Validation test scheduled for " .. #faction_keys .. " factions")

    local delay = 0
    for i = 1, #faction_keys do
        local test_index = i
        local faction_key = faction_keys[i]
        local faction_count = #faction_keys

        cm:callback(function()
            self:log("VALIDATION_TEST [" .. test_index .. "/" .. faction_count .. "] kill " .. faction_key)
            self:kill_faction(faction_key)
        end, delay)
        delay = delay + 1.5

        cm:callback(function()
            self:log("VALIDATION_TEST [" .. test_index .. "/" .. faction_count .. "] revive " .. faction_key)
            self:revive_faction(faction_key, 5)
        end, delay)
        delay = delay + 2.5

        cm:callback(function()
            self:log("VALIDATION_TEST [" .. test_index .. "/" .. faction_count .. "] anarchy kill " .. faction_key)
            self:anarchy_kill_faction(faction_key)
        end, delay)
        delay = delay + 2.5
    end

    cm:callback(function()
        self:log("Validation test completed scheduled sequence for " .. #faction_keys .. " factions")
    end, delay)
end

function revive_boring_campaign:process_pending_revive(faction_key)
    if faction_key and faction_key ~= "" then
        cm:callback(function()
            self:revive_faction(faction_key, 5)
        end, 0.5)
    end
end

function revive_boring_campaign:process_pending_boost(faction_key, options)
    if faction_key and faction_key ~= "" then
        cm:callback(function()
            self:boost_faction(faction_key, options)
        end, 0.5)
    end
end

function revive_boring_campaign:process_pending_nerf(faction_key, options)
    if faction_key and faction_key ~= "" then
        cm:callback(function()
            self:nerf_faction(faction_key, options)
        end, 0.5)
    end
end

--[[-------------------------------------------------------------------------------------------------------------
    Initialize the mod
]]---------------------------------------------------------------------------------------------------------------
function revive_boring_campaign:initialize()
    self:log("Initializing Revive Boring Campaign mod")

    -- Only run in campaign
    if not cm:get_campaign_name() then
        self:log("Not in campaign, skipping initialization")
        return
    end

    self:log("Mod initialized successfully!")
end

--[[-------------------------------------------------------------------------------------------------------------
    Campaign startup listener
]]---------------------------------------------------------------------------------------------------------------
cm:add_first_tick_callback(function()
    revive_boring_campaign:initialize()
end)

revive_boring_campaign:log("Script loaded successfully")
