// Travel Chests

#macro TRAVELING_CHESTS global.__traveling_chests
global.__traveling_chests = undefined;

// runtime state initialization
function __travel_chests_runtime() {
    if (global[$ "__travel_chests"] == undefined) {
        global.__travel_chests = { registered_hooks: undefined };
    }
    return global.__travel_chests;
}

// hook callback registration
function travel_chests_register_callbacks() {
    var _rt = __travel_chests_runtime();
    if (_rt.registered_hooks != undefined) return;
    _rt.registered_hooks = true;

    // save registration. writes to mod_data/travel_chests/saves/<prefix>.json
    mmapi_modsave_register("travel_chests", travel_chests_save_collect, travel_chests_save_apply);

    // filter hook registration. fires at top of pick_node()
    mmapi_filter("resource.node_modifier", travel_chests_mod_node_modifier);

    // filter hook registration. fires at the top of give_item()
    mmapi_filter("items.give", travel_chests_mod_give);

    // guard hook registration. fires at top of write_furniture_to_location()
    mmapi_guard("furniture.place_guard", travel_chests_mod_place_guard);
}

// hook callback
function travel_chests_mod_node_modifier(_value, _ctx) {
    if (_value == undefined) return undefined;

    if (_ctx.action == "pick") {
        var is_rug_pick = false;
        var inst_index = undefined;
        var object_id = undefined;
        var breaker = false;

        for (var xx = 0; xx < 2; xx++) {
            if breaker {
                break;
            }

            for (var yy = 0; yy < 2; yy++) {
                var found = _ctx.grid.try_node_index_for_cell(_ctx.x + xx, _ctx.y + yy);
                if found != undefined && (_ctx.grid.node_object_id[found] != undefined || _ctx.grid.node_rug_id[found] != undefined) {
                    inst_index = found;
                    breaker = true;

                    if _ctx.grid.node_object_id[found] == undefined && _ctx.grid.node_rug_id[found] != undefined {
                        is_rug_pick = true;
                        object_id = undefined; // don't care if it's a rug
                    } else {
                        mmapi_log_info("travel_chests", "found: " + string(found));
                        mmapi_log_flush("travel_chests");

                        object_id = _ctx.grid.node_object_id[inst_index];
                    }
                    break;
                }
            }
        }

        if object_id != undefined {
            var category = object_id_to_object_category(object_id);

            // if it is furniture that is a chest, grab the node's inventory
            if (category == ObjectCategory.Furniture && NODE_PROTOTYPES[object_id].interaction_chest != undefined) {
                mmapi_log_info("travel_chests", "chest broken!");
                mmapi_log_flush("travel_chests");

                var node = _ctx.grid.node_parent[inst_index];
                var inventory = node.inventory;

                if inventory != undefined {
                    var pick_sfx = fiddle_get("tool_fx/pick");
                    var doppel = new TangoDoppel();
                    
                    doppel.play_good(pick_sfx.furniture.sfx);
                    set_rumble(RumbleKind.FurnitureRemove);
                    CAMERA.add_trauma(pick_sfx.furniture.cam_trauma);

                    doppel.resolve();

                    node.inventory = new Inventory(NODE_PROTOTYPES[object_id].interaction_chest.inventory_size);

                    var item_proto = find_item_prototype(object_id);

                    if item_proto != undefined {
                        var live_item = new LiveItem(item_proto.item_id);

                        if live_item.infusion == undefined {
                            live_item.infusion = try_string_to_infusion(node.infusion);
                        }

                        if global.__traveling_chests == undefined {
                            global.__traveling_chests = List();
                        }

                        global.__traveling_chests.push(inventory);
                        var curr = global.__traveling_chests.count() - 1;

                        live_item.inner_item = curr;

                        drop_item(live_item, node.renderer.x, node.renderer.y);

                        erase_object_node(_ctx.grid, inst_index);

                        return 0;
                    }
                }
            }
        }
        return undefined;
    }
}

// debug check. to be deleted once functional
function travel_chests_mod_give(_value, _ctx) {
    if (_value == undefined) return undefined;
    var item = _value.item;
    item = is_struct(item) ? item : new LiveItem(item);

    // if it's a chest, check if it's currently a travel chest,
    // because we don't want to iterate through the list unless we *have* to
    if (item.prototype.tags.contains("chest_and_storage")) {
        mmapi_log_info("travel_chests", "inner_item: " + string(item.inner_item));
        mmapi_log_flush("travel_chests");
    }
    return undefined;
}

