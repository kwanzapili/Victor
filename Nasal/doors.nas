################################################################################
#
#			Handley Page Victor Door System
#
###############################################################################

##
## +++++++++++++++++++++++++++++ Doors and Chute ++++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## Create doors
var cockpit_door  = aircraft.door.new ("/controls/doors/cockpit-door/", 4);
var chute_door	  = aircraft.door.new ("/controls/doors/chute-door/", 2);
var chute_switch  = aircraft.door.new ("/controls/doors/chute-switch/", 1);
var bb_doors	  = aircraft.door.new ("/controls/doors/bomb-bay/", 5);
var jettison_door = aircraft.door.new ("/controls/doors/jettison/", 5);

var toggle_cockpit_door = func {
    if ( fmcCtrlGnd.getValue() ) cockpit_door.toggle();
    else screen.log.write("Cockpit door can only be opened while on the ground");
}

# Drag Chute properties
var ctrlSwChute = props.globals.getNode("/controls/switches/chute");
var ChuteSwPos	= { LOCK: -1, STANDBY: 0, RELEASE: 1 };

## Chute switch OPEN/CLOSE
setlistener("/fdm/jsbsim/systems/chute/chute-switch-cmd", func (n) {
    if ( n.getValue() )	chute_switch.open();
    else		chute_switch.close();

    # plsy a sound
    setprop("/sim/sound/effects/chute-switch", TRUE);
    var t = maketimer(1.0, func {
                        setprop("/sim/sound/effects/chute-switch", FALSE);
                    });
    t.singleShot = TRUE;
    t.start();
}, 0, 0);

## Chute door OPEN/WAIT/CLOSE
setlistener("/fdm/jsbsim/systems/chute/chute-door-cmd", func (n) {
    var cmd = n.getValue();
    if ( cmd == ChuteSwPos.RELEASE )	chute_door.open();
    elsif ( cmd == ChuteSwPos.LOCK )	chute_door.close();
    # otherwise wait in the current state
}, 0, 0);

# Increase chute switch
var incr_chute_switch = func () {
    var sw = ctrlSwChute.getValue() + 1;
    if (sw <= ChuteSwPos.RELEASE) ctrlSwChute.setValue(sw);
}

# Decrease chute switch
var decr_chute_switch = func () {
    var sw = ctrlSwChute.getValue() - 1;
    if (sw >= ChuteSwPos.LOCK) ctrlSwChute.setValue(sw);
}

## Toggle switch position: Locked -> Standby <-> Release
var toggle_chute = func () {
    var sw = ctrlSwChute.getValue();
    if (sw == ChuteSwPos.RELEASE) decr_chute_switch();
    else incr_chute_switch();
}

## Toggle switch position: Locked <-> Standby <-> Release
var operate_chute = func (move) {
    if ( move > 0 )	incr_chute_switch();
    elsif ( move < 0 )	decr_chute_switch();
}

########################################################################################
## Bay Doors
########################################################################################

# Normal BB doors have 3 positions - Closed, Auto, Open.
# controls/doors/bb-doors has 3 values:
# Locked	: -1 (doors cannot be operated - due to a missile outside)
# Closed	: 0
# Open		: 1
# Note that the toggle_bb_doors function only selects Close and Open

var BayPos	= { Locked: -1, Closed: 0, Open: 1 };

var open_doors	= func { bb_doors.open(); };
var close_doors	= func { bb_doors.close(); };

# This just a utility to trigger the sound effect of the lock engaging or releasing
var oldPos = BayPos.Closed;

var lock_sound = func (pos) {
    # play a sound for a few secs is releasing or locking
    var play = FALSE;

    # Locked -> Closed or Closed -> Locked: play sound
    if (oldPos == BayPos.Locked or pos == BayPos.Locked) play = TRUE;

    # set the new position
    oldPos = pos;

    if (play == FALSE) return;

    setprop("/sim/sound/effects/bay-lock", TRUE);
    var t = maketimer(1.0, func {
			setprop("/sim/sound/effects/bay-lock", FALSE);
		    });
    t.singleShot = TRUE;
    t.start();
}

