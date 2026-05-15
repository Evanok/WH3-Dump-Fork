----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
--
--	Runtime Army Template Generator
--
--	Consumes the generated army_template_units_with_characters.lua dataset and produces:
--	- a lord unit key (spawned separately)
--	- a 19-unit force list for campaign spawning
--	- an optional random_army_manager force containing the generated 19-unit stack
--
--	Expected input dataset shape:
--		local data = require("script._lib.mod.army_template_unit_data")
--

runtime_army_template_generator = {
	default_composition = {
		character_hero = 1,
		infantry = 6,
		artillery = 3,
		cavalry = 3,
		ranged = 3,
		monster = 3
	},

	category_groups = {
		character_lord = {"character_lord"},
		character_hero = {"character_hero"},
		infantry = {"melee_infantry", "monstrous_infantry"},
		ranged = {"missile_infantry"},
		artillery = {"artillery", "war_machine"},
		cavalry = {"melee_cavalry", "missile_cavalry", "monstrous_cavalry", "chariot", "missile_chariot"},
		monster = {"monster", "war_beast"}
	}
};


function runtime_army_template_generator:__tostring()
	return "TYPE_RUNTIME_ARMY_TEMPLATE_GENERATOR";
end;


function runtime_army_template_generator:_random_index(max_value)
	if max_value <= 0 then
		return 0;
	end;

	if cm and cm.random_number then
		return cm:random_number(max_value);
	end;

	return math.random(max_value);
end;


function runtime_army_template_generator:_copy_array(source)
	local result = {};
	for i = 1, #source do
		result[i] = source[i];
	end;
	return result;
end;


function runtime_army_template_generator:_contains_category(group_key, category)
	local categories = self.category_groups[group_key];
	if not categories then
		return false;
	end;

	for i = 1, #categories do
		if categories[i] == category then
			return true;
		end;
	end;

	return false;
end;


function runtime_army_template_generator:_build_pools(race_data)
	local pools = {
		character_lord = {},
		character_hero = {},
		infantry = {},
		ranged = {},
		artillery = {},
		cavalry = {},
		monster = {},
		non_character = {}
	};

	for i = 1, #race_data.units do
		local unit = race_data.units[i];
		local category = unit.category;

		if category ~= "character_lord" and category ~= "character_hero" then
			table.insert(pools.non_character, unit);
		end;

		for group_key, _ in pairs(self.category_groups) do
			if self:_contains_category(group_key, category) then
				table.insert(pools[group_key], unit);
			end;
		end;
	end;

	return pools;
end;