function travel_chests_mod_place_guard(_ctx) {
    // if the held item is an interaction_chest with an inner_item, it's a travel chest
    if (_ctx.proto.interaction_chest != undefined && _ctx.stack_count == 0) {
        var item = global.__ari.held_item();

        if (item.inner_item != undefined) {
            var xx = _ctx.x;
            var yy = _ctx.y

            var calc_rot = furniture_rotation_amount(_ctx.rotation, _ctx.proto);

            var rotation_matrix = furniture_calc_rot_to_rotation_matrix(calc_rot, _ctx.proto);

            var region = furniture_size(rotation_matrix, _ctx.proto);
            if local_pos_is_valid(_ctx.grid, xx, yy, region) == false {
                return undefined;
            }
            
            var rot_data = furniture_mask_prep_vecdata(_ctx.proto.size, rotation_matrix);

            var node = create_parent_object_node(_ctx.proto, xx, yy, region);
            node.cardinal_index = calc_rot;
            node.destructable =  _ctx.proto.destructable;
            node.infusion =  undefined;
            node.date_photo =  undefined;
            node.on = false;

            var old_terrain = undefined;
            if _ctx.proto.output_terrain != undefined {
                old_terrain = array_create(_ctx.proto.size.x * _ctx.proto.size.y, undefined);
            }

            for (var i = 0; i < _ctx.proto.size.x; i++) {
                for (var j = 0; j < _ctx.proto.size.y; j++) {
                    rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
                    rot_data.offset.set_rotate(rotation_matrix);
                    var posx = xx + abs(rot_data.transform.x) + rot_data.offset.x;
                    var posy = yy + abs(rot_data.transform.y) + rot_data.offset.y;
                    var this_cell_node = _ctx.grid.try_node_index_for_cell(posx, posy);

                    write_object_inst_node(_ctx.grid, this_cell_node, node);
                    set_collision_grid_flag_on_node(_ctx.grid, _ctx.proto.collision_grid[# i, j], posx, posy);
                }
            }

            node.old_terrain = old_terrain;
            if old_terrain != undefined {
                array_push(_ctx.grid.terrain_editors, node);
            }

            if _ctx.proto.sub_grid != undefined {
                var grid_vec = furniture_mask_prep_vecdata(_ctx.proto.size, rotation_matrix);
                node.child_grid = new Grid(region.x, region.y, _ctx.grid.location_id);
                node.child_grid.parent_node = node;

                //
                for (var i = 0; i < _ctx.proto.size.x; i ++) {
                    for (var j = 0; j < _ctx.proto.size.y; j ++) {
                        grid_vec.offset.set_val(i - grid_vec.center.x, j - grid_vec.center.y);
                        grid_vec.offset.set_rotate(rotation_matrix);
                        var posx = abs(grid_vec.transform.x) + grid_vec.offset.x;
                        var posy = abs(grid_vec.transform.y) + grid_vec.offset.y;

                        write_ground_to_location(node.child_grid, posx, posy, TerrainKind.Ground);
                        var inner_node = node.child_grid.node_index_for_cell(posx, posy);
                        node.child_grid.node_flags[inner_node] = _ctx.proto.sub_grid[# i, j];
                    }
                }
            } else {
                node.child_grid = undefined;
            }

            node.parent_grid = _ctx.grid;

            if node.prototype.interaction_turn_on != undefined {
                node.is_on = false;
            }

            if node.prototype.write_flag != undefined {
                T2R.write(node.prototype.write_flag, true);
            }

            if node.prototype.interaction_chest != undefined {
                if global.__traveling_chests.get(item.inner_item) == undefined {
                    mmapi_log_info("travel_chests", "chest inventory " + string(item.inner_item) + " does not exist");
                    mmapi_log_flush("travel_chests");
                    return false;
                }
                node.inventory = global.__traveling_chests.get(item.inner_item);
                node.chest_icon = undefined;

                global.__traveling_chests.remove(item.inner_item);

                if node.prototype.interaction_chest.allow_soulbound == false {
                    node.inventory.slots.for_each(function(slot) {
                        slot.allow_soulbound = false;
                    });
                };
            }
            
            if (node != undefined && _ctx.grid.location_id == CURRENT_LOCATION_ID) {
                if node[$ "inventory"] != undefined {
                    STORAGE_NODES.push(node);
                    node.use_in_crafting = node.prototype.interaction_chest != undefined
                        && node.prototype.interaction_chest.belongs_to_ari
                        && !node.prototype.interaction_chest.shipping_bin;
                }

                _ctx.grid.initialize_node_renderer(node);

                var old = GAME_STATS.furniture_placed[$ object_id_to_string(item.prototype.object)] ?? 0;
                GAME_STATS.furniture_placed[$ object_id_to_string(item.prototype.object)] = old + 1;

                TANGO.play("SoundEffects/UI/UIPlaceBuilding");
                set_rumble(RumbleKind.FurniturePlace);

                global.__ari.inventory.slot(global.__ari.held_item_index).pop();
            }

            return false;
        }
    }

    return undefined;
}

function travel_chests_save_collect(){
    json3 = global.__traveling_chests.serialize();
    mmapi_log_info("travel_chests", "serialize: " + string(json3));
    mmapi_log_flush("travel_chests");

    json = json_encode(global.__traveling_chests);

    mmapi_log_info("travel_chests", "encode: " + string(json));
    mmapi_log_flush("travel_chests");

    json2 = json_stringify(global.__traveling_chests);

    mmapi_log_info("travel_chests", "stringify: " + string(json2));
    mmapi_log_flush("travel_chests");

    return json;
}

function travel_chests_save_apply(data){
    if data != undefined {
        mmapi_log_info("travel_chests", "data: " + string(data));
        mmapi_log_flush("travel_chests");
        
        global.__traveling_chests = ds_list_create();
        //global.__traveling_chests = deserialize(data);
    }
}

// MMAPI mod declaration + hook registration
mmapi_mod_declare("travel_chests", "1.0.0");
travel_chests_register_callbacks();