setlistener("/controls/doors/bb-door-pos", func (n) {
    var doorPos	= n.getValue();

    # If Locked, we just need to make sure the doors are closed
    if (doorPos == BayPos.Locked) {
	close_doors();
        bb_doors.enable(FALSE);
    } else {
	# re-enable doors
	bb_doors.enable(TRUE);
        if (doorPos == BayPos.Open)	open_doors();
        else    close_doors();
    }
    lock_sound(doorPos);
}, 0, 0);

var toggle_bb_doors = func {
    var doorPos = getprop("controls/doors/bb-door-pos");

    if (doorPos == BayPos.Open) { # Open to Closed
	setprop("/controls/doors/bb-door-pos", BayPos.Closed);
    } elsif (doorPos == BayPos.Closed) {
	setprop("/controls/doors/bb-door-pos", BayPos.Open);
    } else { # (doorPos == BayPos.Locked) doors cannot be operated
	screen.log.write("Sir, bay doors are locked");
    }
}

#
# Emergency jettison function:
# 1) Opens the BB doors
# 2) Jettisons all stores
# 3) Closes the BB doors
#
# Over-ride is possible by selecting the switch.
# Note that this is not available for nuclear weapons (see pilots notes)
# or Shrikes, which are mounted on the wings.

# Toggle emergency door
var emerg_toggle_bb_doors = func (openbay) {
    var doorPos = getprop("controls/doors/bb-door-pos");

    if (doorPos == BayPos.Locked) {     # doors cannot be operated
	screen.log.write("Sir, bay doors cannot be opened");
    } elsif (openbay == TRUE) {
	setprop("/controls/doors/bb-door-pos", BayPos.Open);
    } else {
	setprop("/controls/doors/bb-door-pos", BayPos.Closed);
    }
}

setlistener("controls/doors/emergency-bb-door-pos", func (n) {
    emerg_toggle_bb_doors(n.getValue());
}, 0, 0);

## Jettison one bomb every 0.6 secs
var jettisonBomb = func () {
    # no unsafe releases
    var safe	= safeRelease.getValue();
    var stn     = selStation.getValue();
    var avail   = getprop("controls/armament/station["~stn~"]/units");
    # one last check if the emergency switch is still on
    var keepon	= getprop("controls/doors/emergency-bb-jettison-pos");

    if (avail < 1 or keepon == OFF) {
	jettisonBombTimer.stop();
	setprop("/controls/doors/emergency-bb-jettison-pos", OFF);
    } elsif ( safe ) {
	pullTrigger(stn, 0.2);
    }
}

var jettisonBombTimer = maketimer(0.6, jettisonBomb);

## Jettison all bombs from the bay
var jettison_bombs = func () {
    # one last check if the emergency switch is still on
    if (getprop("controls/doors/emergency-bb-jettison-pos") == OFF) {
	return;
    }

    var wpn = mainWeapon.getValue();
    var stn = -1;
    var j   = -1;
    forindex(var index; Conventional) {
	j = Conventional[index];
	if (wpn == WpnInfo[j].name) {
	    stn = WpnInfo[j].station;
	    break;
	}
    }

    if (stn < 0) return;        # nothing found

    if ( WpnInfo[stn].inbay ) {
        setprop("/controls/armament/station-select", stn);
        jettisonBombTimer.start();
    }
}

var jettisonTimer = maketimer(6, jettison_bombs);
jettisonTimer.singleShot = TRUE;

## Trigger function for jettison of all bombs
var emerg_jettison = func (jettison) {
    # Only jettison conventional bombs
    var wpn_type = getWpnType();
    if ( wpn_type == WpnClass.Bomb ) {
	logprint(LOG_INFO, "Emergency jettison of all loaded bombs!");
	if ( jettison == FALSE ) {
	    jettisonTimer.stop();     # abort jettison
	    setprop("/controls/doors/emergency-bb-door-pos", OFF);
	} else {
	    setprop("/controls/doors/emergency-bb-door-pos", ON);
	    jettisonTimer.start();
	}
    }
}

setlistener("controls/doors/emergency-bb-jettison-pos", func (n) {
    emerg_jettison(n.getValue());
}, 0, 0);

################################# END #######################################
