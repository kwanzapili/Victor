##################################################################
##		Handley Page Victor Engines Starter       	##
##################################################################

## Booleans
TRUE	= 1;
FALSE	= 0;
ON	= TRUE;
OFF	= FALSE;

## -------------------------------------------------------------------------------------------
## Starting the engine
##
## Unlike YASim, JSBSim simulates the startup of turbine engines.
##
## 1. Set the property /controls/engines/engine[~n~]/starter to true.
## 2. JSBsim will begin to crank the engine spinning it up to around 5% N1, and about 25% N2.
## 3. You can set the property /engines/engine[~n~]/cutoff to true at any point.
## 4. If the engine is above 15% N2, and the cutoff property is set to true, JSBsim will
##	introduce fuel to the engine, and the engine will spin up.
## 5. /engines/engine[~n~]/n1 will increase further until it stabilizes at the value which
##	is defined in idlen1 in the engine definition file.
##################################################################


## Start only works on one engine at a time selected with the JSBsim property
## "propulsion/active_engine". This covers both the main engines as well as the APU
## The property "/controls/engines/starter-selected" refers only to the main engines
## which can be selected manually
var currentEngine   = props.globals.getNode("/controls/engines/starter-selected");
## Engine Master switch
var master	    = props.globals.getNode("/controls/engines/master");
var starterEngaged  = props.globals.getNode("/controls/engines/starter-engaged");
var startReq	    = props.globals.getNode("/controls/engines/start-required");
var gear0Wow	    = props.globals.getNode("/gear/gear[0]/wow");
var EngineWaiting   = [ FALSE, FALSE, FALSE, FALSE ];
var EngineLabel	    = ["Engine one", "Engine two", "Engine three", "Engine four", "APU" ];
var apuSwitch	    = props.globals.getNode("/controls/APU/off-start-run");
var APUEng	    = 4;    # the index of the engine that models the APU
var APUState	    = { Off: 0, Start: 1, Run: 2 };
var gndPwrAvailable  = props.globals.getNode("/instrumentation/annunciator/ground-power");
var gndPwrSwitch    = props.globals.getNode("/controls/electric/external-power");
var allEngines	    = ['engine[0]', 'engine[1]', 'engine[2]', 'engine[3]'];

var init_engines = func {
    master.setBoolValue(OFF);
    currentEngine.setValue(0);
    starterEngaged.setBoolValue(FALSE);

    # initialise various engine properties
    # booleans under /controls
    var B1 = [ 'master', 'bleed' ];
    foreach(var b; B1) {
    	foreach(var eng; allEngines) {
	setprop("/controls/engines/"~eng~"/"~b, OFF);
	}
	setprop("/controls/engines/engine["~APUEng~"]/"~b, OFF);
    }
    # booleans under  /engines
    var B2 = [ 'cutoff', 'running' ];
    foreach(var b; B2) {
    	foreach(var eng; allEngines) {
	setprop("/engines/"~eng~"/"~b, OFF);
	}
    }
    # floats under /controls
    var D = [ 'thrust-lever' ];
    foreach(var d; D) {
    	foreach(var eng; allEngines) {
	setprop("/controls/engines/"~eng~"/"~d, 0.0);
	}
    }

    setprop("/controls/APU/run", OFF);
    setprop("/controls/engines/shutdown", FALSE);

    # create some listeners
    forindex (var index; allEngines) {
	# create some listeners
	engineMasterListener(index);
	engineElectricListener(index);
    }

    # remove the initialisation listener
    removelistener(starterInitListener);
}

# Request for Palouste compressor starter
var toggle_gndPower = func () {
    var avail = gndPwrAvailable.getValue();
    if ( avail ) {
	var connected = gndPwrSwitch.getValue();
	if ( connected ) {
	    gndPwrSwitch.setBoolValue(OFF);
	    setprop("/sim/messages/ground", "External power disconnected");
	} else {
	    gndPwrSwitch.setBoolValue(ON);
	    setprop("/sim/messages/ground", "External power connected");
	}
	victor.switchWithSound();
    }
    # otherwise nothing to do
}

