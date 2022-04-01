################################################################################################
#
#			Handley Page Victor Mission Operations
#
# This file runs mission specific nasal functions for the Victor. In particular it handles
# armament operations and mission selection.
#
# Other files do other specific tasks, such as :
#
#       * victor-header.nas - defines all the configuration data and shared nasal variables
#       * flightdirector.nas - provides autopilot and flightdirector functions
#       * fms.nas - provides flight management/guidance functions
#       * ctrlpanel.nas - defines the interactions with the panel and dialog
#       * system.nas - defines the (critical) system management functions including
#		flight modes, electrical system. fuel, instruments, flight controls etc.
#       * starter.nas - manages the engine startup/shutdown operations
#       * tyresmoke.nas - eyecandy effects of smoke and rain on runways
#       * crash.nas - generic crash and stress system
#       * blackout.nas - generic pilot blackout system
#       * Atmos.nas - generic utility to perform atmospheric conversions
#
################################################################################################


#################################################################################################
##
##
## Handley Page Victor operational variants:
##
## B.1   - Strategic bomber aircraft
## B.1A  - Strategic bomber aircraft, with Red Steer tail warning radar and ECM suite
## B.1A (K.2P) - 2-point in-flight refuelling tanker retaining bomber capability
## BK.1  - 3-point in-flight refuelling tanker (renamed K.1 after bombing capability removed)
## BK.1A - 3-point in-flight refuelling tanker (renamed K.1A as for K.1)
## B.2   - Strategic bomber aircraft
## B.2RS - Blue Steel-capable aircraft with RCo.17 Conway 201 engines
## B(SR).2 - Strategic reconnaissance aircraft
## K.2   - In-flight refuelling tanker
########################################################################################
Variants    = { B1: 0, B1A: 1, B2: 2, B2RS: 3, BSR2: 4, K2: 5, K2P: 6 };
NumVariants = 7;

## Vector of armament
var WpnInfo	= [];
var NumStns	= 0;

## Define the mutually exclusive options for weapons configurations
var Nuclear	= [];
var Conventional = [];
var WpnClass = { None: -1, Bomb: 0, Missile: 2, NBomb: 4, NMissile: 6, Refuel: 8 };

## List of the capilities of each variant
var Capabilities = [];

###############################

## Dialogs
var ap_dialog		= nil;
var config_dialog	= nil;
var doors_dialog	= nil;
var altimeter_dialog	= nil;
var fuel_dialog		= nil;
var avionics_dialog	= nil;
var fd_dialog		= nil;
var cabin_dialog	= nil;

#############################################################
###  Utility function to toggle a switch with sound effects
##############################################################

var switchWithSound = func () {
    var prop = props.globals.getNode("sim/sound/effects/switch");
    prop.setBoolValue(TRUE);
    var t = maketimer(0.2, func {
		prop.setBoolValue(FALSE);
	    });
    t.singleShot = TRUE;
    t.start();
}


########################################################################################
## Armament:
##
## The Victor's bomb bay was much larger than that of the Valiant and Vulcan,
## which allowed heavier weapon loads to be carried at the cost of range.
##
## Nuclear weapons:
##   1 x Blue Danube 10,000 lb nuclear gravity bomb with yields of 10-12 kilotons.
##   1 x Yellow Sun 7,250 pounds (3,290 kg) thermonuclear gravity bomb:
##      - 400 kt Green Grass warhead
##      - 1.1 Mt Red Snow warhead
##   1 × Red Beard nuclear gravity bomb. Two versions were produced:
##      - Mk.1, a yield of 15 kilotons, and
##      - Mk.2, with a yield of 25 kilotons.
##   1 × WE.177A (622 lb) parachute-retarded nuclear gravity bomb with yields of
##       0.5 or 10 kilotons
##   1 × WE.177B (1,008 lb) parachute-retarded nuclear gravity bomb with yields
##       of 450 kiloton
##   1 × Blue Steel 17,000 lb (7,700 kg) missile fitted with the W-28 thermonuclear
##       warhead of 1.1 Mt yield
##
## Conventional armaments:
##   1 x 22,000 lb (10,000 kg) Grand Slam with a blast yield of 6.5 tons
##   2 x 12,000 lb (5,400 kg) Tallboy earthquake bombs
##   48 * 1,000 lb (450 kg) bombs
##   39 * 2,000 lb (910 kg) sea mines
##   4 x 395 pounds (177 kg) AGM-45A Shrike anti-radiation missiles
##
## Options allowed here are:
##	- 1 × Blue Steel missile or
##	- 1 × free-fall nuclear bomb or
##	- 48 × 1,000 lb (450 kg) conventional bombs
##	Plus
##	  4 x AGM-45A Shrike anti-radiation missiles
########################################################################################

## Armament hash
var weapon = { name: "", weight: 0, yield_kt: 0, type: -1, station: -1, units: 0, inbay: TRUE };

