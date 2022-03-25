#########################################################################
# Handley Page Victor: Flight Director System
#
#  Abstract:
#    This file contains the nasal code specific to the flightdirector.
#
#########################################################################


#############################################################################
# Lateral Mode
#############################################################################

## Process LNAV
## -------------
var listenerLNAV = func (lnav) {
    var fltMode = fmcFlightMode.getValue();
    var apOn	= fdAPEngage.getValue();
    var apSwitch = ctrlSwitchAP.getValue();
    var onGround = fmcCtrlGnd.getValue();

    if ( apOn == ON and apSwitch == ON ) {
    	# we must check both switch and engagement due to a delay in processing the switch
	if (lnav == LNAV.OFF or lnav == nil) {
	    setprop("/autopilot/locks/heading", "");

	} elsif (lnav == LNAV.RWY) {  # RWY - the only other mode allowed on ground
	    setprop("/autopilot/locks/heading", "runway-heading");
	    setprop("/instrumentation/flightdirector/lateral-mode", MANAGED_MODE);
	    set_heading_mode();

	} elsif (onGround == TRUE) { # no other mode is allowed
	    setprop("/autopilot/locks/heading", "");
	    setLNAV(LNAV.OFF);
	    return;

	} elsif (lnav == LNAV.LEVEL) { # use managed mode because user has no input
	    setprop("/autopilot/locks/heading", "wing-leveler");
	    setprop("/instrumentation/flightdirector/lateral-mode", MANAGED_MODE);
	    set_wl_mode();

	} elsif (lnav == LNAV.HDG) {   # HDG (s)
	    setprop("/autopilot/locks/heading", "dg-heading-hold");
	    setprop("/instrumentation/flightdirector/lateral-mode", SELECTED_MODE);
	    set_heading_mode();

	} elsif (lnav == LNAV.NAV) {  # NAV (fms)
	    # NAV steers the aircraft along the lateral flight plan defined in the FMS
	    setprop("/autopilot/locks/heading", "true-heading-hold");
	    setprop("/instrumentation/flightdirector/lateral-mode", MANAGED_MODE);
	    set_nav_mode();

	} elsif (lnav == LNAV.LOC) {   # LOC
	    # LOC steers the aircraft along a localizer beam
	    setprop("/autopilot/locks/heading", "nav1-hold");
	    # LOC must be enabled first
	    if ( fdLocEnable.getValue() == TRUE ) {
		setLOC();
	    } else {	# revert to NAV or HDG
		disableLOC(lnav);
	    }

	} elsif (lnav == LNAV.TACAN) {	# TACAN
	    setprop("/autopilot/locks/heading","tacan-hold");
	    setprop("/instrumentation/flightdirector/lateral-mode", MANAGED_MODE);
	    set_nav_mode();

	} else {
	    setprop("/autopilot/locks/heading", "");
	    setprop("/instrumentation/flightdirector/lnav", LNAV.OFF);
	}

    } else {
	setprop("/autopilot/locks/heading", "");
	setprop("/instrumentation/flightdirector/lateral-mode", SELECTED_MODE);
	# make sure the LNAV is off
	setprop("/instrumentation/flightdirector/lnav", LNAV.OFF);
    }

};

setlistener("/instrumentation/flightdirector/lnav", func(n) {
    var lnav = n.getValue();
    listenerLNAV(lnav);
}, 0, 0);

##
## Set LNAV mode:
## Preferrable all setting of LNAV should be done by this procedure.
## When invoked, it will ensure that listenerLNAV is always called either after
## setting the property or directly.
var setLNAV = func (lnav) {
    var current = fdLNAV.getValue();

    if (current == lnav) {	# just call listenerLNAV
	listenerLNAV(lnav);
    } else {	# set the property and the listener will call listenerLNAV
	setprop("/instrumentation/flightdirector/lnav", lnav);
    }
};

## Fix lateral managed mode
setlistener("/instrumentation/flightdirector/lateral-managed-mode", func (n) {
    reset_lnav();
}, 0, 0);


#############################################################################
# Vertical Mode
#############################################################################

##
## The AP/FD vertical mode determines the associated A/THR mode:
##  * When an AP/FD vertical mode controls a speed or Mach target,
##    the A/THR mode controls thrust
##  * When an AP/FD vertical mode controls the vertical trajectory,
##    the A/THR mode controls a speed or Mach target.
##
## AP/FD Vertical Modes and Associated A/THR Modes
## THRUST modes:    OP CLB, CLB, OP DES, DES (in idle path)
## SPEED/MACH modes: V/S / FPA, ALT, ALT CRZ, DES (in geometric path), G/S, LAND
##

