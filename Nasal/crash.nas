#
# A Flightgear crash and stress damage system.
#
# Inspired and developed from the crash system in Mig15 by Slavutinsky Victor. And by Hvengel's formula for wingload stress.
#
# Authors: Slavutinsky Victor, Nikolai V. Chr. (Necolatis)
#
#
# Version 0.18
#
# License:
#   GPL 2.0
#
# Modified from the crash system in JA37.
#

var TRUE = 1;
var FALSE = 0;
var Hardness	= { soft: 0.05, medium: 0.5, hard: 1.0 };
var DamageLevel = -1;
var gearLoad	= props.globals.getNode("fdm/jsbsim/gear/load-factor");

## Define impact factor based on height of object, its hardness and the position of the wheels
var impactFactor = func (height, hardness) {
    var gear_pos = 0;
    ## Get average extension of gear
    for (g=0; g < 5; g = g+1) {
	gear_pos = gear_pos + getprop("gear/gear["~g~"]/position-norm");
    }
    ## the landing gear is 2.9m below the body when fully extended
    ## but we are not concerned with objects hitting the wheels hence 2m below
    gear_pos = 2.0 * gear_pos / 5;

    # normalized the factor between -1 and 1 with a slight offset to account for oceans
    var factor = math.clamp((height - gear_pos), -0.1, 1.0);
    factor = (factor + 0.1) * hardness;

    ## Update the damage level due to the new hit
    if (factor > DamageLevel) {
	DamageLevel = factor;
    } else {
	# allow three hits - reduce individual damage tp 30%
	DamageLevel = DamageLevel + 0.3 * factor;
	DamageLevel = (DamageLevel > 1.0) ? 1.0 : DamageLevel;
    }

    return factor;
};


#-----------------------------------------------------------------------
# Aircraft break

