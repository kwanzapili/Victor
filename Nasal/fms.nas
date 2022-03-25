#############################################################################
#
#  Handley Page Victor Flight Management and Flight Guidance.
#
#  Abstract:
#	This module provides utilities for assisting the autopilot.
#	The flightdirector module has the direct interface to the autopilot.
#
#	The modules is in to parts:
#
#	A. Utilities for the flight management functions: reading and
#	setting the control modes based on internal computions (not user input).
#	These should be called whenever an automatic decision needs to be made
#	for the various modes.
#
#	B. Utilities for the flight guidance functions: ensuring concordance
#	beteween the flightdirector, autopilot and FMS.
#
#############################################################################

##
## ++++++++++++++++++++++++++++ MODE EVALUATION ++++++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## Generic class that simply reads the computed values for LNAV, VNAV or SPD.
## The computations are done in JSBsim but is potentially a short delay
## before they can be considered current.
## ---------------------------------------------------------------------------

## FMS class
var FMS = {
    new: func () {
	     var m = {parents : [FMS]};
	     return m;
	 },

    #***********************
    # evaluate managed VNAV
    #-----------------------
    evaluateManagedVNAV : func () {
			      var retVNAV = getprop("/fdm/jsbsim/fmc/vnav/managed-mode");
			      return retVNAV;
			  },

    #******re******************
    # evaluate selected VNAV
    #------------------------
    evaluateSelectedVNAV : func () {
			       var retVNAV = getprop("/fdm/jsbsim/fmc/vnav/selected-mode");
			       return retVNAV;
			   },

    #***************
    # evaluate VNAV
    #---------------
    evaluateVertical : func () {
			   var retVNAV = VNAV.OFF;
			   var apMode = getprop("/instrumentation/flightdirector/autopilot-engage");
			   if (apMode == ON) {
			       var altSelect = getprop("/instrumentation/flightdirector/vertical-alt-mode");
			       var vsSelect  = getprop("/instrumentation/flightdirector/vertical-vs-mode");
			       var managed   = (altSelect == MANAGED_MODE and vsSelect == MANAGED_MODE);
				# for managed mode we use "evaluateManagedVNAV", otherwise we
				# check with "evaluateSelectedVNAV"
			       if ( managed == TRUE ) {
				   retVNAV = me.evaluateManagedVNAV();
			       } else {
				   retVNAV = me.evaluateSelectedVNAV();
			       }
			   }

			   return retVNAV;
		       },

    #***********************
    # evaluate managed LNAV
    #-----------------------
    evaluateManagedLNAV : func () {
			      var retLNAV = getprop("/fdm/jsbsim/fmc/lnav/managed-mode");
			      return retLNAV;
			  },

    #************************
    # evaluate selected LNAV
    #------------------------
    evaluateSelectedLNAV : func () {
			       var retLNAV = getprop("/fdm/jsbsim/fmc/lnav/selected-mode");
			       return retLNAV;
			   },

    #***************
    # evaluate LNAV
    #---------------
    evaluateLateral : func () {
			  var retLNAV = LNAV.OFF;
			  var apMode = getprop("/instrumentation/flightdirector/autopilot-engage");
			  if (apMode == ON) {
			      var managed = getprop("/instrumentation/flightdirector/lateral-mode");
			      if ( managed == MANAGED_MODE ) {
				  retLNAV = me.evaluateManagedLNAV();
			      } else {
				  retLNAV = me.evaluateSelectedLNAV();
			      }
			  }
			  return retLNAV;
		      },

    #**********************
    # evaluate managed SPD
    #----------------------
    evaluateManagedSpeed : func () {
			       var retSpeed = getprop("/fdm/jsbsim/fmc/speed/managed-mode");;
			       return retSpeed;
			   },

    #***********************
    # evaluate selected SPD
    #-----------------------
    evaluateSelectedSpeed : func () {
				var retSpeed = getprop("/fdm/jsbsim/fmc/speed/selected-mode");;
				return retSpeed;
			    },

    #****************
    # evaluate SPEED
    #----------------
    evaluateSpeed : func () {
			var athrMode = getprop("/instrumentation/flightdirector/autothrottle-engage");
			var apMode   = getprop("/instrumentation/flightdirector/autopilot-engage");
			var spdMode  = getprop("/instrumentation/flightdirector/speed-mode");
			var retSpeed = SPD.OFF;

			if (athrMode == ON and apMode == ON) {
			    if (spdMode == SELECTED_MODE or apMode == OFF) {
				retSpeed = me.evaluateSelectedSpeed();
			    } else {
				retSpeed = me.evaluateManagedSpeed();
			    }
			}
			return retSpeed;
		    },

    #########################
    # evaluateArmedVertical
    #########################
    evaluateArmedVertical : func () {
				var retMode = me.evaluateVertical();
				return retMode;
			    },

    #########################
    # evaluateArmedLateral
    #########################
    evaluateArmedLateral : func () {
			       var retMode = me.evaluateLateral();
			       return retMode;
			   },

    #########################
    # evaluateArmedSpeed
    #########################
    evaluateArmedSpeed : func () {
			     var retMode = me.evaluateSpeed();
			     return retMode;
			 }

};

## Create an instance of FMS that we will reuse repeatedly here.
var victorFMS = nil;


## Generic class for setting the LNAV, VNAV or SPD after a short delay.
## This allows the JSBsim evaluators to catch up before the values are
## read from the relevant properties
## ---------------------------------------------------------------------
var Evaluator = {
    new: func () {
	     var m = { parents:[Evaluator] };
	     # this is the function that gets executed
	     m.current_func = nil;
	     m.mode = -1;
	     m.trace = ["LNAV", "VNAV", "SPD"];
	     return m;
	 },

    # selected execution
    exec: func () {
	      var t = maketimer(0.5, func { me.current_func(); });
	      t.singleShot = TRUE;
	      t.start();
	  },

    # evaluators for each mode
    set_lnav: func () {
		  var lnav = victorFMS.evaluateLateral();
		  var current = fdLNAV.getValue();

		  if ( current != lnav ) setLNAV(lnav);
	  },

    set_vnav: func () {
		  var vnav = victorFMS.evaluateVertical();
		  var current = fdVNAV.getValue();
		  var armMode = VNAV.OFF;
		  var altMode = fdAltMode.getValue();
		  var vsMode  = fdVsMode.getValue();
		  var managed = (altMode == MANAGED_MODE) or (vsMode == MANAGED_MODE);

		  if ( current != vnav ) setVNAV(vnav);
		  if (managed == TRUE) armMode = vnav;
		  setprop("/instrumentation/flightdirector/vnav-arm", armMode);
	      },

    set_spd: func () {
		 var spd = victorFMS.evaluateSpeed();
		 var current = fdSPD.getValue();
		 var athr = fdATEngage.getValue();
		 # toggle the autothrottle switch if necessary
		 if (spd == SPD.OFF) {
		     if ( athr == ON ) turn_off_athr();
		 } else {
		     if ( athr == OFF ) turn_on_athr();
		 }

		 if ( current != spd ) setSPD(spd);
	     },

    # now the update functions for each mode
    updateLNAV: func () {
		    me.current_func = me.set_lnav;
		    me.mode=0;
		    me.exec();
		},
    updateVNAV: func () {
		    me.current_func = me.set_vnav;
		    me.mode=1;
		    me.exec();
		},
    updateSPD: func () {
		   me.current_func = me.set_spd;
		   me.mode=2;
		   me.exec();
	       }
    };

##
## -------------------- Lateral --------------------
##

