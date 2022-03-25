#####################################################
# Nasal modules that listens to FailureMgr events.
#
# The main prupose of these modules is to set
# properties to "fail" so that the appropriate
# compenents will be disabled.
#####################################################

var TRUE    = 1;
var FALSE   = 0;
var ON	    = TRUE;
var OFF	    = FALSE;

##
## Electrical System
##

var RepairCount = 0;    ## allow up to 3 repairs then fail completely

## Restore system after the standby power has been activated after a short delay
var repair_electrical = func () {
    var acpower = getprop("/fdm/jsbsim/systems/electrical/ac-power");
    if ( acpower == TRUE and RepairCount < 4) {
	RepairCount = RepairCount + 1;
	var t = maketimer(RepairCount, func {
		setprop("sim/failure-manager/systems/electrical/failure-level", 0.0);
		});
	t.singleShot = TRUE;
	t.start();
    }
};

setlistener("sim/failure-manager/systems/electrical/failure-level", func (n) {
    var condition = 1 - n.getValue();
    setprop("/damage/systems/electrical-condition", condition);
}, 0, 0);

##
## Engines
##

var engine_condition = func (e,  level) {
    var condition = 1 - level;
    setprop("/damage/engines/engine["~e~"]/engine-condition", condition);
};

setlistener("sim/failure-manager/engines/engine[0]/failure-level", func (n) {
    var level = n.getValue();
    engine_condition(0, level);
}, 0, 0);

setlistener("sim/failure-manager/engines/engine[1]/failure-level", func (n) {
    var level = n.getValue();
    engine_condition(1, level);
}, 0, 0);

setlistener("sim/failure-manager/engines/engine[2]/failure-level", func (n) {
    var level = n.getValue();
    engine_condition(2, level);
}, 0, 0);

setlistener("sim/failure-manager/engines/engine[3]/failure-level", func (n) {
    var level = n.getValue();
    engine_condition(3, level);
}, 0, 0);

setlistener("sim/failure-manager/engines/engine[4]/failure-level", func (n) {
    var level = n.getValue();
    engine_condition(4, level);
}, 0, 0);


##
## Controls
##

var controls_condition = func (component,  level) {
    var condition = 1 - level;
    setprop("/damage/controls/flight/"~component~"-condition", condition);
};

setlistener("sim/failure-manager/controls/flight/aileron/failure-level", func (n) {
    var level = n.getValue();
    controls_condition("aileron", level);
}, 0, 0);

setlistener("sim/failure-manager/controls/flight/elevator/failure-level", func (n) {
    var level = n.getValue();
    controls_condition("elevator", level);
}, 0, 0);

setlistener("sim/failure-manager/controls/flight/flaps/failure-level", func (n) {
    var level = n.getValue();
    controls_condition("flaps", level);
}, 0, 0);

setlistener("sim/failure-manager/controls/flight/rudder/failure-level", func (n) {
    var level = n.getValue();
    controls_condition("rudder", level);
}, 0, 0);

setlistener("sim/failure-manager/controls/flight/speedbrake/failure-level", func (n) {
    var level = n.getValue();
    controls_condition("speedbrake", level);
}, 0, 0);

## The landing gear can be damaged outside the failure system
var gear_damaged = func () {
    var fail   = getprop("sim/failure-manager/controls/gear/failure-level");
    var damage = getprop("/fdm/jsbsim/gear/gear-damaged");
    var level  = math.max(fail, damage);
    var condition = 1 - level;
    setprop("/damage/controls/gear-condition", condition);
    if (level > fail)
	setprop("sim/failure-manager/controls/gear/failure-level", level);
};

setlistener("sim/failure-manager/controls/gear/failure-level", gear_damaged, 0, 0);

setlistener("/fdm/jsbsim/gear/gear-damaged", gear_damaged, 0, 0);

##
## Instrumentation
##

var instrument_condition = func (component,  level) {
    var condition = 1 - level;
    setprop("/damage/instrumentation/"~component~"-condition", condition);
};

setlistener("sim/failure-manager/instrumentation/airspeed-indicator/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("asi", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/altimeter/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("altimeter", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/attitude-indicator/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("ai", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/heading-indicator/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("hsi", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/nav[0]/cdi/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("nav1/cdi", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/nav[0]/gs/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("nav1/gs", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/nav[1]/cdi/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("nav2/cdi", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/nav[1]/gs/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("nav2/gs", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/slip-skid-ball/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("slip", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/turn-indicator/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("turn", level);
}, 0, 0);

setlistener("sim/failure-manager/instrumentation/vertical-speed-indicator/failure-level", func (n) {
    var level = n.getValue();
    instrument_condition("vsi", level);
}, 0, 0);


##
## Wings
##

setlistener("sim/failure-manager/fdm/jsbsim/structural/wings/failure-level", func (n) {
    var level = n.getValue();
    var condition = 1 - level;
    setprop("/damage/structural/wings-condition", condition);
}, 0, 0);


################################# END #######################################