var CrashAndStress = {
	# pattern singleton
	_instance: nil,
	# Get the instance
	new: func (gears, stressLimit = nil, wingsFailureModes = nil) {

		var m = nil;
		if(me._instance == nil) {
			me._instance = {};
			me._instance["parents"] = [CrashAndStress];

			m = me._instance;

			m.inService = FALSE;
			m.repairing = FALSE;

			m.exploded = FALSE;

			m.wingsAttached = TRUE;
			m.wingLoadLimitUpper = nil;
			m.wingLoadLimitLower = nil;
			m._looptimer = maketimer(0, m, m._loop);

			m.repairTimer = maketimer(10.0, m, CrashAndStress._finishRepair);
			m.repairTimer.singleShot = 1;

			m.soundWaterTimer = maketimer(3, m, CrashAndStress._impactSoundWaterEnd);
			m.soundWaterTimer.singleShot = 1;

			m.soundTimer = maketimer(3, m, CrashAndStress._impactSoundEnd);
			m.soundTimer.singleShot = 1;

			m.explodeTimer = maketimer(3, m, CrashAndStress._explodeEnd);
			m.explodeTimer.singleShot = 1;

			m.stressTimer = maketimer(3, m, CrashAndStress._stressDamageEnd);
			m.stressTimer.singleShot = 1;

			m.input = {
			    replay:     "sim/replay/replay-state",
			    simCrashed: "sim/crashed",
			    lat:        "position/latitude-deg",
			    lon:        "position/longitude-deg",
			    alt:        "position/altitude-ft",
			    altAgl:     "position/gear-agl-ft",
			    elev:       "position/ground-elev-ft",
			    crackOn:    "damage/sounds/crack-on",
			    creakOn:    "damage/sounds/creaking-on",
			    crackVol:   "damage/sounds/crack-volume",
			    creakVol:   "damage/sounds/creaking-volume",
			    wCrashOn:   "damage/sounds/water-crash-on",
			    crashOn:    "damage/sounds/crash-on",
			    detachOn:   "damage/sounds/detach-on",
			    explodeOn:  "damage/sounds/explode-on",
			    wildfire:   "environment/wildfire/fire-on-crash"
			};

			foreach(var ident; keys(m.input)) {
			    m.input[ident] = props.globals.getNode(m.input[ident], 1);
			}

			m.fdm = jsbSimProp;
			m.fdm.convert();

			m.wowStructure = [];
			m.wowGear = [];

			m.lastMessageTime = 0;

			m._initProperties();
			m._identifyGears(gears);
			m.setStressLimit(stressLimit);
			m.setWingsFailureModes(wingsFailureModes);

			m._startImpactListeners();
		} else {
			m = me._instance;
		}

		return m;
	},
	# start the system
	start: func () {
		me.inService = TRUE;
	},
	# stop the system
	stop: func () {
		me.inService = FALSE;
	},
	# return TRUE if in progress
	isStarted: func () {
		return me.inService;
	},
	# accepts a vector with failure mode IDs, they will fail when wings break off.
	setWingsFailureModes: func (modes) {
	    if(modes == nil) {
		modes = [];
	    }

	    # Returns an actuator object that will set the serviceable property at
	    # the given node to zero when the level of failure is > 0.
	    # it will also fail additionally failure modes.

	    var set_unserviceable_cascading = func(path, casc_paths) {

	        var prop = path ~ "/serviceable";

	        if (props.globals.getNode(prop) == nil) {
	            props.globals.initNode(prop, TRUE, "BOOL");
	        } else {
			props.globals.getNode(prop).setBoolValue(TRUE);
			# in case this gets initialized empty from a recorder signal or MP alias.
	        }

	        return {
	            parents: [FailureMgr.FailureActuator],
	            mode_paths: casc_paths,
	            set_failure_level: func(level) {
	                setprop(prop, level > 0 ? 0 : 1);
	                foreach(var mode_path ; me.mode_paths) {
	                    FailureMgr.set_failure_level(mode_path, level);
	                }
	            },
	            get_failure_level: func { getprop(prop) ? 0 : 1 }
	        }
	    }

	    me.prop = me.fdm.wingsFailureID;
	    me.actuator_wings = set_unserviceable_cascading(me.prop, modes);
	    FailureMgr.add_failure_mode(me.prop, "Main wings", me.actuator_wings);
	},
	# set the stresslimit for the main wings
	setStressLimit: func (stressLimit = nil) {
		if (stressLimit != nil) {
			me.wingloadMax = stressLimit['wingloadMaxLbs'];
			me.wingloadMin = stressLimit['wingloadMinLbs'];
			me.maxG = stressLimit['maxG'];
			me.minG = stressLimit['minG'];
			me.weight = stressLimit['weightLbs'];
			if(me.wingloadMax != nil) {
				me.wingLoadLimitUpper = me.wingloadMax;
			} elsif (me.maxG != nil and me.weight != nil) {
				me.wingLoadLimitUpper = me.maxG * me.weight;
			}

			if(me.wingloadMin != nil) {
				me.wingLoadLimitLower = me.wingloadMin;
			} elsif (me.minG != nil and me.weight != nil) {
				me.wingLoadLimitLower = me.minG * me.weight;
			} elsif (me.wingLoadLimitUpper != nil) {
				me.wingLoadLimitLower = -me.wingLoadLimitUpper * 0.4;
				# estimate for when lower is not specified
			}
			me._looptimer.start();
		} else {
			me._looptimer.stop();
		}
	},
	# repair the aircaft
	repair: func () {
		me.failure_modes = FailureMgr._failmgr.failure_modes;
		me.mode_list = keys(me.failure_modes);

		foreach(var failure_mode_id; me.mode_list) {
			FailureMgr.set_failure_level(failure_mode_id, 0);
		}
		me.wingsAttached = TRUE;
		me.exploded = FALSE;
		me.lastMessageTime = 0;
		me.repairing = TRUE;
		me.input.simCrashed.setBoolValue(FALSE);
		me.repairTimer.restart(10.0);
	},
	_finishRepair: func () {
		me.repairing = FALSE;
	},
	_initProperties: func () {
		me.input.crackOn.setBoolValue(FALSE);
		me.input.creakOn.setBoolValue(FALSE);
		me.input.crackVol.setDoubleValue(0.0);
		me.input.creakVol.setDoubleValue(0.0);
		me.input.wCrashOn.setBoolValue(FALSE);
		me.input.crashOn.setBoolValue(FALSE);
		me.input.detachOn.setBoolValue(FALSE);
		me.input.explodeOn.setBoolValue(FALSE);
	},
	_identifyGears: func (gears) {
		me.contacts = props.globals.getNode("/gear").getChildren("gear");

		foreach(var contact; me.contacts) {
			me.index = contact.getIndex();
			me.isGear = me._contains(gears, me.index);
			me.wow = contact.getChild("wow");
			if (me.isGear == TRUE) {
				append(me.wowGear, me.wow);
			} else {
				append(me.wowStructure, me.wow);
			}
		}
	},
	_isStructureInContact: func () {
		foreach(var structure; me.wowStructure) {
			if (structure.getBoolValue() == TRUE) {
				return TRUE;
			}
		}
		return FALSE;
	},
	_isGearInContact: func () {
		foreach(var gear; me.wowGear) {
			if (gear.getBoolValue() == TRUE) {
				return TRUE;
			}
		}
		return FALSE;
	},
	_contains: func (vector, content) {
		foreach(var vari; vector) {
			if (vari == content) {
				return TRUE;
			}
		}
		return FALSE;
	},
	_startImpactListeners: func () {
		ImpactStructureListener.crash = me;
		foreach(var structure; me.wowStructure) {
			setlistener(structure, func {call(ImpactStructureListener.run, nil, ImpactStructureListener, ImpactStructureListener)},0,0);
		}
	},
	_isRunning: func () {
		if (me.inService == FALSE or me.input.replay.getBoolValue() == TRUE or me.repairing == TRUE) {
			return FALSE;
		}
		me.time = me.fdm.input.simTime.getValue();
		if (me.time != nil and me.time > 1) {
			return TRUE;
		}
		return FALSE;
	},
	_calcGroundSpeed: func () {
		me.realSpeed = me.fdm.getSpeedRelGround();

		return me.realSpeed;
	},
	_impactDamage: func () {
	    me.lat = me.input.lat.getValue();
		me.lon = me.input.lon.getValue();
		me.info = geodinfo(me.lat, me.lon);
		me.solid = me.info == nil?TRUE:(me.info[1] == nil?TRUE:me.info[1].solid);
		me.speed = me._calcGroundSpeed();
		var real_altitude_m = (FT2M * (me.input.alt.getValue() - me.input.elev.getValue()));
		var damage_factor = -1;
		var max_damage	  = -1;
		var obj_hardness  = Hardness.medium;
		var terrain_lege_height=0;

		if (me.exploded == FALSE) {
		    me.failure_modes = FailureMgr._failmgr.failure_modes;
		    me.mode_list = keys(me.failure_modes);
		    me.probability = (me.speed * me.speed) / 40000.0;

		    me.hitStr = "something";
		    if(me.info != nil and me.info[1] != nil) {
			me.hitStr = me.info[1].names == nil?"something":me.info[1].names[0];
			var prefix3 = substr(me.hitStr, 0, 3);
			var prefix8 = substr(me.hitStr, 0, 8);
			foreach(terrain_name; me.info[1].names) {
			    if ((terrain_lege_height < 25)
				    and
				    (
				     (terrain_name=="EvergreenForest")
				     or (terrain_name=="DeciduousForest")
				     or (terrain_name=="MixedForest")
				     or (terrain_name=="RainForest")
				     or (terrain_name=="Sclerophyllous")
				    )
			       )   {
				terrain_lege_height=25;
				me.hitStr = "tree in "~terrain_name;
				obj_hardness = Hardness.hard;
			    }

			    if ((terrain_lege_height < 25)
				    and
				    (
				     (terrain_name=="Urban")
				     or (terrain_name=="SubUrban")
				     or (terrain_name=="Town")
				    )
			       ) {
				terrain_lege_height=25;
				me.hitStr = "building in "~terrain_name;
				obj_hardness = Hardness.hard;
			    }

			    if ((terrain_lege_height < 20)
				    and
				    (
				     (terrain_name=="Orchard")
				     or  (terrain_name=="CropWood")
				    )
			       ) {
				terrain_lege_height=20;
				me.hitStr = "tree in "~terrain_name;
				obj_hardness = Hardness.hard;
			    }

			    if ((terrain_lege_height < 1)
				    and
				    (
				     (terrain_name=="Ocean")
				     or  (terrain_name=="Lake")
				    )
			       )
			    {
				terrain_lege_height=1;
				me.hitStr = "water wave in "~terrain_name;
				obj_hardness = Hardness.medium;
			    }

			    if ((terrain_lege_height < 0.25)
				    and
				    (
				     (terrain_name=="Heath")
				     or (terrain_name=="MixedCropPastureCover")
				     or (terrain_name=="ShrubCover")
				     or (terrain_name=="ShrubGrassCover")
				     or (terrain_name=="ScrubCover")
				     or (terrain_name=="Scrub")
				    )
			       ) {
				terrain_lege_height=0.25;
				me.hitStr = "bush in "~terrain_name;
				obj_hardness = Hardness.medium;
			    }

			    if ((terrain_lege_height < 0.1)
				    and
				    (
				     (terrain_name=="Pond")
				     or (terrain_name=="Resevoir")
				     or (terrain_name=="Steam")
				     or (terrain_name=="Canal")
				     or (terrain_name=="Lagoon")
				     or (terrain_name=="Estuary")
				     or (terrain_name=="Watercourse")
				     or (terrain_name=="Saline")
				    )
			       ) {
				terrain_lege_height=0.1;
				me.hitStr = "water wave in "~terrain_name;
				obj_hardness = Hardness.medium;
			    }

			    if ((terrain_lege_height < 0.1)
				    and
				    (
				     (terrain_name=="Landmass")
				     or (terrain_name=="BareTundraCover")
				     or (terrain_name=="MixedTundraCover")
				     or (terrain_name=="Cemetery")
				    )
			       ) {
				terrain_lege_height=0.1;
				me.hitStr = "ground in "~terrain_name;
				obj_hardness = Hardness.hard;
			    }

			    if ((terrain_lege_height < 0.1)
				    and
				    (
				     (terrain_name=="GrassCover")
				     or (terrain_name=="Greenspace")
				     or (terrain_name == "Grass")
				     or (terrain_name == "Grassland")
				    )
			       ) {
				terrain_lege_height=0.1;
				me.hitStr = "grass in "~terrain_name;
				obj_hardness = Hardness.soft;
			    }

			    if ((terrain_lege_height < 0.1)
				    and
				    (
				     (terrain_name=="Airport")
				    )
			       ) {
				terrain_lege_height=0.1;
				me.hitStr = " Airport";
				if (me.solid) obj_hardness = Hardness.medium;
			    }

			    if ((terrain_lege_height < 0.1)
				    and
				    (
				     (terrain_name=="SomeSort")
				     or (terrain_name=="Default")
				    )
			       ) {
				terrain_lege_height=0.1;
				me.hitStr = " something";
				if (me.solid) obj_hardness = Hardness.hard;
			    }

			    if ((terrain_lege_height == 0)
				    and
				    (
					(prefix3 == "pa_")
				     or (prefix3 == "pc_")
				     or (prefix3 == "lf_")
				     or (prefix8 == "dirt_rwy")
				     or (terrain_name == "AirportKeep")
				    )
			       ) {     # harmless runway object
				me.hitStr = "runway object "~terrain_name;
				# ignore these items
				obj_hardness = 0.0;
			    }

			    ## update the damage factor for each hit
			    damage_factor = impactFactor(real_altitude_m, obj_hardness);
			    max_damage = (max_damage < damage_factor) ? damage_factor : max_damage;
			}
		    }

		    if (real_altitude_m < terrain_lege_height and max_damage > 0.05) { # adopted from JA37
			# test for explosion
			if (me.probability > 0.766 and me.fdm.input.fuel.getValue() > 2500) {
			    # 175kt+ and fuel in tanks will explode the aircraft on impact.
			    me.input.simCrashed.setBoolValue(TRUE);
			    me._explodeBegin("Aircraft hit "~me.hitStr~",");
			    return;
			}
		    }

		    ## Failure results if the accumulative damage is too high
		    if (DamageLevel > 0.5) {
			enginesDamaged();
			me.input.simCrashed.setBoolValue(TRUE);
			logprint(LOG_ALERT, "Crash due to accumulative damage" );
			return;
		    }
		    elsif (max_damage < 0.10) {
			## If the maximum damage is minor, ignore it
			return;
		    }

		    var fail_level = 0;
		    foreach(var failure_mode_id; me.mode_list) {
			if(rand() < me.probability) {
			    fail_level = max_damage + FailureMgr.get_failure_level(failure_mode_id);
			    fail_level = (fail_level > 1) ? 1 : fail_level;
			    FailureMgr.set_failure_level(failure_mode_id, fail_level);
			}
		    }

		    me.str = "Aircraft hit "~me.hitStr~".";
		    me._output(me.str);

		} elsif (me.solid == TRUE) {
			# The aircraft is burning and will ignite the ground
			if(me.input.wildfire.getValue() == TRUE) {
				me.pos= geo.Coord.new().set_latlon(me.lat, me.lon);
				wildfire.ignite(me.pos, 1);
			}
		}
		if(me.solid == TRUE) {
			me._impactSoundBegin(me.speed);
		} else {
			me._impactSoundWaterBegin(me.speed);
		}
	},
	_impactSoundWaterBegin: func (speed) {
		if (speed > 5) {#check if sound already running?
			me.input.wCrashOn.setBoolValue(TRUE);
			me.soundWaterTimer.restart(3);
		}
	},
	_impactSoundWaterEnd: func	() {
		me.input.wCrashOn.setBoolValue(FALSE);
	},
	_impactSoundBegin: func (speed) {
		if (speed > 5) {
			me.input.crashOn.setBoolValue(TRUE);
			me.soundTimer.restart(3);
		}
	},
	_impactSoundEnd: func () {
		me.input.crashOn.setBoolValue(FALSE);
	},
	_explodeBegin: func(str) {
		me.input.explodeOn.setBoolValue(TRUE);
		me.exploded = TRUE;
		me.failure_modes = FailureMgr._failmgr.failure_modes;
	    me.mode_list = keys(me.failure_modes);

	    foreach(var failure_mode_id; me.mode_list) {
		FailureMgr.set_failure_level(failure_mode_id, 1);
	    }

	    me._output(str~" and exploded.", TRUE);

		me.explodeTimer.restart(3);
	},
	_explodeEnd: func () {
		me.input.explodeOn.setBoolValue(FALSE);
	},
	_stressDamage: func (str) {
		me._output("Aircraft damaged: Wings broke off, due to "~str~" G forces.");
		me.input.detachOn.setBoolValue(TRUE);

		FailureMgr.set_failure_level(me.fdm.wingsFailureID, 1);

		me.wingsAttached = FALSE;

		me.stressTimer.restart(3);
	},
	_stressDamageEnd: func () {
		me.input.detachOn.setBoolValue(FALSE);
	},
	_output: func (str, override = FALSE) {
		me.time = me.fdm.input.simTime.getValue();
		if (override == TRUE or (me.time - me.lastMessageTime) > 3) {
			me.lastMessageTime = me.time;
			screen.log.write(str, 0.7098, 0.5372, 0.0);# solarized yellow
			logprint(LOG_ALERT, str);
		}
	},
	_loop: func () {
		me._testStress();
		me._testWaterImpact();
	},
	_testWaterImpact: func () {
		if (me.input.altAgl.getValue() < 0) {
			me.lat = me.input.lat.getValue();
			me.lon = me.input.lon.getValue();
			me.info = geodinfo(me.lat, me.lon);
			me.solid = me.info==nil?TRUE:(me.info[1] == nil?TRUE:me.info[1].solid);
			if(me.solid == FALSE) {
				me._impactDamage();
			}
		}
	},
	_testStress: func () {
		var gearFactor = 1 - gearLoad.getValue();
		if (me._isRunning() == TRUE and me.wingsAttached == TRUE and gearFactor > 0) {
			me.gForce = me.fdm.input.Nz.getValue() == nil?1:me.fdm.input.Nz.getValue();
			me.weight = me.fdm.input.weight.getValue();
			me.wingload = me.gForce * me.weight * gearFactor;
			## I do not see why the wings are loaded when the gear is on the ground

			me.broken = FALSE;

			if(me.wingload < 0) {
				me.broken = me._testWingload(-me.wingload, -me.wingLoadLimitLower);
				if(me.broken == TRUE) {
					me._stressDamage("negative");
				}
			} else {
				me.broken = me._testWingload(me.wingload, me.wingLoadLimitUpper);
				if(me.broken == TRUE) {
					me._stressDamage("positive");
				}
			}
		} else {
			me.input.crackOn.setBoolValue(FALSE);
			me.input.creakOn.setBoolValue(FALSE);
		}
	},
	_testWingload: func (wingloadCurr, wingLoadLimit) {
		if (wingloadCurr > (wingLoadLimit * 0.5)) {
			me.tremble_max = math.sqrt((wingloadCurr - (wingLoadLimit * 0.5)) / (wingLoadLimit * 0.5));

			if (wingloadCurr > (wingLoadLimit * 0.75)) {

				me.input.creakVol.setDoubleValue(me.tremble_max);
				me.input.creakOn.setBoolValue(TRUE);

				if (wingloadCurr > (wingLoadLimit * 0.90)) {
					me.input.crackOn.setBoolValue(TRUE);
					me.input.crackVol.setDoubleValue(me.tremble_max);
					if (wingloadCurr > wingLoadLimit) {
						me.input.crackVol.setDoubleValue(1);
						me.input.creakVol.setDoubleValue(1);
						return TRUE;
					}
				} else {
					me.input.crackOn.setBoolValue(FALSE);
				}
			} else {
				me.input.creakOn.setBoolValue(FALSE);
			}
		} else {
			me.input.crackOn.setBoolValue(FALSE);
			me.input.creakOn.setBoolValue(FALSE);
		}
		return FALSE;
	},
};



