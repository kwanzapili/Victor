################################################################################
#
#			Handley Page Victor Systems
#
###############################################################################


##
## ++++++++++++++++++++++++++++++ LIGHTS SYSTEM +++++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## ========================= Fuselage Lights =========================

## These light produce 90 flashes per min (1.5 per second).
var pattern = [0.15, 0.15, 0.15, 1];

## Anti-Collision Beacon lights
var beacon = aircraft.light.new( "/sim/model/lights/beacon", pattern, "/controls/lighting/beacon" );

## Strobe lights
var strobe = aircraft.light.new( "/sim/model/lights/strobe", pattern, "/controls/lighting/strobe" );

var strobeLightsOn = func () {
    setprop("/controls/lighting/strobe", ON);
    switchWithSound();
}

var strobeLightsOff = func () {
    setprop("/controls/lighting/strobe", OFF);
    switchWithSound();
}

var beaconLightsOn = func () {
    setprop("/controls/lighting/beacon", ON);
    switchWithSound();
}

var beaconLightsOff = func () {
    setprop("/controls/lighting/beacon", OFF);
    switchWithSound();
}


## ========================= Nose Gear Lights =========================
##
## The nose gear lights comprise a 1000W landing light and a 450W taxi light.
## Only one of these two lights can be used at a time. The lights are controlled
## by a three-position landing and taxi lights switch. The switch positions are:
## LAND (up), TAXI (down) and OFF (center). The switch is ineffective when the
## nose gear is retracted.
var NoseLights = { TAXI: -1, OFF: 0, LAND: 1 };

## Transfer of the nose lights switch position to the respective landing and
## taxi lights circuit breakers in done in the "lights" system within JSBsim.
## The landing lights need airstream cooling and thus burn out when used on
## the ground. Use taxi lights on the ground and landing lights when airborne.

var taxiLightsOn = func () {
    setprop("/controls/switches/nose-lights", NoseLights.TAXI);
    switchWithSound();
}

var taxiLightsOff = func () {
    # check switch position first
    var sw = getprop("/controls/switches/nose-lights");
    if ( sw == NoseLights.TAXI ) {
	setprop("/controls/switches/nose-lights", NoseLights.OFF);
	switchWithSound();
    }
}

var landLightsOn = func () {
    setprop("/controls/switches/nose-lights", NoseLights.LAND);
}

var landLightsOff = func () {
    # check switch position first
    var sw = getprop("/controls/switches/nose-lights");
    if ( sw == NoseLights.LAND ) {
	setprop("/controls/switches/nose-lights", NoseLights.OFF);
	switchWithSound();
    }
}

var noseLightsOff = func () {
    setprop("/controls/switches/nose-lights", NoseLights.OFF);
    switchWithSound();
}

var noseLightsOn = func () {
    var gnd = fmcCtrlGnd.getValue();
    # Use taxi lights on the ground and landing lights when airborne
    if ( gnd == TRUE ) taxiLightsOn();
    else		landLightsOn();
}

var toggleNoseLights = func () {
    var sw = getprop("/controls/switches/nose-lights");
    if (sw == NoseLights.OFF ) {
	noseLightsOn();
    } else {
	noseLightsOff();
    }
}

## ===================================================

var intLightsOn = func () {
    setprop("/controls/lighting/panel-lights", ON);
    setprop("/controls/lighting/instrument-lights", ON);
    setprop("/controls/lighting/map-lights", ON);
}

var intLightsOff = func () {
    setprop("/controls/lighting/panel-lights", OFF);
    setprop("/controls/lighting/instrument-lights", OFF);
    setprop("/controls/lighting/map-lights", OFF);
}

var extLightsOn = func () {
    setprop("/controls/lighting/nav-lights", ON);
    setprop("/controls/lighting/strobe", ON);
    setprop("/controls/lighting/beacon", ON);
}

var extLightsOff = func () {
    setprop("/controls/lighting/nav-lights", OFF);
    setprop("/controls/lighting/strobe", OFF);
    setprop("/controls/lighting/beacon", OFF);
    noseLightsOff();
}

##
## Initialise the lights at startup
## -------------------------------
var initLights = func () {
# booleans
    var B = [ 'landing-lights', 'turn-off-lights', 'taxi-light', 'logo-lights',
		'map-lights', 'nav-lights', 'panel-lights', 'beacon', 'strobe',
		'instrument-lights' ];
    foreach(var b; B) {
	setprop("/controls/lighting/"~b, OFF);
    }

    # doubles
    var D = [ 'panel-norm', 'instruments-norm', 'dome-norm' ];
    foreach(var d; D) {
	setprop("/controls/lighting/"~d, 0.0);
    }

    # nose lights must be off
    noseLightsOff();
}


##
## ++++++++++++++++++++++++++++ ELECTRICAL SYSTEM +++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

var initElectric = func () {

    var base = props.globals.getNode("systems/electrical/outputs");
    # check that the systems is ready
    if (base == nil) {
	logprint(LOG_ALERT, "Failed to initialize the electrical system ...");
	return;
    }

    var consumers   = base.getChildren();
    var components  = size(consumers);
    if (components == 0) {
	logprint(LOG_ALERT, "No consumer components found in the electrical system ...");
	return;
    }

    for(var i=0; i < components; i+=1) {
	# initialise the value
	consumers[i].setValue(0);
    }
}