## evaluate and set LNAV
var reset_lnav = func () {
    var apMode = fdAPEngage.getValue();

    if (apMode == ON) {
	var eval = Evaluator.new();
	eval.updateLNAV();
    }
    else {
	var armMode = victorFMS.evaluateArmedLateral();
	setLNAV(LNAV.OFF);
	setprop("/instrumentation/flightdirector/lnav-arm", armMode);
    }
}

## set the lataral mode if n = -/+ 1; 0 implies unchanged
var set_lateral_mode = func (n) {
    var lateral = fdLatMode.getValue();

    lateral = lateral + n;
    if (lateral < -1) {
	lateral = -1;
    }
    if (lateral > 0) {
	lateral = 0;
    }
    setprop("/instrumentation/flightdirector/lateral-mode", lateral);
}


##
## -------------------- Vertical --------------------
##

## evaluate and set VNAV
var reset_vnav = func () {
    var apMode = fdAPEngage.getValue();

    if (apMode == ON) {
	var eval = Evaluator.new();
	eval.updateVNAV();
    }
    else {
	var armMode = victorFMS.evaluateArmedVertical();
	setVNAV(VNAV.OFF);
	setprop("/instrumentation/flightdirector/vnav-arm", armMode);
	setprop("instrumentation/flightdirector/alt-acquire-mode", OFF);
    }
}

## set the ALT mode if n = -/+ 1; 0 implies unchanged
var set_vert_alt_mode = func (n) {
    var vertical = getprop("/instrumentation/flightdirector/vertical-alt-mode");
    vertical = vertical + n;
    if (vertical < -1) {
	vertical = -1;
    }
    if (vertical > 0) {
	vertical = 0;
    }
    setprop("/instrumentation/flightdirector/vertical-alt-mode", vertical);
}

## set the V/S mode if n = -/+ 1; 0 implies unchanged
var set_vert_vs_mode = func (n) {
    var vs = getprop("instrumentation/flightdirector/vertical-vs-mode");
    vs = vs + n;
    if (vs < -1) {
	vs = -1;
    }
    if (vs > 0) {
	vs = 0;
    }
    setprop("/instrumentation/flightdirector/vertical-vs-mode", vs);
}


##
## -------------------- Speed --------------------
##

## evaluate and set SPD
var reset_spd = func () {
    var athMode = fdATEngage.getValue();

    if (athMode == ON) {
	var eval = Evaluator.new();
	eval.updateSPD();
    }
    else {
	var armMode = victorFMS.evaluateArmedSpeed();
	setSPD(SPD.OFF);
	setprop("/instrumentation/flightdirector/spd-arm", armMode);
    }
}

## set the SPEED mode if n = -/+ 1; 0 implies unchanged
var set_speed_mode = func (n) {
    var speed = fdSpdMode.getValue();
    speed = speed + n;
    if (speed < -1) {
	speed = -1;
    }
    if (speed > 0) {
	speed = 0;
    }
    setprop("/instrumentation/flightdirector/speed-mode", speed);
    reset_spd();
}


##
## ++++++++++++++++++++++++++++ UTILITY FUNCTIONS +++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

##
## Sanity checks on cruise speed settings
## ---------------------------------------
var check_speeds = func () {
    var mach = getprop("/instrumentation/fmc/cruise-mach");
    mach = (mach < 0.75) ? 0.75 : (mach > 0.85) ? 0.85 : mach;
    setprop("/instrumentation/fmc/cruise-mach", mach);

    var speed = getprop("/instrumentation/fmc/cruise-speed");
    speed = (speed < 250) ? 250 : (speed > 500) ? 500 : speed;
    setprop("/instrumentation/fmc/cruise-speed", speed);
}

## Synchronise the cruise altitudes in the FMC and route manager
## --------------------------------------------------------------
var sync_cruise = func () {
    var toc = fdPastToC.getValue();
    var tod = fdPastToD.getValue();

    # Before the ToC, the altitude cannot be lower than the cruise altitude
    # Also allow for changes to cruise altutude during the cruise phase
    if (toc == FALSE or tod == FALSE) {
	check_altitudes();
    }

    # Is route manager active? If not, no update is needed
    var active = apRMActive.getValue();
    if ( active == FALSE ) return;

    # NB/ the route-manager only allows one of cruise altitude
    # or flight level to be set. The other is automatically set to 0.
    var crzAlt = fmcCruiseAlt.getValue();
    var rmAlt = getprop("/autopilot/route-manager/cruise/altitude-ft");
    if (rmAlt < 100) {
	setprop("/autopilot/route-manager/cruise/altitude-ft", crzAlt/100);
    } else {
	setprop("/autopilot/route-manager/cruise/altitude-ft", crzAlt);
    }

    # set the cruise speeds
    # NB/ The route manager only allows one of mach or speed knots to be set.
    # The other one will be set to zero.
    var crzSpd = fmcCruiseSpeed.getValue();
    var crzMach = fmcCruiseMach.getValue();
    var rmSpd = getprop("/autopilot/route-manager/cruise/speed-kts");
    # use  mach if knots is 0
    if (rmSpd == 0) {
	setprop("/autopilot/route-manager/cruise/mach", crzMach);
    } else {	# use knots instead
	setprop("/autopilot/route-manager/cruise/speed-kts", crzSpd);
    }
}

##
## Altitude settings variables
## -------------------------------------

## This container holds the waypoint and its number (if any)
var WaypointAlt = { number: -1, altitude: -9999 };

## This vector holds the waypoint altitudes
var AltVector = [];

# ---------------------------------------------------------------------------------
# Route manager waypoint naming convections
#
# The route has a standard structure some of which are optional:
#   [Dep] → [WP 1] ... [WP X] → [APP-Z] ... [APP-4] →
#   RWY-12 → RWY-8 → RWY-GS → Dest
# So only the last 4 (ILS) waypoints are guaranteed to be in the plan.
# Both the departure and destination points are named in the format "APT-RWY"
# When invoked mid-flight, then the departure item will NOT be present.
#
# We are interested in capturing information on RWY-12 and APP-Z (the first approach)
# if it exists. When it does not exist, we will make a fictitious point.
# ---------------------------------------------------------------------------------

## Indices in route plan for the approaches
## Remember that the approach indices and waypoint number are in the opposite order
## of each other, i.e. the index of InitialAppr is always higher than that of
## ILS12Appr, but its waypoint appears before that of ILS12Appr
var InitialAppr = {idx: -1, wp: -1};
var ILS12Appr	= { parents: [InitialAppr] };
var DecelIndex	= -1;
var CruiseIndex = -1;
var ClimbIndex	= -1;
var DepAptIndex = -1; 	# usually this is 0
var NextIndex	= -1;	# pointer to the next item to use in the vector
##
## Define the departure waypoint index
## ------------------------------------------------------------
var get_dep_wpt = func () {
    # initialise
    DepAptIndex = -1;	# nothing found

    var pts = getprop("autopilot/route-manager/route/num");
    if (pts > 0) {
	var depApt = getprop("autopilot/route-manager/departure/airport");
	var wp0 = getprop("autopilot/route-manager/route/wp[0]/id");
	# the first waypoint ID is in the form "ICAO-RWY"
	if (depApt != "" and wp0 != "")	{
	    var sub = left(wp0, 4);
	    if (sub == depApt) DepAptIndex = 0;
	}
    }
};

##
## Define the descent approach points:
## ------------------------------------------------------------