## Indices (stations) assign to each armament
var WpnIndex = { NN: 0, SK1: 1, SK2: 2, SK3: 3, SK4: 4, BD: 5, BS: 6, RB: 7, WA: 8, WB: 9, YS: 10, GS: 11, TB: 12 };

## Intialise weapons information for use when loading them
var setWpnDetails = func (index, name, weight, yield, units, type, inbay=TRUE) {
    WpnInfo[index] = { parents:[weapon] };
    WpnInfo[index].name = name;
    WpnInfo[index].weight = weight;
    WpnInfo[index].yield_kt = yield;
    WpnInfo[index].station = index;
    WpnInfo[index].units = units;
    WpnInfo[index].type = type;
    WpnInfo[index].inbay = inbay;

    # create the two main configurations
    if ( type == WpnClass.Bomb )	append(Conventional, index);
    elsif ( type == WpnClass.NBomb )	append(Nuclear, index);
    elsif ( type == WpnClass.NMissile)	append(Nuclear, index);
    # ignore the shrike missiles
}

var initWpnInfo = func () {
    # first clean vectors
    forindex(var index; WpnInfo) pop(WpnInfo);
    forindex(var index; Nuclear) pop(Nuclear);
    forindex(var index; Conventional) pop(Conventional);

    # now add an element for each type of weapon
    foreach(var hash_key ; keys(WpnIndex)) append(WpnInfo, nil);
    NumStns = size(WpnInfo);

    # conventional bombs - yield is scaled up for effects
    setWpnDetails(WpnIndex.NN, "Iron Bomb", 1000, 0.1, 48, WpnClass.Bomb);

    # Blue Danube
    setWpnDetails(WpnIndex.BD, "Blue Danube", 10000, 12, 1, WpnClass.NBomb);

    # Blue Steel
    setWpnDetails(WpnIndex.BS, "Blue Steel", 17000, 1100, 1, WpnClass.NMissile, FALSE);

    # WE177 Type A
    setWpnDetails(WpnIndex.WA, "WE177A", 622, 10, 1, WpnClass.NBomb);

    # WE177 Type B
    setWpnDetails(WpnIndex.WB, "WE177B", 1008, 450, 1, WpnClass.NBomb);

    # Shrike missiles x 4 - yield is scaled up for effects
    setWpnDetails(WpnIndex.SK1, "Shrike 1", 395, 0.1, 1, WpnClass.Missile, FALSE);
    setWpnDetails(WpnIndex.SK2, "Shrike 2", 395, 0.1, 1, WpnClass.Missile, FALSE);
    setWpnDetails(WpnIndex.SK3, "Shrike 3", 395, 0.1, 1, WpnClass.Missile, FALSE);
    setWpnDetails(WpnIndex.SK4, "Shrike 4", 395, 0.1, 1, WpnClass.Missile, FALSE);

    # Red Beard Mk.2
    setWpnDetails(WpnIndex.RB, "Red Beard", 1750, 25, 1, WpnClass.NBomb);

    # Yellow Sun Mk.2
    setWpnDetails(WpnIndex.YS, "Yellow Sun", 7250, 400, 1, WpnClass.NBomb);

    # Grand Slam conventional bomb - yield is scaled up for effects
    setWpnDetails(WpnIndex.GS, "Grand Slam", 22000, 0.65, 1, WpnClass.Bomb);

    # Tallboy earthquake conventional bombs - yield is scaled up for effects
    setWpnDetails(WpnIndex.TB, "Tallboy", 12000, 0.33, 2, WpnClass.Bomb);
}


## Set weapon load or refuelling capabilities for each variant
var declareCap = func () {
    forindex(var index; Capabilities)       pop(Capabilities);
    for (var index = 0; index < NumVariants; index += 1)
	append(Capabilities, [ WpnClass.None ]);

    # B.1 bomber - conventional and nuclear bombs
    append(Capabilities[Variants.B1], WpnClass.Bomb, WpnClass.NBomb);
    # B.1A bomber - conventional and nuclear bombs
    append(Capabilities[Variants.B1A], WpnClass.Bomb, WpnClass.NBomb);
    # B.2 bomber - conventional and nuclear bombs plus shrike missiles
    append(Capabilities[Variants.B2], WpnClass.Bomb, WpnClass.NBomb, WpnClass.Missile);
    # B.2RS bomber - conventional and nuclear bombs plus shrike and Blue Steel missiles
    append(Capabilities[Variants.B2RS], WpnClass.Bomb, WpnClass.NBomb, WpnClass.Missile, WpnClass.NMissile);
    # B(SR).2 - no weapons
    #Capabilities[Variants.BSR2] = [ WpnClass.None ];
    # K.2 - refuelling only
    append(Capabilities[Variants.K2], WpnClass.Refuel);
    # B.1A (K.2P) - reuling and conventional bombs
    append(Capabilities[Variants.K2P], WpnClass.Refuel, WpnClass.Bomb);
}