##
## Toggle Switches ON / OFF
## -------------------------

var instrumentsOn = func () {
    setprop("/controls/switches/master-avionics", ON);
    setprop("/controls/switches/pitot-heat", ON);

    ## switch on all avionics instruments
    for (var i=0; i < 2; i=i+1) {
	setprop("/instrumentation/comm["~i~"]/power-switch", ON);
	setprop("/instrumentation/nav["~i~"]/power-switch", ON);
    }
    setprop("/instrumentation/adf/func-knob", AdfKnob.ADF);
    setprop("/instrumentation/dme/switch-position", DmeKnob.HOLD);
    setprop("/instrumentation/transponder/inputs/knob-mode", TransponderKnob.STANDBY);
}

var instrumentsOff = func () {
    setprop("/controls/switches/master-avionics", OFF);
    setprop("/controls/switches/pitot-heat", OFF);

    ## switch on all avionics instruments
    for (var i=0; i < 2; i=i+1) {
	setprop("/instrumentation/comm["~i~"]/power-switch", OFF);
	setprop("/instrumentation/nav["~i~"]/power-switch", OFF);
    }
    setprop("/instrumentation/adf/func-knob", AdfKnob.OFF);
    setprop("/instrumentation/dme/switch-position", DmeKnob.OFF);
    setprop("/instrumentation/transponder/inputs/knob-mode", TransponderKnob.OFF);
}

var acPowerOn = func () {
    setprop("/controls/switches/pitot-heat", ON);
    setprop("/instrumentation/radar/power-on", ON);
    intLightsOn();
}

var acPowerOff = func () {
    setprop("/controls/switches/pitot-heat", OFF);
    setprop("/instrumentation/radar/power-on", OFF);
    intLightsOff();
    extLightsOff();
}

var electricOff = func () {
    instrumentsOff();
    acPowerOff();
    setprop("/controls/electric/master-switch", OFF);
    starter.setMasterOff();
}

## This property has values 0 .. 3, where :
## 0 = no power, 1 = DC only, 2 = AC only, 3 = both AC and DC power
setlistener("/fdm/jsbsim/systems/electrical/power-available", func (n) {
    var avail = n.getValue();
    if ( avail > 0 ) {
        if (avail > 1) {    # AC power is also available
            acPowerOn();
        } else {    # just DC power
            acPowerOff();
        }
    } else {    # no power at all
        electricOff();
    }
}, 0, 0);


##
## +++++++++++++++++++++++++++++++++ FUEL SYSTEM +++++++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

###############################################################
## The Fuel System B Mk 2 Series aircraft.
## ---------------------------------------
##
## The fuel system varied a lot between different variants (bombers Mk 1 & 2,
## reconnaissance, tanker). For example, the tanker versions used the bomb bay
## for fuel tanks in the form of bags. Thus, it may have had up to twenty-nine
## fuel tanks. This fuel system is primarily based on the Mk 2 version with
## twenty-two tanks. with a total capacity of 84,456 lb.
##
## There are three basic fuel systems:
##  1 The Fuselage system
##  2 The Port and Starboard Wing systems
##  3 Bomb bay system
##
## Wing tanks:
## * Tank 1 was located in the wing centre section in the Fuselage
## * Tanks 3-5 were located in the inner wing
## * Tank 6 was broken down into 6A, 6B, and 6C in the outer wing.
## * Tank 2 had been deleted for the Mk 2
##
## The fuselage system was located totally in the rear fuselage and numbered 7-12.
## * The two No. 7 tanks designated 7 Port and 7 Starboard were located over the
##   nose-wheel bay and were extended into the stub wing to give increased capacity
## * Tank 8 was located behind Tanks 7 to the front face of the bomb bay.
## * Tank 8B was located behind Tank 8 up to the equipment bay.
## * There was no No 9 tank because its cell was used as an equipment bay and the B
##   cell renamed 8B.
## * Tank 10 divided into A and B cells
## * Tank 11 followed Tank 10 and divided into A and B cells that ended at the rear
##   face of the bomb bay.
## * The last two tanks were 12 Port and 12 Starboard located aft of the bomb bay
##   and extended down into the flash bomb bay. 
##
## The bomb bay had two cylindrical tanks, one forward and one aft, each with a
## capacity of 8,000lb.
## The under wing tanks were fitted to increase the range for Blue Steel operations
## as the Bomb Bay tanks used on the basic B Mk 2 version could not be fitted in that
## role.
##
## The fuel system was pressure fed at 50 psi from external couplings.
## The fuselage was fitted with a proportioner: a device to regulate the amount of
## fuel that was pumped out of the tank when in flight to maintain the aircraft’s
## Centre of Gravity within prescribed limits. All tanks contained a capacity system,
## pumps and tank pressurisation equipment.
##
## The B (SR) 2 version was capable of carrying initially two 8,0001b bomb bay tanks
## along with various reconnaissance camera fits. After the deletion of the camera
## crate an additional 8,0001b tank was fitted. 
##
## The fuel system for the three-pointer tanker was vastly different to that of the
## bomber. The main fuselage and wing system was retained and only slightly modified.
## In the bomb bay the doors were removed as well as the 8,0001b tanks and fittings.
## Into this area were fitted the large two bomb-bay tanks that became a feature of
## these tankers. These tanks had the largest capacity of any on the Victor, 15,3001b,
## and were to be used as collector tanks to feed the engines and the dispensing
## equipment. The fuselage and wings were fed into them. The fuel system was modified
## to accommodate the necessary changes and this ended up in combining all three systems
## and, in theory, you could pump fuel from any tank to any other tank. 
##
## For our purpsoes, we will only model 16 tanks defined as follows:
##
##	Wing Tanks (should be 6 on each wing)
##	----------
##
##                           Engines              Capacity
##  Tank Name       1       2       3       4       (lb)
##  Portside 1	    X                               7,320
##  Portside 3+4            X                       7,320
##  Portside 5      X                               4,880
##  Portside 6              X                       4,880
##  Portside UW     X       X                       5,116
##  Starboard 1                     X               7,320
##  Starboard 3+4                           X       7,320
##  Starboard 5                     X               4,880
##  Starboard 6                             X       4,880
##  Starboard UW                    X       X       5,116
##
##	Fuselage Tanks (should be 8)
##	--------------
##                           Engines                      Capacity
##  Tank Name       1       2       3       4      APU     (lb)
##  Fuselage 7      X               X               X       8,000
##  Fuselage 8+9            X               X       X       8,026
##  Fuselage 10+11  X       X       X       X       X       9,000
##  Fuselage 12     X       X       X       X       X       9,000
##
##	Bomb bay Tanks (x 2)
##	--------~-----------
##  Tank Name          Engine   Capacity (lb)
##  Bomb Bay Fore       All	    7,900
##  Bomb Bay Aft	All	    7,900
##
## To effect transfers, we model tank groups and tank pairs.
## Cross-feeding occurs between tank groups, while forward and aft transfers
## occur between pairs.
##
## The groups are linked to the engines that the tanks feed. So these are
## essentially the wing tanks:
##  Group    Engine      Tanks
##    1         1       P1, P5
##    2         2       P3+4, P6
##    3         3       S1, S5
##    4         4       S3+4, S6
##
## The tank pairs are in the form (Fore, Aft). The fore tank only does aft
## transfers while the aft tank only does forward transfers.
## Wing:    (P1 ~ P5), (P3+4 ~ P6), (S1 ~ S5), (S3+4 ~ S6)
## Fuselage: (F7 ~ F12), (F5+9 ~ F10+11)
## Bom bay: (Fore ~ Aft)
##
###############################################################