## Process VNAV
## -------------
var listenerVNAV = func(vnav) {
    var onGround = fmcCtrlGnd.getValue();
    var apOn	 = fdAPEngage.getValue();
    var apSwitch = ctrlSwitchAP.getValue();
    var spd	 = fdSPD.getValue();	# this value might need to be fixed
    var curSpd   = spd;

    if (apOn == ON and apSwitch == ON) {
    	# we must check both switch and engagement due to a delay in processing the switch
	if (vnav == VNAV.OFF) {
	    setprop("/autopilot/locks/altitude", "");

	} elsif (onGround == TRUE) {	# VNAV must be off - reset
	    setprop("/instrumentation/flightdirector/vnav", VNAV.OFF);
	    setprop("/autopilot/locks/altitude", "");
	    return;

	} elsif (vnav == VNAV.ALT) {   # ALT (s/m)
	    setprop("/instrumentation/flightdirector/alt-acquire-mode", OFF);
	    setprop("/autopilot/locks/altitude", "altitude-hold");
	    set_alt_mode();

	} elsif (vnav == VNAV.VS) {   # V/S (s)
	    setprop("/instrumentation/flightdirector/vertical-vs-mode", SELECTED_MODE);
	    setprop("/autopilot/locks/altitude", "vertical-speed-hold");
	    set_vs_mode();

	} elsif (vnav == VNAV.FPA) {  # pitch hold
	    setprop("/autopilot/locks/altitude", "pitch-hold");

	} elsif (vnav == VNAV.OPCLB) {   # OP CLB (s): Alt = s, VS = ?
	    # climb towards the AFS CP selected altitude, maintaining a TARGET SPEED
	    # (managed or selected) with a fixed given thrust
	    # we want to use a fixed thrust mode
	    spd = SPD.SPDPTCH;

	    setprop("/instrumentation/flightdirector/alt-acquire-mode", ON);
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", SELECTED_MODE);
	    setprop("/autopilot/locks/altitude", "climb-mode");
	    set_vs_mode();

	} elsif (vnav == VNAV.OPDES) {   # OP DES (s): Alt = s, VS = ?
	    # descend towards the AFS CP selected altitude, maintaining a TARGET SPEED
	    # (managed or selected) with a fixed given thrust
	    # we want to use a fixed thrust mode
	    if ( spd != SPD.THRIDL ) spd = SPD.SPDPTCH;

	    setprop("/instrumentation/flightdirector/alt-acquire-mode", ON);
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", SELECTED_MODE);
	    setprop("/autopilot/locks/altitude", "descend-mode");
	    set_vs_mode();

	} elsif (vnav == VNAV.ALTCRZ) {   # ALTCRZ (m)
	    # even through the default speed mode is cruise, it should be set after a delay
	    # so we leave the current spd mode for now, which is then reset later
	    setprop("/instrumentation/flightdirector/alt-acquire-mode", OFF);
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
	    setprop("/autopilot/locks/altitude", "altitude-hold");
	    set_alt_mode();

	} elsif (vnav == VNAV.CLB) {  # CLB (m): Alt = m, VS = m
	    # CLB steers the aircraft along the vertical path of the FMS flight plan
	    # and takes into account altitude and speed constraints of the flight plan

	    # we should always use "THR CLB"
	    spd = SPD.THRCLB;

	    setprop("/instrumentation/flightdirector/alt-acquire-mode", ON);
	    setprop("/instrumentation/flightdirector/vertical-vs-mode", MANAGED_MODE);
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
	    setprop("/autopilot/locks/altitude", "vertical-speed-hold");
	    set_vs_mode();

	} elsif (vnav == VNAV.DES) {  # DES (m): Alt = m, VS = m
	    # DES steers the aircraft along the vertical path of the FMS flight plan
	    # and takes into account altitude and speed constraints of the flight plan
	    # we should always use "THR DES"
	    spd = SPD.THRDES;

	    setprop("/instrumentation/flightdirector/alt-acquire-mode", ON);
	    setprop("/instrumentation/flightdirector/vertical-vs-mode", MANAGED_MODE);
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
	    setprop("/autopilot/locks/altitude", "vertical-speed-hold");
	    set_vs_mode();

	} elsif (vnav == VNAV.GS) {   # G/S
	    var good = apGSintercept.getValue();
	    var weak = apGSweak.getValue();
	    if ( (good == TRUE) or (weak == TRUE) ) {
		# we only accept manual or SPEED mode
		if ( spd != SPD.OFF ) spd = SPD.SPEED;

		setprop("/instrumentation/flightdirector/alt-acquire-mode", OFF);
		setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
		setprop("/instrumentation/flightdirector/vertical-vs-mode", MANAGED_MODE);
		setprop("/autopilot/locks/altitude", "gs1-hold");
		setAPPR();
	    } else {	# revert to V/S
		setVNAV(VNAV.VS);
		return;
	    }

	} elsif (vnav == VNAV.LEVEL) {   # LEVEL (m)
	    # use vertical speed rather than pitch hold
	    setprop("/instrumentation/flightdirector/alt-acquire-mode", OFF);
	    setprop("/instrumentation/flightdirector/vertical-vs-mode", MANAGED_MODE);
	    setprop("/autopilot/locks/altitude", "vertical-speed-hold");
	    set_vs_mode();

	} elsif (vnav == VNAV.AGL) {   # AGL (m)
	    setprop("/instrumentation/flightdirector/alt-acquire-mode", OFF);
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
	    setprop("/autopilot/locks/altitude", "agl-hold");
	    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
	    set_alt_mode();

	} else {    # wrong mode
	    setprop("/instrumentation/flightdirector/vnav", VNAV.OFF);
	    setprop("/autopilot/locks/altitude", "");
	    return;
	}

    } else {	# AP is off
	# make sure that VNAV is off
	setprop("/instrumentation/flightdirector/vnav", VNAV.OFF);
	setprop("/autopilot/locks/altitude", "");
	setprop("/instrumentation/flightdirector/vertical-alt-mode", SELECTED_MODE);
	setprop("/instrumentation/flightdirector/vertical-vs-mode", SELECTED_MODE);
    }

    # align VNAV and SPD modes
    if (curSpd != spd) setSPD(spd);
};

## Realign the VNAV and SPD modes when they are misaligned
setlistener("/instrumentation/flightdirector/vnav-spd-mismatch", func (n) {
    if ( n.getValue() ) {
	var spd = fdSPD.getValue();
	setSPD(spd);
	# reset the mismatch value
	setprop("/instrumentation/flightdirector/vnav-spd-mismatch", FALSE);
    };
}, 0, 0);

## Main listener for VNAV mode
setlistener("/instrumentation/flightdirector/vnav", func(n) {
    var vnav = n.getValue();
    listenerVNAV(vnav);
}, 0, 0);

##
## Set VNAV mode:
## Preferrable all setting of VNAV should be done by this procedure.
## When invoked, it will ensure that listenerVNAV is always called either after
## setting the property or directly.
var setVNAV = func (vnav) {
    var current = fdVNAV.getValue();

    if (current == vnav) {	# just call listenerVNAV
	listenerVNAV(vnav);
    } else {	# set the property and the listener will call listenerVNAV
	setprop("/instrumentation/flightdirector/vnav", vnav);
    }
};

## Fix wrong climb or descend mode
var switchClbDes = func (n) {
    var vnav	= fdVNAV.getValue();
    var altMode = fdAltMode.getValue();
    var vsMode	= fdVsMode.getValue();
    if (n == ClimbDescend.Des) {
	if ( altMode == MANAGED_MODE ) vnav = VNAV.DES;
	else vnav = VNAV.OPDES;
    } elsif (n == ClimbDescend.Clb) {
	if ( altMode == MANAGED_MODE ) vnav = VNAV.CLB;
	else vnav = VNAV.OPCLB;
    }
    setVNAV(vnav);
    # reset the signal indicating a problem.
    setprop("/instrumentation/flightdirector/vnav-mode-mismatch", FALSE);
};