## Evaluate the indices of the approaches
## ---------------------------------------
var eval_appr_wpt = func () {
    # initialise
    reset_appr_idx();

    var pts = getprop("autopilot/route-manager/route/num");

    # ILS-12 is always at (n - 4)
    ILS12Appr.wp = pts - 4;
    if (ILS12Appr.wp < 0) {
	logprint(LOG_INFO, "[FMS]: there are no ILS waypoints in the flight plan");
	return;
    }

    var destApt = getprop("autopilot/route-manager/destination/airport");
    var destRwy = getprop("autopilot/route-manager/destination/runway");
    var nextWpt = getprop("autopilot/route-manager/wp/id");

    # verify that it indeed an ILS waypoint  with the name
    var ils12name = destRwy~"-12";
    var name = getprop("autopilot/route-manager/route/wp["~ILS12Appr.wp~"]/id");
    if (ils12name != name) {
	logprint(LOG_INFO, "[FMS]: the 1st ILS waypoints in the flight plan is malformed");
	return;
    }

    # index 0 is the origin (perhaps the departure airport)
    # check the names of waypoints prior to ILS-12 for the first approach
    var sub = "";
    for (var p = ILS12Appr.wp - 1; p > DepAptIndex; p = p-1) {
	name = getprop("/autopilot/route-manager/route/wp["~p~"]/id");
	sub = left(name, 4);
	if (sub == "APP-") {
	    InitialAppr.wp = p;
	}
	else break;
    }
};

## Reset the indices of the approaches
## ------------------------------------
var reset_appr_idx = func () {
    InitialAppr.idx = -1;
    InitialAppr.wp = -1;
    ILS12Appr.idx = -1;
    ILS12Appr.wp = -1;
};

## Reset the altitude vector
## --------------------------
var reset_alt_vector = func () {
    var s = size(AltVector);
    for (var j=0; j < s; j += 1) pop(AltVector);
    NextIndex = -1;
    DecelIndex = -1;
    CruiseIndex = -1;
    ClimbIndex = -1;
    reset_appr_idx();
};

## Create a new waypoint altitude container
## -------------------------------------------
var new_waypoint = func (alt, n=-1) {
    var wp = { parents:[WaypointAlt] };
    wp.number = n;
    wp.altitude = alt;
    return (wp);
};

## Add an altitude item to the altitude vector
## -------------------------------------------
var add_altitude = func (wp, b) {
    # "b" is the minimum value acceptable
    var wpAlt = getprop("/autopilot/route-manager/route/wp["~wp~"]/altitude-ft");

    wpAlt = (wpAlt > 0) ? wpAlt : b;
    var w = new_waypoint(wpAlt, wp);
    append(AltVector, w);
};

## Evaluate and set the approach altitudes
## also updates the indices
## -------------------------------------------
var approach_altitudes = func () {
    # the indices should have been initialised
    if ( ILS12Appr.idx < 0 or InitialAppr.idx < 0 ) {
	eval_appr_wpt();
    }

    if ( ILS12Appr.wp > -1) {
	# normally the height is 4,000 ft AGL
	add_altitude(ILS12Appr.wp, 4000);
	var n = size(AltVector) - 1;	# index in vector
	ILS12Appr.idx = n;
	var appr2Alt = AltVector[n].altitude;
	# get or estimate the altitude of the first approach
	if (InitialAppr.wp > -1) {
	    # there is at least one valid approach, so we process them all
	    # each subsequent altitude is not lower than the prior altitude
	    var appr1Alt = appr2Alt + 1000;
	    for(var j=(ILS12Appr.wp - 1); j >= InitialAppr.wp; j -= 1) {
		add_altitude(j, appr1Alt);
		n += 1;
		appr1Alt = AltVector[n].altitude + 500;
	    }
	    # get the last element as the first approach
	    InitialAppr.idx = n;
	    appr1Alt = AltVector[n].altitude;
	} else {
	    # we can only estimate the values for the initial approach
	    var appr1Alt = appr2Alt + 1000;
	    var w = new_waypoint(appr1Alt);
	    append(AltVector, w);
	    InitialAppr.idx = n + 1;
	}
    } else {	# estimate both initial and ILS approach altitudes
	var n = size(AltVector) - 1;	# last index in vector
	# usually the 1st ILS approach is 2000 ft above the remaining three
	var appr2Alt = AltVector[n].altitude + 2000;
	var appr1Alt = appr2Alt + 1000;
	var w1 = new_waypoint(appr1Alt);
	var w2 = new_waypoint(appr2Alt);
	append(AltVector, w2, w1);
	ILS12Appr.idx = n;
	InitialAppr.idx = n + 1;
    }

    setprop("/instrumentation/fmc/approach/initial-alt-ft", appr1Alt);
    setprop("/instrumentation/fmc/approach/final-alt-ft", appr2Alt);
};

## Add the cruise altitude to the altitude vector
## -----------------------------------------------
var add_cruise_alt = func (crzAlt) {
    var w = new_waypoint(crzAlt);
    append(AltVector, w);
    CruiseIndex = size(AltVector) - 1;
};

## Populate the altitude vector
## ------------------------------
var fill_alt_vector = func () {
    # start with a fresh list each time
    reset_alt_vector();

    var wpts = getprop("autopilot/route-manager/route/num");
    # we need at least three waypoints (the destination and its ILS approaches)
    if (wpts < 4) return;

    # the vector has values in reverse order:
    # destination ← approaches ← deceleration ← cruise ← climb ← takeoff

    # last waypoints: the destination (n-1),
    var wp = wpts - 1;
    add_altitude(wp, 0);

    # the last 3 waypoints ought to be the ILS approaches
    # RWY-GS (n-2) and RWY-8 (n-3) both at 2,000 ft AGL
    wp = wp - 1;
    if (wpts > 2) {
	add_altitude(wp, 2000);
	add_altitude((wp-1), 2000);
	wp = wp - 2;
    } else {	# guess the altitudes
	var w1 = new_waypoint(2000, (wp-1));
	var w2 = new_waypoint(2000, wp);
	append(AltVector, w1, w2);
    }

    # the next item is RWY-12 (1st ILS approach): now add the other approaches
    approach_altitudes();

    if (InitialAppr.wp > -1) {	# initial approach waypoint was found
	wp = InitialAppr.wp - 1;
    } elsif ( ILS12Appr.wp > -1) { # only the 1st of the ILS approach waypoint was found
	wp = ILS12Appr.wp - 1;
    }

    # add the deceleration altitude
    var declAlt = fmcDecelAlt.getValue();
    var n = size(AltVector) - 1;
    # the deceleration altitude must be at least 1,000 ft above the initial approach
    var minAlt = AltVector[n].altitude + 1000;
    declAlt = (declAlt < minAlt) ? minAlt : declAlt;
    setprop("/instrumentation/fmc/deceleration-alt", declAlt);
    var w = new_waypoint(declAlt);
    append(AltVector, w);
    DecelIndex = n + 1;

    # the remaining waypoint altitudes must be at least that of the deceleration altitude
    minAlt = declAlt;
    var wpAlt = -9999;
    for(var j=wp; j > DepAptIndex; j -= 1) {
	wpAlt = getprop("/autopilot/route-manager/route/wp["~j~"]/altitude-ft");
	wpAlt = (wpAlt < minAlt) ? minAlt : wpAlt;
	add_altitude(j, wpAlt);
    }
    wp = j;

    # add the cruise altitude only if there are no additional waypoints before the approaches
    var crzAlt = fmcCruiseAlt.getValue();
    n = size(AltVector) - 1;
    if (n == DecelIndex) { # no waypoints found beyond the deceleration point
	add_cruise_alt(crzAlt);
    }

    # lastly the climb altitude
    wpAlt = fmcClimbAlt.getValue();
    w = new_waypoint(wpAlt);
    append(AltVector, w);
    ClimbIndex = size(AltVector) - 1;

    # fix the altitude of the destination item
    wpAlt = getprop("/autopilot/route-manager/destination/field-elevation-ft");
    AltVector[0].altitude = wpAlt;
};