##
## Forward Transfer Switches
## -------------------------

var fwdTransferOn = func () {
    setprop("/controls/fuel/fwd-transfer", ON);
}

var fwdTransferOff = func () {
    setprop("/controls/fuel/fwd-transfer", OFF);
}

var toggleFwdTransfer= func () {
    var sw = getprop("/controls/fuel/fwd-transfer");
    if ( sw == ON )	fwdTransferOff();
    else		fwdTransferOn();
}

##
## Aft Transfer Switches
## -----------------------

var aftTransferOn = func () {
    setprop("/controls/fuel/aft-transfer", ON);
}

var aftTransferOff = func () {
    setprop("/controls/fuel/aft-transfer", OFF);
}

var toggleAftTransfer= func () {
    var sw = getprop("/controls/fuel/aft-transfer");
    if ( sw == ON )	aftTransferOff();
    else		aftTransferOn();
}

##
## Cross-feed Switches
## ---------------------

var crossfeedOn = func () {
    setprop("/controls/fuel/cross-feed", ON);
}

var crossfeedOff = func () {
    setprop("/controls/fuel/cross-feed", OFF);
}

var toggleCrossfeed= func () {
    var sw = getprop("/controls/fuel/cross-feed");
    if ( sw == ON )	crossfeedOff();
    else		crossfeedOn();
}

##
## Automatic Fuel Transfer
## -----------------------
## The code for the CoG state is as follows:
##	-2 :- too far forward; start aft transfer
##	-1 :- close to forward boundary; keep current transfer
##	 0 :- within permissable range; turn off transfers
##	 1 :- close to aft boundary; keep current transfer
##	 2 :- too far aft; start forward transfer
var autoTransfer = func () {
    var cog = getprop("/instrumentation/fmc/CoG-state");
    if (cog < -1) {	# start aft transfer
	aftTransferOn();
	fwdTransferOff();
    } elsif (cog > 1) {	# start forward transfer
	fwdTransferOn();
	aftTransferOff();
    } elsif (cog == 0) {	# turn off both transfers
	fwdTransferOff();
	aftTransferOff();
    } else {	# approaching boundary

    }
};

setlistener("/instrumentation/fmc/CoG-state", autoTransfer, 0, 0);

##
## Low fuel monitoring
## -------------------
setlistener("/instrumentation/annunciator/fuel-warning", func (n) {
    var level = n.getValue();
    var onGnd = fmcCtrlGnd.getValue();

    if ( onGnd == TRUE or level == FuelCodes.OK ) return;

    if ( level == FuelCodes.CRITICAL ) {
	copilot.announce("Fuel level critical");
    } elsif ( level == FuelCodes.WARN ) {
	copilot.announce("Fuel level warning");
    }
}, 0, 0);