# Report status change of ground power
setlistener("/instrumentation/annunciator/ground-power", func (n) {
    var avail     = n.getValue();
    var connected = gndPwrSwitch.getValue();
    if ( avail ) {
	if ( connected == FALSE )
	    setprop("/sim/messages/ground", "External power available");
    } else {
	if ( connected == TRUE)
	    setprop("/sim/messages/ground", "External power unavailable");
    }
}, 0, 0);

# Report status of master engine switch
var masterEngSwitch = func () {
    var enabled = master.getValue();
    if (enabled == OFF) {
        screen.log.write("Master engine switch is OFF");
    }
    return enabled;
};

## Check if there is enough power to start an engine
## An external starting unit is required for ground starts. There are no aircraft controls
## for this system. It is operated by the ground crew in instructions from the pilot.
## This function is a proxy check for an air-turbine starter cart.
var engStarterAvailable = func () {
    var powered = getprop("/systems/electrical/bus/main-ac-bus");
    var avail   = powered > 100;

    if (avail == FALSE) {
        screen.log.write("There is no power to start the engine");
    }

    return (avail);
}

## Check if there is enough power to start the APU
## This relies on the main AC bus having power and the master switch being ON
var apuStarterAvailable = func () {
    var powered = engStarterAvailable();
    var switch  = masterEngSwitch();
    var avail   = powered and (switch == ON);

    return (avail);
}

## Utility function to report on the status of the engines
var running_engines = func () {
    var active  = getprop("/fdm/jsbsim/systems/propulsion/active-engines");
    return (active);
}

# Count of the number of engines with master switches in the ON position
var numEngsStarted = func () {
    var count = 0;
    foreach (var eng; allEngines) {
        count = count + getprop("/controls/engines/"~eng~"/master");
    }
    return count;
}

## Grab the starter so that no one else can use it
## Return TRUE if successful or FALSE otherwise
var grabStarter = func (e) {
    # first chack that it is truly free
    var current_engine = getprop("/fdm/jsbsim/propulsion/active_engine");
    var current_status = starterEngaged.getValue();

    if ( current_status == TRUE ) {
	# check if this engine already has the starter
        if ( current_engine == e ) {
            return (TRUE);
        } else {
            return (FALSE);
        }
    }

    # we only need to set this engine as the active one; JSBsim will engage the starter
    setprop("/fdm/jsbsim/propulsion/active_engine", e);
    return (TRUE);
}

##
## Shutdown routine
## ----------------
var ShutdownClass = {
    initialised:	FALSE,
    # start signal
    start:	FALSE,
    # the engine we are working on
    eng:	-1,

    # timer that waits for the start signal once the engine is active
    loopTimer:	nil,

    # actual shutdown steps
    exec: func () {
		    # set throttle off
		    var time = getprop("/controls/engines/engine["~me.eng~"]/throttle");
		    interpolate("/controls/engines/engine["~me.eng~"]/throttle", 0, time);
		    setprop("/controls/engines/engine["~me.eng~"]/cutoff", TRUE);
		    setprop("/controls/engines/engine["~me.eng~"]/starter", OFF);
		    setprop("/controls/engines/engine["~me.eng~"]/ignition", OFF);
		    setprop("/controls/engines/shutdown", TRUE);
		    # reset the active engine
		    var t = maketimer(2.0, func {
					var prop = "/fdm/jsbsim/propulsion/active_engine";
					var current = getprop(prop);
					if (current == me.eng) setprop(prop, -1);
					setprop("/controls/engines/shutdown", FALSE);
				    });
		    t.singleShot = TRUE;
		    t.start();
		},

    # stop the routine
    stop: func () {
		    if (me.initialised == FALSE) return;

		    # stop loop
		    if ( me.loopTimer.isRunning ) me.loopTimer.stop();
		},

    # grab the starter then shutdown the engine
    loop: func () {
		  if (me.initialised == FALSE) return;

		  if (me.eng < 0 or me.eng > 4) me.stop();

		  # try to grab the starter
		  me.start = grabStarter(me.eng);

		  if (me.start == TRUE) {
			# if successful, stop the  loop and exec the actual engine shutdown
		      me.stop();
		      me.exec(me.eng);
		  } else {	# restart in 2 secs
		      me.loopTimer.restart(2);
		  }
	      },

    # create a new instance and initialise it (each engine must do this for itself)
    new: func (e) {
		     var p = { parents:[ShutdownClass] };
		     p.loopTimer = maketimer(0.5, p, p.loop);
		     p.initialised = TRUE;
		     p.eng = e;
		     return p;
		 },

    # run the shutown routine (after initialisation)
    run: func {
		 if (me.initialised == FALSE) return;

		    # do not run more than one instance
		 if ( me.loopTimer.isRunning )  return;

		 me.loopTimer.start();
	     }
};