## Rebuild the altitude vector
## ----------------------------
var create_alt_vector = func () {
    get_dep_wpt();
    reset_appr_idx();
    fill_alt_vector();
    approach_distances();
};

## Remove a set of obsolete waypoint from a given point to the end
## -----------------------------------------------------------------
var remove_obsolete = func (start) {
    var end = size(AltVector);

    for (var j = start; j < end; j += 1) {
	pop(AltVector);
    }
};

## Set the next valid index in the altitude vector
## This is a heap, so we need to pop items once they are not longer valid
## then use the top item on the heap
## ------------------------------------------------------------------------
var set_next_idx = func () {
    # usually we need the top item
    NextIndex = size(AltVector) - 1;

    if ( NextIndex < 0 ) return;

    var wp  = apRMCurWP.getValue();
    var toc = fdPastToC.getValue();
    var tod = fdPastToD.getValue();
    var index = -1;

    if ( toc == FALSE ) {
	# before ToC we cannot skip the climb altitude
	if (NextIndex != ClimbIndex) {
	    # spmethings is wrong so rebuild vertor
	    create_alt_vector();
	    NextIndex = size(AltVector) - 1;
	}
	# the next index is now the climb index
	index = NextIndex;

    } elsif ( tod == TRUE ) {
	# we skip all altitudes prior to the deceleration altitude
	# we are now in the descent phases so the next index cannot be higher
	# than the deceleration index
	NextIndex = (NextIndex < DecelIndex) ? NextIndex : DecelIndex;
	index = NextIndex;

	var phase = fdPhase.getValue();
	var alt = getprop("/instrumentation/fmc/altitude-ft");
	var decAlt = fmcDecelAlt.getValue();

	if (phase < FlightPhase.Decel) {
	    # we need to aim for the deceleration altitude
	    index = NextIndex;
	} elsif (phase == FlightPhase.Decel) { # switch to next altitude
	    var appr1 = DecelIndex - 1; # this is the first approach
	    index = (index < appr1) ? index : appr1;
	} else   { # search for waypoint or the next lower altitude
	    for (var w = NextIndex; w > -1; w -= 1) {
		if (wp == AltVector[w].number or alt > AltVector[w].altitude) {
		    # this is the current waypoint
		    index = w;
		    break;
		}
	    }
	}

    } else {
	# we do not want the climb item anymore
	if (NextIndex == ClimbIndex) {
	    NextIndex = ClimbIndex - 1;
	}

	index = NextIndex;

	if (CruiseIndex > -1) { # stick to the cruise altitude
	    index = CruiseIndex;
	} else {	# search for the waypoint
	    for (var w=NextIndex; w > DecelIndex; w -= 1) {
		if (wp == AltVector[w].number) {
		    # this is the current waypoint before deceleration
		    index = w;
		    break;
		}
	    }
	}

    }

    NextIndex = (NextIndex < index) ? NextIndex : index;
};

## The altitude vector is a heap, so we need to pop items once
## they are not longer valid
## --------------------------------------------------------------
var cleanup_heap = func () {
    if (NextIndex < 0) return;

    # we want the value after the next valid index
    var next = NextIndex + 1;
    remove_obsolete(next);
};

## Set target altitude for managed altitude mode
## ----------------------------------------------
var set_altitude = func () {
    var active = apRMActive.getValue();
    if (active == FALSE) {
	# check if the cruise altitude shoud be used
	var pastTC = fdPastToC.getValue();
	var crzAlt = fmcCruiseAlt.getValue();
	var tocAlt = fmcClimbAlt.getValue();
	# before ToC we use the climb altitude, other we use the cruise altitude
	if (pastTC == FALSE) {
	    setprop("/instrumentation/fmc/altitude-ft", tocAlt);
	} else {
	    setprop("/instrumentation/fmc/altitude-ft", crzAlt);
	}
	return;
    }

    var wpAlt = -9999;
    var alt   = getprop("/instrumentation/fmc/altitude-ft");

    # set the waypoint altitude if available
    set_next_idx();
    if (NextIndex > -1) {
	wpAlt = AltVector[NextIndex].altitude;
    }

    alt = (wpAlt > 0) ? wpAlt : alt;

    # update the altitude
    setprop("/instrumentation/fmc/altitude-ft", alt);

    # clean up heap
    cleanup_heap();
};

## Check if past ToD (Top Of Descend) defined in route manager
## ------------------------------------------------------------
var past_tod = func () {

    if (fdPastToD.getValue() == FALSE) {
	var wp = apRMCurWP.getValue();
	var past = FALSE;
	var id = nil;
	for (var p = 0; p < wp; p=p+1) {
	    id = getprop("/autopilot/route-manager/route/wp["~p~"]/id");
	    if (id == "(T/D)") {
		setprop("/instrumentation/flightdirector/past-td", TRUE);
		past = TRUE;
		logprint(LOG_INFO, "Gone past Top Of Descend");
	    }
	}
    }
};


## Calculate the distances from the approaches to the destination
## ---------------------------------------------------------------
var approach_distances = func () {
    var active = apRMActive.getValue();

    # the indices should have been initialised
    if ( ILS12Appr.idx < 0 or active == FALSE )  return;

    # distance remaining to end
    var destDist = apRMDist.getValue();
    var last = getprop("autopilot/route-manager/route/num") - 1;

    # the 1st ILS fix is usually 12 nm from the destination
    var ilsfix = 0;
    var legdist = 0;

    if (ILS12Appr.wp > -1) { # valid waypoint was found
	for(var j = last; j > ILS12Appr.wp; j -= 1) {
	    legdist = getprop("/autopilot/route-manager/route/wp["~j~"]/leg-distance-nm");
	    ilsfix += legdist;
	}
    }
    else ilsfix = 12;

    var appr1fix = ilsfix;
    if (InitialAppr.wp > -1 and ILS12Appr.wp > -1) { # there is a valid approach
	for(var j = ILS12Appr.wp; j > InitialAppr.wp; j -= 1) {
	    legdist = getprop("/autopilot/route-manager/route/wp["~j~"]/leg-distance-nm");
	    appr1fix += legdist;
	}
    }
    else { # use an estimate
	appr1fix += 5;
    }

    setprop("/instrumentation/fmc/approach/initial-to-dest-nm", appr1fix);
    setprop("/instrumentation/fmc/approach/final-to-dest-nm", ilsfix);
}


## Waypoint update of altitude and speeds
## ---------------------------------------
var waypoint_updates = func () {
    var pastTC = fdPastToC.getValue();
    ## set Top Of Descend status
    if ( pastTC )	past_tod();

    var fp = flightplan();
    var curWP = fp.currentWP();
    if (curWP != nil) {
	var altCstr = curWP.alt_cstr;
	var spdCstr = curWP.speed_cstr;

	if (fdAPEngage.getValue() == ON) {
	    # read altitude the vector always within the restrictions
	    set_altitude();
	    if (fdSpdMode.getValue() == MANAGED_MODE) {
		var newSpeed = spdCstr;
		if (newSpeed > 0 and newSpeed < 1) {	# mach mode has numbers between 0 and 1
		    setprop("/autopilot/internal/settings/target-speed-mach", newSpeed);
		} elsif (newSpeed > 200) {
		    setprop("/autopilot/internal/managed-speed-kt", newSpeed);
		}
	    }
	}
    }
};


## At ToC we need to change altitude
## ---------------------------------
var past_toc = func () {
    var pastTC = fdPastToC.getValue();
    set_altitude();

    if ( pastTC ) {
	if (tocListener != nil) removelistener(tocListener);
	tocListener = nil;
    }
};