setlistener("/instrumentation/flightdirector/vnav-mode-mismatch", func (n) {
    if ( n.getValue() == TRUE ) {	# there is a mistake
	var mode = getprop("/autopilot/internal/elevation/des-hold-clb");
	switchClbDes(mode);
    }
}, 0, 0);

## Verify V/S managed mode
## Managed climb and descend modes use managed vertical speed
var verifyVertModes = func () {
    var apOn    = fdAPEngage.getValue();


    if (apOn == OFF) {	# this check is necessary because we do not call setVNAV
	setprop("/instrumentation/flightdirector/vnav", VNAV.OFF);
    } else {
	# evaluate the new mode after a short delay to give the evaluator time to update
	reset_vnav();
    }
};

## Listen to both vertical modes
setlistener("/instrumentation/flightdirector/vertical-alt-mode", verifyVertModes, 0, 0);
setlistener("/instrumentation/flightdirector/vertical-vs-mode", verifyVertModes, 0, 0);


## Switch to ALT-HOLD or LEVEL
var holdALT = func () {
    var apOn = fdAPEngage.getValue();
    if (apOn == OFF) return;

    var altMode = fdAltMode.getValue();

    # There are several posible settings:
    # * In Alt select mode, we switch to ALT
    # * In Alt managed mode, we choose between these options:
    #	- In final approach, use AGL mode
    #	- In desecent mode, switch to LEVEL before deceleration
    #	- If climbing above the cruise altitude, switch to level
    #	- Otherwise, switch to ALT

    if (altMode == MANAGED_MODE) {
	var final   = fdInAppr.getValue();
	var phase   = fdPhase.getValue();
	var crzAlt  = fmcCruiseAlt.getValue();
	var desAlt  = fmcDecelAlt.getValue();
	var curAlt  = altFtNode.getValue();

	if ( final ) {
	    setVNAV(VNAV.AGL);
	} elsif (curAlt > crzAlt) {
	    setVNAV(VNAV.LEVEL);
	} else {
	    setVNAV(VNAV.ALT);
	}
    }
    else {
	setVNAV(VNAV.ALT);
    }

    # initially revert to speed-with-throttle
    set_spdthr();
}

setlistener("/autopilot/internal/switch-to-alt-hold", func (n) {
    if ( n.getValue() )  holdALT();
}, 0, 0);



#############################################################################
# LOCaliser Mode
#############################################################################

## Disable LOC mode if we lose the LOCaliser signal
var disableLOC = func (lnav) {
    if ( lnav != LNAV.LOC ) return;

    var landing	 = isLanding();
    var flt_mode = fmcFlightMode.getValue();
    var latMode	 = fdLatMode.getValue();
    var weakLoc	 = apLOCweak.getValue();
    var msg	 = "LOCaliser signal lost";

    # when the LOCaliser is lost, we respond based on mode
    # * in flare or retard - use RUNWAY because we are already aligned
    # * in final approach - disable autopilot and inform the pilot
    # * otherwise set NAV mode
    if ( landing ) {
	setLNAV(LNAV.RWY);
    }
    elsif ( weakLoc ) {	    # stay in LOC mode
	msg = "Drifting from LOCaliser mid-line";
    }
    elsif (flt_mode == FlightModes.FLARE) { # go around
	screen.log.write(msg);
	setprop("/instrumentation/fmc/landing/go-around", TRUE);
	caution();
    }
    else {    # switch to HDG or NAV mode
	screen.log.write(msg);
	caution();
	if ( latMode == SELECTED_MODE ) {
	    setLNAV(LNAV.HDG);
	} else {
	    setLNAV(LNAV.NAV);
	}
    }
    logprint(LOG_INFO, msg);
}

## Setting the LOCaliser only works if it is armed. This happens via filters.
var setLOC = func () {
    var intercepted = apLOCintercept.getValue();
    var weakLoc	    = apLOCweak.getValue();
    var apOn	    = fdAPEngage.getValue();
    var enabled	    = fdLocEnable.getValue();
    var lnav	    = fdLNAV.getValue();
    var landing	    = isLanding();

    if ( lnav != LNAV.LOC ) return;

    if ( apOn == OFF ) {
	setLNAV(LNAV.OFF);
	return;
    }

    # in flare or retard mode, we don't need the LOCaliser
    if ( landing ) {
	setLNAV(LNAV.RWY);
	return;
    }

    if ( enabled == FALSE ) { # disable LOC mode
	disableLOC(lnav);
	return;
    }
}

## Respond to the LOC enable signal
var locEnable = func () {
    var enabled = getprop("/instrumentation/flightdirector/loc-enable");
    # when we are committed to landing, we don't need the LOCaliser
    var landing	= isLanding();
    var lnav    = fdLNAV.getValue();
    if ( enabled ) {
	if (! landing ) setLNAV(LNAV.LOC);
	else		setLNAV(LNAV.RWY);
	# switch to AGL mode
	switch2AGL();
    }
    else    disableLOC(lnav);
};

## make sure we are in the correct mode during approach
var checkApproach = func () {
    var in_zone = getprop("/instrumentation/flightdirector/in-approach");
    var ap_on	= fdAPEngage.getValue();
    if (in_zone == FALSE or ap_on == FALSE) return;

    # we only allow three modes during the approach phase: AGL, DES or G/S
    var vnav = fdVNAV.getValue();
    if (vnav == VNAV.DES) {
	# let it complete the descent, then acquire the set altitude
	setprop("/instrumentation/flightdirector/alt-acquire-mode", ON);
    } elsif (vnav == VNAV.GS) {
	# do nothing
    } elsif (vnav == VNAV.AGL) {
	# do nothing
    } else {
	# switch to AGL mode
	switch2AGL();
    }
};

## LOC listeners are as follows:
##	- Index 0: zone signal
##	- Index 1: LOC enable

var LOClisteners = [ nil, nil ];