## Utility function to check if the variant is capable of carrying the load
var verifyLoad = func (name, load) {
    var ok      = FALSE;
    var variant = Variants[name];
    var list    = Capabilities[variant];
    forindex (var index; list) {
	if (load == list[index]) {
	    ok = TRUE;
	    break;
	}
    }

    return (ok);
}

## Utility function to set the variant capabilities
var setVariantCap = func (name) {
    var variant = Variants[name];
    var list    = Capabilities[variant];
    var cap     = nil;

    # reset capabilities first
    setprop("/sim/variant/bomber", FALSE);
    setprop("/sim/variant/nbomber", FALSE);
    setprop("/sim/variant/shrikes", FALSE);
    setprop("/sim/variant/nmissile", FALSE);
    setprop("/sim/variant/tanker", FALSE);

    forindex(var index; list) {
	cap = list[index];
	if (cap == WpnClass.Bomb) setprop("/sim/variant/bomber", TRUE);
	elsif (cap == WpnClass.Missile) setprop("/sim/variant/shrikes", TRUE);
	elsif (cap == WpnClass.NBomb) setprop("/sim/variant/nbomber", TRUE);
	elsif (cap == WpnClass.NMissile) setprop("/sim/variant/nmissile", TRUE);
	elsif (cap == WpnClass.Refuel) setprop("/sim/variant/tanker", TRUE);
    }
}

## Update capabilities whenever the variant changes
setlistener("/sim/variant/name", func (n) {
    var name = n.getValue();
    var mission = selMission.getValue();
    setVariantCap(name);
    requestMission(mission);
}, 0, 0);

## Default mission by variant
var defaultMission = func (name) {
    var mission = "Clean";
    if (name == "B1")       mission = "Black Buck One";
    elsif (name == "B1A")   mission = "Blue Danube";
    elsif (name == "B2")    mission = "Black Buck Six";
    elsif (name == "B2RS")  mission = "Blue Steel";
    elsif (name == "BSR2")  mission = "Clean";
    elsif (name == "K2")    mission = "Clean";
    elsif (name == "K2P")   mission = "Tallboy";

    return mission;
}

## Utility function to determine the main weapon class for a given mission
var getMissionWpnType = func (mission) {
    var wclass = WpnClass.None;

    if (mission == "Clean") {	# no weapons
    }
    elsif (mission == "Full Works") { # conventional bombs and shrikes
	wclass = WpnInfo[WpnIndex.NN].type;
    }
    elsif (mission == "WE177A") {
	wclass = WpnInfo[WpnIndex.WA].type;
    }
    elsif (mission == "WE177B") {
	wclass = WpnInfo[WpnIndex.WB].type;
    }
    elsif (mission == "Red Beard") {
	wclass = WpnInfo[WpnIndex.RB].type;
    }
    elsif (mission == "Blue Steel") {
	wclass = WpnInfo[WpnIndex.BS].type;
    }
    elsif (mission == "Blue Danube") {
	wclass = WpnInfo[WpnIndex.BD].type;
    }
    elsif (mission == "Yellow Sun") {
	wclass = WpnInfo[WpnIndex.YS].type;
    }
    elsif (mission == "Black Buck One") {       # Carrying forty-eight 1,000-pound bombs
	wclass = WpnClass.Bomb;
    }
    elsif (mission == "Black Buck Six") {       # armed with four Shrike missiles
	wclass = WpnClass.Missile;
    }
    elsif (mission == "Grand Slam") {
	wclass = WpnInfo[WpnIndex.GS].type;
    }
    elsif (mission == "Tallboy") {
	wclass = WpnInfo[WpnIndex.TB].type;
    }

    return (wclass);
}

## Utility function to determine the main weapon's class
var getWpnType = func () {
    var wpn = mainWeapon.getValue();

    # if empty, return none
    if (wpn == "") return (WpnClass.None);

    var j = -1;
    forindex(var index; Nuclear) {
	j = Nuclear[index];
	if (wpn == WpnInfo[j].name)
	    return WpnInfo[j].type;
    }
    forindex(var index; Conventional) {
	j = Conventional[index];
	if (wpn == WpnInfo[j].name)
	    return WpnInfo[j].type;
    }

    # failure must never happen
    logprint("LOG_ALERT", "Error: The type of weapon "~wpn~" has not defined!");
    return (WpnClass.None);
}

## Utility function to identify a shrike missile by station
var isShrike = func (n) {
   if ( n > NumStns ) return FALSE;
   elsif ( n < WpnIndex.SK1 ) return FALSE;
   elsif ( n > WpnIndex.SK4) return FALSE;
   else return TRUE;
}