########################################################################################
## Refuelling Operations
########################################################################################

var refuel_drogues = aircraft.door.new ("/controls/refuelling/drogues/", 5);

var toggle_refuelling_drogues = func () {
    var isTanker = variantTanker.getValue();
    if ( isTanker ) {
        refuel_drogues.toggle();
    } else {
        screen.log.write("This aircraft is not capable of tanker operations");
    }
}

## Refuelling monitoring
## ---------------------
setlistener("/instrumentation/annunciator/refuel-pump", func (n) {
    if ( n.getValue() ) {
	screen.log.write("Refuelling pump is ON");
    } else {
	screen.log.write("Refuelling pump is OFF");
    }
}, 0, 0);

setlistener("/fdm/jsbsim/propulsion/refuel", func (n) {
    if ( n.getValue() ) {
        setprop("/sim/messages/ground", "Refuelling started");
    } else {
        setprop("/sim/messages/ground", "Refuelling disconnected");
    }
}, 0, 0);


##
## ++++++++++++++++++++++++++++ INSTRUMENT OPERATIONS ++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

######################################################
##      CTL 62 ADF Control for ADF-462 receiver     ##
######################################################

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## ADF Knob Modes
##  0 - OFF
##  1 - ANT
##  2 - ADF
##  3 - BFO
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

var AdfKnob = { OFF: 0, ANT: 1, ADF: 2, BFO: 3 };

var adf_switch = func (switch, power_btn) {

    # if power is off then switch it off
    if ( power_btn == OFF ) {
	setprop("instrumentation/adf/mode", "off");
    }
    elsif (switch == AdfKnob.OFF) {
	setprop("instrumentation/adf/mode", "off");
    } elsif (switch == AdfKnob.ANT) {
	setprop("instrumentation/adf/mode", "ant");
    } elsif (switch == AdfKnob.ADF) {
	setprop("instrumentation/adf/mode", "adf");
    } elsif (switch == AdfKnob.BFO) {
	setprop("instrumentation/adf/mode", "bfo");
    }
}

## Listen to both ADF power and the knob
setlistener("instrumentation/adf/func-knob", func (n) {
    var switch = n.getValue();
    var power_btn = getprop("instrumentation/adf/power-btn");
    adf_switch(switch, power_btn);
}, 0, 0);

setlistener("instrumentation/adf/power-btn", func (n) {
    var power_btn = n.getValue();
    var switch = getprop("instrumentation/adf/func-knob");
    adf_switch(switch, power_btn);
}, 0, 0);


######################################################
##	KDI 572 DME				    ##
######################################################

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## DME Knob Modes
##  0 - OFF
##  1 - Nav1 Slaved
##  2 - Hold
##  3 - Nav2 Slaved
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

var DmeKnob = { OFF: 0, NAV1: 1, HOLD: 2, NAV2: 3 };

var dme_switch = func (switch) {

    if (switch < 0 or switch > 3) {
	switch = math.clamp(switch, 0, 3);
	setprop("instrumentation/dme/switch-position", switch);
    }

    if (switch == DmeKnob.OFF) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/dme/frequencies/selected-mhz");
    } elsif (switch == DmeKnob.NAV1) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/nav[0]/frequencies/selected-mhz");
    } elsif (switch == DmeKnob.HOLD) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/dme/frequencies/selected-mhz");
    } elsif (switch == DmeKnob.NAV2) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/nav[1]/frequencies/selected-mhz");
    }
}

setlistener("instrumentation/dme/switch-position", func (n) {
    dme_switch(n.getValue());
}, 0, 0);


######################################################
##	Transponder and TCAS Operations		    ##
######################################################

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Transponder Knob/Functional Modes
##    0 - OFF
##    1 - Standby
##    2 - Test
##	  3 - Ground mode, responds to altitude interrogation but does not broadcast an ID.
##		This would typically be used while taxiing prior to takeoff.
##    4 - ON, normal operation but altitude transmission is inhibited
##    5 - Alt, same as on but altitude is broadcast if transponder was configured in
##		Mode-S or Mode-C
##
## FlightGear TCAS has the following features:
##	* Works with AI and multiplayer traffic.
##	* Aural traffic alerts (TA) are issued, in essence Traffic, traffic! warnings.
##	* Aural resolution advisories (RA) are issued, in essence Climb, climb! or Descend, descend!.
##	* Switchable TCAS mode
## TCAS mode selection:
##	0 = OFF
##	1 = Standby
##	2 = TA-only
##	3 = Auto (TA/RA)
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

var TransponderKnob = { OFF: 0, STANDBY: 1, TEST: 2, GROUND: 3, ON: 4, ALT: 5 };

var knobPosition = func (pos) {
    setprop("instrumentation/transponder/inputs/knob-mode", pos);
};

var TCASmodes = { OFF: 0, STANDBY: 1, TA: 2, AUTO: 3 };

var tcasPosition = func (pos) {
    setprop("instrumentation/tcas/inputs/mode", pos);
};