function runtime_army_template_generator:_pick_unit(pool, usage)
	if #pool == 0 then
		return false;
	end;

	local min_usage = nil;
	local candidates = {};

	for i = 1, #pool do
		local unit = pool[i];
		local unit_key = unit.unit_key;
		local unit_usage = usage[unit_key] or 0;

		if min_usage == nil or unit_usage < min_usage then
			min_usage = unit_usage;
			candidates = {unit};
		elseif unit_usage == min_usage then
			table.insert(candidates, unit);
		end;
	end;

	local choice = candidates[self:_random_index(#candidates)];
	usage[choice.unit_key] = (usage[choice.unit_key] or 0) + 1;
	return choice;
end;


function runtime_army_template_generator:_mixed_fallback_pool(pools)
	if #pools.infantry > 0 and #pools.ranged > 0 then
		local mix = self:_copy_array(pools.infantry);
		for i = 1, #pools.ranged do
			table.insert(mix, pools.ranged[i]);
		end;
		return mix, "fallback_mix";
	end;

	if #pools.infantry > 0 then
		return pools.infantry, "fallback_infantry";
	end;

	if #pools.ranged > 0 then
		return pools.ranged, "fallback_ranged";
	end;

	return pools.non_character, "fallback_any_non_character";
end;


function runtime_army_template_generator:_get_slot_pool(slot_key, pools)
	local primary = pools[slot_key];
	if primary and #primary > 0 then
		return primary, slot_key;
	end;

	if slot_key == "ranged" then
		if #pools.infantry > 0 then
			return pools.infantry, "fallback_infantry";
		end;
		return self:_mixed_fallback_pool(pools);
	end;

	if slot_key == "artillery" or slot_key == "cavalry" or slot_key == "monster" or slot_key == "infantry" then
		return self:_mixed_fallback_pool(pools);
	end;

	return {}, "missing";
end;


function runtime_army_template_generator:_build_generation_plan(composition)
	local plan = {};

	for slot_key, amount in pairs(composition) do
		for i = 1, amount do
			table.insert(plan, slot_key);
		end;
	end;

	table.sort(plan);
	return plan;
end;


function runtime_army_template_generator:get_race_data(dataset, race_key)
	if not dataset or not dataset.races then
		script_error("runtime_army_template_generator:get_race_data() called without a valid dataset");
		return false;
	end;

	local race_data = dataset.races[race_key];
	if not race_data then
		script_error("runtime_army_template_generator:get_race_data() could not find race [" .. tostring(race_key) .. "]");
		return false;
	end;

	return race_data;
end;


function runtime_army_template_generator:generate_army(dataset, race_key, options)
	options = options or {};

	local race_data = self:get_race_data(dataset, race_key);
	if not race_data then
		return false;
	end;

	local composition = options.composition or self.default_composition;
	local pools = self:_build_pools(race_data);
	local usage = {};
	local picks = {};
	local source_breakdown = {};

	if #pools.character_lord == 0 then
		script_error("runtime_army_template_generator:generate_army() race [" .. race_key .. "] has no lords");
		return false;
	end;

	if #pools.character_hero == 0 then
		script_error("runtime_army_template_generator:generate_army() race [" .. race_key .. "] has no heroes");
		return false;
	end;

	local lord = self:_pick_unit(pools.character_lord, usage);
	local plan = self:_build_generation_plan(composition);

	for i = 1, #plan do
		local slot_key = plan[i];
		local pool, source = self:_get_slot_pool(slot_key, pools);
		if #pool == 0 then
			script_error("runtime_army_template_generator:generate_army() race [" .. race_key .. "] has no valid pool for slot [" .. slot_key .. "]");
			return false;
		end;

		local unit = self:_pick_unit(pool, usage);
		table.insert(picks, {
			slot = slot_key,
			source = source,
			unit_key = unit.unit_key,
			name = unit.name,
			category = unit.category
		});
		source_breakdown[source] = (source_breakdown[source] or 0) + 1;
	end;

	local unit_keys = {};
	for i = 1, #picks do
		unit_keys[i] = picks[i].unit_key;
	end;

	return {
		race_key = race_key,
		race_name = race_data.name,
		lord = lord,
		units = picks,
		unit_keys = unit_keys,
		force_list = table.concat(unit_keys, ","),
		source_breakdown = source_breakdown
	};
end;


function runtime_army_template_generator:register_force_with_random_army_manager(force_key, generated_army)
	if not random_army_manager then
		script_error("runtime_army_template_generator:register_force_with_random_army_manager() requires random_army_manager");
		return false;
	end;

	if not generated_army then
		script_error("runtime_army_template_generator:register_force_with_random_army_manager() called without generated_army");
		return false;
	end;

	random_army_manager:remove_force(force_key);
	random_army_manager:new_force(force_key);

	for i = 1, #generated_army.unit_keys do
		random_army_manager:add_mandatory_unit(force_key, generated_army.unit_keys[i], 1);
	end;

	return true;
end;


function runtime_army_template_generator:generate_and_register_force(dataset, race_key, force_key, options)
	local generated_army = self:generate_army(dataset, race_key, options);
	if not generated_army then
		return false;
	end;

	self:register_force_with_random_army_manager(force_key, generated_army);
	return generated_army;
end;


function runtime_army_template_generator:get_force_list(dataset, race_key, options)
	local generated_army = self:generate_army(dataset, race_key, options);
	if not generated_army then
		return false;
	end;

	return generated_army.lord.unit_key, generated_army.force_list, generated_army;
end;