## Update the armament total weight
var updateArmsWeight = func () {
    var u = 0;
    var w = 0;
    var tt = 0;

    # do not include the shrike missiles
    for (var j = 0; j < WpnIndex.SK1; j += 1) {
	u = getprop("controls/armament/station["~j~"]/units");
	w = getprop("controls/armament/station["~j~"]/unit-weight-lbs");
	tt = tt + (u * w);
    }
    for (var j = WpnIndex.SK4 + 1; j < NumStns; j += 1) {
	u = getprop("controls/armament/station["~j~"]/units");
	w = getprop("controls/armament/station["~j~"]/unit-weight-lbs");
	tt = tt + (u * w);
    }
    bombsWeight.setValue(tt);

    # now for the shrike missiles
    updateShrikesWeight();
}

## Update the shrike missiles total weight
var updateShrikesWeight = func () {
    var u = 0;
    var w = 0;
    var tt = 0;

    # portside
    for (var j = WpnIndex.SK1; j <= WpnIndex.SK2; j += 1) {
	u = getprop("controls/armament/station["~j~"]/units");
	w = getprop("controls/armament/station["~j~"]/unit-weight-lbs");
	tt = tt + (u * w);
    }
    shrikes12Weight.setValue(tt);

    # starboard
    tt = 0;
    for (var j = WpnIndex.SK3; j <= WpnIndex.SK4; j += 1) {
	u = getprop("controls/armament/station["~j~"]/units");
	w = getprop("controls/armament/station["~j~"]/unit-weight-lbs");
	tt = tt + (u * w);
    }
    shrikes34Weight.setValue(tt);
}

## Adjust the total weight of a pointmass based on the station ID
## Note that "wgt" may be positive or negative.
var adjustArmsWeight = func (stn, wgt) {
    if (wgt == 0) return;

    var shrike = isShrike(stn);

    if ( shrike == FALSE ) {
	var totalwgt = bombsWeight.getValue() + wgt;
	# When loading/unloading on the ground, this must be done carefully to
	# avoid distablising the plane. Therefore, we change the weight of an
	# intermediate property which is then interpolated to the final value
	# via an XML filter
	bombsWeight.setValue(totalwgt);
    } else {	# this is a shrike missile, but in which mount point
	if (stn < WpnIndex.SK3) {	# portside
	    var totalwgt = shrikes12Weight.getValue() + wgt;
	    shrikes12Weight.setValue(totalwgt);
	} else {	# starboard
	    var totalwgt = shrikes34Weight.getValue() + wgt;
	    shrikes34Weight.setValue(totalwgt);
	}
    }
}

## Update the current status of the selected station to the "root"
var selectedStnStatus = func () {
    var stn	= selStation.getValue();
    var armed	= getprop("controls/armament/station["~stn~"]/armed");
    var avail	= getprop("controls/armament/station["~stn~"]/units");
    var suffix	= " / "~avail;
    if (avail == 0)	setprop("/controls/armament/status", "Empty");
    elsif ( armed )	setprop("/controls/armament/status", "Armed"~suffix);
    else		setprop("/controls/armament/status", "Unarmed"~suffix);

    setprop("/controls/armament/units", avail);
    setprop("/controls/armament/current-weapon", WpnInfo[stn].name);
}

## Unload the armament load from a given station reducing the corresponding weight
var unloadStation = func (stn, n) {
    var base	= "controls/armament/station["~stn~"]";
    var curnum	= getprop(base~"/units");
    var unitwgt	= getprop(base~"/unit-weight-lbs");
    var curwgt	= curnum * unitwgt;
    var newnum	= curnum - n;
    newnum = (newnum < 0) ? 0 : newnum;
    var redwgt	= (newnum - curnum) * unitwgt;	# this ought to be -ve

    # choose which pointmass to reduce
    adjustArmsWeight(stn, redwgt);

    setprop(base~"/units", newnum);
    if ( newnum == 0 ) {
	setprop(base~"/jettison-all", TRUE);
	setprop(base~"/release-all", TRUE);
	setprop(base~"/armed", FALSE);
    }
}

## Load station with it's assigned weapon
var loadStation = func (stn) {
    var wpn = WpnInfo[stn];
    var base = "controls/armament/station["~stn~"]";
    # we need the current load so that we can calculate the additional weight
    var current  = getprop(base~"/units");
    setprop(base~"/units", wpn.units);
    setprop(base~"/unit-weight-lbs", wpn.weight);
    setprop(base~"/jettison-all", FALSE);
    setprop(base~"/release-all", FALSE);
    var addwgt = (wpn.units - current) * wpn.weight;

    # choose which pointmass to increase
    adjustArmsWeight(stn, addwgt);
}

## Arm a station
var armStation = func (stn) {
    var n = getprop("controls/armament/station["~stn~"]/units");
    if ( n > 0 )
	setprop("/controls/armament/station["~stn~"]/armed", TRUE);
    selectedStnStatus();
}