##
## APU Tank
## --------
## The APU uses a special collector tank exclusively. This tank holds a small
## amount of fuel (~1 - 2 lbs), that is replenished automatically when the APU
## is running. In order to starve the APU when it is switched off, we need to
## set the valve of this tank to zero. When the APU is switched, we then
## release the valve. Setting the priority to zero is like closing a valve
## "at the tank".
var APUtank = {
    # index in the list of tanks
    index: 16,
    # default priority of the tank
    priority: 8,

    # close the value - set priority to zero
    close: func {
	       setprop("/fdm/jsbsim/propulsion/tank["~me.index~"]/priority", 0);
	    },

    # open the value - set the default priority
    open: func {
	      setprop("/fdm/jsbsim/propulsion/tank["~me.index~"]/priority", me.priority);
	  }
};

## manage the APU cuttoff command listener
var apuCutoffListener = nil;

var createAPUCutoffListener = func () {
    if (apuCutoffListener == nil) {
        apuCutoffListener =
            setlistener("/fdm/jsbsim/systems/propulsion/APU/cutoff-cmd", func (n) {
		    if ( n.getValue() ) {
			setprop("/fdm/jsbsim/propulsion/cutoff_cmd", OFF);
			setprop("/controls/engines/engine["~APUEng~"]/cutoff", FALSE);
		    }
		}, 0, 0);
    }
}

var deleteAPUCutoffListener = func () {
    if (apuCutoffListener != nil) {
        removelistener(apuCutoffListener);
        apuCutoffListener = nil;
    }
}

## Ignite the APU
var igniteAPU = func () {
    ## only start when we have the starter lock
    var lock = grabStarter(APUEng);

    if (lock == FALSE) return;

    var t = maketimer(1.0, func {
		interpolate("/controls/engines/engine["~APUEng~"]/throttle", 0.5, 4.0);
            });
    t.singleShot = TRUE;

    screen.log.write("Igniting APU engine");
    setprop("/controls/engines/engine["~APUEng~"]/starter", ON);
    setprop("/controls/engines/engine["~APUEng~"]/cutoff", TRUE);

    # stop the ignite timer
    igniteAPUTimer.stop();
    t.start();
}

var igniteAPUTimer = maketimer(1.0, igniteAPU);

## APU startup
var apuStartup = func () {
    var curState = apuSwitch.getValue();

    if (curState == APUState.Off) return;

    if (curState == APUState.Run) {
	screen.log.write("APU is already running!");
        return;
    }

    engineReset(APUEng);        # critical if restarting the engine

    # start the ignition process
    if ( ! igniteAPUTimer.isRunning ) igniteAPUTimer.start();
}

## Initiate APU shutdown
var apuShutdown = func () {
    var running = isEngRunning(APUEng);
    if ( running )  {
	screen.log.write("APU is shutting down");
    }
    var s = ShutdownClass.new(APUEng);
    s.run();
    setprop("/controls/pneumatic/APU-bleed", OFF);

    # we must switch off the electrical supply because the XML APU system will stop running
    setprop("/controls/electric/APU-generator", OFF);
    setprop("/controls/electric/engine["~APUEng~"]/bus-tie", OFF);
    setprop("/controls/electric/engine["~APUEng~"]/generator", OFF);
}

## Switch off external power once the APU is generating enough power
var disconnectGndPwr = func () {
    setprop("/controls/electric/external-power", OFF);
};

