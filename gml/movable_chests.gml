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
    // guard hook registration. fires at top of write_furniture_to_location()
    //mmapi_guard("furniture.place_guard", movable_chests_mod_place_guard); 
}

// hook callback
function movable_chests_mod_node_modifier(_value, _ctx) {
    mmapi_log_info("movable_chests", "hello mistria");
    mmapi_log_flush("movable_chests");
    var is_rug_pick = false;
    var inst_index = undefined;
    var object_id = undefined;
    var breaker = false;
    var x;
    var y;

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
                    object_id = undefined; // don't care anymore if it's a rug
                } else {
                    mmapi_log_info("movable_chests", "found: " + string(found));
                    mmapi_log_flush("movable_chests");

                    object_id = _ctx.grid.node_object_id[inst_index];

                    x = _ctx.x + xx;
                    y = _ctx.y + yy;
                }
                break;
            }
        }
    }

    if object_id != undefined {
        var category = object_id_to_object_category(object_id);

        // if it is furniture that is a chest, grab the node's inventory
        if category == ObjectCategory.Furniture && NODE_PROTOTYPES[object_id].interaction_chest != undefined {
            var node = _ctx.grid.node_parent[inst_index];
            var inventory = node.inventory;

        }
    }
    return undefined;
}


// MMAPI mod declaration + hook registration
mmapi_mod_declare("movable_chests", "1.0.0");
movable_chests_register_callbacks();