## Disarm a station
var disarmStation = func (stn) {
    setprop("/controls/armament/station["~stn~"]/armed", FALSE);
    selectedStnStatus();
}

## Update a stationa - disarm if necessary
var updateStation = func (stn) {
    var n = getprop("controls/armament/station["~stn~"]/units");
    if ( n < 1 )    disarmStation(stn);
    else	    selectedStnStatus();
}

## Toggle armed status on the given station
var toggleStnArmed = func(stn) {
    var unlocked = masterArm.getValue();
    var armed	= getprop("controls/armament/station["~stn~"]/armed");
    var avail	= getprop("controls/armament/station["~stn~"]/units");
    var idnum	= getprop("controls/armament/station["~stn~"]/id");
    var name	= WpnInfo[stn].name;

    if ( ! unlocked ) {
	screen.log.write("Sir, master arm is off");
	return;
    }
    if (avail < 1) {
	screen.log.write("Sir, there is nothing on station "~idnum);
	return;
    }
    elsif ( armed ) {
	disarmStation(stn);
	screen.log.write(name~" on station "~idnum~" is now disarmed");
    }
    else {
	armStation(stn);
	screen.log.write(name~" on station "~idnum~" is now armed");
    }
    switchWithSound();
    selectedStnStatus();
}

## Toggle armed status on the current selected station
var toggleArmed = func() {
    var stn = selStation.getValue();
    toggleStnArmed(stn);
}

## Disarm all stations
var disarmAll = func () {
    for (var j = 0; j < NumStns; j += 1) {
	setprop("/controls/armament/station["~j~"]/armed", FALSE);
    }
    screen.log.write("Sir, master arm is now OFF");
    selectedStnStatus();
}

## Monitor the master arm switch and act as necessary
setlistener("controls/armament/master-arm", func (n) {
    if ( n.getValue() == OFF ) disarmAll();
    else screen.log.write("Sir, master arm is now ON");
}, 0, 0);

## Unload all weapons
var unloadWeapons = func () {
    # unload on the ground or jettison safely when airborne
    var flt_mode = fmcFlightMode.getValue();
    if ( flt_mode > FlightModes.ENG and flt_mode < FlightModes.DEST) {
	var safe = safeRelease.getValue();
	if ( safe == FALSE ) {
	    screen.log.write("Unloading is only possible when it is safe");
	    return;
	}
    }

    for (var j = 0; j < NumStns; j += 1) {
	setprop("/controls/armament/station["~j~"]/units", 0);
	setprop("/controls/armament/station["~j~"]/jettison-all", TRUE);
	setprop("/controls/armament/station["~j~"]/release-all", TRUE);
	setprop("/controls/armament/station["~j~"]/armed", FALSE);
    }
    bombsWeight.setValue(0);
    shrikes12Weight.setValue(0);
    shrikes34Weight.setValue(0);
    setprop("/controls/armament/status", "Empty");
}

var ShrikesFlexible = TRUE;	# whether we have flexibility in shrikes loading

## Reload shrike missiles
var reloadShrikes = func() {
    ## verify the mode first
    verify_shrikes();

    # check for shrike missiles
    var shrike = enableShrike.getValue();
    if ( shrike ) {	# load 4 shrikes
	loadStation(WpnIndex.SK1);
	loadStation(WpnIndex.SK2);
	loadStation(WpnIndex.SK3);
	loadStation(WpnIndex.SK4);
    } else {	# unload all shrikes
	unloadStation(WpnIndex.SK1, 1);
	unloadStation(WpnIndex.SK2, 1);
	unloadStation(WpnIndex.SK3, 1);
	unloadStation(WpnIndex.SK4, 1);
    }
}

## Monitor the shrike selection
setlistener("/controls/armament/shrikes", reloadShrikes, 0, 0);

## Reload weapons based on the mission
var reloadWeapons = func () {
    # load only on the ground
    var flt_mode = fmcFlightMode.getValue();
    if ( flt_mode > FlightModes.ENG and flt_mode < FlightModes.DEST) {
	screen.log.write("Loading is only possible when stationary");
	return;
    }

    var wpn = mainWeapon.getValue();
    # only this station will be loaded

    var j = -1;
    forindex(var index; Nuclear) {
	j = Nuclear[index];
	if (wpn == WpnInfo[j].name) loadStation(j);
	else	unloadStation(j, WpnInfo[j].units);
    }
    forindex(var index; Conventional) {
	j = Conventional[index];
	if (wpn == WpnInfo[j].name) loadStation(j);
	else	unloadStation(j, WpnInfo[j].units);
    }

    # now for shrikes
    reloadShrikes();

    updateArmsWeight();
    selectedStnStatus();
}

