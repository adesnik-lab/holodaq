# holodaq

MATLAB data acquisition and stimulation framework for the Adesnik lab two-photon
rigs.

## First time on this machine

Everything machine-specific — DAQ channel map, COM ports, sample rate, data
drives — lives in a **rig file**, `rigs/<Name>Rig.m`. Nothing picks one for you,
so do this **before running anything against hardware**:

1. **Check your microscope has a rig file** in `rigs/`. If not, copy
   `rigs/ExampleRig.m` to `rigs/<YourName>Rig.m`, rename the function, and fill
   in your wiring — every field is documented in the template.
2. **Tell this machine which rig it is.** Copy `rigs/rig_config.m.example` to
   `rig_config.m` anywhere on your MATLAB path and return your rig name from it.
   That file is gitignored: one per machine, never committed. (Setting the
   `HOLODAQ_RIG` environment variable to your rig name works too, and wins over
   `rig_config.m`.)

If you skip step 2 and `rigs/` happens to hold exactly one rig file, `load_rig`
falls back to that file **and warns**. Take the warning seriously: a rig file for
someone else's microscope has the wrong channel map for your hardware, and on a
two-photon rig that means commanding the wrong physical line. Configure step 2
instead of relying on the fallback.

See [rigs/README.md](rigs/README.md) for the rig-file schema, the full resolution
order, validation rules, and how optional hardware is declared.

## Running things

- **`default_setup`** — loads the rig, builds the DAQ object, opens the serial
  devices the rig declares, and adds the rig's MATLAB paths. Experiment scripts
  call it first. It is a thin front end over **`rig_hardware()`**, which does the
  work and *returns* a struct instead of injecting `rig`/`dq`/`sp`/`arduino_obj`
  into the caller's workspace. Scripts keep calling `default_setup`; anything
  that cannot rely on workspace injection — a classdef method, e.g. holoexpt's
  `Experiment/setup` — calls `rig_hardware()` directly.
- **`ScopeController`** — launches *only* the laser/shutter/power GUI
  (`PowerControllerCalibrated`), optionally connected to the phone webapp. Run
  this **instead of** `ExperimentLauncher`; the two must not run at once because
  they share the DAQ and the ELL14 serial port.
- **Smoke test** — off-rig sanity check of the rig configuration system, no
  hardware needed:

  ```bash
  matlab -batch "addpath(genpath(pwd)); test_rig_smoke"
  ```