## Initialise listener for ToC
## ----------------------------
var tocListener = nil;

var make_toc_listener = func () {
    if ( tocListener == nil )
	tocListener = setlistener("/instrumentation/flightdirector/past-tc", past_toc, 0, 0);
};


#######################
## Standard rate turn
#######################

## Radius of turn formula at Rate 1
## --------------------------------
var radius_of_turn_rate = func (v) {
    ## If Rate 1, 2 or 3 turn at a specific TAS is given,
    ## r(nm) = v(kn) / 20 * Pi * omega(deg/sec), where:
    ## r is the radius, v is the TAS, and omega is the rate of turn.
    ## A rate half turn (1.5° per second) is normally used when flying faster than 250 kn.

    var omega = 3.0;      # standard rate of turn
	if (v > 250) {
	    if (v > 300) omega = 1.5;   # half turn
	    else omega = 1.5 * (1 +  (300 - v) / 50);
	}
    var r = v / ( 20 * math.pi * omega);

    return (r);
};


## Radius of turn formula at a specified bank angle
## -------------------------------------------------
var radius_of_turn_theta = func (v, theta) {
    ## If the velocity and the angle of bank is given,
    ## r(ft) = v^2(kn) / [ 11.294 * tan(theta) ]
    ## where r is the radius, v is the TAS, and theta is the angle of bank
    # Figure 4-15 in the SR-71 manual gives the formula as:
    # r = 14.815 * v^2 / [1,000,000 * tan(theta)] (nm)

    var radians = theta * D2R;
    var r = 0.000164579 * (v * v) / (11.294 * math.tan(radians));   # in nm from feet

    return (r);
};

## Angle of bank formula
## ---------------------
var angle_of_bank = func (v) {
    ## A convenient approximation for the bank angle in degrees is
    ## theta = v(kn) / 10 + 7;
    ## where v is the velocity in knots

    var theta = v / 10 + 7;

    return (theta);
};

## Calculate the best turn radius
## ------------------------------
var calc_turn_radius = func (angleDeg=0) {
    var v = getprop("/instrumentation/fmc/TAS-kt");
    if (angleDeg == 0) {
	var theta = angle_of_bank(v);
    } else {
	var theta = angleDeg;
    }

    # Faster aircraft use 30° for their turns.
    # limit the bank angle to 32°
    theta = (theta > 32) ? 32 : theta;

    # radius at calculated theta
    var radius = radius_of_turn_theta(v, theta);

    # radius without bank restrictions
    var r0 = radius_of_turn_rate(v);

    return (radius);
};


##
## +++++++++++++++++++++++++ ROUTE MANAGER FUNCTIONS ++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## Get the cruise altitudes and speeds from the route manager
## --------------------------------------------------------------
var copy_cruise = func () {

    # NB/ the route-manager only allows one of cruise altitude
    # or flight level to be set. The other is automatically set to 0.
    var rmAlt = getprop("/autopilot/route-manager/cruise/altitude-ft");
    if (rmAlt < 10000)
	rmAlt = 100 * getprop("/autopilot/route-manager/cruise/flight-level");
    # select this altitude only if it his higher than 10,000 ft
    if (rmAlt >= 10000) {
	setprop("/instrumentation/fmc/cruise-alt-ft", rmAlt);
    }

    # set the cruise speeds
    # NB/ The route manager only allows one of mach or speed knots to be set.
    # The other one will be set to zero.
    var rmSpd = getprop("/autopilot/route-manager/cruise/speed-kts");
    # select this speed if it higher than 350 knots
    if (rmSpd >= 350) {
	setprop("/instrumentation/fmc/cruise-speed", crzSpd);
    }

    var rmMach = getprop("/autopilot/route-manager/cruise/mach");
    # select this speed if it is higher than 0.7
    if (rmMach >= 0.7) {
	setprop("/instrumentation/fmc/cruise-mach", rmMach);
    }
}

##
## Sanity checks on altitude settings
## ----------------------------------
var check_altitudes = func () {
    ## Logically cruise > descent > approach and cruise > climb
    var desAlt	= fmcDecelAlt.getValue();
    var crzAlt	= fmcCruiseAlt.getValue();
    var clbAlt  = fmcClimbAlt.getValue();
    var wpts	= size(AltVector);

    # The last two fixes altitudes are usually 2000 ft above ground,
    # so logically, the final approach is 4000 ft AGL. The intial approach
    # is thus above 4000 ft (say 5000 ft). This means that the descent altitude
    # has to be above cannot be lower than 6000.
    # Assume we are at a high altitude of 10,000 ft, then the upper limit is
    # 16,000ft
    var alt = 6000;
    if (DecelIndex > 1 and DecelIndex < wpts) {
	# need to update the vector as well
	alt = AltVector[DecelIndex - 1].altitude + 1000;
	desAlt = math.clamp(desAlt, alt, 16000);
	AltVector[DecelIndex].altitude = desAlt;
    } else {
	desAlt = math.clamp(desAlt, alt, 16000);
    }

    # The climb altitude is at least 8,000 ft above departure airport
    # but no more than 15,000 ft
    alt = 8000 + fmcDepAltFt.getValue();
    alt = math.clamp(alt, 8000, 15000);
    if (clbAlt < alt or clbAlt > alt) {
	setprop("/instrumentation/fmc/climb-alt", alt);
	if (ClimbIndex > 1 and ClimbIndex < wpts) {
	    # need to update the vector as well
	    AltVector[ClimbIndex].altitude = alt;
	}
    }

    # The cruise altitude must be above the deceleration altitude up to the
    # service ceiling 55,000 ft
    alt = math.max(alt+1000, desAlt+2000);
    crzAlt = math.clamp(crzAlt, alt, 55000);
    if (CruiseIndex > -1 and CruiseIndex < wpts) {	# update the vector as well
	AltVector[CruiseIndex].altitude = crzAlt;
    }

    setprop("/instrumentation/fmc/cruise-alt-ft", crzAlt);
    setprop("/instrumentation/fmc/deceleration-alt", desAlt);

    # update the altitude setting
    set_altitude();
}

##
## Updates due to change in the waypoints
## ---------------------------------------
setlistener("/autopilot/route-manager/route/num", func (n) {
    ## create the altitude vector
    var active = apRMActive.getValue();
    if ( active ) {
	create_alt_vector();
    }

    ## Verify the altitude settings
    check_altitudes();

    ## re-evaulate VNAV and SPD in managed modes only
    var managedAlt = (fdAltMode.getValue() == MANAGED_MODE) or
    (fdVsMode.getValue() == MANAGED_MODE);
    if (managedAlt) {
	reset_vnav();
    }

    if (fdSpdMode.getValue() == MANAGED_MODE) {
	reset_spd();
    }
}, 0, 0);

##
## Updates due to route manager activation
## ---------------------------------------
setlistener("/autopilot/route-manager/active", func(n) {
    var active = n.getValue();
    if ( active ) {
    	# copy the cruise information first
    	copy_cruise();
	# the guidance system needs the altitudes information
	create_alt_vector();
	# start the navigation updates
	updateNavTimer.start();
    } else {
	# stop the navigation update
	stopNavTimer();
    }
}, 0, 0);

##
## Updates due to change in the current waypoint
## ----------------------------------------------
setlistener("/autopilot/route-manager/current-wp", waypoint_updates, 0, 0);