## Select armament based on a mission
var missionArmament = func () {
    # load only on the ground
    var flt_mode = fmcFlightMode.getValue();
    if ( flt_mode > FlightModes.ENG and flt_mode < FlightModes.DEST) {
	screen.log.write("Loading is only possible when stationary");
	return;
    }

    # reset bay doors
    setprop("/controls/doors/bb-door-pos", BayPos.Closed);

    var mission = selMission.getValue();

    if (mission == "Clean") {	# no weapons
	setprop("/controls/armament/main-weapon", "");
	setprop("/controls/armament/units", 0);
	setprop("/controls/armament/shrikes", OFF);
	unloadWeapons();
	return;
    }
    elsif (mission == "Full Works") { # conventional bombs and shrikes
	setprop("/controls/armament/main-weapon", "Iron Bomb");
	setprop("/controls/armament/shrikes", ON);
    }
    elsif (mission == "WE177A") {
	setprop("/controls/armament/main-weapon", "WE177A");
    }
    elsif (mission == "WE177B") {
	setprop("/controls/armament/main-weapon", "WE177B");
    }
    elsif (mission == "Red Beard") {
	setprop("/controls/armament/main-weapon", "Red Beard");
    }
    elsif (mission == "Blue Steel") {
	setprop("/controls/armament/main-weapon", "Blue Steel");
	# we need to lock the bay doors from use
	setprop("/controls/doors/bb-door-pos", BayPos.Locked);
    }
    elsif (mission == "Blue Danube") {
	setprop("/controls/armament/main-weapon", "Blue Danube");
    }
    elsif (mission == "Yellow Sun") {
	setprop("/controls/armament/main-weapon", "Yellow Sun");
    }
    elsif (mission == "Black Buck One") {   # Carrying twenty-one 1,000-pound bombs
	setprop("/controls/armament/main-weapon", "Iron Bomb");
	setprop("/controls/armament/shrikes", OFF);
    }
    elsif (mission == "Black Buck Six") {	# armed with four Shrike missiles
	setprop("/controls/armament/main-weapon", "");
	setprop("/controls/armament/shrikes", ON);
    }
    elsif (mission == "Grand Slam") {
	setprop("/controls/armament/main-weapon", "Grand Slam");
    }
    elsif (mission == "Tallboy") {
	setprop("/controls/armament/main-weapon", "Tallboy");
    }

    # now reload the weapons
    reloadWeapons();
}

setlistener("/sim/armament/mission", missionArmament, 0, 0);

## Verify the mission request before assigning it or the default mission for the variant
## call this function and not missionArmament
var requestMission = func (mission) {
    var name = selVariant.getValue();
    var load = getMissionWpnType(mission);
    var ok  = verifyLoad(name, load);
    var current = selMission.getValue();

    if (ok == TRUE) {
	if (current == mission) {       # just reload them
	    reloadWeapons();
	} else  setprop("/sim/armament/mission", mission);

    } else {  # check the current mission and set to default if necesary
	load = getMissionWpnType(current);
	ok = verifyLoad(name, load);
	if (ok == FALSE) {      # reset
	    current = defaultMission(name);
	    setprop("/sim/armament/mission", current);
	} else {        # just reload the weapons
	    reloadWeapons();
	}
    }
}

## Return valid shrike permission for given missions
var shrikesOption = func (mission) {
    var enable = enableShrike.getValue();
    var flexible = variantShrikes.getValue();   # if variant can carry shrikes
    if (flexible == FALSE) {
        enable = FALSE;
    } elsif ( (mission == "Black Buck One") or (mission == "Clean") ) {
	enable = FALSE;
	flexible = FALSE;
    } elsif ( (mission == "Black Buck Six") or (mission == "Full Works") ) {
	enable = TRUE;
	flexible = FALSE;
    }

    ShrikesFlexible = flexible;
    return (enable);
}

## Verify shrikes enable mode depending in user selection and current mission
var verify_shrikes = func () {
    var mission = selMission.getValue();
    var current = enableShrike.getValue();
    var allowed = shrikesOption(mission);
    if (allowed != current) {
	setprop("/controls/armament/shrikes", allowed);
    }
}

## Toggle shrikes on/off
var toggle_shrikes = func () {
    if ( ShrikesFlexible == TRUE ) {
	var current = getprop("/controls/armament/shrikes");
	if (current == OFF) setprop("/controls/armament/shrikes", ON);
	else setprop("/controls/armament/shrikes",  OFF);
	verify_shrikes();
    }
}

## Simulate the release sound of the armament
var detachSound = func () {
    setprop("/sim/sound/armament/armament-release", ON);
    var t = maketimer(2.0, func {
	    setprop("/sim/sound/armament/armament-release", OFF);
	    });
    t.singleShot = TRUE;
    t.start();
}

