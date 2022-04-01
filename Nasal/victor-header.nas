#########################################################################
#  Handley Page Victor: Flight Management System Global variables
#
#  Abstract:
#    This file contains global variables used by various nasal code.
#
#########################################################################

## Booleans
ON	= 1;
OFF	= 0;
TRUE	= ON;
FALSE	= OFF;

################################################################################
## NOTES:
## We use 12 modes of flight which are captured by the property
## "/instrumentation/fmc/flight-mode". These mean the following:
##      1 -> Power on
##      2 -> First engine ignition
##      3 -> Second engine powered
##      4 -> WOW and ground speed < V1
##      5 -> WOW and ground speed > V1
##      6 -> Liftoff
##      7 -> AGL = [400 - 1500] ft
##      8 -> AGL > 1500 ft - normal flight
##      9 -> Flare mode: AGL < 1000 and gear down
##      10 -> WOW (touchdown)
##      11 -> On runway and ground speed < 80 (rollout)
##      12 -> Engines off or 5 mins after TD
################################################################################

var FlightModes = { OFF:0, PWR:1, ENG:2, READY:3, TAXI:4, V1:5, LIFTOFF:6, CLB:7, NORMAL:8,
    FLARE:9, TDOWN:10, DEST:11, END:12 };

## Flight director modes
var MANAGED_MODE = -1;          # use FMC (passive mode)
var SELECTED_MODE = 0;          # user directed

## Passive modes: FG uses "/autopilot/locks/passive-mode" to change how keys are interpreted.
## If the value is 0, then only "/autopilot/settings/***" values can be changed.
## So we define our own modes to fit with this definition
var PassiveMode = { OFF: -1, AUTO: 0, ON: 1 };

################################################################################
## Flight director phases
## ----------------------
##
## 0 -> Off
## 1 -> Takeoff
## 2 -> Climb
##      Top-of-climb (transition to cruise/operations)
## 3 -> Mission
##      Top-of-descent (transition to descent)
## 4 -> Descent
## 5 -> Decelerate
## 6 -> Initial Approach
## 7 -> Localizer Approach
## 8 -> Final Approach
## 9 -> Land
## 10 -> Go Around (same as takeoff)
##
## These values are set in the property "/instrumentation/flightdirector/fd-phase"
##
var FlightPhase = { Off: 0, TO: 1, Climb: 2, Mission: 3, Descent: 4, Decel: 5,
    Appr: 6, Loc: 7, Final: 8, Land: 9, GA: 10 };

## Decelaration phase steps: acquire (-1), level (0), leave (1)
var DecelPhase = { Acquire: -1, Level: 0, Leave: 1 };

################################################################################

# Autoflight modes (s-selected, m-managed)
# -----------------------------------------
# lnav: 0=off, 1=LEVEL(m/s), 2=HDG(s), 3=NAV(m) 4=LOC(m), 5=TACAN(m), 6=RWY(m)
# vnav: 0=off, 1=ALT(s/m), 2=V/S(s), 3=FPA(s), 4=OP CLB(s), 5=OP DES(s),
#       6=ALTCRZ(m), 7=CLB(m) 8=DES(m), 9=G/S(m), 10=AGL(m - landing), 11=LEVEL
# spd:  0=off, 1=SPEED(s), 2=MACH(s), 3=THR CLB(m), 4=THR DES(m), 5=THR IDL(m), 6=CRZ(m)

var LNAV = { OFF:0, LEVEL:1, HDG:2, NAV:3, LOC:4, TACAN:5, RWY:6 };
var VNAV = { OFF:0, ALT:1, VS:2, FPA:3, OPCLB:4, OPDES:5, ALTCRZ:6, CLB:7, DES:8, GS:9,
    AGL:10, LEVEL:11 };
var SPD  = { OFF:0, SPEED:1, MACH:2, THRCLB:3, THRDES:4, THRIDL:5, CRZ:6, SPDPTCH:7 };

## Descriptions of the modes
var lnavStr = ["off", "LEVEL", "HDG", "NAV", "LOC", "TACAN", "RWY"];
var vnavStr = ["off", "ALT", "V/S", "FPA", "OP CLB", "OP DES", "ALTCRZ", "CLB", "DES", "G/S",
	"AGL", "LEVEL"];