## Connect TCAS to transponder cockpit switch
var syncTCAS = func (tp) {
    var pos = TCASmodes.OFF;

    # switch off test in case it was on
    setprop("instrumentation/tcas/inputs/self-test", OFF);

    if (tp == TransponderKnob.OFF)		pos = TCASmodes.OFF;
    elsif (tp == TransponderKnob.STANDBY)	pos = TCASmodes.STANDBY;
    elsif (tp == TransponderKnob.TEST)	{
	pos = TCASmodes.STANDBY;
	setprop("instrumentation/tcas/inputs/self-test", ON);
    }
    elsif (tp == TransponderKnob.GROUND)	pos = TCASmodes.STANDBY;
    elsif (tp == TransponderKnob.ON)		pos = TCASmodes.TA;
    elsif (tp == TransponderKnob.ALT)		pos = TCASmodes.AUTO;

    tcasPosition(pos);
};

setlistener("instrumentation/transponder/inputs/knob-mode", func (n) {
    syncTCAS(n.getValue());
}, 0, 0);

## While testing the TCAS, do the same for the marker beacons
setlistener("instrumentation/tcas/inputs/self-test", func (n) {
    if ( n.getValue() ) setprop("instrumentation/marker-beacon/test", ON);
    else	setprop("instrumentation/marker-beacon/test", OFF);
}, 0, 0);


######################################################
##              Altimeter and QNH                   ##
######################################################

## If "std" is true, then use standard pressure, otherwise use the current
## environmental pressure (the default)
var getQNH = func (std=0) {
    if ( std == TRUE ) {
	var p = 29.92;
    } else {
	var p =  getprop("/environment/pressure-sea-level-inhg");
	if ( p == nil ) return;
    }

    # set the altimeter pressure
    setprop("/instrumentation/altimeter[0]/setting-inhg", p);
    setprop("/instrumentation/altimeter[1]/setting-inhg", p);
    var q =  sprintf("%.2f", p);
    var qnh = int(getprop("/instrumentation/altimeter/setting-hpa"));
    copilot.announce("Pressure set to "~q~": QNH is "~qnh);
}


##
## ++++++++++++++++++++++++++++ FLIGHT PARAMETERS ++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

###
### Set cross-over altitude
###
var set_crossover = func (c, m) {
    # we are only interested in high altitude speeds where CAS > 300 and Mach > 0.7
    var speed = velAirSpdKts.getValue();
    var cas   = math.max(c, speed, 300);
    var mach  = (m < 0.7) ? 0.7 : m;
    var alt   = atmos.calculateCrossover(cas, mach);

    # sanity check of returned value, which should be higher than 15,000 ft
    if (alt > 15000) {
        setprop("/instrumentation/fmc/changeover-alt", alt);
    }
};

###
### Update cross-over altitude in climb/descend modes
###
var update_crossover = func () {
    # select which mode we need to consider
    var mode = apDesOrClb.getValue();

    if (mode == ClimbDescend.Des) {
        var mach = fmcDesMach.getValue();
        var cas  = fmcDesSpeed.getValue();
        set_crossover(cas, mach)
    }
    elsif (mode == ClimbDescend.Clb) {
        var mach = fmcClimbMach.getValue();
        var cas  = fmcClimbSpeed.getValue();
        set_crossover(cas, mach);
    }
    # ignore Hold mode
};


## Run this update every 15 seconds
var crossoverTimer = maketimer(15.0, update_crossover);

## We are only interested in updating the cross-over altitude above the
## transistion altitude ~ 10,000 ft
setlistener("/instrumentation/annunciator/above-transition-alt", func (n) {
    if ( n.getValue() ) {
        if (crossoverTimer.isRunning == FALSE) crossoverTimer.start();
    } else {
        if (crossoverTimer.isRunning == TRUE) crossoverTimer.stop();
    }
}, 0, 0);


##
## V-speed annunciators
## ---------------------

var vspeedListeners = [ nil, nil, nil ];

## create listeners
var makeVspeedListeners = func () {
    if (vspeedListeners[0] == nil ) {
        vspeedListeners[0] = setlistener("/instrumentation/annunciator/VR", func (n) {
                if ( n.getValue() ) {
                    screen.log.write("Rotate");
                }
                }, 0, 0);
    }

    if (vspeedListeners[1] == nil ) {
        vspeedListeners[1] = setlistener("/instrumentation/annunciator/V1", func (n) {
                if ( n.getValue() ) {
                    screen.log.write("V1");
                }
                }, 0, 0);
    }

    if (vspeedListeners[2] == nil ) {
        vspeedListeners[2] = setlistener("/instrumentation/annunciator/V2", func (n) {
                if ( n.getValue() ) {
                    screen.log.write("V2");
                }
                }, 0, 0);
    }
}

# delete listeners when not needed
var deleteVspeedListeners = func () {
    forindex(var index; vspeedListeners) {
        if (vspeedListeners[index] != nil ) removelistener(vspeedListeners[index]);
        vspeedListeners[index] = nil;
    }
}

##
## Convert between EAS and CAS
## ----------------------
## EAS = TAS x sqrt { rho / rho_0}, where
## rho is actual air density,
## rho_0 is standard sea level density (1.225 kg/m3 or 0.00237 slug/ft3).