## Create the LOC listeners
var makeLOClisteners = func () {
    if (LOClisteners[0] == nil) {
	LOClisteners[0] = setlistener("/instrumentation/flightdirector/in-approach", checkApproach, 0, 0);
    }

    if (LOClisteners[1] == nil) {
	LOClisteners[1] = setlistener("/instrumentation/flightdirector/loc-enable", locEnable, 0, 0);
    }
};

## Destroy the LOC listeners
var delLOClisteners = func () {
    forindex(var j; LOClisteners) {
	if (LOClisteners[j] != nil) {
	    removelistener(LOClisteners[j]);
	    LOClisteners[j] = nil;
	}
    }
};


#############################################################################
# Glideslope Mode
#############################################################################

## Disable APPRoach when signal is lost
var disableAPPR = func (vnav) {
    if ( vnav != VNAV.GS ) return;

    var landing	  = isLanding();
    var gsIsClose = apGSweak.getValue();
    var msg = "Glideslope signal lost!";

    # if ILS signal is lost we respond based on current mode
    # - in flare / retard we do not mind because we can use FPA
    # - If the signal is weak, then we hope for recovery
    # - in final approach we tell the pilot to go around

    if ( landing ) {
	setVNAV(VNAV.VS);
    } elsif ( gsIsClose ) {
	setVNAV(VNAV.GS);
    } else {  # Go around
	screen.log.write(msg);
	setprop("/instrumentation/fmc/landing/go-around", TRUE);
	caution();
    }

    logprint(LOG_INFO, msg);
}

## Set APPRoach once the glideslope is intercepted
var setAPPR = func() {
    var intercepted = apGSweak.getValue();
    var apOn	    = fdAPEngage.getValue();
    var apprOn	    = fdApprEnable.getValue();
    var vnav	    = fdVNAV.getValue();
    var flt_mode    = fmcFlightMode.getValue();

    # we should be called in G/S mode only
    if ( vnav != VNAV.GS )
	return;

    if ( apOn == OFF ) {
	setVNAV(VNAV.OFF);
	return;
    }

    # only set if in normal or flare modes
    if (flt_mode != FlightModes.NORMAL and flt_mode != FlightModes.FLARE) {
	# Wrong flight mode, so revert to pitch hold
	setVNAV(VNAV.FPA);
	return;
    }

    if ( apprOn == TRUE ) {	# Good ILS signals
	setprop("/autopilot/locks/altitude", "gs1-hold");
    }
    elsif ( intercepted ) { # weak intercept
	setprop("/autopilot/locks/altitude", "gs1-hold");
    }
    else {	# ILS signals lost -  disable vertical mode and inform the pilot
	disableAPPR(vnav);
    }
}

## Respond to the G/S enable signal
var apprEnable = func () {
    var landing	= isLanding();
    var vnav	= fdVNAV.getValue();
    var enabled = getprop("/instrumentation/flightdirector/appr-enable");
    # if not committed to landing, try glideslope
    if ( enabled == TRUE and landing == FALSE )	setVNAV(VNAV.GS);
    else disableAPPR(vnav);
};

## Listen for the quality of the G/S signal
var weakApprSignal = func () {
    var vnav = fdVNAV.getValue();
    var intercept = apGSintercept.getValue();
    var weak = getprop("/autopilot/internal/gs-intercepted-weak");
    if ( weak == FALSE and intercept == FALSE ) disableAPPR(vnav);
};

## APPR listeners are as follows:
##	- Index 0: APPR weak signal
##	- Index 1: APPR enable

var APPRlisteners = [ nil, nil ];

## Create the LOC listeners
var makeAPPRlisteners = func () {
    if (APPRlisteners[0] == nil) {
	APPRlisteners[0] = setlistener("/autopilot/internal/gs-intercepted-weak", weakApprSignal, 0, 0);
    }

    if (APPRlisteners[1] == nil) {
	APPRlisteners[1] = setlistener("/instrumentation/flightdirector/appr-enable", apprEnable, 0, 0);
    }
};

## Destroy the LOC listeners
var delAPPRlisteners = func () {
    forindex(var j; APPRlisteners) {
	if (APPRlisteners[j] != nil) {
	    removelistener(APPRlisteners[j]);
	    APPRlisteners[j] = nil;
	}
    }
};


#############################################################################
# Waypoint Helpers
#
# Most of the waypoint management functions are in the flight guidance
# module "fms"
#############################################################################


## Switch to AGL mode during final approach
var switch2AGL = func () {
    var vnav	= fdVNAV.getValue();
    var passive = apLocksPassive.getValue();
    var final   = fdInAppr.getValue();

    # in final approach or active flightdirector mode, switch to AGL mode
    if ( final == TRUE ) {
	# for passive mode, switch unconditionally, otherwise VNAV must be ALT
	if ( (passive = PassiveMode.ON) or (vnav == VNAV.ALT) ) {
	    setVNAV(VNAV.AGL);
	}
    }
}


#############################################################################
# Speed Mode
#
# There are two parameters that an A/T can maintain, or try to attain:
# speed and thrust.
#
# In speed mode the throttle is positioned to attain a set target speed.
# This mode controls aircraft speed within safe operating margins.
#############################################################################

## Set speed throttle mode depending on mach mode
var setSpeedThrottle = func() {
    var machMode = fdMachMode.getValue();
    var curMode  = fdSPD.getValue();
    # if the mode is either OFF, SPEED or MACH, we can toggle it, otherwise we just set
    # the autopilot lock
    if ( (curMode == SPD.OFF) or (curMode == SPD.SPEED) or (curMode == SPD.MACH) ) {
	if ( machMode == TRUE ) {
	    var newmode = SPD.MACH;
	} else {
	    var newmode = SPD.SPEED;
	}
	setSPD(newmode);
    } else {
	if ( machMode == TRUE ) {
	    setprop("/autopilot/locks/speed", "mach-with-throttle");
	} else {
	    setprop("/autopilot/locks/speed", "speed-with-throttle");
	}
    }

    # ensure the autothrottle is ON
    turn_on_athr();
}