## Simulate missile sound
var missileSound = func (stn) {
    # different sound from shrikes and Blue Steel
    if (stn ==  WpnInfo[WpnIndex.BS].station) {
	var vol = 1.0;
	setprop("/sim/sound/armament/cruise-missile", ON);
    } else {
	var vol = 0.8;
	setprop("/sim/sound/armament/cruise-missile", OFF);
    }
    setprop("/sim/sound/armament/missile-volume", vol);
    setprop("/sim/sound/armament/missile-fired", ON);
    # shrikes sound for 7 s 27 ms, Blue Steel for 4 s 778 ms
    var t = maketimer(7.5, func {
	    setprop("/sim/sound/armament/missile-fired", OFF);
	    });
    t.singleShot = TRUE;
    t.start();
}

## Pull and release the trigger after a given time
var pullTrigger = func (stn, time=0.2) {
    var is_bomb = WpnInfo[stn].inbay;
    setprop("/controls/armament/station["~stn~"]/trigger", TRUE);
    detachSound();
    var t = maketimer(time, func {
	    setprop("/controls/armament/station["~stn~"]/trigger", FALSE);
	    updateArmsWeight();
	    updateStation(stn);
	    });
    t.singleShot = TRUE;
    t.start();
    if ( ! is_bomb ) missileSound(stn);
}

## Release weapon
var fireWeapon = func () {
    # safety checks
    var safe = safeRelease.getValue();
    if ( safe == FALSE ) return;

    ## must be armed before release
    var stn	= selStation.getValue();
    var armed	= getprop("controls/armament/station["~stn~"]/armed");
    var avail	= getprop("controls/armament/station["~stn~"]/units");
    var idnum	= getprop("controls/armament/station["~stn~"]/id");
    if (avail < 1) {
	screen.log.write("Sir, there is nothing to release on station "~idnum);
	return;
    }
    if ( ! armed ) {
	screen.log.write("Sir, you need to arm station "~idnum~" first!");
	return;
    }

    # the bay door might need to be open
    if ( WpnInfo[stn].inbay ) {
	var baypos = bb_doors.getpos();
	if ( baypos < 1 ) {
	    screen.log.write("Sir, the bomb bay doors are still closed!");
	    return;
	}
    }

    # good to go
    pullTrigger(stn);
}

## Fire from a given station
var fireStation = func (stn) {
    setprop("/controls/armament/station-select", stn);
    fireWeapon();
}

## Select next station forward (+1) or backwards (-1)
var changeStation = func (step) {
    var n = step + selStation.getValue();
    n = math.clamp(n, 0, NumStns - 1);
    setprop("/controls/armament/station-select", n);
    selectedStnStatus();

    var avail = getprop("controls/armament/station["~n~"]/units");
    if (avail > 0)
	screen.log.write("The selected station has "~WpnInfo[n].name);
    else
	screen.log.write("The selected station is now empty");
}


###################################
## Impact and Explosions effects
###################################

## Explosion based on yield and distance
var explosion = func (distance, yield)
{
    var blast_factor = math.round(yield / 10);	# scale it down for the larger explosions
    var vol = blast_factor * 0.3 / math.sqrt(distance);;
    vol = math.clamp(vol, 0.2, 1.0);

    # a full blast lasts for 4 s 338 ms
    blast_factor = math.clamp(blast_factor, 1, 6);
    var time = 4.3381 * blast_factor;

    setprop("/sim/sound/armament/explosion-volume", vol);
    setprop("/sim/sound/armament/explosion", ON);
    var t = maketimer(time, func {
		setprop("/sim/sound/armament/explosion", OFF);
	    });
    t.singleShot = TRUE;
    t.start();
}

## Missile explosion based on yield and distance
var missileHit = func (distance, yield)
{
    var blast_factor = math.round(yield / 10);	# scale it down for the larger explosions
    var vol = blast_factor * 0.3 / math.sqrt(distance);;
    vol = math.clamp(vol, 0.5, 1.0);

    # a full blast lasts for 1 s 100 ms
    setprop("/sim/sound/armament/explosion-volume", vol);
    setprop("/sim/sound/armament/missile-hit", ON);
    var t = maketimer(1.2, func {
		setprop("/sim/sound/armament/missile-hit", OFF);
	    });
    t.singleShot = TRUE;
    t.start();

    # if this is a nuclear weapon, then add the explosion as well
    var ex = maketimer(1.5, func {
		explosion(distance, yield);
	    });
    ex.singleShot = TRUE;
    if (yield > 5) ex.start();
}

## Get yield of bomb that exploded
var getYield = func (name) {
    var yield = 0;
    foreach(var wpn; WpnInfo) {
	if (wpn.name == name) {
	    yield = wpn.yield_kt;
	    break;
	}
    }
    return yield;
}