## Monitor APU status
var monitorAPU = func (state) {
    if (state == APUState.Run) {
        screen.log.write("APU is running");
        setprop("/controls/engines/engine["~APUEng~"]/starter", OFF);
        interpolate("/controls/engines/engine["~APUEng~"]/throttle", 1.0, 4.0);
        disconnectGndPwr();
    }
    elsif (state == APUState.Start) {
        createAPUCutoffListener();
        # open the valve in the collector tank
        APUtank.open();
    }
    else {
        screen.log.write("APU is switched OFF");
        deleteAPUCutoffListener();
        # close the value in the collector tank
        APUtank.close();
    }
}

## Listen to APU switch
setlistener("/controls/APU/off-start-run", func (n) {
    monitorAPU(n.getValue());
}, 0, 0);

## Listen to the APU trigger
setlistener("/controls/APU/trigger-switch", func (n) {
    var trigger = n.getValue();
    if (trigger < 0) apuShutdown();
    elsif (trigger > 0) apuStartup();
}, 0, 0);

## Toggle the APU on/off
var toggle_apu = func () {
    var curState = getprop("/controls/APU/run");
    var power    = apuStarterAvailable();

    if (curState == OFF and power == TRUE) {
        setprop("/controls/APU/run", ON);
    } else {
        setprop("/controls/APU/run", OFF);
    }
}


## Find the next engine waiting to start
var nextStarter = func {
    var found = FALSE;
    forindex (var i; EngineWaiting) {
        if ( EngineWaiting[i] == TRUE ) {
            selectEngine(i);
            found = TRUE;
            break;
        }
    }
    return found;
}

## Select a particular engine
var selectEngine = func (e) {
    if (e < 0 or e > 3) return;
    if ( starterEngaged.getValue() ) {
        screen.log.write("Engine starter is currently engaged");
        return;
    }
    else {
        currentEngine.setValue(e);
        screen.log.write(EngineLabel[e]~" is selected");
    }
}

## Trigger a reset button for an engine On and then Off
var engineReset = func (e) {
    var prop = "/controls/engines/engine["~e~"]/reset-cmd";
    setprop(prop, ON);
    # give the cutoff delay switch time to settle - see propulsion system file
    var t = maketimer(3.0, func {
		setprop(prop, OFF);
            });
    t.singleShot = TRUE;
    t.start();
}

var setMasterOff = func {
    master.setBoolValue(OFF);
    starterEngaged.setBoolValue(FALSE);
}

var setMasterOn = func {
    master.setBoolValue(ON);
}

# Toggle the main engine master switch.
var toggleMaster = func {
    if ( master.getValue() )
    {
        var engs = numEngsStarted();
        if (engs > 0) {
            screen.log.write("Switch off "~engs~" live engines first");
        } else  setMasterOff();
    }
    else
    {
        setMasterOn();
    }
}

## Check if an engine is already running
var isEngRunning = func (e) {
    var e_run   = getprop("/engines/engine["~e~"]/running");

    return (e_run);
}

## Check if an engine is on - stable
var isEngOn = func (e) {
    if (e < 0 or e > 4) return (FALSE);
    var n2  = getprop("/engines/engine["~e~"]/n2");
    var ign = getprop("/controls/engines/engine["~e~"]/ignition");
    var result = (ign == TRUE) or (n2 > 45.0);
    return result;
}

## Check if an engine is past the starting stage
var isEngStarting = func (e) {
    if (e < 0 or e > 4) return (FALSE);
    var n2      = getprop("/engines/engine["~e~"]/n2");
    var result  = (n2 > 15.0);
    return result;
}

## Switch to next engine in start sequence
var nextEngine = func () {
    var waiting = FALSE;
    if ( ! starterEngaged.getValue() ) {
        waiting = nextStarter();
    } else waiting = TRUE;

    return waiting;
}

