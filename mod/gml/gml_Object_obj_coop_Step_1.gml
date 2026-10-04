coop_try(zs_fps_begin_step);
if (global.zs_rf) exit;
coop_try(coop_npc_guest_purge);
coop_try(coop_down_begin_step);
coop_try(coop_panel_begin_step);