## Add listener for bomb impact
setlistener("sim/ai/aircraft/impact/bomb", func (n) {
    var impact	= n.getValue();
    var valid	= getprop(impact ~ "/valid");
    if ( ! valid ) return;

    var solid	= getprop(impact ~ "/material/solid");
    var weapon	= getprop(impact ~ "/name");
    var yield	= getYield(weapon);
    var time	= simTime.getValue();
    setprop("/sim/armament/weapons/impact-time", time);

    if (solid) {
	var long = getprop(impact ~ "/impact/longitude-deg");
	var lat = getprop(impact ~ "/impact/latitude-deg");
	var name = getprop(impact ~ "/material/name");
	var mat_type = getprop(impact ~ "/impact/type");
	var location = geo.Coord.new().set_latlon(lat, long);
	var distance = geo.aircraft_position().direct_distance_to(location) / 1000;
	var ltext = "Bomb of type "~weapon~" hit " ~ name ~ " target";
	screen.log.write(ltext);
	setprop("/sim/armament/weapons/yield-ktn", yield);
	geo.put_model("Aircraft/victor/Models/Effects/Armament/bomb.xml", lat, long);
	explosion(distance, yield);
    } else {
        var ltext = "Impact on non solid surface, detonation aborted!";
        screen.log.write(ltext);
    }
}, 0, 1);

## Add listener for missile impact
setlistener("sim/ai/aircraft/impact/missile", func (n) {
    var impact	= n.getValue();
    var valid	= getprop(impact ~ "/valid");
    if( ! valid ) return;

    var solid	= getprop(impact ~ "/material/solid");
    var weapon	= getprop(impact ~ "/name");
    var yield	= getYield(weapon);
    var time	= simTime.getValue();
    setprop("/sim/armament/weapons/impact-time", time);

    if (solid) {
	var long = getprop(impact ~ "/impact/longitude-deg");
	var lat = getprop(impact ~ "/impact/latitude-deg");
	var name = getprop(impact ~ "/material/name");
	var mat_type = getprop(impact ~ "/impact/type");
	var location = geo.Coord.new().set_latlon(lat, long);
	var distance = geo.aircraft_position().direct_distance_to(location) / 1000;
	var ltext = "Bomb of type "~weapon~" hit " ~ name ~ " target";
	screen.log.write(ltext);
	setprop("/sim/armament/weapons/yield-ktn", yield);
	geo.put_model("Aircraft/victor/Models/Effects/Armament/missile.xml", lat, long);
	missileHit(distance, yield);
    } else {
        var ltext = "Impact on non solid surface, detonation aborted!";
        screen.log.write(ltext);
    }
}, 0, 1);

##
## ++++++++++++++++++++++++++++ STARTUP / SHUTDOWN ++++++++++++++++++++++++++++
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## ============================ Rain Effects ===================================
###  Rain effects on the canopy

# == make a rain timer ==
var rainTimer = maketimer(5, func { aircraft.rain.update(); });

##
## Initialise the mission
## -----------------------

var init_mission = func () {
    aircraft.livery.init("Aircraft/victor/Models/Liveries");

    # bombs
    bombsWeight.setValue(0);
    # shrikes
    shrikes12Weight.setValue(0);
    shrikes34Weight.setValue(0);

    config_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/config/dialog",
	    "Aircraft/victor/Dialogs/config.xml");

    doors_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/doors/dialog",
	    "Aircraft/victor/Dialogs/doors.xml");

    fuel_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/fuel/dialog",
		"Aircraft/victor/Dialogs/fuel.xml");

    altimeter_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/altimeter/dialog",
	    "Aircraft/victor/Dialogs/altimeter.xml");

    avionics_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/avionics/dialog",
	    "Aircraft/victor/Dialogs/avionics.xml");

    fd_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/flightdirector/dialog",
	    "Dialogs/flightdirector.xml");

    cabin_dialog = gui.Dialog.new("/sim/gui/dialogs/victor/cabin/dialog",
	    "Dialogs/cabin.xml");

    ap_dialog = gui.Dialog.new("/sim/gui/dialogs/autopilot/dialog",
	    "Aircraft/victor/Dialogs/autopilot-dlg.xml");


    # initiliase variables
    setprop("/controls/gear/brake-parking", 1);
    cockpit_door.open();

    # init weapons information
    initWpnInfo();
    # and variant capabilities
    declareCap();
    var name = selVariant.getValue();
    setVariantCap(name);
    # start with the mission weapons
    var mission = selMission.getValue();
    requestMission(mission);

    # Enable wildfire on crashes
    setprop("/environment/wildfire/enabled", TRUE);
    setprop("/environment/wildfire/fire-on-crash", TRUE);

    # ============================ Rain ===================================
    aircraft.rain.init();
    # == fire up rain updates ===
    rainTimer.start();

    # remove the FDM listener
    removelistener(missionInitListener);
}

var missionInitListener = setlistener("sim/signals/fdm-initialized", init_mission, 0, 0);

##
## SHUTDOWN
## --------

var missionShutdown = func () {
    rainTimer.stop();
};

################################# END #######################################