#--------------------------------------------------------------------
# Aircraft breaks listener

var ImpactStructureListener = {
	crash: nil,
	run: func () {
		if (crash._isRunning() == TRUE) {
			var wow = crash._isStructureInContact();
			if (wow == TRUE) {
				crash._impactDamage();
			}
		}
	},
};

# static class
var fdmProperties = {
    input: {},
    convert: func () {
	foreach(var ident; keys(me.input)) {
	    me.input[ident] = props.globals.getNode(me.input[ident], 1);
	}
    },
    fps2kt: func (fps) {
	return fps * FPS2KT;
    },
    getSpeedRelGround: func () {
    return 0;
    },
    wingsFailureID: nil,
};

var jsbSimProp = {
	parents: [fdmProperties],
	input: {
	    weight:     "fdm/jsbsim/inertia/weight-lbs",
	    fuel:       "fdm/jsbsim/propulsion/total-fuel-lbs",
	    simTime:    "fdm/jsbsim/simulation/sim-time-sec",
	    northFps:   "velocities/speed-north-fps",
	    eastFps:    "velocities/speed-east-fps",
	    downFps:    "velocities/speed-down-fps",
	    ## MIK: this value is horribly unstable near ground level so we use our own
	    #Nz:         "fdm/jsbsim/accelerations/Nz",
	    Nz:         "instrumentation/accelerometer/g-load",
	},
	getSpeedRelGround: func () {
	    me.northSpeed = me.input.northFps.getValue();
	    me.eastSpeed  = me.input.eastFps.getValue();
	    me.horzSpeed  = math.sqrt((me.eastSpeed * me.eastSpeed) + (me.northSpeed * me.northSpeed));
	    me.vertSpeed  = me.input.downFps.getValue();
	    me.realSpeed  = me.fps2kt(math.sqrt((me.horzSpeed * me.horzSpeed) + (me.vertSpeed * me.vertSpeed)));

	    return me.realSpeed;
	},
	wingsFailureID: "fdm/jsbsim/structural/wings",
};

