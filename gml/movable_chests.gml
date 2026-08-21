// Travel Chests

// runtime state initialization
function __movable_chests_runtime() {
    if (global[$ "__movable_chests"] == undefined) {
        global.__movable_chests = { registered_hooks: undefined };
    }
    return global.__movable_chests;
}

// hook callback registration
function movable_chests_register_callbacks() {
    var _rt = __movable_chests_runtime();
    if (_rt.registered_hooks != undefined) return;
    _rt.registered_hooks = true;

    // filter hook registration. fires at top of pick_node()
    mmapi_filter("resource.node_modifier", movable_chests_mod_node_modifier); 

    // event hook registration. fires at the top of give_item()
    mmapi_filter("items.give", movable_chests_mod_give);

    // guard hook registration. fires at top of write_furniture_to_location()
    mmapi_guard("furniture.place_guard", movable_chests_mod_place_guard); 
}

// hook callback
function movable_chests_mod_node_modifier(_value, _ctx) {
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
                        mmapi_log_info("movable_chests", "found: " + string(found));
                        mmapi_log_flush("movable_chests");

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
                mmapi_log_info("movable_chests", "chest broken!");
                mmapi_log_flush("movable_chests");

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
                        live_item.inner_item = inventory;

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


function movable_chests_mod_give(_value, _ctx) {
    if (_value == undefined) return undefined;
    var item = _value.item;
    item = is_struct(item) ? item : new LiveItem(item);

    // if it's a chest, check if it's currently a travel chest,
    // because we don't want to iterate through the list unless we *have* to
    if (item.prototype.tags.contains("chest_and_storage")) {
        mmapi_log_info("movable_chests", "inner_item: " + string(item.inner_item));
        mmapi_log_flush("movable_chests");
    }
    return undefined;
}

function movable_chests_mod_place_guard(_ctx) {
    // if the held item is an interaction_chest with an inner_item, it's a travel chest
    if (_ctx.proto.tags.interaction_chest != undefined && _ctx.stack_count == 0) {
        var item = global.__ari.held_item();

        if (item.inner_item != undefined) {
            var xx = _ctx.x;
            var yy = _ctx.y

            var calc_rot = furniture_rotation_amount(_ctx.rotation, _ctx.proto);

            var rotation_matrix = furniture_calc_rot_to_rotation_matrix(calc_rot, _ctx.proto);

            var region = furniture_size(rotation_matrix, _ctx.proto);
            if local_pos_is_valid(grid, xx, yy, region) == false {
                return undefined;
            }
            
            var rot_data = furniture_mask_prep_vecdata(_ctx.proto.size, rotation_matrix);

            var node = create_parent_object_node(_ctx.proto, xx, yy, region);
            node.cardinal_index = calc_rot;
            node.destructable =  _ctx.proto.destructable;
            node.on = false;

            for (var i = 0; i < _ctx.proto.size.x; i++) {
                for (var j = 0; j < _ctx.proto.size.y; j++) {
                    rot_data.offset.set_val(i - rot_data.center.x, j - rot_data.center.y);
                    rot_data.offset.set_rotate(rotation_matrix);
                    var posx = xx + abs(rot_data.transform.x) + rot_data.offset.x;
                    var posy = yy + abs(rot_data.transform.y) + rot_data.offset.y;
                    var this_cell_node = grid.try_node_index_for_cell(posx, posy);

                    write_object_inst_node(grid, this_cell_node, node);
                    set_collision_grid_flag_on_node(grid, _ctx.proto.collision_grid[# i, j], posx, posy);
                }
            }


            if node.prototype.interaction_chest != undefined {
                node.inventory = item.inner_item;
                node.chest_icon = undefined;

                if node.prototype.interaction_chest.allow_soulbound == false {
                    node.inventory.slots.for_each(function(slot) {
                        slot.allow_soulbound = false;
                    });
                };
            }

            return 0;
        }
    }

    return undefined;
}

// MMAPI mod declaration + hook registration
mmapi_mod_declare("movable_chests", "1.0.0");
movable_chests_register_callbacks();