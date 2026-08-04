#!/usr/bin/env python3
"""Build the Millennium Phoenix setup + operation guide as a PDF.

    python3 docs/make_phoenix_guide.py [--out PATH]

Run it from anywhere; it locates the repos from its own position on disk, not from
the working directory. Default output is beside this script.

The provenance line on page 1 reports each repo's current commit, read with
`git rev-parse` AT BUILD TIME. Those four hashes used to be hardcoded and were
hand-edited twice in one day before drifting anyway -- a guide that misreports which
code it describes is worse than one with no hashes at all, because the reader has no
way to tell.

Sibling repos are expected beside holodaq, the same layout holo_paths and
holodaq_root require:

    code/
      holodaq/          <- this repo
      holoexpt/
      holography2k/
      modules/

A repo that is missing, or not a git checkout, is reported as "not found" in the
provenance line rather than aborting the build -- the guide is still useful on a
machine that only has some of them.

Needs reportlab:  python3 -m pip install reportlab
"""

import argparse
import subprocess
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate, Frame, KeepTogether, PageBreak, PageTemplate, Paragraph,
    Spacer, Table, TableStyle,
)

HERE = Path(__file__).resolve().parent          # <repo>/docs
REPO = HERE.parent                              # <repo>            = holodaq
CODE = REPO.parent                              # holds the sibling checkouts

_ap = argparse.ArgumentParser(description=__doc__)
_ap.add_argument("--out", default=str(HERE / "Millennium-Phoenix-Setup-Guide.pdf"),
                 help="where to write the PDF (default: beside this script)")
OUT = _ap.parse_args().out

REPOS = ["holodaq", "holoexpt", "holography2k", "modules"]