## Set speed pitch mode depending on mach mode
var setSpeedPitch = func() {
    if ( fdMachMode.getValue() == TRUE) {
	setprop("/autopilot/locks/speed", "mach-with-pitch-trim");
    } else {
	setprop("/autopilot/locks/speed", "speed-with-pitch-trim");
    }

    # ensure the autothrottle is ON
    turn_on_athr();
}

## Bit positions for each speed type
var p_bit = 0;	# pitch bit
var t_bit = 1;	# throttle bit
var o_bit = 2;	# off bit

## This utility functions simply compares two bit vectors and returns the
## number that matches the vector of compatible position, e.g. 6="11" indicates
## a compatability in both position. Thus, 0="00" indicates no clash at all.
var test_bit_vectors = func (a, b) {
    var n = 0;
    var m = 0;
    # compatability is defined if boths bits are not "1"
    for (var i = 0; i < 2; i += 1) {
	m = SpdVec[a][i] * SpdVec[b][i];
	n += n + m;
    }

    return n;
}

## Compute and return a compatible speed mode for a given VNAV mode
var computeSPD = func (vnav, spd) {
    # Deal with the exclusive modes first

    if (vnav == VNAV.ALTCRZ) {   # ALTCRZ (m) usually uses CRZ mode
	if (spd == SPD.CRZ) return (SPD.CRZ);
    }

    if (vnav == VNAV.DES) {  # DES (m) always uses THRDES
	return (SPD.THRDES);
    }

    if (vnav == VNAV.OPDES) {   # OP DES (s) always uses a fixed thrust mode
	# we only accept SPDPTCH
	return (SPD.SPDPTCH);
    }

    if (vnav == VNAV.OPCLB) {   # OP CLB (s) always uses a fixed thrust mode
	# we only accept SPDPTCH
	return (SPD.SPDPTCH);
    }

    if (vnav == VNAV.CLB) {  # CLB (m) always used THRCLB
	return (SPD.THRCLB);
    }

    if (vnav == VNAV.OFF) { # When VNAV is OFF no speed mode is allowed
	return (SPD.OFF);
    }

    var default = selectThrType();

    if (spd == SPD.THRIDL) {
	# we must be in flare mode
	var flare = fmcCtrlFlare.getValue();
	if ( flare == ON ) {
	    return (spd);
	} else {
	    return (default);
	}
    }

    # initial check got compliance
    var vnav_key = vnavStr[vnav];
    var spd_key  = spdStr[spd];
    var clash = test_bit_vectors(VnavBlocks[vnav_key], SpdBlocks[spd_key]);
    if (spd == SPD.CRZ and vnav != VNAV.ALTCRZ) {   # only allowed with VNAV = CRZ
	clash = 1;
    }
    if (clash == 0) {	# all is well
	return (spd);
    }

    # Some modes are not allowed without the corresponding VNAV
    if (spd == SPD.THRCLB or spd == SPD.THRDES)
	return (default);

    # get a new speed mode
    default = victorFMS.evaluateSpeed();
    spd_key = spdStr[default];
    clash = test_bit_vectors(VnavBlocks[vnav_key], SpdBlocks[spd_key]);
    if (clash > 0) {	# no luck - give up
	default = FallbackSpd[VnavBlocks[vnav_key]];
    }

    return (default);
}

##
## Set SPD mode
## -------------
## This is the ONLY place where "instrumentation/flightdirector/spd" is set,
## so that the mode is ALWAYS consistent with VNAV. The procedure accepts a
## desired SPD mode, but reserves the right to reject the request if it will
## result in incompatbility issues
##
var setSPD = func (spd) {
    var vnav	 = fdVNAV.getValue();
    var machMode = fdMachMode.getValue();

    # compute the correct speed mode
    var newSpd = computeSPD(vnav, spd);

    if ( newSpd == SPD.OFF ) {
	# switch off auto throttle
	var atOn = OFF;
    } else {
	# fix a few inconsistencies
	if ( machMode == TRUE and newSpd == SPD.SPEED ) newSpd = SPD.MACH;
	if ( machMode == FALSE and newSpd == SPD.MACH ) newSpd = SPD.SPEED;
	var atOn = ON;
    }

    setprop("/controls/switches/autothrottle", atOn);
    setprop("/instrumentation/flightdirector/spd", newSpd);
}

## Process SPD
## ------------
var listenerSPEED = func (spd) {
    var athrOn	= ctrlSwAT.getValue();
    # check the button not the engagement of the autothrottle mode
    var vnav	= fdVNAV.getValue();

    if ( athrOn == ON ) {

	if (spd == SPD.OFF) {   # OFF
	    setprop("/instrumentation/flightdirector/autothrottle-engage", OFF);
	    setprop("/autopilot/locks/speed", "");
	    turn_off_athr();

	} elsif (spd == SPD.SPEED) {   # SPEED (s)
	    setprop("/autopilot/locks/speed", "speed-with-throttle");

	} elsif (spd == SPD.MACH) {   # MACH (s)
	    setprop("/autopilot/locks/speed", "mach-with-throttle");

	} elsif (spd == SPD.THRCLB) {   # THR CLB
	    setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);
	    setSpeedThrottle();

	} elsif (spd == SPD.CRZ) { # CRZ
	    setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);
	    setSpeedThrottle();

	} if (spd == SPD.THRDES) {   # THR DES
	    setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);
	    setSpeedThrottle();

	} elsif (spd == SPD.THRIDL) {
	    setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);

	} elsif (spd == SPD.SPDPTCH) {
	    setprop("/instrumentation/flightdirector/speed-mode", SELECTED_MODE);
	    setSpeedPitch();

	}

    } else {
	setprop("/autopilot/locks/speed", "");
	if ( spd != SPD.OFF) setSPD(SPD.OFF);
    }

};

setlistener("/instrumentation/flightdirector/spd", func(n) {
    var spd = n.getValue();
    listenerSPEED(spd);
}, 0, 0);


## Choose betwwen SPEED or MACH modes
var selectThrType = func() {
    var sel = SPD.OFF;
    if ( fdATEngage.getValue() == ON  ) {
	var mode = fdMachMode.getValue();
	if ( mode ) sel = SPD.MACH;
	else	sel = SPD.SPEED;
    }

    return (sel);
}