var spdStr  = ["off", "SPEED", "MACH", "THR CLB", "THR DES", "THR IDL", "CRZ", "SPD PITCH"];

# Mapping between permissible VNAV and SPEED modes:
## Define a bit vector[P T], where "P" is the pitch bit, "T" is the throttle bit.
## Therefore, [0 0] implies neither mode is used by the item, whereas [1 1] means
## that both modes are used by the item. Thus, we have the following list of options:
var None            = 0;    # 0 0
var PitchOnly       = 1;    # 0 1
var ThrOnly         = 2;    # 1 0
var Both            = 3;    # 1 1
var SpdVec = [ [0, 0], [0, 1], [1, 0], [1, 1] ];

var ModeStr = [ "none", "pitch only", "throttle only", "both" ];

## Each speed mode is controlled by either pitch, throttle or both.
## So "off" is the only one that is not controlled.
var SpdBlocks= { "off": None, "SPEED": ThrOnly, "MACH": ThrOnly, "THR CLB": ThrOnly,
    "THR DES": ThrOnly, "THR IDL": ThrOnly, "CRZ": ThrOnly, "SPD PITCH": PitchOnly };

## For VNAV modes, we determine which controls they need and thus are blocked from being
## used by a speed mode at the same time. So, if a VNAV mode needs exclusive control of
## pitch, it will block the "P" bit.
var VnavBlocks = { "off": None, "ALT": None, "V/S": None, "FPA": PitchOnly, "OP CLB": None,
    "OP DES": None, "ALTCRZ": PitchOnly, "CLB": PitchOnly, "DES": PitchOnly,
    "G/S": PitchOnly, "AGL": PitchOnly, "LEVEL": PitchOnly };

## Default speed modes for each blocking type
var FallbackSpd = [ SPD.OFF, SPD.SPEED, SPD.SPDPTCH, SPD.OFF ];

## Climb, hold or descend mode
var ClimbDescend = { Des: -1, Hold: 0, Clb: 1 };

## TACAN mode switch settings
var TacanSwitch = { OFF: 0, REC: 1, TR: 2, AA: 3, BCN: 4 };

## Fuel level codes:
var FuelCodes = { OK: 0, WARN: 1, CRITICAL: 2 };

## Warning signal codes:
var Warning = { clear: 0, warn: 1, critical: 2 };

## -------------------------------------------------------------------------------
##                      Parameters
## -------------------------------------------------------------------------------

var MIN_VS_FPM	= -4800;
var MAX_VS_FPM	= 12000;
var MIN_VS_FPS	= MIN_VS_FPM / 60;
var MAX_VS_FPS	= MAX_VS_FPM / 60;
var CLIMB_FACTOR = 2.0;	# So, we get 2,000 fpm for 1,000 ft difference in altitude
var MIN_PITCH	= -10.0;
var MAX_PITCH	= 20.0;
## In level flight, the pitch is about 0°

## HANDLEY-PAGE VICTOR B.2:
#MaxTOWeight	= 216000;	# Max takeoff weight: 97,980 kilograms, 216,000 pounds
#TypicalWeight	= 150000;	# Typical Weight with weapons
#EmptyWeight	= 91000;	# Empty weight: 41,275 kilograms, 91,000 pounds

## Minimum and maximum landing speeds
#MinLandSpeed	= 145;
#MaxLandSpeed	= 160;
## Tail Chute release speed threshold: 145 kts
#ChuteRelSpd	= 145;

## Difference in target and current altitude when we switch from VS to Alt-Hold.
## At this point, the Alt-Hold and VS climb rates need to match.
## Thus for a difference "d", we need CLIMB_FACTOR * d = 1000 (used in Alt-Hold)
var SwitchToAltHoldFt = 500;  # in ft

## Distance and Altitude thresholds for arming LOC and APPR
## These are part of the JSBsim FCS file now instead of nasal scripts
#LOCThesholdDist = 35000;
#APPRThesholdDist = 30000;
#LOCThesholdAgl	 = 8000;
#APPRThesholdAgl = 4000;