##
## Update navigation parameters
## ------------------------------
var update_nav = func () {
    # Turn Start Automatic (TSA) point the current angle (limited to 32°)
    var theta  = fmcBankAngle.getValue();
    var radius = WpAircraftSpecificTurnFactor * calc_turn_radius(theta);
    setprop("/instrumentation/fmc/turn-radius-nm", radius);

    ## add an inertial-turn offset (the aircraft needs some time to get into 20° turn)
    var gndVel = velGndSpdKt.getValue();
    var dist = radius + (WpAircraftSpecificTurnInertiaFactor * gndVel);
    setprop("/instrumentation/fmc/turn-distance-nm", dist);

    var currWPtrueCourse = getprop("autopilot/route-manager/wp[0]/true-bearing-deg") or 0;
    var nextWPtrueCourse = getprop("autopilot/route-manager/wp[1]/true-bearing-deg") or 0;
    var bearingDiff = (nextWPtrueCourse - currWPtrueCourse);
    bearingDiff = math.periodic(-180, 180, bearingDiff);
    setprop("/instrumentation/fmc/next-heading-diff-deg", bearingDiff);
}

## Timer runs every 3 secs
var updateNavTimer = maketimer(3.0, update_nav);

var stopNavTimer = func () {
    if ( updateNavTimer.isRunning ) updateNavTimer.stop();
}

##
## Monitor turns at Waypoints
## ----------------------------

## monitoring turn
var monitor_turn = func() {
    var inTurn = fmcWPInTurn.getValue();
    var courseDiff = trueHdgOffset.getValue();

    if ( inTurn == OFF ) {
	stop_turn_monitor();
    } elsif ( abs(courseDiff) <= 2 ) {
	# the course is now stable so switch off monitor
	setprop("/instrumentation/fmc/wp-turn-on", FALSE);
	stop_turn_monitor();
    }
}

## start monitoring
var start_turn_monitor = func () {
    if (! monitorTurnTimer.isRunning ) {
	monitorTurnTimer.start();
    }
}

## stop monitoring
var stop_turn_monitor = func () {
    if ( monitorTurnTimer.isRunning ) {
	monitorTurnTimer.stop();
    }
}

## run checks every 3 secs
var monitorTurnTimer = maketimer(3.0, monitor_turn);


##
## Waypoint switch type container
## -------------------------------
var WaypointSwitch = {
    new: func () {
	     var m = { parents:[WaypointSwitch] };
	     m.waypointDistanceNm = 36000.0;
	     m.waypointIdPrev = nil;
	     # this is the function that gets executed
	     m.current_func = nil;
	     m.mode = -1;
	     m.trace = ["without turn", "with turn"];
	     return m;
	 },

    # selected execution
    exec: func () {
	      me.current_func();
	  },

    # switch at waypoint (without turns)
    without_turn: func () {
		      if ((apRMActive.getValue() == TRUE) and
			      (apRMAirborne.getValue() == TRUE) and
			      (fdLatMode.getValue() == MANAGED_MODE)) {

		      var waypointId	= apRMWpId.getValue();
		      var monitorOn	= apWPMonitor.getValue();
		      var currentWaypointIndex = apRMCurWP.getValue();
		      var doSwitch	= apWpNearby.getValue();
		      var routeManagerWaypointNearBy = FALSE;

		      if (waypointId != nil and waypointId != "" and waypointId != me.waypointIdPrev) {
			  routeManagerWaypointNearBy = TRUE;
		      }

		      if (doSwitch and routeManagerWaypointNearBy and monitorOn) {
			  currentWaypointIndex += 1;
			  setprop("/autopilot/route-manager/current-wp", currentWaypointIndex);
			  me.waypointIdPrev = waypointId;
		      }
		  }
	      },

    # switch at waypoint (with turn)
    with_turn: func () {
		   if ( fdLatMode.getValue() != MANAGED_MODE )
		       return;

		   if ( apWpSwitchOn.getValue() == FALSE ) return;

		   var currentWaypointIndex = apRMCurWP.getValue();
		   var monitorOn = apWPMonitor.getValue();
		   var routeManagerWaypointNearBy = FALSE;
		   var groundspeedKt = velGndSpdKt.getValue();
		   var waypointId = apRMWpId.getValue();
		   var waypointDistanceNmCurrent = apRMWpDist.getValue();
		   var waypointDistanceNmIsReal = FALSE;
		   var makeTurn = FALSE;
		   var waypointDistanceNmSwitchToNext = fmcTurnDist.getValue();

		   # workaround: sometimes after switch of current-waypoint the distance isn't
		   # yet updated (FG-bug  ?!?), so wait until there's a major change in distance
		   if (abs(waypointDistanceNmCurrent - me.waypointDistanceNm) > 0.0000001) {
		       me.waypointDistanceNm = waypointDistanceNmCurrent;
		       waypointDistanceNmIsReal = TRUE;
		   } else {
		       waypointDistanceNmIsReal = FALSE;
		   }

		   if (waypointId != nil and waypointId != "" and monitorOn and
			   me.waypointDistanceNm != nil and waypointDistanceNmIsReal == TRUE) {

		       if (waypointId != me.waypointIdPrev) {
			   routeManagerWaypointNearBy = TRUE;
		       }

			# switch to next waypoint a short distance in order to smooth the curve to fly
			# (not for last waypoint or when the bearing difference is less than 2 degs)
		       if ( routeManagerWaypointNearBy ) {
			   if (currentWaypointIndex >= 0) {
			       var wptBearingDiff = fmcNextHdg.getValue();

			       if ( abs(wptBearingDiff) > 2 ) {    # +-2 degrees - make turn
				   makeTurn = TRUE;
			       }
			       setprop("/instrumentation/fmc/wp-turn-on", makeTurn);
			   }

			# waypointDistanceNmSwitchToNext = <distance to waypoint on which to switch to the
			# next waypoint> (have to switch before reaching waypoint, because we have to take
			# into account the curve the aircraft does)
			# in passive mode, the altitude will change automatically
			# regardless of managed mode
			   if (makeTurn == TRUE) {
			       currentWaypointIndex += 1;
			       setprop("autopilot/route-manager/current-wp", currentWaypointIndex);
			       me.waypointIdPrev = waypointId;
			   }
		       }
		   }
	       },

    # actual switch function where n=FALSE is without turn and n=TRUE is with turn
    switchWaypoint: func (n) {
			me.mode = n;
			if (n == TRUE)	me.current_func = me.with_turn;
			else	me.current_func = me.without_turn;
			me.exec();
		    },

    reset: func () {
	       me.waypointDistanceNm = 36000.0;
	       me.waypointIdPrev = nil;
	   }

};

var wpSwitch = WaypointSwitch.new();

## Controller for waypoint listener
var listenerApWaypointCtrl = func (turn) {
    var monitorOn = apWPMonitor.getValue();
    if ( monitorOn ) {
	wpSwitch.switchWaypoint(turn);
    } else {    # waypoint monitoring is switched off -> cleanup
	wpSwitch.reset();
    }
};


##
## Listeners that manage waypoint actions
## ---------------------------------------------
## Index	Action
##  0		Switch waypoint with turn ON
##  1		Switch waypoint with turn OFF
##  2		Monitor turns
## ---------------------------------------------

var WaypointListeners = [ nil, nil, nil ];

## create listeners when needed
var createWpListeners = func () {
    if (WaypointListeners[0] == nil ) {
	WaypointListeners[0] = setlistener("/autopilot/internal/waypoint-switch-on", func(n) {
					var nearby = n.getValue();

					if ( nearby ) {	# switch with turn
					    listenerApWaypointCtrl(TRUE);
					}
				    }, 0, 0);
    }

    if (WaypointListeners[1] == nil) {
	WaypointListeners[1] = setlistener("/autopilot/internal/waypoint-nearby", func(n) {
					var nearby = n.getValue();

					if ( nearby ) {	# switch without turn
					    listenerApWaypointCtrl(FALSE);
					}
				    }, 0, 0);
    }

    if (WaypointListeners[2] == nil) {
	WaypointListeners[2] = setlistener("/instrumentation/fmc/wp-turn-on", func(n) {
					var turnOn = n.getValue();

					if ( turnOn ) start_turn_monitor();
					else	stop_turn_monitor();
				    }, 0, 0);
    }

}