# calculate EAS at current altitude given CAS
var calcKEAS =  func (cas) {
    var alt = posAltFt.getValue();
    var tas = atmos.calculateFromCAS(alt, cas, "tas");
    var rho = getprop("/environment/density-slugft3");
    var f = rho / 0.0023769;
    var keas = tas * math.sqrt(f);

    return keas;
};

# calculate CAS at current altitude given EAS
var calcKCAS =  func (eas) {
    var alt = posAltFt.getValue();
    var rho = getprop("/environment/density-slugft3");
    var f = rho / 0.0023769;
    var tas = eas / math.sqrt(f);
    var kcas = atmos.calculateFromTAS(alt, tas, "cas");

    return kcas;
};

# calculate CASand Mach at current altitude given EAS
# this returns an array with [CAS, Mach] values
var calc_CAS_Mach =  func (eas) {
    var alt = posAltFt.getValue();
    var rho = getprop("/environment/density-slugft3");
    var f = rho / 0.0023769;
    var tas = eas / math.sqrt(f);
    var result = [ nil, nil ];

    # first CAS
    result[0] = atmos.calculateFromTAS(alt, tas, "cas");

    # then Mach
    result[1] = atmos.calculateFromTAS(alt, tas, "mach");

    return result;
};


##
## CAS minimum speed update
## -------------------------
var minimumCAS = func () {
    var eas = getprop("/instrumentation/fmc/speed-min-keas");
    var cas = calcKCAS(eas);
    setprop("/instrumentation/fmc/speed-min-kias", cas);
}

##
## CAS climb and descend managed speed updates
## -------------------------------------------
var climb_descend_speeds = func () {
    # climb speed
    var eas = getprop("/instrumentation/fmc/climb-keas");
    var speedvec = calc_CAS_Mach(eas);
    setprop("/instrumentation/fmc/climb-speed", speedvec[0]);
    setprop("/instrumentation/fmc/climb-mach", speedvec[1]);

    # descent speed
    eas = getprop("/instrumentation/fmc/descend-keas");
    speedvec = calc_CAS_Mach(eas);
    setprop("/instrumentation/fmc/descend-speed", speedvec[0]);
    setprop("/instrumentation/fmc/descend-mach", speedvec[1]);
}

##
## Update all CAS values
## ----------------------
var updateCAS = func () {
    minimumCAS();
    climb_descend_speeds();
}

## Run the CAS updates every 15 seconds
var casTimer = maketimer(15.0, updateCAS);


##
## ++++++++++++++++++++++++++++ FLIGHT OPERATIONS ++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

##########################################
##	Co-pilot announcements		##
##########################################

# Copilot announcements
var copilot = {
    # Print the announcement on the screen
    announce : func(msg) {
        setprop("/sim/messages/copilot", msg);
    }
};

##
## Caution annunciator
## --------------------
var caution = func () {
  setprop("/instrumentation/annunciator/master-caution", ON);

  ## revert after 5 seconds
    var t = maketimer(5.0, func {
		setprop("/instrumentation/annunciator/master-caution", OFF);
	    });
    t.singleShot = TRUE;
    t.start();
}

##
## Warning signal that triggers the master causion
## -----------------------------------------------

setlistener("/instrumentation/annunciator/warning-signal", func (n) {
    var sig = n.getValue();

    if ( sig == Warning.clear ) { # clear the caution
	setprop("/instrumentation/annunciator/master-caution", OFF);
    }
    elsif ( sig == Warning.warn ) { # issue a temporary warning 
	caution();
    }
    elsif ( sig == Warning.critical ) { # set a caution that must be cleared by the crew
	setprop("/instrumentation/annunciator/master-caution", ON);
    }
}, 0, 0);


######################################################
##              Cabin Environment                   ##
######################################################

## ------------------------------------------------------------------------------------
## The crew compartment can be pressurised to either a 10,000 ft or 26,000 ft
## schedule. The 26,000 is usually preferred since it enhances cockpit and bay
## cooling. The maximum rate of pressure change is 5,000 fpm.
##
## The cockpits remain essentially unpressurised while below 26,0000 to 28,000 ft
## pressure altitude with the 26,000 ft schedule. Cockpit pressure is then maintained
## at 26,000 ft at all higher altitudes. With the 10,000 ft schedule selected,
## pressurisation starts at 10,000 ft and maintained at 10,000 ft until the aircraft
## altitude exceeds 28,000 ft, then at a pressure 5 psi greater than the ambient at
## higher altitudes.
##
## The settings for cabin pressure and cabin temperatuire are handled by JSBsim
## channels in the system file "environment.xml. Here  we deal with the conversion
## of cabin pressure into cabin altitude in feet.
## ------------------------------------------------------------------------------------

var cabinPsi   = props.globals.getNode("instrumentation/pressurisation/cabin-pressure-psi");
var cabinAlt   = props.globals.getNode("instrumentation/pressurisation/cabin-altitude-ft");
var CabinPress = { DUMP: -1, OFF: 0, PRESS: 1 };