## Start the current engine. Note that we don't use the controls.nas methods
## as there is an interconnect between the engine starter and the selector.
var pressStarter = func {
    # There must be an air starter available
    var powered = engStarterAvailable();
    if (powered == FALSE) {
        return;
    }

    var enabled = masterEngSwitch();
    if (enabled == OFF) {
        return;
    }

    var e = currentEngine.getValue();
    var lock = grabStarter(e);

    if ( lock == FALSE ) {
        screen.log.write("The starter is currently in use");
        return;
    }

    # an engine has four distinct phases: off -> starting => on => running
    var phase3  = isEngOn(e);
    var phase2  = isEngStarting(e);

    if ( phase3 ) {    # this implies phase 4 also
        EngineWaiting[e] = FALSE;
        screen.log.write(EngineLabel[e]~" is already started");
        return;
    } elsif ( phase2 ) {    # check if is waiting for the starter
        if ( EngineWaiting[e] == FALSE ) {
            screen.log.write(EngineLabel[e]~" is already starting");
            return;
        }
    }

    screen.log.write("Starting "~EngineLabel[e]);
    setprop("/controls/engines/engine["~e~"]/starter", ON);
    setprop("/controls/engines/engine["~e~"]/cutoff", TRUE);
    EngineWaiting[e] = FALSE;
}

## Listener for each engine's commands
var cutoffListeners = [ nil, nil, nil, nil];

var makeCutoffListener = func (e) {
    cutoffListeners[e] =
        setlistener("/fdm/jsbsim/systems/propulsion/"~allEngines[e]~"/cutoff-cmd", func (n) {
		if ( n.getValue() ) {
		   setprop("/fdm/jsbsim/propulsion/cutoff_cmd", OFF);
		   setprop("/controls/engines/"~allEngines[e]~"/cutoff", FALSE);
                }
	   }, 0, 0);
}

## create listeners when needed
var createCutoffListeners = func () {
    forindex(var index; allEngines) {
	# do not overwrite an existng listener
        if (cutoffListeners[index] != nil) continue;

	# Now create a new one
        makeCutoffListener(index);
    }
}

## delete listeners when not needed
var deleteCutoffListeners = func () {
    forindex(var index; cutoffListeners) {
        if (cutoffListeners[index] != nil ) {
            removelistener(cutoffListeners[index]);
            cutoffListeners[index] = nil;
        }
    }
}

## Acquire the starter
var acquireStarter = func () {
    var pending = startReq.getValue();
    if (pending == FALSE) {
        acquireStarterTimer.stop();
        return;
    }

    if ( starterEngaged.getValue() ) {
        acquireStarterTimer.restart(5); # give it 5 secs to complete
	return;
    }

    var e = currentEngine.getValue();
    # the starter is free
    # check if an engine is waiting for the starter, then stop the timer
    if ( EngineWaiting[e] ) {   # start current engine
        engineReset(e);
        pressStarter();
        acquireStarterTimer.restart(14);         # give it 10 secs to start up
	return;
    }

    # start another engine
    pending = nextEngine();
    if ( pending ) acquireStarterTimer.restart(0.5);   # retry immediately
    else        acquireStarterTimer.restart(5.0);      # wait for termination
}

var acquireStarterTimer = maketimer(1, acquireStarter);
acquireStarterTimer.simulatedTime = TRUE;

## Listen to the start signal and control the start procedure
setlistener("/controls/engines/start-required", func (n) {
    if ( n.getValue() ) {
	# first create the listeners
        createCutoffListeners();
        acquireStarterTimer.restart(1);
    } else {
        acquireStarterTimer.stop();
	## cleanup listeners
        deleteCutoffListeners();
    }
}, 0, 0);

## Update engine controls when an running status changes
var engineElectric = func (e, running) {
    if (running == TRUE) {
        setprop("/controls/engines/engine["~e~"]/starter", OFF);
        setprop("/controls/electric/engine["~e~"]/generator", ON);
        setprop("/controls/electric/engine["~e~"]/bus-tie", ON);
    }
    else {
        setprop("/controls/electric/engine["~e~"]/bus-tie", OFF);
        setprop("/controls/electric/engine["~e~"]/generator", OFF);
    }
}

## Engine ignition
var engineIgnite = func (e) {
    if ( isEngOn(e) ) {
        EngineWaiting[e] = FALSE;
        return;
    }

    EngineWaiting[e] = TRUE;
}

## Shutdown engine
var engineShutdown = func (e) {
    screen.log.write("Shutting down "~EngineLabel[e]);
    var s = ShutdownClass.new(e);
    s.run();
    EngineWaiting[e] = FALSE;
}

