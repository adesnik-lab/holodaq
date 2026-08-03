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
- `rig_hardware()` — load the rig **and** open what it declares: returns
  `.rig`, `.dq`, `.serial.<name>` (open ports), plus back-compat `.sp` /
  `.arduino_obj` / `.power_calibration`. `default_setup` is the script-shaped
  front end over it; call `rig_hardware()` directly from anywhere that cannot
  take variables injected into its workspace, such as a classdef method.
- `stim_data_root()` — the one place save paths resolve: the active profile's
  save root, else `rig.paths.data_root`, else the documented default (which
  warns, since nothing said where this machine's data belongs).

**Opto channels and power control**

- `opto_channel(name, wavelength, fpc, slm, ...)` — build one entry of
  `rig.opto`. The only way to build one: MATLAB refuses to concatenate structs
  whose fields differ in name or order, so `[a, b]` in a rig file works only if
  every entry came from here.
- `opto_channels(rig)` — resolve and validate the whole table, in declaration
  order, with the derived names filled in (`hr<nm>`, `stim_<nm>`). Those are
  computed here and never stored, so a channel cannot be wired to one
  wavelength's hardware and another's data.
- `power_control_spec(cfg, ...)` — validate one `fpc_*` module's power path and
  fill its defaults. Reports a `gate_mode` of `'shutter'` or `'waveform'`.
- `power_control(dq, cfg, ...)` — the single place that turns that spec into
  objects. `Experiment.setup` calls it instead of constructing a power path
  itself, so the shape of the hardware lives in the rig file rather than in the
  runtime.
- `publish_rig_config()` — post the satellite-relevant parts of the loaded rig to
  holochat. Run it after every rig edit, or the other machines keep stale values.
- `rig_remote_get('<dotted.path>', fallback)` — the satellites' read side:
  published config, else a local rig, else the fallback. The machines that use it
  have no rig file of their own.

## How a power path is declared

An `fpc_*` module declares a `kind`, because a rig can set photostim power with
different hardware and — more importantly — keep the laser dark by different
mechanisms:

- **`kind = 'ell14'`** (the default, and what every rig file meant before the
  field existed): a half-wave plate on an Elliptec rotator sets the power, a
  digital shutter gates it. Needs `shutter`, `serial`, `ell14_channel`.
- **`kind = 'eom'`**: a modulator (EOM, Pockels cell, AOM) on an **analog** line
  both sets and gates, resting at `rest` volts whenever the laser must be dark.
  Needs `output`; `shutter` is optional.

The kind is explicit rather than inferred from which fields are present. A typo'd
field name would otherwise silently reclassify the channel, and the two kinds gate
the laser by completely different means — getting that wrong does not fail loudly,
it delivers light at the wrong time.

The two also fail in **opposite** directions with no calibration LUT, which is why
they warn differently: a waveform-gated channel stays at rest and delivers no
light (fails dark), while rotator-plus-shutter opens the shutter anyway with no
clamp (fails hot).

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
- `rig.opto`, if present, must be built with `opto_channel`, and every entry must
  name an `fpc` and an `slm` module that `rig.modules` actually declares. Channel
  names must be unique and legal MATLAB field names; no two channels may share a
  module, a half-wave-plate address, or an SLM board.
- Each channel's `fpc` module must declare a coherent power path for its `kind`
  (see above). This runs through the same `power_control_spec` the factory uses at
  build time, so what `load_rig` accepts and what `Experiment.setup` can actually
  construct cannot drift apart.

A rig with no `rig.opto` is fine — a vis-only scope has no lasers, and
`opto_channels` returns an empty table rather than erroring.

## What is NOT in here

`rig.serial` is not a list of the DAQ's COM ports. `rig_hardware` opens only
`ell14`, `wheel`, and any bus a declared module's `serial` field names. An entry
nothing references is inert — `rig.serial.sutter` on Scope2K describes a port on
the *holography* computer, which is why it can repeat a COM number used by a
different machine's bus without conflicting.