def head(repo_name):
    """Short HEAD of a sibling checkout, or None if it is not a git repo."""
    path = REPO if repo_name == REPO.name else CODE / repo_name
    try:
        out = subprocess.run(["git", "-C", str(path), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout.strip() or None


def provenance():
    """The page-1 sentence naming the commit each repo is on right now."""
    parts, missing = [], []
    for name in REPOS:
        h = head(name)
        if h:
            parts.append(f"{name} <font name='Courier'>{h}</font>")
        else:
            missing.append(name)
    text = "Written against " + ", ".join(parts) if parts else "No git checkouts found"
    if missing:
        text += f". Not found: {', '.join(missing)}"
    return (text + ". If your checkout is older than these, pull before following "
            "anything below.")

INK      = colors.HexColor("#1a1a1a")
MUTED    = colors.HexColor("#5b6470")
RULE     = colors.HexColor("#c9d1d9")
ACCENT   = colors.HexColor("#0b5394")
WARN_BG  = colors.HexColor("#fff4e5")
WARN_ED  = colors.HexColor("#d98324")
STOP_BG  = colors.HexColor("#fdecea")
STOP_ED  = colors.HexColor("#c0392b")
CODE_BG  = colors.HexColor("#f4f6f8")
HEAD_BG  = colors.HexColor("#eef2f6")

ss = getSampleStyleSheet()

def S(name, **kw):
    base = dict(fontName="Helvetica", fontSize=9.5, leading=13.2, textColor=INK,
                alignment=TA_LEFT, spaceBefore=0, spaceAfter=0)
    base.update(kw)
    return ParagraphStyle(name, **base)

TITLE   = S("t",  fontName="Helvetica-Bold", fontSize=20, leading=23, textColor=INK)
SUB     = S("su", fontSize=10.5, leading=14, textColor=MUTED)
H1      = S("h1", fontName="Helvetica-Bold", fontSize=13, leading=16,
            textColor=ACCENT, spaceBefore=16, spaceAfter=6, keepWithNext=1)
H2      = S("h2", fontName="Helvetica-Bold", fontSize=10.5, leading=14,
            textColor=INK, spaceBefore=10, spaceAfter=4, keepWithNext=1)
BODY    = S("b",  spaceAfter=6)
SMALL   = S("sm", fontSize=8.5, leading=11.5, textColor=MUTED)
CELL    = S("c",  fontSize=8.2, leading=10.8)
CELLB   = S("cb", fontSize=8.2, leading=10.8, fontName="Helvetica-Bold")
MONO    = S("m",  fontName="Courier", fontSize=8.5, leading=11.5)
CHECK   = S("ck", fontSize=9.5, leading=14, leftIndent=16, firstLineIndent=-16,
            spaceAfter=4)
STEP    = S("st", fontSize=9.5, leading=13.4, leftIndent=18, firstLineIndent=-18,
            spaceAfter=5)


def code(txt):
    """Monospace block on a tinted background."""
    t = Table([[Paragraph(txt, MONO)]], colWidths=[6.9 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("BOX", (0, 0), (-1, -1), 0.4, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return t


def callout(title, body, kind="warn"):
    bg, ed = (WARN_BG, WARN_ED) if kind == "warn" else (STOP_BG, STOP_ED)
    inner = [Paragraph(f"<b>{title}</b>", S("ct", fontSize=10, leading=13.5,
                                            fontName="Helvetica-Bold"))]
    for p in body:
        inner.append(Spacer(1, 3))
        inner.append(Paragraph(p, S("cbody", fontSize=9, leading=12.4)))
    t = Table([[inner]], colWidths=[6.9 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 0.9, ed),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return t


def grid(rows, widths, header=True):
    data = []
    for i, r in enumerate(rows):
        style = CELLB if (header and i == 0) else CELL
        data.append([Paragraph(str(c), style) for c in r])
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    cmds = [
        ("GRID", (0, 0), (-1, -1), 0.4, RULE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    if header:
        cmds.append(("BACKGROUND", (0, 0), (-1, 0), HEAD_BG))
    t.setStyle(TableStyle(cmds))
    return t


def box(txt):
    return Paragraph(f"[&nbsp;&nbsp;]&nbsp;&nbsp;{txt}", CHECK)


def step(n, txt):
    return Paragraph(f"<b>{n}.</b>&nbsp;&nbsp;{txt}", STEP)


story = []
A = story.append

# ---------------------------------------------------------------- title -----
A(Paragraph("Millennium Phoenix", TITLE))
A(Spacer(1, 3))
A(Paragraph("Setting up and running experiments on the holodaq / holoexpt framework",
            SUB))
A(Spacer(1, 10))
A(Table([[""]], colWidths=[6.9 * inch], rowHeights=[1.6],
        style=TableStyle([("BACKGROUND", (0, 0), (-1, -1), ACCENT)])))
A(Spacer(1, 10))
A(Paragraph(provenance(), SMALL))
A(Spacer(1, 12))

A(callout(
    "Read this first: Phoenix is not yet runnable end to end",
    ["The framework now <i>accepts</i> a scope like Phoenix, which it could not before. "
     "Several Phoenix-specific pieces are still missing, so do not expect to reach a "
     "recording by working through this document today. What is outstanding:",
     "&bull;&nbsp; The Phoenix rig file does not exist yet. Three values still need "
     "deciding (stim wavelength, and three DAQ channels that disagree between the "
     "existing runners).",
     "&bull;&nbsp; There is no EOM power calibration in the format this framework reads. "
     "Without one the laser <b>stays dark and delivers no light at all</b>.",
     "&bull;&nbsp; The existing <font name='Courier'>ExpRunner_*.m</font> scripts still "
     "talk msocket, not holochat. They need porting before they run under this framework.",
     "&bull;&nbsp; The visual-stimulus trigger runs the opposite direction on Phoenix "
     "than on Scope2K. This may need a cable, not a setting. See Section 7.",
     "Sections 1 to 3 are useful now. Sections 4 and 5 describe the intended flow once "
     "the above is closed."],
    kind="stop"))

A(Paragraph("What changed, and why you should care", H1))
A(Paragraph(
    "Everything specific to one microscope — DAQ channels, COM ports, save folders, "
    "calibration paths, which hardware exists at all — now lives in a single file called "
    "a <b>rig file</b>. Nothing scope-specific is written into the experiment code any "
    "more. Two consequences for you:", BODY))
A(Paragraph(
    "<b>You no longer edit code to change a path.</b> The old "
    "<font name='Courier'>MPhoenixLocFile.m</font> carried the instruction "
    "\"IF YOU CHANGE THIS FILE, ENSURE COPIES ARE PRESENT AND SYNCHED ON ALL RELEVANT "
    "COMPUTERS\". That manual sync is what the rig file replaces: the DAQ machine holds "
    "the one authoritative copy and publishes it to the other computers.", BODY))
A(Paragraph(
    "<b>Each machine must say which scope it is.</b> That is the one piece of setup that "
    "does not arrive with a <font name='Courier'>git pull</font>, and it is the single "
    "most common reason things break. Section 2.", BODY))

# ------------------------------------------------------- 1. per machine -----
A(Paragraph("1. One-time setup, per computer", H1))
A(Paragraph(
    "Phoenix is four computers. Each needs a different set of checkouts.", BODY))
A(grid([
    ["Computer", "Needs", "Notes"],
    ["DAQ", "holodaq, holoexpt, the Phoenix experiments repo",
     "Runs the experiment. Holds the authoritative rig file."],
    ["Holography", "holography2k <b>and holodaq beside it</b>",
     "See the warning below — this is a new hard requirement."],
    ["ScanImage", "ScanImage as before",
     "Receives commands over holochat; no rig file of its own."],
    ["Visual stimulus", "the PsychoPy / PTB stimulus code",
     "Reads its settings from the published rig config."],
    ["Analysis box", "modules", "For <font name='Courier'>analysis</font> / "
     "<font name='Courier'>preprocessing</font> imports and the plot style."],
], [1.15 * inch, 2.5 * inch, 3.25 * inch]))
A(Spacer(1, 10))

A(callout(
    "On the holography computer, holodaq must sit next to holography2k",
    ["<font name='Courier'>makePaths</font> and <font name='Courier'>holo_paths</font> "
     "find holodaq as a <b>sibling directory</b> of this checkout — one named "
     "<font name='Courier'>holodaq</font>, or the only neighbour that looks like a "
     "holodaq checkout. If there is none they <b>stop with an error</b> instead of "
     "carrying on with empty paths.",
     "That is deliberate — the old behaviour was to add nothing silently and fail much "
     "later somewhere unrelated — but it means this is a setup step. Clone holodaq "
     "beside holography2k:"]))
A(Spacer(1, 6))
A(code("Documents\\GitHub\\<br/>&nbsp;&nbsp;holography2k\\ &nbsp;&nbsp;&lt;- this repo"
       "<br/>&nbsp;&nbsp;holodaq\\ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;- must be here"))
A(Spacer(1, 4))
A(Paragraph("There is no environment variable for this, on purpose. A "
            "<font name='Courier'>HOLODAQ_HOME</font> used to come first and was removed: "
            "it is invisible in the checkout, machine-global, and stays silently wrong "
            "once it outlives the path it names — which here means loading a stale "
            "channel map.", SMALL))
A(Spacer(1, 10))
A(Paragraph("Checklist", H2))
A(box("Clone or pull every repo that machine needs, from the table above."))
A(box("Holography box only: confirm holodaq is checked out <b>beside</b> "
      "holography2k."))
A(box("Confirm the <font name='Courier'>P:</font> share is mounted and writable "
      "(holoRequests, calibrations and spatial calibration all live there)."))
A(box("Confirm <font name='Courier'>D:</font> exists on the DAQ machine — that is where "
      "recordings are written."))
A(box("Do Section 2 on <b>every</b> machine before running anything."))


# ------------------------------------------------------ 2. rig selection ----
A(Paragraph("2. Tell each machine which scope it is", H1))
A(Paragraph(
    "<font name='Courier'>rig_config.m</font> is a one-line file, per machine, that "
    "returns the name of the rig that machine belongs to. It is deliberately excluded "
    "from git, so it <b>never arrives with a pull</b> — you create it once on each "
    "computer.", BODY))
A(code("copy rigs\\rig_config.m.example  rig_config.m<br/><br/>"
       "%% then open it and change the returned name:<br/>"
       "function name = rig_config()<br/>"
       "&nbsp;&nbsp;&nbsp;&nbsp;name = 'MillenniumPhoenix';<br/>"
       "end"))
A(Spacer(1, 8))
A(callout(
    "Copy AND edit. The example file ships returning 'Scope2K'.",
    ["If you copy it without changing the name, that machine silently loads Scope2K's "
     "channel map — the wrong physical lines, with no error. This is the single most "
     "dangerous mistake in this document.",
     "Equally: while Phoenix's rig file does not yet exist, Scope2K machines are getting "
     "away without a <font name='Courier'>rig_config.m</font> because there is only one "
     "rig file to choose from. <b>The moment the Phoenix rig file is added, every machine "
     "without this file stops working</b> — Scope2K's included. Create it now, not later."]))
A(Spacer(1, 10))
A(Paragraph("How to check it worked", H2))
A(Paragraph("Every load prints where its choice came from. Run "
            "<font name='Courier'>load_rig()</font> and read the line:", BODY))
A(grid([
    ["What it prints", "What that means"],
    ["<font name='Courier'>(rig_config.m)</font>",
     "Correct. This machine chose its rig deliberately."],
    ["<font name='Courier'>(HOLODAQ_RIG environment variable)</font>",
     "Also correct."],
    ["<font name='Courier'>(only rig file in ...)</font>",
     "<b>Not configured.</b> Nothing on this machine chose a rig; it fell back to the "
     "only one available. Fix it before trusting any channel."],
], [2.5 * inch, 4.4 * inch]))
A(Spacer(1, 10))
A(box("Created and <b>edited</b> <font name='Courier'>rig_config.m</font> on the DAQ machine."))
A(box("Same on the holography machine."))
A(box("Same on any other machine that loads holodaq."))
A(box("Ran <font name='Courier'>load_rig()</font> on each and confirmed it does "
      "<i>not</i> say \"only rig file in\"."))

# --------------------------------------------------------- 3. rig file -----
A(Paragraph("3. What goes in the Phoenix rig file", H1))
A(Paragraph(
    "For reference and review. The values below were recovered from the existing Phoenix "
    "runners and from <font name='Courier'>MPhoenixLocFile.m</font>; the rig file is "
    "where they now live instead.", BODY))
A(grid([
    ["Rig field", "Phoenix value", "Came from"],
    ["<font name='Courier'>daq.device</font> / <font name='Courier'>daq.rate</font>",
     "<font name='Courier'>Dev1</font> / 20000 Hz", "all three runners agree"],
    ["<font name='Courier'>modules.si.trigger</font>",
     "<font name='Courier'>port0/line10</font>", "all three agree"],
    ["<font name='Courier'>modules.patch</font>",
     "out <font name='Courier'>ao0</font>, in <font name='Courier'>ai2</font>",
     "<b>ai0 vs ai2 disagree</b> — verify"],
    ["<font name='Courier'>modules.slm_eom.trigger</font>",
     "<font name='Courier'>port0/line8</font>",
     "<b>line8 vs line9 disagree</b> — verify"],
    ["<font name='Courier'>modules.slm_eom.flip</font>",
     "<font name='Courier'>ai3</font>", "SLM trigger read-back"],
    ["<font name='Courier'>modules.fpc_eom</font>",
     "kind <font name='Courier'>eom</font>, out <font name='Courier'>ao3</font>, "
     "rest <font name='Courier'>-0.375</font> V", "the laser EOM line and its idle offset"],
    ["<font name='Courier'>modules.si.frame</font>",
     "<font name='Courier'>port0/line2</font>",
     "<b>line1 vs line2 disagree</b> — verify"],
    ["<font name='Courier'>paths.holo_request</font>",
     "<font name='Courier'>P:\\mnumphoenix\\holography\\Holorequests\\HoloRequest-DAQ\\</font>",
     "<font name='Courier'>locations.HoloRequest_DAQ</font>"],
    ["<font name='Courier'>paths.calib_dir</font>",
     "<font name='Courier'>P:\\mnumphoenix\\holography\\SpatialCalib\\</font>",
     "<font name='Courier'>locations.SpatialCalib</font>"],
    ["<font name='Courier'>paths.power_calib_dir</font>",
     "<font name='Courier'>P:\\mnumphoenix\\holography\\LaserCalib\\</font>",
     "<font name='Courier'>locations.PowerCalib</font>'s folder"],
    ["<font name='Courier'>paths.data_root</font>",
     "<font name='Courier'>D:\\Voltage Imaging</font>",
     "what the runners actually write; note the loc file says "
     "<font name='Courier'>D:\\data\\</font>"],
], [2.05 * inch, 2.5 * inch, 2.35 * inch]))
A(Spacer(1, 8))
A(Paragraph(
    "Three channels above are marked <b>verify</b>: the three example runners disagree "
    "about them, and no single runner has the combination we would otherwise pick. They "
    "need five minutes with a meter or a look behind the rack, not a guess — a wrong "
    "channel here records noise instead of a cell, silently.", BODY))
A(Paragraph(
    "One more value is still open: the <b>stim laser wavelength</b>. It is not cosmetic — "
    "the framework builds the saved data field names from it, so getting it wrong "
    "mislabels every recording from then on.", BODY))


# ------------------------------------------------- 4. before first expt -----
A(Paragraph("4. Before the first experiment", H1))
A(callout(
    "A modulator with no power calibration fails dark",
    ["Phoenix sets stim power with an EOM on an analog line. That path needs a "
     "power-to-volts lookup table, and if it is missing the framework leaves the "
     "modulator at its resting voltage: the channel delivers <b>no light at all</b> and "
     "you get a clean recording of nothing.",
     "Phoenix's existing <font name='Courier'>LaserPower.mat</font> is <b>not</b> this "
     "file. It feeds the older power-scaling code and has a different shape. A new "
     "calibration has to be measured, most likely with "
     "<font name='Courier'>AutoLaserPowerCalib_EOM.m</font> in holography2k.",
     "You will get a warning at startup if it is absent. Do not ignore it."]))
A(Spacer(1, 10))
A(Paragraph("Checklist", H2))
A(box("An EOM power calibration exists and <font name='Courier'>fpc_eom.calibration</font> "
      "points at it."))
A(box("<b>Measure the EOM idle voltage on a scope.</b> The framework forces the very last "
      "sample of every trial to 0 V rather than to the resting level. On Phoenix that is "
      "about 50 microseconds at the end of each trial, and on some modulators 0 V is fully "
      "<i>open</i>. Confirm what your modulator does at 0 V before putting a sample under "
      "the objective."))
A(box("A spatial (SLM/CoC) calibration exists in "
      "<font name='Courier'>P:\\mnumphoenix\\holography\\SpatialCalib\\</font>."))
A(box("The holochat broker is running and reachable from all four computers."))
A(box("A <font name='Courier'>holoRequest.mat</font> is in the HoloRequest-DAQ folder."))
A(box("You have confirmed the three <b>verify</b> channels in Section 3."))

# ------------------------------------------------------ 5. running ---------
A(Paragraph("5. Running an experiment", H1))
A(Paragraph("The intended order once Section 4 is closed. Note which computer each step "
            "happens on.", BODY))
A(step(1, "<b>Holography box.</b> Start the hologram listener. It prints the config it "
          "resolved — the calibration folder, the SDK path, the hologram method and the "
          "SLM timeout. Read those lines and confirm they are Phoenix's, not another "
          "scope's."))
A(step(2, "<b>ScanImage box.</b> Bring ScanImage up. Set your imaging parameters "
          "(for voltage imaging, roughly 330 Hz). Leave the resonant scanner on."))
A(step(3, "<b>Visual stimulus box.</b> Start the stimulus program if the experiment uses "
          "one. It takes its monitor and screen settings from the published rig config, "
          "so it should need no local edits."))
A(step(4, "<b>DAQ box.</b> Run <font name='Courier'>default_setup</font>. This loads the "
          "rig, opens the hardware it declares, and prints an audit of what it built: "
          "each module, the rig entry it came from, and the physical wiring. "
          "<b>Read the audit.</b> It is the cheapest possible check that this machine is "
          "driving the scope you think it is."))
A(step(5, "<b>DAQ box.</b> Publish the rig config so the other computers see it, then "
          "start your experiment script."))
A(step(6, "During the run, watch for the warnings listed in Section 6. Several of them "
          "mean the experiment will complete and produce data that is quietly wrong, "
          "rather than stopping."))
A(step(7, "Recordings land under <font name='Courier'>paths.data_root</font> on the DAQ "
          "machine. Confirm the first file appears where you expect before leaving a long "
          "run unattended."))


# ------------------------------------------------------- 6. troubleshoot ----
A(Paragraph("6. Troubleshooting", H1))
A(Paragraph("Messages you are most likely to meet, what each actually means, and the fix.",
            BODY))
A(grid([
    ["Message", "Meaning and fix"],
    ["<font name='Courier'>load_rig:noRig</font>",
     "More than one rig file exists and this machine did not choose one. Create "
     "<font name='Courier'>rig_config.m</font> (Section 2). Expect this the first time "
     "the Phoenix rig file lands."],
    ["<font name='Courier'>load_rig:unconfigured</font> (warning)",
     "A rig was loaded by fallback, not by choice. It may be another scope's channel map. "
     "Treat as an error and fix it."],
    ["<font name='Courier'>load_rig:badChannel</font>",
     "A channel string is malformed. Almost always capitalisation: it must be "
     "<font name='Courier'>port0/line10</font>, lower-case <font name='Courier'>line</font>. "
     "The old runners wrote <font name='Courier'>Line10</font> and that is now rejected."],
    ["<font name='Courier'>load_rig:duplicateChannel</font>",
     "Two modules claim one physical terminal. On Phoenix watch the LED line and the frame "
     "clock — both have wanted <font name='Courier'>port0/line2</font> historically."],
    ["<font name='Courier'>load_rig:badSerialRef</font>",
     "A module names a serial bus the rig file does not declare. Check the spelling of "
     "the bus name."],
    ["<font name='Courier'>load_rig:shadowed</font> (warning)",
     "The rig file that actually ran is not the one in the checkout you are editing — "
     "usually a second copy earlier on the MATLAB path. Your edits are having no effect. "
     "Run <font name='Courier'>which &lt;Name&gt;Rig -all</font>."],
    ["<font name='Courier'>holo_paths:noHolodaq</font>",
     "The holography box cannot find holodaq. Clone it beside holography2k "
     "(Section 1). There is no environment variable that overrides this."],
    ["<font name='Courier'>power_control_spec:eomWiring</font>",
     "The <font name='Courier'>fpc_eom</font> module declares kind "
     "<font name='Courier'>eom</font> but no <font name='Courier'>output</font>. A "
     "modulator needs the analog line that drives it."],
    ["<font name='Courier'>power_control_spec:eomAnalog</font>",
     "The <font name='Courier'>output</font> is not an <font name='Courier'>ao&lt;n&gt;</font> "
     "line. A digital line can only be on or off, which cannot set a power level."],
    ["<font name='Courier'>power_control_spec:noCalibration</font> (warning)",
     "<b>The important one.</b> No power lookup table, so the modulator stays at rest and "
     "the channel delivers no light. See Section 4."],
    ["<font name='Courier'>LaserPowerControl:powerOutOfRange</font> (warning)",
     "The requested power does not map through the calibration. That trial stays dark "
     "rather than delivering an unknown level."],
    ["<font name='Courier'>opto_channels:noModule</font>",
     "The opto channel names an fpc or SLM module the rig file does not declare. Usually "
     "a typo in the module name."],
    ["<font name='Courier'>Experiment:slmWiring</font>",
     "The SLM module is missing <font name='Courier'>trigger</font> or "
     "<font name='Courier'>flip</font>."],
], [2.25 * inch, 4.65 * inch]))

# -------------------------------------------------------- 7. limitations ---
A(Paragraph("7. Known limitations on Phoenix today", H1))
A(Paragraph("These are real and current. None is a mistake in your setup.", BODY))
A(grid([
    ["What", "Status"],
    ["The experiment runners",
     "<font name='Courier'>ExpRunner_voltImg*.m</font> still use msocket. They must be "
     "ported to the holochat interface before they run under this framework. This is the "
     "largest remaining piece of work."],
    ["Visual-stimulus trigger direction",
     "On Phoenix the stimulus computer <i>starts</i> the DAQ through an external trigger "
     "on <font name='Courier'>PFI0</font>. Scope2K works the other way round: the DAQ "
     "drives the stimulus computer from a digital output. The framework only supports the "
     "Scope2K direction, so Phoenix needs either a cable and a spare digital line, or new "
     "code. Decide this early."],
    ["No ready-made patch experiment",
     "<font name='Courier'>patch_experiment.m</font> was deleted on 2026-08-03. Both "
     "copies of it demanded two specific lasers by name, so neither could ever have run "
     "on Phoenix, and one called a class that does not exist. Nothing misleading is left "
     "to trip over, but it does mean Phoenix needs a patch experiment written fresh — in "
     "the experiments repo, not in holodaq."],
    ["The power-control GUI",
     "The calibrated power controller has no modulator support — it disables its buttons "
     "rather than crashing, but there is no GUI power control on a modulator rig."],
    ["Pockels cell on <font name='Courier'>ao1</font>",
     "A Pockels cell is an EOM, and the driver for one already exists "
     "(<font name='Courier'>LaserModulator</font>, which is what "
     "<font name='Courier'>kind = 'eom'</font> builds). What is missing is a place to "
     "declare a modulator that is <i>not</i> a photostim channel: "
     "<font name='Courier'>opto_channel</font> requires an SLM, and this one is on the "
     "imaging path. Before building anything, note the runners write <b>0 to "
     "<font name='Courier'>ao1</font> on every sweep</b> and never modulate it — so "
     "whether the DAQ needs to drive it at all is a hardware question. Beware "
     "<font name='Courier'>LaserEOM.m</font>: it is a stub with no methods."],
    ["Calibration scripts",
     "<font name='Courier'>alignCodeDAQ2K.m</font> still hardcodes DAQ channels and is "
     "already broken for an unrelated reason. Deferred deliberately, to be integrated "
     "with the other calibration scripts later."],
], [1.65 * inch, 5.25 * inch]))

A(Paragraph("8. Where to read more", H1))
A(Paragraph(
    "All five were written or corrected on 2026-08-03, so they agree with this guide "
    "rather than describing an older version of the system.", BODY))
A(grid([
    ["Document", "Read it for"],
    ["<font name='Courier'>holodaq/README.md</font>",
     "the whole system: the four computers, which module belongs to which one (\u00a72), "
     "the full rig-file schema, and a troubleshooting section"],
    ["<font name='Courier'>holodaq/rigs/README.md</font>",
     "the rig file itself \u2014 what <font name='Courier'>load_rig</font> validates, and "
     "how to declare a power path (<font name='Courier'>kind</font> "
     "<font name='Courier'>'ell14'</font> vs <font name='Courier'>'eom'</font>)"],
    ["<font name='Courier'>holoexpt/README.md</font>",
     "the experiment runtime: how <font name='Courier'>setup()</font> builds the rig, and "
     "when a <font name='Courier'>laser_gate</font> is and is not required"],
    ["<font name='Courier'>holography2k/README.md</font>",
     "<b>read before touching the holography computer.</b> New. Covers the "
     "sibling-checkout requirement and every rig field that machine reads"],
    ["<font name='Courier'>modules/docs/ai/MAP.md</font>",
     "the analysis library, once you have data. Generated from source, so it does not go "
     "stale quietly"],
], [2.25 * inch, 4.65 * inch]))

A(Spacer(1, 14))
A(Paragraph(
    "Nothing in this framework has yet been run against Phoenix's actual SLM, camera or "
    "ScanImage. Everything above was verified away from the rig. Treat the first session "
    "as a commissioning run: expect to find things, and check the light on a power meter "
    "before it reaches a sample.", SMALL))


# ------------------------------------------------------------- build -------
def decorate(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(0.85 * inch, 0.55 * inch, "Millennium Phoenix setup guide")
    canvas.drawRightString(7.75 * inch, 0.55 * inch, f"Page {doc.page}")
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(0.85 * inch, 0.72 * inch, 7.75 * inch, 0.72 * inch)
    canvas.restoreState()


doc = BaseDocTemplate(OUT, pagesize=letter,
                      leftMargin=0.85 * inch, rightMargin=0.85 * inch,
                      topMargin=0.8 * inch, bottomMargin=0.85 * inch,
                      title="Millennium Phoenix Setup Guide",
                      author="", subject="holodaq framework setup and operation")
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="f")
doc.addPageTemplates([PageTemplate(id="all", frames=[frame], onPage=decorate)])
doc.build(story)
print("wrote", OUT)