# static class
var yaSimProp = {
	input: {
	    weight:     "yasim/gross-weight-lbs",
	    fuel:       "consumables/fuel/total-fuel-lbs",
	    simTime:    "sim/time/elapsed-sec",
	    northFps:   "velocities/speed-north-fps",
	    eastFps:    "velocities/speed-east-fps",
	    downFps:    "velocities/speed-down-fps",
	    Nz:         "accelerations/n-z-cg-fps_sec",
	},
	convert: func () {
		foreach(var ident; keys(me.input)) {
		    me.input[ident] = props.globals.getNode(me.input[ident], 1);
		}
	},
	fps2kt: func (fps) {
		return fps * FPS2KT;
	},
	getSpeedRelGround: func () {
		return 0;
	},
	getSpeedRelGround: func () {
		me.northSpeed = me.input.northFps.getValue();
		me.eastSpeed  = me.input.eastFps.getValue();
		me.horzSpeed  = math.sqrt((me.eastSpeed * me.eastSpeed) + (me.northSpeed * me.northSpeed));
		me.vertSpeed  = me.input.downFps.getValue();
		me.realSpeed  = me.fps2kt(math.sqrt((me.horzSpeed * me.horzSpeed) + (me.vertSpeed * me.vertSpeed)));

		return me.realSpeed;
	},
	wingsFailureID: "structural/wings",
};