## Revert to managed speed mode if SPD is incompatible with selected mode
var revertManagedSpd = func (target, current) {
    # try to change
    setSPD(target);
    var spd = fdSPD.getValue();	# get the new value
    if (spd == current ) { # the change failed
	setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);
    }
}

## When the speed managed mode changes, we might need to change the mode
setlistener("/instrumentation/flightdirector/speed-managed-mode", func (n) {
    var mode = n.getValue();
    var spd = fdSPD.getValue();     # this value might need to be fixed

    if ( mode == SELECTED_MODE ) { # check for permissible managed modes
	if ( spd == SPD.THRCLB ) { # try SPEED
	    revertManagedSpd(SPD.SPEED, spd);
	} elsif ( spd == SPD.CRZ ) { # try SPEED
	    revertManagedSpd(SPD.SPEED, spd);
	} elsif ( spd == SPD.THRDES ) { # try SPEED
	    revertManagedSpd(SPD.SPEED, spd);
	}
    } else {	# check for permissible managed modes
	if ( spd == SPD.SPDPTCH ) { # revert
	    setprop("/instrumentation/flightdirector/speed-mode", SELECTED_MODE);
	}
    }
}, 0, 0);


#############################################################################
# Landing Mode
#############################################################################

## Utility function to indicate if we are landing
var isLanding = func () {
    # if we are within 100 ft of the ground. assume we are landing anyway
    var landing = getprop("/instrumentation/fmc/landing/commit");
    return (landing);
}

## Utility functions to create and destroy the ILS listeners

var makeILSlisteners = func () {
    makeLOClisteners();
    makeAPPRlisteners();
}

var delILSlisteners = func () {
    delLOClisteners();
    delAPPRlisteners();
}

## Reset LOC/APPR indicators when not in approach phase
setlistener("/instrumentation/flightdirector/start-approach", func (n) {
    if ( n.getValue() == OFF ) {
	# reset LOC and APPR arming and activation
	setprop("/instrumentation/flightdirector/loc-arm", OFF);
	setprop("/instrumentation/flightdirector/loc-enable", OFF);
	setprop("/instrumentation/flightdirector/appr-arm", OFF);
	setprop("/instrumentation/flightdirector/appr-enable", OFF);
	# reset approach signal
	setprop("/instrumentation/flightdirector/in-approach", OFF);
	# remove the ILS listeners
	delILSlisteners();
    } else {
	# create the ILS listeners
	makeILSlisteners();
	# start the landing monitor
	toggleLandingMonitor(ON);
    }
}, 0, 0);

## Prepare for landing
## --------------------
var prepareLanding = func () {
    var apOn	= fdAPEngage.getValue();
    var athrOn	= fdATEngage.getValue();

    # always use knots not mach
    setprop("/instrumentation/flightdirector/mach-mode", FALSE);

    if ( apOn or athrOn ) setSPD(SPD.SPEED);
}

##
## TOGA in an emergency
## --------------------
var toga = func () {
    var enabled = getprop("/instrumentation/fmc/landing/go-around");
    if ( ! enabled ) return;

    copilot.announce("Go around!");

    ## set the selected speed to 250 KIAS just in case
    setprop("/instrumentation/fmc/target-speed-kt", 250);

    # tell the guidance system
    go_around();
    setprop("/instrumentation/fmc/flight-mode", FlightModes.CLB);
    # set managed vertical modes
    setprop("/instrumentation/flightdirector/vertical-vs-mode", MANAGED_MODE);
    setprop("/instrumentation/flightdirector/vertical-alt-mode", MANAGED_MODE);
    # switch to ALT initially
    setVNAV(VNAV.ALT);
    # set managed speed
    setprop("/instrumentation/flightdirector/speed-mode", MANAGED_MODE);

    # rate of climb should be between 1000 and 2000 fpm
    setprop("/instrumentation/flightdirector/vertical-speed-select", 1500);
    setLNAV(LNAV.LEVEL);

    # clean up
    delLandListeners();
}


## ----------
##  FLARE
## ----------

var flare = func () {
    var flareOn	 = fmcCtrlFlare.getValue();
    var apOn	 = fdAPEngage.getValue();
    var rmActive = apRMActive.getValue();
    var aptElevFt = 0;

    if ( flareOn ) {
	copilot.announce("FLARE!");
	if ( rmActive ) {
	    aptElevFt = getprop("/instrumentation/gps/wp/wp[1]/altitude-ft");
	}

	# Retard happens at about 30 ft, by which point we should be sinking at about 10 fps.
	# First estimate a time to reach 30 ft, then change the glide rate within that time
	# period. It takes about 2 sec to sink 25 ft. We need teh inerpolation to avoid
	# discontinuities in sink rate if there was a sudden change.
	var elev = getprop("/position/gear-agl-ft");
	var vel	 = velVertSpdFps.getValue();
	# since to takes time to achieve the desired rate, we will do it in 1/2 the target time
	var sec  = 0.5 * (30 - elev) / vel;
	if (sec < 0.5) {	# no need for interpolation
	    var sinkRate = getprop("/autopilot/internal/gs-sink-rate-fpm");
	    setprop("/autopilot/internal/settings/vertical-speed-fpm", sinkRate);
	} else {
	    # the glide rate is restricted to between -600 and -500 fpm
	    var glideRate = 60 * vel;
	    setprop("/autopilot/internal/settings/vertical-speed-fpm", glideRate);
	    if (glideRate < -600 or glideRate > -500) {
		interpolate("/autopilot/internal/settings/vertical-speed-fpm", -500, sec);
	    }
	}

	# Set the target altitude to the airport elevation
	setprop("/instrumentation/fmc/altitude-ft", aptElevFt);

	if ( apOn ) {
	    # align with the runway
	    setLNAV(LNAV.RWY);
	    setVNAV(VNAV.VS);
	}
    }
}

## ----------
## RETARD
## ----------

var retard = func () {
    var mode = fmcRetard.getValue();
    var apOn = fdAPEngage.getValue();

    if ( mode == ON and apOn == TRUE ) {
	# cut off speed to idle
	setprop("/instrumentation/fmc/target-speed-kt", 0);
	# move throttle to idle
	setSPD(SPD.THRIDL);
	# set runway hold if not already set
	setLNAV(LNAV.RWY);
    }
};