## The default property used for altitude checks:
## True altitude is position/altitude-ft
## Indicated altitude is instrumentation/altimeter/indicated-altitude-ft (pressure altitude)
var AltitudeFtProp = "/position/altitude-ft";
#var AltitudeFtProp = "/instrumentation/altimeter[0]/indicated-altitude-ft";

#############################
## Waypoint Parameters
#############################

## Factors for multiplying the turn radius in order to get the turn distance

## A standard rate turn is defined as a 3° per second turn, which completes a 360° turn
## in 2 minutes. This is known as a 2-minute turn, or rate one (180°/min). Fast airplanes,
## or aircraft on certain precision approaches, use a half standard rate.
var WpAircraftSpecificTurnFactor = 0.5;
# passed distance (kts) per second per kt (The Handley Page Victor needs 2 second to get into 20° roll)
var WpAircraftSpecificTurnInertiaFactor = 2.0 / 3600.0;

##
## Bank angle limits
## -----------------
## The bank angle limits varies by mode:
## 	* Manual and Heading-hold modes:		45°
## 	* Auto-Nav mode or with pitch autopilot:	40°
##	* Tacan and ILS modes:				36°
##	* ILS Approach mode:				15°
BankLimits = { Heading: 45, Nav: 40, Tacan: 36, Approach: 15 };


#########################################
## Variables for the autopilot
#########################################

# Heading-hold bank angle limit is 45° but this is reduced to 40° if the pitch autopilot
# is also in use. Therefore, we limit the bank angle to 45°.
# Auto-Nav commands a maximum bank angle of 40°.
var headingMaxRoll	= BankLimits.Heading;
var kpForAglClimbRate	= CLIMB_FACTOR / 60;	# needs to be in fps
var kpForAltClimbRate	= CLIMB_FACTOR / 60;	# needs to be in fps
var kpForAltHold	= 0.15;
# For Altitude-hold with throttle, the inputs are scaled down by 0.01 for this parameter
var kpForAltThrottle	= 0.375;
var kpForAoAHold	= -0.05;
var kpForGSHold		= 0.15;
# For GS-hold with throttle, the inputs are scaled down by 0.01 for this parameter
var kpForGSHoldThr	= 0.35;
var kpForHeadingDeg	= -1 * headingMaxRoll / 20;
# For 20° deflection we get a 45° max roll
var kpForHeadingHold	= 1 / 20;	# 20° difference yeilds full lock
var kpForMachPitchDeg	= -3.333;
# Mach 0.003 ~ 2 kts yields a 1 degree change in pitch - the inputs/references are scaled by 100x
var kpForMachThrottle	= 3.50;		# avoid saturating the servo - keep this low
var kpForPitchHold	= -0.10;
var kpForRollDeg	= -0.004;
var kpForSpeedPitchDeg	= -0.5;		# assume 2kts difference yields a 1 degree change in pitch
var kpForSpeedThrottle	= 0.075;	# avoid saturating the servo - align with noise filter
var kpForVsHold		= 0.15;
# For VSpeed-hold with throttle, the inputs are scaled down by 0.001 for this parameter
var kpForVsHoldThr	= 0.050;
var tdForHeadingHold	= 0.0001;
var tiForHeadingHold	= 10.0;

##
## Global property nodes
## ----------------------

