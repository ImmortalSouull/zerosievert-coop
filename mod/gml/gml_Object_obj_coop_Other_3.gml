// Game End: a clean exit - no rejoin offer next time (a crash skips this event)
coop_try(coop_rejoin_forget);
coop_try(coop_net_stop);
