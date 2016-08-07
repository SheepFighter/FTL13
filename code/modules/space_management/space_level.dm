/datum/space_level
	var/name = "Your config settings failed, you need to fix this for the datum space levels to work"
	var/zpos = 1
	var/flags = list() // We'll use this to keep track of whether you can teleport/etc

	// Map transition stuff
	var/list/neighbors = list()
	// # How this level connects with others. See __MAP_DEFINES.dm for defines
	var/linkage = SELFLOOPING
	// # imaginary placements on the grid - these reflect the point it is linked to
	var/xi
	var/yi
	var/list/transit_north = list()
	var/list/transit_south = list()
	var/list/transit_east = list()
	var/list/transit_west = list()

	// Init deferral stuff
	var/dirt_count = 0
	var/list/init_list = list()

/datum/space_level/New(z, name, transition_type = SELFLOOPING, traits = list(BLOCK_TELEPORT))
	zpos = z
	flags = traits
	set_linkage(transition_type)
	build_space_destination_arrays()

/datum/space_level/proc/build_space_destination_arrays()
	// Bottom border
	for(var/turf/open/space/S in block(locate(1,1,zpos),locate(world.maxz,TRANSITIONEDGE,zpos)))
		transit_south |= S

	// Top border
	for(var/turf/open/space/S in block(locate(1,world.maxy,zpos),locate(world.maxz,world.maxy - TRANSITIONEDGE - 1,zpos)))
		transit_north |= S

	// Left border
	for(var/turf/open/space/S in block(locate(1,TRANSITIONEDGE+1,zpos),locate(TRANSITIONEDGE,world.maxy - TRANSITIONEDGE - 2,zpos)))
		transit_west |= S

	// Right border
	for(var/turf/open/space/S in block(locate(world.maxx - TRANSITIONEDGE - 1,TRANSITIONEDGE+1,zpos),locate(world.maxx,world.maxy - TRANSITIONEDGE - 2,zpos)))
		transit_east |= S

/datum/space_level/proc/get_turfs()
	return block(locate(1, 1, zpos), locate(world.maxx, world.maxy, zpos))

/datum/space_level/proc/set_linkage(transition_type)
	linkage = transition_type
	if(transition_type == SELFLOOPING)
		link_to_self() // `link_to_self` is defined in space_transitions.dm
	if(transition_type == UNAFFECTED)
		reset_connections()

/datum/space_level/proc/resume_init()
	if(dirt_count > 0)
		throw EXCEPTION("Init told to resume when z-level still dirty. Z level: '[zpos]'")
	log_debug("Releasing freeze on z-level '[zpos]'!")
	log_debug("Beginning initialization!")
	var/list/our_atoms = init_list // OURS NOW!!! (Keeping this list to ourselves will prevent hijack)
	init_list = list()
	var/list/late_maps = list()
	var/list/pipes = list()
	// var/list/cables = list()
	for(var/schmoo in our_atoms)
		var/atom/movable/AM = schmoo
		if(AM) // to catch stuff like the nuke disk that no longer exists

			// This can mess with our state - we leave these for last
			if(istype(AM, /obj/effect/landmark/map_loader))
				late_maps.Add(AM)
				continue
			AM.initialize()
			if(istype(AM, /obj/machinery/atmospherics))
				pipes.Add(AM)
			// else if(istype(AM, /obj/structure/cable))
			// 	cables.Add(AM)
	log_debug("Primary initialization finished.")
	our_atoms.Cut()
	if(pipes.len)
		do_pipes(pipes)
	// if(cables.len)
	// 	do_cables(cables)
	if(late_maps.len)
		do_late_maps(late_maps)

/datum/space_level/proc/do_pipes(list/pipes)
	log_debug("Building pipenets on z-level '[zpos]'!")
	for(var/schmoo in pipes)
		var/obj/machinery/atmospherics/machine = schmoo
		if(machine)
			machine.build_network()
	pipes.Cut()
/* Not sure if you guys have powernets
/datum/space_level/proc/do_cables(list/cables)
	var/watch = start_watch()
	log_debug("Building powernets on z-level '[zpos]'!")
	for(var/schmoo in cables)
		var/obj/structure/cable/C = schmoo
		if(C)
			makepowernet_for(C)
	cables.Cut()
	log_debug("Took [stop_watch(watch)]s")
*/
// Not sure if you guys have map loaders
/datum/space_level/proc/do_late_maps(list/late_maps)
	space_manager.add_dirt(zpos) // Let's not repeatedly resume init for each template
	for(var/schmoo in late_maps)
		var/obj/effect/landmark/map_loader/ML = schmoo
		if(ML)
			ML.initialize()
	late_maps.Cut()
	space_manager.remove_dirt(zpos)