## Create listeners for all engines - these are permanent
var EngMasterListeners = [nil, nil, nil, nil];

var engineMasterListener = func (e) {
    EngMasterListeners[e] =
        setlistener("/controls/engines/"~allEngines[e]~"/master", func(n) {
		if ( n.getValue() ) {
		    engineIgnite(e)
		}
		else {
		    engineShutdown(e);
		}
	    }, 0, 0);
}


## Create listeners for electrical generation from each engine
var EngElectricListeners = [nil, nil, nil, nil];

var engineElectricListener = func (e) {
    EngElectricListeners[e] =
        setlistener("/engines/"~allEngines[e]~"/running", func (n) {
		    engineElectric(e, n.getValue());
	       }, 0, 0);
}

## Start the selected engine
var startEngine = func () {
    var powered = engStarterAvailable();
    if (powered == FALSE) {
        return;
    }

    var enabled = masterEngSwitch();
    if (enabled == FALSE) {
        return;
    }

    var e = currentEngine.getValue();
    if ( isEngOn(e) ) {
        screen.log.write(EngineLabel[e]~" is already ON");
        return;
    }

    setprop("/controls/engines/engine["~e~"]/master", ON);
    # to start the engine, we need to move the throttle from OFF to IDLE
    setprop("/controls/engines/engine["~e~"]/throttle", 0.005);
}

## Switch off the selected engine
var stopEngine = func () {
    var inUse = getprop("/instrumentation/fmc/flight-control-flight-mode");

    if ( inUse == TRUE ) {
        screen.log.write("Engines cannot be shutdown in flight!");
        return;
    }

    var e = currentEngine.getValue();
    if ( isEngOn(e) ) {
        setprop("/controls/engines/engine["~e~"]/master", OFF);
    } else {
        screen.log.write(EngineLabel[e]~" is already OFF");
    }
}

## Wait for the APU power to be available before starting the engines
var engStartWait = func () {
    var enabled = engStarterAvailable();

    if ( enabled ) {
        foreach (var eng; allEngines) {
            setprop("/controls/engines/"~eng~"/master", ON);
        }
	# stop the timer
        engStartWaitTimer.stop();
    }
}

var engStartWaitTimer = maketimer(6.0, engStartWait);

## External auto-start of all engines
var autoStart = func {
    var count = running_engines();
    if ( count > 3 ) {
        setprop("/sim/messages/ground", "All engines are already running");
        return;
    }

    # We need the external power to start the engines
    var powered = engStarterAvailable();
    if ( powered == FALSE ) {
        screen.log.write("You need to request for the Palouste starter");
        return;
    }

    setMasterOn();

    var apu_ready = apuSwitch.getValue();

    if (apu_ready == APUState.Off) {
	# We need the external power to start the APU
        apu_power = apuStarterAvailable();
        if ( apu_power == OFF ) {
            screen.log.write("You need to switch on the master switch");
            return;
        }

	# start the APU first
        setprop("/controls/APU/run", ON);
    }

    # now wait for the APU power to be available
    if ( ! engStartWaitTimer.isRunning )
        engStartWaitTimer.start();
}

## Shutdown of all engines - only done on the ground
var autoShutdown = func {
    var wow = gear0Wow.getValue();
    var gndspd = getprop("/velocities/groundspeed-kt");
    if (wow == FALSE or gndspd > 1) {
	screen.log.write("It is not safe to switch off the engines");
	return;
    }

    var brakes = getprop("/controls/gear/brake-parking");
    if ( brakes < 1 ) {
	screen.log.write("Parking brakes must be ON before engine shutdown");
	return;
    }

    var count = numEngsStarted();
    if ( count == 0 ) {
	setprop("/sim/messages/ground", "All engines are already off");
	return;
    }

    foreach(var eng; allEngines) {
	setprop("/controls/engines/"~eng~"/master", OFF);
    }
}


## **********
## FDM init
## **********

var starterInitListener = setlistener("/sim/signals/fdm-initialized", init_engines, 0, 0);

################################# END #######################################