# initialise the cabin environment
var init_cabin_env = func () {
    # turn off pressure dump
    setprop("/controls/switches/cabin-pressure", CabinPress.OFF );

    # short delay to allow the variables to stablise
    var t = maketimer(1.0, func {
			# set the cabin altitude to the airport altitude
			var alt = posAltFt.getValue();
			setprop("/instrumentation/pressurisation/cabin-altitude-ft", alt);

			# Cabin pressure set to take-off altitude psi.
			var static_psi = atmos.convertAltitudePressure("feet", alt, "psi");
			setprop("/instrumentation/pressurisation/target-cabin-pressure-psi", static_psi);
			setprop("/instrumentation/pressurisation/cabin-pressure-psi", static_psi);

			# set the initial tmeperature
			var temp = getprop("environment/temperature-degc");
			setprop("instrumentation/pressurisation/target-cabin-temperature-degc", temp);
			# assume the cockpit was kept overnight at standard temperatur ~15C or 59F
			setprop("instrumentation/pressurisation/cabin-temperature-degc", 15);
			setprop("controls/anti-ice/window-temperature-degc", 15);
		    });
    t.singleShot = TRUE;
    t.start();
}

##
## Start pressurising the cabin environment
## -----------------------------------------
var cabinPressOn = func () {
    setprop("/controls/switches/cabin-pressure", CabinPress.PRESS);
}

##
## Stop pressurising the cabin environment
## -----------------------------------------
var cabinPressOff = func () {
    setprop("/controls/switches/cabin-pressure", CabinPress.OFF);
}

##
## Dump the cabin pressure
## -----------------------
var cabinPressDump = func () {
    setprop("/controls/switches/cabin-pressure", CabinPress.DUMP);
}

##
## Update the cabin environment
## -----------------------------
var cabin_env = func {
    var cabin_psi = cabinPsi.getValue();
    var cabin_alt = cabinAlt.getValue();

    # Now set the current cabin altitude
    var h = atmos.convertPressureAltitude("psi", cabin_psi, "feet");
    # sanity check
    h = (h < 0) ? cabin_alt : h;
    setprop("/instrumentation/pressurisation/cabin-altitude-ft", h);
}

# This update only runs in certain stages of the flight
var cabinEnvTimer = maketimer(2.5, cabin_env);


##############################################
##          Flight Controls                 ##
##############################################

## Gently centre flight elevator trim when the autopilot is switched OFF
var centreElevatorTrim = func (time=3) {
    ## wait for a sec for the RoC lock to be released
    var t = maketimer(1.0, func {
		var ap_engaged  = fdAPEngage.getValue();
		var elev_locked = rocLock.getValue();
		# do not re-trim when the AP is engaged
		if (ap_engaged == FALSE or elev_locked == FALSE) {
		    interpolate("/autopilot/internal/elevator-trim-servo", 0, time);
		    interpolate("/controls/flight/elevator-trim", 0, time);
		}
	    });
    t.singleShot = TRUE;
    t.start();
}

## Gently centre flight elevator when the autopilot is switched ON
var centreElevator = func (time=10) {
    interpolate("/controls/flight/elevator", 0, time);
}

## Transist from manual to automatic control of the flight elevator with some delay
var initAutoElevator =  func () {
    centreElevator(10);
    # after the centering is complete, switch on auto-elevator control
    var t = maketimer(10, func {
		setprop("/autopilot/internal/auto-elevator", ON);
	    });
    t.singleShot = TRUE;
    t.start();
}

setlistener("/instrumentation/fmc/roc-lock", func (n) {
    if ( n.getValue() == FALSE ) centreElevatorTrim(2);
    else initAutoElevator();
}, 0, 0);

## Gently centre flight controls
var centreFlightControls = func {
    interpolate("/autopilot/internal/aileron-servo",0, 1.25);
    interpolate("/controls/flight/aileron", 0, 1.25);
    interpolate("/autopilot/internal/rudder-servo", 0, 1.25);
    interpolate("/controls/flight/rudder", 0, 1.0);
    centreElevator(3);
    centreElevatorTrim();
}

## Airbrake controls (replacing spoilers)
var stepSpeedbrake = func(step) {
    var prop = "controls/flight/speedbrake";
    # Hard-coded speedbrake movement in 2 equal steps:
    var val = 0.5 * step + getprop(prop);
    setprop(prop, val > 1 ? 1 : val < 0 ? 0 : val);
}

## Reduce throttle to idle
var idleThrottle = func (time=3.0) {
    # match the maximum rate of 0.35/sec by default in changing the throttle
    var athrOn = fdATEngage.getValue();

    # do not touch if autothrottle is ON
    if ( athrOn == FALSE ) {
        for (var e=0; e < 4; e=e+1) {
            interpolate("/controls/engines/engine["~e~"]/throttle", 0, time);
        }
    }
}

## Some systems only start after take off
var airborne = func () {
    chute_door.enable(FALSE);
    cockpit_door.enable(FALSE);
}

var onground = func () {
    setprop("/controls/radar/altimeter/limiter-active", OFF);
    chute_switch.enable(TRUE);
    chute_door.enable(TRUE);
    cockpit_door.enable(TRUE);
}


setlistener("/instrumentation/fmc/flight-control-ground-mode", func (n) {
    if ( n.getValue() ) onground();
    else                airborne();
}, 0, 0);


##
## ++++++++++++++++ Centralized Flight Mode Monitoring System ++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

######################################################
##	Listener to changes in the flight mode	    ##
######################################################