#
## Flightdirector
var fdAltSelect	= props.globals.getNode("/instrumentation/flightdirector/altitude-select");
var fdAltAcq	= props.globals.getNode("/instrumentation/flightdirector/alt-acquire-mode");
var fdApprArm	= props.globals.getNode("/instrumentation/flightdirector/appr-arm");
var fdApprEnable = props.globals.getNode("/instrumentation/flightdirector/appr-enable");
var fdApprOn	= props.globals.getNode("/instrumentation/flightdirector/appr-on");
var fdAPEngage	= props.globals.getNode("/instrumentation/flightdirector/autopilot-engage");
var fdATEngage	= props.globals.getNode("/instrumentation/flightdirector/autothrottle-engage");
var fdFDOn	= props.globals.getNode("/instrumentation/flightdirector/fd-on");
var fdHdgSelect	= props.globals.getNode("/instrumentation/heading-indicator/heading-bug-deg");
var fdInAppr    = props.globals.getNode("/instrumentation/flightdirector/in-approach");
var fdLatMode	= props.globals.getNode("/instrumentation/flightdirector/lateral-mode");
var fdLNAV	= props.globals.getNode("/instrumentation/flightdirector/lnav");
var fdLocArm	= props.globals.getNode("/instrumentation/flightdirector/loc-arm");
var fdLocEnable	= props.globals.getNode("/instrumentation/flightdirector/loc-enable");
var fdLocOn	= props.globals.getNode("/instrumentation/flightdirector/loc-on");
var fdMachMode	= props.globals.getNode("/instrumentation/flightdirector/mach-mode");
var fdMachSelect = props.globals.getNode("/instrumentation/flightdirector/mach-select");
var fdPanelLat  = props.globals.getNode("/instrumentation/flightdirector/panel-lat-mode");
var fdPanelVert = props.globals.getNode("/instrumentation/flightdirector/panel-vert-mode");
var fdPastToC   = props.globals.getNode("/instrumentation/flightdirector/past-tc");
var fdPastToD   = props.globals.getNode("/instrumentation/flightdirector/past-td");
var fdPhase     = props.globals.getNode("/instrumentation/flightdirector/fd-phase");
var fdPitchDeg	= props.globals.getNode("/instrumentation/flightdirector/pitch-deg");
var fdSPD	= props.globals.getNode("/instrumentation/flightdirector/spd");
var fdSpdMode	= props.globals.getNode("/instrumentation/flightdirector/speed-mode");
var fdSpdSelect	= props.globals.getNode("/instrumentation/flightdirector/speed-select");
var fdAltMode	= props.globals.getNode("/instrumentation/flightdirector/vertical-alt-mode");
var fdVertMode	= props.globals.getNode("/instrumentation/flightdirector/vertical-managed-mode");
var fdVsSpdSelect = props.globals.getNode("/instrumentation/flightdirector/vertical-speed-select");
var fdVsMode	= props.globals.getNode("/instrumentation/flightdirector/vertical-vs-mode");
var fdVNAV	= props.globals.getNode("/instrumentation/flightdirector/vnav");
var fdSpdMismatch = props.globals.getNode("/instrumentation/flightdirector/vnav-spd-mismatch");

## Autopilot control panel switches
var ctrlSwAP	= props.globals.getNode("/controls/switches/autopilot");
var ctrlSwAT	= props.globals.getNode("/controls/switches/autothrottle");
var ctrlSwAlt	= props.globals.getNode("/controls/switches/altitude-mode");
var ctrlSwHdg	= props.globals.getNode("/controls/switches/heading-mode");
var ctrlSwNav	= props.globals.getNode("/controls/switches/nav-mode");

