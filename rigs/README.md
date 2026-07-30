# Rig files

Everything machine-specific about a microscope — DAQ channels, device ids,
sample rate, serial (COM) ports, which modules exist, calibration paths,
network endpoints, data folders — lives in one **rig file**: a MATLAB function
in this folder that returns a struct. Nothing rig-specific is hardcoded in the
scripts or classes; they all read the loaded rig.

## Using holodaq on a new microscope

1. **Copy the template**: `rigs/ExampleRig.m` → `rigs/<YourName>Rig.m`, rename
   the function, and fill in your wiring. Every field is documented in the
   template; `rigs/Scope2KRig.m` is a complete working example.
2. **Delete what you don't have.** A module your rig lacks (no SLM, no patch,
   no running wheel…) is simply omitted from `rig.modules` — experiment
   scripts and GUIs check `rig_has(rig, '<module>')` and skip it.
3. **Select the rig on each machine.** `load_rig()` resolves in this order,
   first match wins:
   1. the rig already loaded this session (cached);
   2. the `HOLODAQ_RIG` environment variable, set to your rig name;
   3. a `rig_config.m` on your MATLAB path returning your rig name — copy
      `rigs/rig_config.m.example` (gitignored, one per machine). **This is the
      recommended way**;
   4. *fallback:* if `rigs/` holds exactly one rig file besides `ExampleRig.m`,
      it is used **and `load_rig` warns** — nothing on the machine actually
      chose it, so the channel map may belong to a different microscope.
      Configure (3) rather than relying on this;
   5. otherwise an error listing the available rig files.

## How it works

- `load_rig()` resolves, **validates** (channel string formats, duplicate
  channel assignments, serial references), fills defaults, and caches the rig
  for the session. `default_setup` calls it first thing.
- `rig_has(rig, 'patch')` — does this rig have that module?
- `rig_get('network.holochat_server', fallback)` — dotted-path lookup into the
  cached rig from anywhere (class internals use this for their defaults; with
  no rig loaded the fallback keeps satellite machines and Simulate-mode GUIs
  working).
- `open_serial(rig.serial.<name>)` — build a `serialport` from a rig entry.
- `stim_data_root()` — the one place save paths resolve: the active profile's
  save root, else `rig.paths.data_root`, else the documented default (which
  warns, since nothing said where this machine's data belongs).

## Validation rules

- `rig.name` is required.
- `rig.daq.rate` (> 0) and `rig.daq.vendor` are required once any module
  declares a DAQ channel.
- Channel strings must look like `port<n>/line<n>`, `ai<n>`, `ao<n>`, or
  `ctr<n>` (same patterns `DAQInterface` uses to derive the channel type).
- The same physical channel cannot be assigned to two modules.
- `rig.modules.<m>.serial` must name an entry in `rig.serial`.
- A missing calibration file is a warning, not an error, so rig files can be
  edited off-rig.