## delete the waypoint listeners
var deleteWpListeners = func () {
    forindex(var index; WaypointListeners) {
	if (WaypointListeners[index] != nil) {
	    removelistener(WaypointListeners[index]);
	    WaypointListeners[index] = nil;
	}
    }
}

## Automatically create and delete the waypoint listeners are the moonitoring switches
setlistener("/autopilot/internal/waypoint-monitor-on", func (n) {
    if ( n.getValue() )	    createWpListeners();
    else    deleteWpListeners();
}, 0, 0);


##
## +++++++++++++++++++++++ FLIGHT MANAGEMENT FUNCTIONS ++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


## -----------------------------------------------------------------------
## ++++++++++++++++++++++++++++ Managed Modes ++++++++++++++++++++++++++++
## -----------------------------------------------------------------------

## Make sure that all modes are managed: AP modes override ATHR modes
var set_managed_modes = func () {
    setprop("/instrumentation/flightdirector/vertical-vs-mode", MANAGED_MODE);
    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
    setprop("/instrumentation/flightdirector/lateral-mode", MANAGED_MODE);
    turn_on_athr();
    setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);
}


## ---------------------------------------------------------------------
## ++++++++++++++++++++++++++++ Cruise Mode ++++++++++++++++++++++++++++
## ---------------------------------------------------------------------

## Start cruise speed after 30 sec
var delay_cruise_speed = func () {
    var t = maketimer(30, func {
		# recheck if cruise mode is still active
		var vnav = fdVNAV.getValue();
		if (vnav == VNAV.ALTCRZ)
		    setSPD(SPD.CRZ);
	    });
    t.singleShot = TRUE;
    t.start();
};

## Cruise acquisition
setlistener("/instrumentation/flightdirector/acquire-cruise", func (n) {
    var crz = n.getValue();
    if ( crz == TRUE ) {
	setVNAV(VNAV.ALTCRZ);
	setprop("/instrumentation/flightdirector/vnav-arm", VNAV.OFF);
	# delay start of cruise speed for 30 sec
	delay_cruise_speed();
    }
}, 0, 0);

## Switch between mach and knots modes
var toggle_mach_knot = func () {
    var atOn = fdATEngage.getValue();

    if (atOn == OFF) return;

    if ( spdPitchMode.getValue() ) {
	setSpeedPitch();
    } else {
	setSpeedThrottle();
    }
};

setlistener("/instrumentation/flightdirector/mach-mode", toggle_mach_knot, 0 , 0);

## Toggle mach/knots at the cross-over altitude
setlistener("/instrumentation/fmc/changeover-mode", func (n) {
    var mode = n.getValue();
    setprop("/instrumentation/flightdirector/mach-mode", mode);
}, 0 , 0);


## ------------------------------------------------------------------------------
## ++++++++++++++++++++++++++++++++ Descend Mode ++++++++++++++++++++++++++++++++
## ------------------------------------------------------------------------------

var desListeners = [ nil, nil ];

## delay start to descent to allow time for the target altitude to be set
var start_descent = func () {
    var t = maketimer(1.0, func {
		setVNAV(VNAV.DES);
	    });
    t.singleShot = TRUE;
    set_altitude();
    t.start();
}

## Respond to changes in deceleration phase steps
var decel_step = func () {
    var step = getprop("/instrumentation/flightdirector/decel-step");

    if (step == DecelPhase.Level) {
	# delayed level off
	var t = maketimer(0.5, func {
		    set_altitude();
		    setVNAV(VNAV.LEVEL);
		    # reset descend arm
		    setprop("/instrumentation/flightdirector/descend-arm", OFF);
		});
	t.singleShot = TRUE;
	t.start();
    } elsif (step == DecelPhase.Leave) {
	# exit from the level
    } elsif (step == DecelPhase.Acquire) {
	# nothing to do but wait
    };
}

## process the descend signal
var init_descent = func () {
    var armed = getprop("/instrumentation/flightdirector/descend-arm");
    if ( armed ) {
	var vnav    = fdVNAV.getValue();
	var crzAlt  = fmcCruiseAlt.getValue();
	var alt	    = altFtNode.getValue();
	# we do not want to remain in ALTCRZ mode or LEVEL mode above cruise
	if (vnav == VNAV.ALTCRZ) {
	    setVNAV(VNAV.ALT);
	}
	if (vnav == VNAV.LEVEL and alt >= crzAlt) {
	    setVNAV(VNAV.ALT);
	}

	start_descent();
    }
}

var create_des_listeners =  func () {
    ## Descend Arm
    if (desListeners[0] == nil) {
	desListeners[0] = setlistener("/instrumentation/flightdirector/descend-arm",
				    init_descent, 0, 0);
    }

    ## Deceleration mode
    if (desListeners[1] == nil) {
	desListeners[1] = setlistener("/instrumentation/flightdirector/decel-step",
				    decel_step, 0, 0);
    }
}

# remove the descend listeners when no longer needed
var del_des_listeners = func () {
    forindex(var j; desListeners) {
	if (desListeners[j] != nil) {
	    removelistener(desListeners[j]);
	    desListeners[j] = nil;
	}
    }
}

setlistener("/autopilot/internal/monitor-descent-on", func (n) {
    if ( n.getValue() ) {
	create_des_listeners();
    } else {
	del_des_listeners();
    }
}, 0, 0);


##
## ++++++++++++++++++++++++ FLIGHT DIRECTOR FUNCTIONS +++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#############################################################################
## Flight director phases
## ----------------------
##
## The FD and autopilot systems are designed to work together, but it is
## possible to use the flight director without engaging the autopilot, or
## the autopilot without the FD. Without autopilot engagement, the FD
## presents all processed information to the pilot in the form of command
## bar cues, but you must manually fly the airplane to follow these cues
## to fly the selected flightpath.
##
## When you engage the autopilot, it simply follows the cues generated by
## the flight director to control the airplane along the selected
## lateral and vertical paths.
#############################################################################

## signal to the autopilot to change flight parameters when necessary
var inc_fd_signal = func () {
    var n = getprop("/instrumentation/flightdirector/fd-signal") + 1;
    setprop("/instrumentation/flightdirector/fd-signal", n);
}

## re-evaluate the flight phase
var eval_flight_phase = func () {
    var alt = altFtNode.getValue();
    var fltMode = fmcFlightMode.getValue();
    var tod = getprop("/instrumentation/flightdirector/past-td");
    var locInRange = getprop("/instrumentation/nav[0]/in-range");
    var phase = getprop("/instrumentation/flightdirector/fd-phase");

    if (fltMode > FlightModes.FLARE)  {	# land
	phase = FlightPhase.Land;
    } elsif (fltMode == FlightModes.FLARE)  {	# final approach
	phase = FlightPhase.Final;
    } elsif (fltMode < FlightModes.V1) {	# Off
	phase = FlightPhase.Off;
    } elsif (fltMode < FlightModes.CLB) {	# Takeoff
	phase = FlightPhase.TO;
    } elsif ( tod == TRUE and phase < FlightPhase.Descent) {	# Descent
	phase = FlightPhase.Descent;
    } elsif (phase < FlightPhase.Mission) {
	phase = FlightPhase.Climb;
    }

    # now set the phase
    setprop("/instrumentation/flightdirector/fd-phase", phase);
}

