// ZERO Sievert co-op: key doors. Opening one (lab, armory, sewer...) removes the wall under it; the partner's
// copy opens too (without using their key). Doors are matched by object + starting position.

#macro COOP_MSG_DOOR 65

function coop_door_key(_d)
{
    return string(real(_d.object_index)) + "_" + string(floor(_d.xstart)) + "_" + string(floor(_d.ystart));
}

function coop_doors_step()
{
    var _c = coop();
    if (!coop_shared_ready() || _c.frame mod 15 != 7)
    {
        exit;
    }
    with (obj_door_parent)
    {
        if (open && !variable_instance_exists(id, "coop_door_sent"))
        {
            coop_door_sent = true;
            coop_msg_begin(COOP_MSG_DOOR);
            buffer_write(_c.send_buf, buffer_string, coop_door_key(id));
            coop_msg_send(true);
            coop_log("door opened, sent ", coop_door_key(id));
        }
    }
}

// Host: a late joiner needs every door that is already open.
function coop_doors_resend_all()
{
    instance_activate_object(obj_door_parent);
    with (obj_door_parent)
    {
        if (variable_instance_exists(id, "coop_door_sent"))
        {
            variable_instance_set(id, "coop_door_sent", undefined);
        }
    }
    with (obj_door_parent)
    {
        if (open)
        {
            var _c = coop();
            coop_msg_begin(COOP_MSG_DOOR);
            buffer_write(_c.send_buf, buffer_string, coop_door_key(id));
            coop_msg_send(true);
            coop_door_sent = true;
        }
    }
}

function coop_door_on_message(_b)
{
    var _key = buffer_read(_b, buffer_string);
    if (!coop_in_raid())
    {
        exit;
    }
    instance_activate_object(obj_door_parent);
    with (obj_door_parent)
    {
        if (coop_door_key(id) != _key || open)
        {
            continue;
        }
        // Same steps as player_action_interact, minus the key.
        if (place_meeting(x, y, obj_solid))
        {
            var _s = instance_place(x, y, obj_solid);
            var _xx = _s.x;
            var _yy = _s.y;
            with (_s)
            {
                instance_destroy();
            }
            x = _xx;
            y = _yy;
            depth = -_yy;
        }
        sprite_index = global.door_sprite_open[id_door];
        visible = true;
        open = true;
        coop_door_sent = true;
        coop_log("door opened by partner ", _key);
    }
}
