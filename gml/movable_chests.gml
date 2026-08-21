#macro MY_TRAVEL_CHESTS global.__my_travel_chests
global.__my_travel_chests = ds_list_create();

function __TravelChest(item_id, inventory, picked_up) constructor {
    self.item_id = item_id;
    self.inventory = inventory;
    self. picked_up = picked_up;
}

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
                node.inventory = new Inventory(NODE_PROTOTYPES[object_id].interaction_chest.inventory_size);
                chest = new __TravelChest(find_item_prototype(object_id).item_id, inventory, false);

                ds_list_add(global.__my_travel_chests, chest);

                var curr = ds_list_size(global.__my_travel_chests) - 1;

                mmapi_log_info("movable_chests", "curr: " + string(curr));
                mmapi_log_flush("movable_chests");

                mmapi_log_info("movable_chests", "item: " + string(global.__my_travel_chests[curr].item_id));
                mmapi_log_flush("movable_chests");
                mmapi_log_info("movable_chests", "inventory: " + string(global.__my_travel_chests[curr].inventory));
                mmapi_log_flush("movable_chests");
                mmapi_log_info("movable_chests", "picked up? " + string(global.__my_travel_chests[curr].picked_up));
                mmapi_log_flush("movable_chests");
            }
        }
    }
    return undefined;
}


function movable_chests_mod_give(_value, _ctx) {
    if (_value == undefined) return undefined;
    var item = _value.item;
    item = is_struct(item) ? item : new LiveItem(item);

    // if it's a chest, check if it's currently a travel chest,
    // because we don't want to iterate through the list unless we *have* to
    if (item.prototype.tags.contains("chest_and_storage")) {
        for (var i = 0; i < ds_list_size(global.__my_travel_chests); i++) {
            if (global.__my_travel_chests[i].picked_up == false && global.__my_travel_chests[i].item_id == item.item_id) {
                mmapi_log_info("movable_chests", "it is a travel chest!");
                mmapi_log_flush("movable_chests");

                item.inner_item = global.__my_travel_chests[i].inventory;

                mmapi_log_info("movable_chests", "inner_item: " + string(item.inner_item));
                mmapi_log_flush("movable_chests");
                
                return item;
            }
        }
    }

    
    
    return undefined;
}

// function movable_chests_mod_drop(_ctx){
//     mmapi_log_info("movable_chests", "dropping");
//     mmapi_log_flush("movable_chests");
// }

// MMAPI mod declaration + hook registration
mmapi_mod_declare("movable_chests", "1.0.0");
movable_chests_register_callbacks();