## --------------
## Touchdown
## --------------

var touchdown = func () {
    var apOn	= fdAPEngage.getValue();
    var fltMode = fmcFlightMode.getValue();

    if ( fltMode == FlightModes.TDOWN ) {
	setprop("/instrumentation/fmc/target-speed-kt", 0);
	setprop("/instrumentation/fmc/target-pitch-deg", 0.0);
	setVNAV(VNAV.OFF);
	turn_off_athr();
	setprop("/instrumentation/fmc/thrust-lever", 0.0);
	setprop("/instrumentation/flightdirector/loc-on", OFF);
	setprop("/instrumentation/flightdirector/appr-on", OFF);
	setprop("/instrumentation/flightdirector/fd-on", OFF);
	if ( apOn ) {
	    interpolate("/controls/flight/aileron", 0, 0.5);
	    interpolate("/controls/flight/elevator", 0.1, 2);
	}
    }
}


## --------------
## Rollout
## --------------

## disconnect AP and reset all modes
var disconnectAP = func {
    turn_off_autopilot();
    turn_off_athr();
    setVNAV(VNAV.OFF);
    setLNAV(LNAV.OFF);
    setSPD(SPD.OFF);
    setprop("/instrumentation/flightdirector/loc-on", OFF);
    setprop("/instrumentation/flightdirector/appr-on", OFF);
    setprop("/instrumentation/flightdirector/fd-on", OFF);
    centreFlightControls();
    copilot.announce("Your controls!");
};

## timed disconnect of AP
var timedAPOff = func (delay) {
    var t = maketimer(delay, func() {
		var apOn = fdAPEngage.getValue();
		var atOn = fdATEngage.getValue();
		if (apOn or atOn) disconnectAP();
		# delete landing listeners
		delLandListeners();
	    });

    t.singleShot = TRUE;
    t.start();
};

## Ensure that the lateral mode is "runway" once the front gear touches down
var rollout = func () {
    var apOn   = fdAPEngage.getValue();
    var enable = fmcRollout.getValue();

    if ( apOn ) {
	if ( enable == TRUE ) {
	    # set runway mode if not already drt
	    setLNAV(LNAV.RWY);
	}
	# AP/ATHR switch off is called from "system.nas"
    }
    # stop the landing monitor
    toggleLandingMonitor(OFF);
};


##
## Landing Phase Listeners
## ------------------------
## These are:
##	Go-Around
##	Flare
##	Retard
##	Rollout

var landingListeners = [ nil, nil, nil, nil ];
var landingMonitor   = nil;

## Create the listeners
var makeLandListeners = func () {
    # index 0 for Go-Around
    if (landingListeners[0] == nil )
	landingListeners[0] = setlistener("/instrumentation/fmc/landing/go-around", toga, 0, 0);

    # index 1 for Flare
    if (landingListeners[1] == nil )
	landingListeners[1] = setlistener("/instrumentation/fmc/flight-control-flare-mode", flare, 0, 0);

    # index 2 for Retard
    if (landingListeners[2] == nil )
	landingListeners[2] = setlistener("/instrumentation/fmc/flight-control-retard-mode", retard, 0, 0);

    # index 3 for Rollout
    if (landingListeners[3] == nil )
	landingListeners[3] = setlistener("/instrumentation/fmc/flight-control-rollout-mode", rollout, 0, 0);
}

## Destroy the listeners
var delLandListeners = func () {
    forindex(var j; landingListeners) {
	if (landingListeners[j] != nil) {
	    removelistener(landingListeners[j]);
	    landingListeners[j] = nil;
	}
    }
}

## Toggle the landing listeners
var toggleLandListeners = func () {
    var sw = getprop("/instrumentation/fmc/landing/monitor");
    if (sw == ON)
	makeLandListeners();
    else    delLandListeners();
};

# Toggle the landing monitor listener
var toggleLandingMonitor = func (sw) {
    if (sw == ON) {
	# switch on the landing monitor listener which controls the other listeners
	if (landingMonitor == nil) {
	    landingMonitor = setlistener("/instrumentation/fmc/landing/monitor", toggleLandListeners, 0, 0);
	}
    } else {
	# delete the landing monitor listener
	if (landingMonitor != nil) removelistener(landingMonitor);
	landingMonitor = nil;
    }
}


#############################################################################
# Utilities
#############################################################################

## smoothing function for proportional gain
var smoothKP = func(prop, target, fraction, time) {
    # do not adjust if we are still in a previous interpolation
    if ( getprop(prop) >= target ) {
	setprop(prop, (target * fraction));
	interpolate(prop, target, time);
    }
}

## Filter smoothing functions

var smoothAltHoldSwitchFunc = func {
    if (apLocksAlt.getValue() == "altitude-hold") {
	smoothKP("/autopilot/internal/kp-for-alt-hold-base", kpForAltHold, 0.1, 2);
    }
}

var smoothPitchHoldSwitchFunc = func {
    if (apLocksAlt.getValue() == "pitch-hold") {
	smoothKP("/autopilot/internal/kp-for-pitch-hold", kpForPitchHold, 0.2, 1);
    }
}

var smoothVsHoldSwitchFunc = func {
    if (apLocksAlt.getValue() == "vertical-speed-hold") {
	smoothKP("/autopilot/internal/kp-for-vs-hold-base", kpForVsHold, 0.1, 2);
    }
}

var smoothSpeedWithPitchSwitchFunc = func {
    if (apLocksSpd.getValue() == "speed-with-pitch-trim") {
	smoothKP("/autopilot/internal/kp-for-speed-pitch-deg", kpForSpeedPitchDeg, 0.1, 2);
    }
    if (apLocksSpd.getValue() == "mach-with-pitch-trim") {
	smoothKP("/autopilot/internal/kp-for-mach-pitch-deg", kpForMachPitchDeg, 0.1, 2);
    }
}

var smoothManagedHeadingModeFunc = func {
    smoothKP("/autopilot/internal/kp-for-heading-hold", kpForHeadingHold, 0.2, 1);
    smoothKP("/autopilot/internal/kp-for-roll-deg", kpForRollDeg, 0.75, 1);
};