## FMC
var fmcBankAngle    = props.globals.getNode("/instrumentation/fmc/bank-angle/limit-max");
var fmcChangeoverAlt = props.globals.getNode("/instrumentation/fmc/changeover-alt");
var fmcChangeMode   = props.globals.getNode("/instrumentation/fmc/changeover-mode");
var fmcClimbAlt	    = props.globals.getNode("/instrumentation/fmc/climb-alt-ft");
var fmcClimbMach    = props.globals.getNode("/instrumentation/fmc/climb-mach");
var fmcClimbSpeed   = props.globals.getNode("/instrumentation/fmc/climb-speed");
var fmcCruiseAlt    = props.globals.getNode("/instrumentation/fmc/cruise-alt-ft");
var fmcCruiseMach   = props.globals.getNode("/instrumentation/fmc/cruise-mach");
var fmcCruiseSpeed  = props.globals.getNode("/instrumentation/fmc/cruise-speed");
var fmcDecelAlt     = props.globals.getNode("/instrumentation/fmc/deceleration-alt");
var fmcDepAltFt	    = props.globals.getNode("/instrumentation/fmc/dep-alt-ft");
var fmcDesMach      = props.globals.getNode("/instrumentation/fmc/descend-mach");
var fmcDesSpeed     = props.globals.getNode("/instrumentation/fmc/descend-speed");
var fmcCtrlFlare = props.globals.getNode("/instrumentation/fmc/flight-control-flare-mode");
var fmcCtrlFlight = props.globals.getNode("/instrumentation/fmc/flight-control-flight-mode");
var fmcCtrlGnd	= props.globals.getNode("/instrumentation/fmc/flight-control-ground-mode");
var fmcRetard	= props.globals.getNode("/instrumentation/fmc/flight-control-retard-mode");
var fmcRollout	= props.globals.getNode("/instrumentation/fmc/flight-control-rollout-mode");
var fmcFlightMode = props.globals.getNode("/instrumentation/fmc/flight-mode");
var fmcMaxVSfps	= props.globals.getNode("/instrumentation/fmc/limit-vs-fps-max");
var fmcMinVSfps	= props.globals.getNode("/instrumentation/fmc/limit-vs-fps-min");
var fmcNextHdg	= props.globals.getNode("/instrumentation/fmc/next-heading-diff-deg");
var fmcTurnDist = props.globals.getNode("/instrumentation/fmc/turn-distance-nm");
var fmcV1	= props.globals.getNode("/instrumentation/fmc/vspeeds/V1");
var fmcV2	= props.globals.getNode("/instrumentation/fmc/vspeeds/V2");
var fmcVR	= props.globals.getNode("/instrumentation/fmc/vspeeds/VR");
var ChuteRelSpd = props.globals.getNode("/instrumentation/fmc/vspeeds/V-dragchute-kt");
var fmcWPInTurn	= props.globals.getNode("/instrumentation/fmc/wp-turn-on");
var rocLock	= props.globals.getNode("/instrumentation/fmc/roc-lock");

## Autopilot Locks
var apLocksHdg	= props.globals.getNode("/autopilot/locks/heading");
var apLocksAlt	= props.globals.getNode("/autopilot/locks/altitude");
var apLocksSpd	= props.globals.getNode("/autopilot/locks/speed");
var apLocksPassive = props.globals.getNode("/autopilot/locks/passive-mode");

## Autopilot Settings
var apSettingAlt = props.globals.getNode("/autopilot/settings/target-altitude-ft");
var apSettingAgl = props.globals.getNode("/autopilot/settings/target-agl-ft");
var apSettingVS	 = props.globals.getNode("/autopilot/settings/vertical-speed-fpm");
var apSettingKt	 = props.globals.getNode("/autopilot/settings/target-speed-kt");
var apSettingMach = props.globals.getNode("/autopilot/settings/target-speed-mach");

## Routemanager
var apRMActive	= props.globals.getNode("/autopilot/route-manager/active");
var apRMAirborne = props.globals.getNode("/autopilot/route-manager/airborne");
var apRMCurWP	= props.globals.getNode("/autopilot/route-manager/current-wp");
var apRMDist	= props.globals.getNode("/autopilot/route-manager/distance-remaining-nm");
var apRMWpSecs	= props.globals.getNode("/autopilot/route-manager/wp/eta-seconds");
var apRMWpId	= props.globals.getNode("/autopilot/route-manager/wp/id");
var apRMWpDist	= props.globals.getNode("/autopilot/route-manager/wp/dist");

## GPS
var gpsWp1Valid	= props.globals.getNode("/instrumentation/gps/wp/wp[1]/valid");
var gpsWp1Sec	= props.globals.getNode("/instrumentation/gps/wp/wp[1]/TTW-sec");
var gpsWp1TTW	= props.globals.getNode("/instrumentation/gps/wp/wp[1]/TTW");
var gpsWp1DistNm = props.globals.getNode("/instrumentation/gps/wp/wp[1]/distance-nm");

## TACAN
var tacanDistNm	= props.globals.getNode("/instrumentation/tacan/indicated-distance-nm");
var tacanTimeMin = props.globals.getNode("/instrumentation/tacan/indicated-time-min");
var tacanInRange = props.globals.getNode("/instrumentation/tacan/in-range");
var tacanSwPos	= props.globals.getNode("/instrumentation/tacan/switch-position");