setlistener("/instrumentation/fmc/flight-mode", func (n) {
    var mode = n.getValue();

    if ( mode == FlightModes.PWR ) {
	screen.log.write("Power on");
	setprop("/controls/electric/master-switch", ON);
    }
    elsif ( mode == FlightModes.ENG ) {
        # one engine started
        setprop("/controls/electric/external-power", OFF);
        instrumentsOn();
        startSysTimers();
	# set the altimeters to outside pressure
	var p =  getprop("/environment/pressure-inhg");
	if ( p != nil ) {
	    setprop("/instrumentation/altimeter[0]/setting-inhg", p);
	    setprop("/instrumentation/altimeter[1]/setting-inhg", p);
	}
    }
    elsif ( mode == FlightModes.READY ) {
        # all engines started - switch off APU
        setprop("/controls/APU/run", OFF);

        # transponder to ground mode
        knobPosition(TransponderKnob.GROUND);
        # start V-speed listeners
        makeVspeedListeners();
	cockpit_door.close();
	extLightsOn();
    }
    elsif ( mode == FlightModes.TAXI ) {
        # taxing below 80 kts
        # use taxi lights on the ground and landing lights when airborne
        taxiLightsOn();
    }
    elsif ( mode == FlightModes.V1 ) {
        # refusal speed reached
    }
    elsif ( mode == FlightModes.LIFTOFF ) {
        # wheels off the ground
	setprop("/controls/flight/auto-coordination", ON);
	# switch on the standby generator
	setprop("/controls/switches/RAT", ON);
	# transponder to ON mode
	knobPosition(TransponderKnob.ON);
	# start cabin pressure
	cabinPressOn();
    }
    elsif ( mode == FlightModes.CLB ) {
        # 400 ft above ground
        noseLightsOff();
    }
    elsif ( mode == FlightModes.NORMAL ) {
        # 1,500 ft above ground
        screen.log.write("Normal flight mode");
        # transponder to ALT mode
        knobPosition(TransponderKnob.ALT);
        # stop V-speed listeners
        deleteVspeedListeners();
        # start speed bleed updates
        casTimer.start();
    }
    elsif ( mode == FlightModes.FLARE ) {
        # 1,000 ft above ground
        prepareLanding();
        landLightsOn();
        # transponder to ON mode
        knobPosition(TransponderKnob.ON);
        # stop the navigation and descent timers
        stopFgTimers();
    }
    elsif ( mode == FlightModes.TDOWN ) {
        # MLG on the ground
        setprop("/controls/flight/auto-coordination", OFF);
        touchdown();
        copilot.announce("Touch down!");
        # transponder to ground mode
        knobPosition(TransponderKnob.GROUND);
	# switch off the standby generator
	setprop("/controls/switches/RAT", OFF);
        # use taxi lights on the ground and landing lights when airborne
        taxiLightsOn();
        # stop speed bleed updates
        casTimer.stop();
        # the cockpit air should be shutoff
        setprop("/controls/anti-ice/window-heat", OFF);
        # dump cabin pressure
        cabinPressDump();
    }
    elsif ( mode == FlightModes.DEST ) {
        # rolling below 80 kts
        copilot.announce("You have arrived!");
        # transponder to standby
        knobPosition(TransponderKnob.STANDBY);
        ## centre rudder
        interpolate("/controls/flight/rudder", 0, 2);
        ## switch off the AP and ATHR within 4 secs in case they are still ON
        timedAPOff(4);
        instrumentsOff();
        cabinPressOff();
    }
    elsif ( mode == FlightModes.END ) {
        # last engine shutdown
	mainShutdown();
    }
}, 0, 0);


##
## ++++++++++++++++++++++++++++ STARTUP / SHUTDOWN ++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

###
### Startup routine
### ----------------

## utility function to start some timers running in this file when starting up
var startSysTimers = func {
    cabinEnvTimer.start();
};

var initialSetup = func () {
    initElectric();
    setprop("/controls/flight/auto-coordination", OFF);
    setprop("/controls/gear/brake-parking", 1);

    # all lights are off
    initLights();

    # align the heading indicator to the magnetic compass
    # periodically re-adjust the Directional Gyro to the Wet Compass
    var magvar = 0 - getprop("/environment/magnetic-variation-deg");
    setprop("instrumentation/heading-indicator-dg/align-deg", magvar);

    # set the iniitial heading
    var hdg = getprop("/orientation/heading-deg");
    setprop("/instrumentation/heading-indicator/heading-bug-deg", hdg);

    # create new atmospheric calculator container
    atmos = Atmos.new();

    # initialise the cockpit environment
    init_cabin_env();

    logprint(LOG_INFO, "Vulcan systems initialised");

    # remove the FDM listener
    removelistener(sysInitListener);
};

var sysInitListener = setlistener("/sim/signals/fdm-initialized", initialSetup, 0, 0);


###
### Shutdown routine
### ----------------

## utility function to stop some timers running in this file when closing down
var stopSysTimers = func {
    cabinEnvTimer.stop();
    if ( casTimer.isRunning ) casTimer.stop();
};

var mainShutdown = func () {
    # call shutdown scripts in other files
    fdShutdown();
    missionShutdown();

    # stop timers in this script
    stopSysTimers();

    # switch off electrics
    electricOff();
}

################################# END #######################################
