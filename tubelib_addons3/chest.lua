--[[

	Tubelib Addons 3
	================

	Copyright (C) 2017-2020 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	chest.lua

	A high performance chest

]]--

-- Load support for I18n
local S = tubelib_addons3.S

local PlayerActions = {}
local InventoryState = {}


local function store_action(pos, player, action, stack)
	local meta = minetest.get_meta(pos)
	local name = player and player:get_player_name() or ""
	local number = meta:get_string("number")
	local item = stack:get_name().." "..stack:get_count()
	PlayerActions[number] = {name, action, item}
end

local function send_off_command(pos)
	local meta = minetest.get_meta(pos)
	local dest_num = meta:get_string("dest_num")
	local own_num = meta:get_string("number")
	local owner = meta:get_string("owner")
	tubelib.send_message(dest_num, owner, nil, "off", own_num)
end


local function send_command(pos)
	local meta = minetest.get_meta(pos)
	local dest_num = meta:get_string("dest_num")
	if dest_num ~= "" then
		local own_num = meta:get_string("number")
		local owner = meta:get_string("owner")
		tubelib.send_message(dest_num, owner, nil, "on", own_num)
		minetest.after(1, send_off_command, pos)
	end
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	store_action(pos, player, "put", stack)
	send_command(pos)
	return stack:get_count()
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	store_action(pos, player, "take", stack)
	send_command(pos)
	return stack:get_count()
end

local function formspec()
	return "size[12,10]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;main;0,0;12,6;]"..
	"list[current_player;main;2,6.3;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

minetest.register_node("tubelib_addons3:chest", {
	description = S("HighPerf Chest"),
	tiles = {
		-- up, down, right, left, back, front
		'tubelib_addons3_chest_bottom.png',
		'tubelib_addons3_chest_bottom.png',
		"tubelib_addons3_chest_side.png",
		"tubelib_addons3_chest_side.png",
		"tubelib_addons3_chest_side.png",
		"tubelib_addons3_chest_front.png",
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('main', 72)
	end,

	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "tubelib_addons3:chest")
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("formspec", formspec())
		meta:set_string("infotext", S("HighPerf Chest").." "..number)
	end,

	can_dig = function(pos,player)
		if minetest.is_protected(pos, player:get_player_name()) then
			return false
		end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("main")
	end,

	on_dig = function(pos, node, puncher, pointed_thing)
		minetest.node_dig(pos, node, puncher, pointed_thing)
		tubelib.remove_node(pos)
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_blast = function() end,
})


minetest.register_craft({
	output = "tubelib_addons3:chest",
	recipe = {
		{"default:tin_ingot", "tubelib_addons1:chest", ""},
		{"tubelib_addons1:chest", "default:gold_ingot", ""},
		{"", "", ""},
	},
})

tubelib.register_node("tubelib_addons3:chest", {}, {
	on_pull_stack = function(pos, side)
		local meta = minetest.get_meta(pos)
		return tubelib.get_stack(meta, "main")
	end,
	on_pull_item = function(pos, side)
		local meta = minetest.get_meta(pos)
		return tubelib.get_item(meta, "main")
	end,
	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "main", item, tubelib.refill)
	end,
	on_unpull_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "main", item)
	end,

	on_recv_message = function(pos, topic, payload)
		if topic == "state" then
			local meta = minetest.get_meta(pos)
			return tubelib.get_inv_state(meta, "main")
		elseif topic == "player_action" then
			local meta = minetest.get_meta(pos)
			local number = meta:get_string("number")
			return PlayerActions[number]
		elseif topic == "set_numbers" then
			if tubelib.check_numbers(payload) then
				local meta = minetest.get_meta(pos)
				meta:set_string("dest_num", payload)
				local number = meta:get_string("number")
				meta:set_string("infotext", S("HighPerf Chest").." "..number.." "..S("connected with").." "..payload)
				return true
			end
		else
			return "unsupported"
		end
	end,
})