var MaxTOWeight = getprop("/limits/mass-and-balance/maximum-takeoff-mass-lbs");
var maxG = getprop("/limits/max-positive-g");
var minG = getprop("/limits/max-negative-g");
var StressLimits = {"weightLbs": MaxTOWeight, "maxG": maxG, "minG": minG};

var crashCode = nil;
var crash_start = func {
        removelistener(lsnr);
        ## critical: identify ALL gears below otherwise they will be considered to be structures
        crashCode = CrashAndStress.new([0,1,2,3,4], StressLimits);
        crashCode.start();
}

## Stop the systems after a short delay
var crash_stop = func {
	var t = maketimer(2.0, func { crashCode.stop(); } );
	t.singleShot = TRUE;
	t.start();
};

var lsnr = setlistener("sim/signals/fdm-initialized", crash_start);

var repair = func {
	if (crashCode != nil) {
		crashCode.repair();
	}
};

var lsnr = setlistener("/sim/signals/reinit", repair);

var crashListener = func(n) {
    var crashed = n.getValue();

    if (crashed and crashCode != nil) {
        crashCode._impactDamage();
        crash_stop();
	masterShutdown();
    }
}

var lscrash = setlistener("/sim/crashed", crashListener, 0, 0);

###########################################################################
## Master SHUTDOWN of all routines on crash
###########################################################################

var masterShutdown = func () {
    enginesDamaged();
    victor.mainShutdown();
}

## On crash, switch off the engines
var enginesDamaged = func {
    setprop("/controls/switches/autopilot", FALSE);
    setprop("/controls/switches/autothrottle", FALSE);

    for (var i=0; i < 4; i = i+1) {
	setprop("/controls/engines/engine[" ~ i ~ "]/on-fire", TRUE);
        setprop("/sim/failure-manager/engines/engine[" ~ i ~ "]/failure-level", 1.0);
    }
    victor.centreFlightControls();
    victor.idleThrottle(5);
}

################################# END #######################################