## Autopilot Internal
var apDesOrClb      = props.globals.getNode("/autopilot/internal/elevation/des-hold-clb");
var apAltHoldFt     = props.globals.getNode("/autopilot/internal/switch-to-alt-hold-ft");
var apAltHoldNear   = props.globals.getNode("/autopilot/internal/switch-to-alt-hold-near");
var apClimbRateFps  = props.globals.getNode("/autopilot/internal/target-climb-rate-fps");
var apGSintercept   = props.globals.getNode("/autopilot/internal/gs-intercepted-good");
var apGSweak	    = props.globals.getNode("/autopilot/internal/gs-intercepted-weak");
var apLOCintercept  = props.globals.getNode("/autopilot/internal/vorloc-intercepted-good");
var apLOCweak	    = props.globals.getNode("/autopilot/internal/vorloc-intercepted-weak");
var apWPMonitor     = props.globals.getNode("/autopilot/internal/waypoint-monitor-on");
var apWpNearby      = props.globals.getNode("/autopilot/internal/waypoint-nearby");
var apWpSwitchOn    = props.globals.getNode("/autopilot/internal/waypoint-switch-on");
var apWpValid       = props.globals.getNode("/autopilot/internal/waypoint-valid");
var trueHdgOffset   = props.globals.getNode("/autopilot/internal/true-heading-error-deg");
var spdPitchMode    = props.globals.getNode("/autopilot/internal/speed-pitch-mode");
var variableRoCLock = props.globals.getNode("/autopilot/internal/variable-vs-roc-lock");

# Actual autopilot switch
var ctrlSwitchAP =  props.globals.getNode("/controls/switches/autopilot");

## Other
var altFtNode	= props.globals.getNode(AltitudeFtProp);
var posAltFt	= props.globals.getNode("/position/altitude-ft");
var posAglFt	= props.globals.getNode("/position/altitude-agl-ft");

var HeadingDeg	= props.globals.getNode("/orientation/heading-deg");

var velAirSpdKts = props.globals.getNode("/velocities/airspeed-kt");
var velGndSpdKt	 = props.globals.getNode("/velocities/groundspeed-kt");
var velMach	 = props.globals.getNode("/velocities/mach");
var velVertSpdFps = props.globals.getNode("/velocities/vertical-speed-fps");
var machLimit	 = props.globals.getNode("/limits/mmo");

var grossWeight	= props.globals.getNode("/fdm/jsbsim/inertia/weight-lbs");
var crewWeight	= props.globals.getNode("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]");
var equipWeight = props.globals.getNode("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]");
# intermediate property that holds the target bombs weight when loading/unloading
# to be finally transferred eventually to "/fdm/jsbsim/inertia/pointmass-weight-lbs[2]"
var bombsWeight	= props.globals.getNode("/controls/armament/bombs-weight-lbs");
var shrikes12Weight = props.globals.getNode("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]");
var shrikes34Weight = props.globals.getNode("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]");

## Engines
var allEngines   = ['engine[0]', 'engine[1]', 'engine[2]', 'engine[3]'];
var ctrlThottle0 = props.globals.getNode("/controls/engines/engine[0]/throttle");

## Armament
var masterArm	= props.globals.getNode("/controls/armament/master-arm");
var selStation	= props.globals.getNode("/controls/armament/station-select");
var safeRelease	= props.globals.getNode("/controls/armament/safe-to-release");
var releaseAgl	= props.globals.getNode("/controls/armament/release-agl-ft");
var mainWeapon	= props.globals.getNode("/controls/armament/main-weapon");
var enableShrike = props.globals.getNode("/controls/armament/shrikes");

## Variant properties
var selVariant		= props.globals.getNode("/sim/variant/name");
var variantBomber	= props.globals.getNode("/sim/variant/bomber");
var variantNBomber	= props.globals.getNode("/sim/variant/nbomber");
var variantShrikes	= props.globals.getNode("/sim/variant/shrikes");
var variantNMissiles	= props.globals.getNode("/sim/variant/nmissile");
var variantTanker	= props.globals.getNode("/sim/variant/tanker");
var selMission		= props.globals.getNode("/sim/armament/mission");