var smoothSelectedHeadingModeFunc = func {
    smoothKP("/autopilot/internal/kp-for-heading-hold", kpForHeadingHold,  0.4, 1);
    smoothKP("/autopilot/internal/kp-for-roll-deg", kpForRollDeg, 0.5, 1);
};

var smoothHeadingModeFunc = func {
    if (apLocksHdg.getValue() == "true-heading-hold") {
	if (apRMActive.getValue() == TRUE) {
	    smoothManagedHeadingModeFunc();
	} else {
	    smoothSelectedHeadingModeFunc();
	}
    }
    elsif (apLocksHdg.getValue() == "wing-leveler" or
	    apLocksHdg.getValue() == "dg-heading-hold") {
	smoothSelectedHeadingModeFunc();
    }
    elsif (apLocksHdg.getValue() == "tacan-hold") {
	smoothManagedHeadingModeFunc();
    }
};

#############################################################################
## TACAN mode:
##
## Mode Selector Switch:
##   OFF - Disconects power
##   REC - Bearing to selected ground station. Range is not available.
##   T/R - Bearing and slant range to a selected ground station.
##   A/A REC - Bearing to an coperating aircraft.  Range is not available.
##   A/A T/R - Bearing and slant range to a cooperating aircraft.
## Our TACAN control panel combines the A/A modes.
##
## We only model the air-to-air operations. There are two parts to operating
## the TACAN mode. First it needs to be armed; then it needs to be enabled.
## Arming occurs (but not necessarily enabled) when:
##	* the switch is NOT in the OFF position and;
##	* the TACAN signal is in range.
## The TACAN mode is enabled when two conditions are met:
##	* the switch is at T/R or A/A
##	* the TACAN signal is in range
#############################################################################

var TacanClass = {
    # we use this to save the previous lateral mode
    saveLNAV:	-1,
    # we use this to save the previous vertical mode
    saveVNAV:	-1,
    # indicates it this instance is active
    running:	FALSE,
    initialised:	FALSE,
    tacanTimer:	nil,

    reset: func () {	# reset to non-running mode
		    me.saveLNAV = -1;
		    me.saveVNAV = -1;
		    me.running  = FALSE;
		},

    restore: func () {	# restore previous mode
		     var lnav = fdLNAV.getValue();
		     if (lnav == LNAV.TACAN) {
			 if (me.saveLNAV > -1)	setLNAV(me.saveLNAV);
			 if (me.saveVNAV > -1)	setVNAV(me.saveVNAV);
		     }
		     me.reset();
		 },

    stop: func () {	# switch from TACAN mode and restore previous modes
		    # check if TACAN was previously engaged
		  if (me.running == FALSE) return;

		    # restore previous modes
		  me.restore();

		    # stop display timer
		  if ( me.tacanTimer.isRunning ) me.tacanTimer.stop();

		    # fuselage lights : beacon
		  beaconLightsOn();
	      },

    start: func () {	# switch to TACAN mode
		    # only start if this instance is not running
		   if (me.running == TRUE) return;

		    # make sure that it was intialised
		   if (me.initialised == FALSE) me.init();

		    # save the current mode
		   me.saveLNAV = fdLNAV.getValue();
		   me.saveVNAV = fdVNAV.getValue();

		    # altimeter needs to be set to 29.92 inHg
		   getQNH(TRUE);
		    # fuselage lights : strobe
		   strobeLightsOn();

		    # now the actual switch
		   setLNAV(LNAV.TACAN);
		   setprop("/instrumentation/flightdirector/vertical-alt-mode", SELECTED_MODE);
		   setVNAV(VNAV.ALT);
		   me.running = TRUE;

		    # start display timer
		   if ( ! me.tacanTimer.isRunning )  me.tacanTimer.start();
	       },

    eta: func () {
	    # Get the TTW from TACAN and reformat for use in the HUD display
	    # The indicated time is a mess
	     var dist    = tacanDistNm.getValue();
	     var spd     = velAirSpdKts.getValue();
	     var time_h  = dist / spd;  # in hours
	     var hh      = math.floor(time_h);
	     var minutes = (time_h - hh ) * 60;
	     var mm      = math.floor(minutes);
	     var ss      = int((minutes - mm) * 60);

	     setprop("/instrumentation/fmc/tacan-mins", int(mm));
	     setprop("/instrumentation/fmc/tacan-secs", int(ss));
	 },

    init: func () {
		# do not intialise more than once
	      if (me.initialised == TRUE) return;

	      me.tacanTimer = maketimer(2.0, me, me.eta);
	      me.initialised = TRUE;
	  },

    new: func {	# create a new instance and initialise it
	     var p = { parents:[TacanClass] };
	     p.init();
	     return p;
	 }
};

##
## TACAN instance and listeners
## ----------------------------

var tacanMon =  nil;

var tacanResponse =  func (switch) {
    if ( tacanMon == nil ) return;

    if (switch == ON) tacanMon.start();
    else	tacanMon.stop();
};

setlistener("/instrumentation/flightdirector/tacan-enable", func (n) {
    tacanResponse( n.getValue() );
}, 0, 0);

## If the TACAN power is disconnected while the TACAN as active, the TACAN functions
## might be left dangling because the JSBsim channel is switched off before it sends
## the termination signal. We monitor the power switch so as to cleanup on exiting TACAN mode
setlistener("/instrumentation/tacan/power-on", func (n) {
    var swPos	= n.getValue();
    if ( swPos == OFF ) {
	setprop("/instrumentation/flightdirector/tacan-arm", OFF);
	setprop("/instrumentation/flightdirector/tacan-enable", OFF);
    }
}, 0, 0);



##
## ++++++++++++++++++++++++++++++ INITIALISATION ++++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

var init_fd_sys = func () {
    logprint(LOG_INFO, "Initialising Flight Director ");

    # create the TACAN monitor
    tacanMon = TacanClass.new();

    # remove the FDM listener
    removelistener(fdInitListener);
};

var fdInitListener = setlistener("/sim/signals/fdm-initialized", init_fd_sys, 0, 0);


##
## SHUTDOWN routine
##
var fdShutdown = func () { };

################################# END #######################################