## This function updates the flight parameters when the FD is active
var exec_flight_phase = func (phase) {
    var mode = apLocksPassive.getValue();
    if (mode != PassiveMode.ON) {
	return;
    }

    # we always operate in managed modes
    if (phase != FlightPhase.Land)  set_managed_modes();

    # here we are mainly interested in fixing one-way switches
    # in case we entered a "dangling" phase
    var vnav = fdVNAV.getValue();

    if (phase == FlightPhase.TO) {

    } elsif (phase == FlightPhase.Climb) {
	setprop("/instrumentation/flightdirector/past-tc", FALSE);
	setprop("/instrumentation/flightdirector/past-td", FALSE);
	if (vnav != VNAV.CLB) {
	    setVNAV(VNAV.CLB);
	}

    } elsif (phase == FlightPhase.Mission) {
	setprop("/instrumentation/flightdirector/past-tc", TRUE);
	setprop("/instrumentation/flightdirector/past-td", FALSE);
	if (vnav != VNAV.ALTCRZ and vnav != VNAV.ALT) {
	    setVNAV(VNAV.ALT);
	}

    } elsif (phase == FlightPhase.Descent) {
	setprop("/instrumentation/flightdirector/past-tc", TRUE);
	setprop("/instrumentation/flightdirector/past-td", TRUE);
	# this ought to be set automatically
	if (vnav != VNAV.ALT and vnav != VNAV.DES) {
	    var des = getprop("/instrumentation/flightdirector/descend-arm");
	    if (des == OFF) {
		setprop("/instrumentation/flightdirector/descend-arm", ON);
	    } else {
		start_descent();
	    }
	}

    } elsif (phase == FlightPhase.Decel) {
	# we might need to increase the step to "level"
	var step = getprop("/instrumentation/flightdirector/decel-step");
	var des = getprop("/instrumentation/flightdirector/descend-arm");
	if (step < DecelPhase.Level and vnav != VNAV.DES) {
	    setprop("/instrumentation/flightdirector/decel-step", DecelPhase.Level);
	    # reset disarm trigger - it will be triggered on automatically
	    setprop("/instrumentation/flightdirector/descend-arm", OFF);
	}

    } elsif (phase == FlightPhase.Appr) {
	# this ought to be switch to DES automatically
	if (vnav != VNAV.DES) {
	    setprop("/instrumentation/flightdirector/descend-arm", ON);
	}

    } elsif (phase == FlightPhase.Loc) {
	setprop("/instrumentation/flightdirector/loc-on", ON);
	if (vnav != VNAV.ALT and vnav != VNAV.AGL) {
	    setVNAV(VNAV.ALT);
	}

    } elsif (phase == FlightPhase.Final) {
	setprop("/instrumentation/flightdirector/appr-on", ON);
	if (vnav != VNAV.GS and vnav != VNAV.AGL) {
	    setVNAV(VNAV.AGL);
	}

    } elsif (phase == FlightPhase.Land) {

    } elsif (phase == FlightPhase.GA) {
	go_around();

    }
}

## the FD setting does not do have a direct effect, but rather sets passive mode
var passive_lock = func () {
    var status = apLocksPassive.getValue();

    if ( status == PassiveMode.ON ) {
	set_managed_modes();
	# This timer sets the vertical mode a few seconds after passive mode is entered,
	# giving time for the other variables (VNAV) to update
	var passiveTimer = maketimer(1.0, func {
		reevaluate_modes(); });
	passiveTimer.singleShot = TRUE;
	passiveTimer.start();   # set the altitude
    }
}

## To avoid repeat invocation of the FD signal processing, we monitor the last signal
## issued, then only invoke the procedure if this changes
var currentFDsignal = -1;

var flight_phase_signal = func () {
    var v = getprop("/instrumentation/flightdirector/fd-signal");
    if (v != currentFDsignal) {
	var phase = getprop("/instrumentation/flightdirector/fd-phase");
	exec_flight_phase(phase);
	currentFDsignal = v;
    }
}

## Flight director listeners
var fdListeners = [ nil, nil, nil ];

## toggle the listeners depending on the status of the FD button
var toggle_fdListeners = func () {
    var status = fdFDOn.getValue();

    if (status == ON) {
	# listen for the passive mode setting
	if (fdListeners[0] == nil) {
	    fdListeners[0] = setlistener("/autopilot/locks/passive-mode", passive_lock, 0, 0);
	}
	# listen for the flight phase changes
	if (fdListeners[1] == nil) {
	    fdListeners[1] = setlistener("/instrumentation/flightdirector/fd-phase", inc_fd_signal, 0, 0);
	}
	# listen for the flight phase changes
	if (fdListeners[2] == nil) {
	    fdListeners[2] = setlistener("/instrumentation/flightdirector/fd-signal", flight_phase_signal, 0, 0);
	}
    } else {
	forindex(var j; fdListeners) {
	    if (fdListeners[j] != nil) {
		removelistener(fdListeners[j]);
		fdListeners[j] = nil;
	    }
	}

    }
}

## initialise the FD functions
var initFD = func () {
    # create listeners, then trigger the FD signal
    toggle_fdListeners();
    inc_fd_signal();
}

## suspend the FD functions
var stopFD = func () {
    toggle_fdListeners();
}


## Emergency Go-Around mode
## -------------------------
var go_around = func () {
    # gear up
    setprop("/controls/gear/gear-down", FALSE);
    # reset unneeded items
    setprop("/instrumentation/flightdirector/fd-on", OFF);
    setprop("/autopilot/route-manager/active", OFF);
    reset_alt_vector();
    setprop("/instrumentation/flightdirector/fd-phase", FlightPhase.GA);
    setprop("/instrumentation/fmc/landing/descent-rate-ratio", 0);
    var alt = posAltFt.getValue() + 6000;
    setprop("/instrumentation/fmc/altitude-ft", alt);
    # we do not want to return to the old cruise altitude
    setprop("/instrumentation/fmc/cruise-alt-ft", alt + 2000);
    # reset the ToC and ToD indicators
    setprop("/instrumentation/flightdirector/past-tc", FALSE);
    setprop("/instrumentation/flightdirector/past-td", FALSE);
    make_toc_listener();
    setprop("/instrumentation/flightdirector/loc-on", OFF);
    setprop("/instrumentation/flightdirector/loc-arm", OFF);
    setprop("/instrumentation/flightdirector/appr-on", OFF);
    setprop("/instrumentation/flightdirector/appr-arm", OFF);
    setprop("/autopilot/internal/vorloc-intercepted-good", FALSE);
    setprop("/autopilot/internal/vorloc-intercepted-weak", FALSE);
    setprop("/autopilot/internal/gs-intercepted-good", FALSE);
    setprop("/autopilot/internal/gs-intercepted-weak", FALSE);
};


##
## ++++++++++++++++++++++++++++++ INITIALISATION ++++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

var init_fg_fms = func () {
    logprint(LOG_INFO, "Initialising Flight Guidance");

    # initialise the FMS container
    victorFMS = FMS.new();

    # remove the FDM listener
    removelistener(fgInitListener);

    # create the ToC listener
    make_toc_listener();
};

var fgInitListener = setlistener("/sim/signals/fdm-initialized", init_fg_fms, 0, 0);


##
## +++++++++++++++++++++++++++ SHUTDOWN FUNCTIONS +++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


#############################################################################
# Shutdown routine
#############################################################################

## utility function so shut down running timers in this file
var stopFgTimers = func {
    stopNavTimer();
    stop_turn_monitor();
};


################################# END #######################################