# Simulation
var simTime	= props.globals.getNode("/sim/time/elapsed-sec");

## global container of Atmosphere calculator
var atmos = nil;

##
## Initialise the properties
## --------------------------

## Initialise the properties

var init_params = func() {

    setprop("/autopilot/internal/climb-factor", CLIMB_FACTOR);
    setprop("/autopilot/internal/gs-rate-of-climb-filtered", 0.0);
    setprop("/autopilot/internal/kp-for-agl-climb-rate", kpForAglClimbRate);
    setprop("/autopilot/internal/kp-for-alt-climb-rate", kpForAltClimbRate);
    setprop("/autopilot/internal/kp-for-alt-hold-base", kpForAltHold);
    setprop("/autopilot/internal/kp-for-alt-throttle", kpForAltThrottle);
    setprop("/autopilot/internal/kp-for-aoa-hold", kpForAoAHold);
    setprop("/autopilot/internal/kp-for-gs-hold", kpForGSHold);
    setprop("/autopilot/internal/kp-for-gs-hold-thr", kpForGSHoldThr);
    setprop("/autopilot/internal/kp-for-heading-deg", kpForHeadingDeg);
    setprop("/autopilot/internal/kp-for-heading-hold", kpForHeadingHold);
    setprop("/autopilot/internal/kp-for-mach-pitch-deg", kpForMachPitchDeg);
    setprop("/autopilot/internal/kp-for-mach-throttle", kpForMachThrottle);
    setprop("/autopilot/internal/kp-for-pitch-hold", kpForPitchHold);
    setprop("/autopilot/internal/kp-for-roll-deg", kpForRollDeg);
    setprop("/autopilot/internal/kp-for-speed-pitch-deg", kpForSpeedPitchDeg);
    setprop("/autopilot/internal/kp-for-speed-throttle", kpForSpeedThrottle);
    setprop("/autopilot/internal/kp-for-vs-hold-base", kpForVsHold);
    setprop("/autopilot/internal/kp-for-vs-hold-thr", kpForVsHoldThr);
    setprop("/autopilot/internal/switch-to-alt-hold", FALSE);
    setprop("/autopilot/internal/switch-to-alt-hold-ft", SwitchToAltHoldFt);
    setprop("/autopilot/internal/switch-to-alt-hold-near", FALSE);
    setprop("/autopilot/internal/target-climb-rate-fps", 0.0);
    setprop("/autopilot/internal/td-for-heading-hold", tdForHeadingHold);
    setprop("/autopilot/internal/ti-for-heading-hold", tiForHeadingHold);
    setprop("/autopilot/internal/speed-with-pitch-max", MAX_PITCH);
    setprop("/autopilot/internal/speed-with-pitch-min", MIN_PITCH);
    setprop("/autopilot/internal/variable-vs-enabled", FALSE);
    setprop("/autopilot/internal/variable-vs-mode", OFF);
    setprop("/autopilot/internal/variable-vs-roc-lock", FALSE);
    setprop("/autopilot/internal/waypoint-switch-on", FALSE);

    # A/P settings
    apSettingAlt.setIntValue(15000);
    apSettingAgl.setIntValue(2000);
    apSettingKt.setIntValue(250);
    apSettingMach.setValue(0.75);
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");

    fdAltSelect.setIntValue(15000);
    fdAltAcq.setBoolValue(OFF);
    fdApprArm.setBoolValue(OFF);
    fdAPEngage.setBoolValue(FALSE);
    fdATEngage.setBoolValue(FALSE);
    fdFDOn.setBoolValue(FALSE);
    fdHdgSelect.setDoubleValue(0);
    fdLatMode.setIntValue(SELECTED_MODE);
    fdLNAV.setIntValue(LNAV.OFF);
    fdLocArm.setBoolValue(OFF);
    fdMachMode.setBoolValue(FALSE);
    fdMachSelect.setDoubleValue(0.75);
    fdSPD.setIntValue(SPD.OFF);
    fdSpdMode.setIntValue(SELECTED_MODE);
    fdSpdSelect.setIntValue(250);
    fdAltMode.setIntValue(SELECTED_MODE);
    fdVertMode.setIntValue(SELECTED_MODE);
    fdVsSpdSelect.setIntValue(2000);
    fdVsMode.setIntValue(SELECTED_MODE);
    fdVNAV.setIntValue(VNAV.OFF);
    fdPitchDeg.setDoubleValue(6.0);
    setprop("/instrumentation/flightdirector/acquire-cruise", OFF);
    setprop("/instrumentation/flightdirector/vnav-spd-mismatch", FALSE);

    var altFt = posAltFt.getValue();
    setprop("/instrumentation/fmc/dep-alt-ft", altFt);      # departure airport altitude in feet
    var altM = FT2M * altFt;
    setprop("/instrumentation/fmc/dep-alt-m", altM);      # departure airport altitude in metres
    altFt += 8000;	# add 8,000 to the current position
    setprop("/instrumentation/fmc/climb-alt-ft", altFt);
    fmcCtrlFlare.setBoolValue(FALSE);
    fmcCtrlFlight.setBoolValue(FALSE);
    fmcCtrlGnd.setBoolValue(TRUE);
    fmcFlightMode.setIntValue(FlightModes.OFF);
    fmcNextHdg.setValue(0);
    fmcRetard.setBoolValue(FALSE);
    fmcTurnDist.setValue(0);
    setprop("/instrumentation/fmc/changeover-alt", 29314);  ## assuming CAS of 300 kts and Mach 0.78
    setprop("/instrumentation/fmc/changeover-mode", OFF);   ## OFF/ON ~ below/above cross-over altitude
    setprop("/instrumentation/fmc/climb-mach", 0.70);
    setprop("/instrumentation/fmc/climb-speed", 300);
    setprop("/instrumentation/fmc/cruise-alt-ft", 30000);
    setprop("/instrumentation/fmc/cruise-mach", 0.85);
    setprop("/instrumentation/fmc/cruise-speed", 350);
    setprop("/instrumentation/fmc/deceleration-alt",6000);
    setprop("/instrumentation/fmc/descend-mach", 0.70);
    setprop("/instrumentation/fmc/descend-speed", 300);
    setprop("/instrumentation/fmc/transition-ft", 10000);
    setprop("/instrumentation/fmc/vspeeds/V1", 135);
    setprop("/instrumentation/fmc/vspeeds/V2", 150);
    setprop("/instrumentation/fmc/vspeeds/Vapp", 180);
    setprop("/instrumentation/fmc/vspeeds/VR", 140);
    setprop("/instrumentation/fmc/vspeeds/Vref", 138);

    # bank angles
    setprop("/instrumentation/fmc/bank-angle/heading", BankLimits.Heading);
    setprop("/instrumentation/fmc/bank-angle/nav", BankLimits.Nav);
    setprop("/instrumentation/fmc/bank-angle/tacan", BankLimits.Tacan);
    setprop("/instrumentation/fmc/bank-angle/approach", BankLimits.Approach);
    setprop("/instrumentation/fmc/bank-angle/limit-max", BankLimits.Heading);
    setprop("/instrumentation/fmc/bank-angle/limit-min", BankLimits.Heading * -1);

    setprop("/limits/max-vs-fps", MAX_VS_FPS);
    setprop("/limits/min-vs-fps", MIN_VS_FPS);

    # align the heading indicator to the magnetic compass
    # periodically re-adjust the Directional Gyro to the Wet Compass
    var magvar = 0 - getprop("/environment/magnetic-variation-deg");
    setprop("/instrumentation/heading-indicator-dg/align-deg", magvar);

    ## clouds
    setprop("/environment/turbulence/use-cloud-turbulence", "true");

    # remove the listener
    removelistener(mainListener);
    logprint(LOG_INFO, "Parameter initialisation complete");
}

var mainListener = setlistener("/sim/signals/fdm-initialized", init_params, 0, 0);

################################# END #######################################
