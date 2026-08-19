---
name: macos-triage
description: |
  Use when a Mac is slow, hot, freezing, or was force-restarted, or
  when asked "why did it hang", "kernel panic", "fan is loud",
  "battery drains", "high CPU", "memory pressure", "disk full",
  "為什麼變慢", "很燙", "當機". Covers both post-mortem (what took the
  machine down) and steady-state (what is burning power) triage on
  Apple Silicon macOS.
version: 1.0.0
tools: Read, Glob, Grep, Bash
user-invocable: true
---

# macOS Triage (Apple Silicon)

Two different investigations. Pick the one that matches the symptom —
they use different evidence and answering the wrong one wastes the
window in which the logs still exist.

- **Post-mortem** — it froze, panicked, or was force-restarted.
  Question: what took it down? Evidence: what the log stopped saying.
- **Steady-state** — it is hot, slow, loud, or draining battery.
  Question: what is burning power right now? Evidence: cumulative CPU.

This is a READ-ONLY investigation in both cases. Never delete caches,
kill processes, run `mdutil -E`, or purge anything. Put changes in the
recommendations and let the user decide.

## Ground rules for this machine

Violating these produces confident wrong answers, not errors.

1. **Aliases shadow standard commands**: `ls`→eza, `ps`→procs,
   `df`→duf, `du`→dust, and `mv`/`rm`/`cp` carry `-i` (which hangs a
   non-interactive shell until it times out). Use absolute paths:
   `/bin/ps`, `/bin/df`, `/usr/bin/du`, `/bin/ls`, `/usr/bin/log`.
   The dangerous one is `ps aux` — procs reads `aux` as a keyword
   FILTER, exits 0, and returns a few rows instead of ~900. Right exit
   code, wrong answer.
2. **zsh does not word-split** unquoted parameter expansions.
   `set -- $var` yields one argument and empties the rest, silently
   turning a command into a broken one that still exits 0. Quote
   explicitly or use `${=var}`.
3. **`log` is a zsh builtin** in the non-interactive shell. `log show …`
   hits the builtin, prints "too many arguments", exits 1 — and since a
   pipeline's status is its LAST command's, `log show … | wc -l` prints
   0 and exits 0. Always spell it `/usr/bin/log`.
4. **A failed query is not a negative result.** Before writing "nothing
   found", prove the query landed: directory exists, is readable, is
   non-empty; the tool produced output at all under a broader filter.
   Otherwise write "inconclusive".
5. **A `log show` predicate can match your own command line**, because
   your command is itself logged. Check hits against your own shell
   activity before believing a recent one.
6. **sudo needs a password and will hang.** Test once with
   `sudo -n true`. If it fails, do not run sudo — collect every
   root-only command into one block for the user to run with `!`.
7. **Some diagnostic commands stream forever** and will hang the shell
   until it times out, producing no output at all: `pmset -g thermlog`,
   `log stream`, `fs_usage` without `-t`, `top` without `-l`,
   `powermetrics` without `-n`. Always bound them.

## Post-mortem: what took the machine down

### Step 1 — Was it a panic or a hang?

```bash
/bin/ls -ld /Library/Logs/DiagnosticReports
/bin/ls -1 /Library/Logs/DiagnosticReports | wc -l
find /Library/Logs/DiagnosticReports -maxdepth 2 -iname '*panic*'
```

Check `Retired/` too — reports get moved there. A `zsh: no matches
found` from a `*.panic` glob proves nothing: the glob failed, so `ls`
never ran. Only a readable, non-empty directory with zero `*panic*`
hits is a real negative.

**No panic report + machine had to be force-restarted = it HUNG.** The
kernel never faulted; it was starved. That points at resources (disk,
memory, I/O), not at a crashing driver.

### Step 2 — Find the moment it stopped

```bash
sysctl -n kern.boottime
/usr/bin/log show --start "YYYY-MM-DD HH:MM:00" \
    --end "YYYY-MM-DD HH:MM:SS" --style compact | tail -12
```

A clean shutdown leaves a shutdown sequence. **A log that stops
mid-stream on ordinary chatter, followed by a boot seconds later, is
the signature of a forced power-off.** Note the gap length.

### Step 3 — Walk backwards for the cause

Elevated log rate, then these in the final minutes:

- `coreaudiod … HALS_OverloadMessage` — the system could not service
  audio in time. A reliable marker of a system-wide stall.
- `deleted_helper … No space could be purged at urgency N` — urgency 3
  is the ceiling: macOS tried and could free nothing.
- `AssetCache … The system urgently needs disk space`
- `kernel … Failed to open corefile … (low disk space)`
- `MemoryResourceException` in `DiagnosticRequest_*autobugcapture*`

```bash
/usr/bin/log show --start "YYYY-MM-DD HH:MM:00" --end "…" \
  --predicate 'eventMessage CONTAINS[c] "disk space" OR
               eventMessage CONTAINS[c] "no space" OR
               eventMessage CONTAINS[c] "ENOSPC"' --style compact
```

## Steady-state: what is burning power

### A. Baseline

`hw.model`, chip, RAM, `sw_vers`, `sysctl kern.osversion`, uptime,
whether the model is fanless, and
`system_profiler SPHardwareDataType SPPowerDataType` for battery cycle
count, condition, and AC status.

### B. Throttling versus merely warm

```bash
pmset -g therm      # see the warning below before reading this
```

**`pmset -g therm` cannot answer this on Apple Silicon.** Its
`CPU_Speed_Limit` / `CPU_Available_CPUs` counters are an Intel-era
mechanism; on Apple Silicon the reply is three lines of
"No … has been recorded", and that is the NORMAL reply, not a clean
bill of health. Reporting it as "not throttling" is exactly the
unrun-query mistake in rule 4. Do not run `pmset -g thermlog` either —
it streams (rule 7).

The verdict needs root, so put it in the ask-the-user block:

```bash
sudo powermetrics -n 3 -i 1000 --samplers cpu_power,thermal,smc
```

Read package watts, fan RPM and die temperature. A fanless Air runs hot
by design, so temperature alone is never the verdict. Until this runs,
thermal status is **inconclusive** — say so in those words.

### C. Who is burning CPU — ask BOTH questions

```bash
top -l 2 -n 15 -o cpu -stats pid,command,cpu,mem   # use 2nd sample
/bin/ps -Ao time,pid,comm | sort -r | head -20     # cumulative
```

The cumulative one finds the daemon quietly spinning at 3% for days.
On a machine that got slower over weeks it is more often the answer
than the top of `top`. Also check for x86_64 processes under Rosetta.

### D. Memory

`vm_stat` (page size is **16384** on Apple Silicon — multiply, do not
eyeball), `sysctl vm.swapusage`, compressor size versus uncompressed.
Then `JetsamEvent*.ips` in `/Library/Logs/DiagnosticReports`:

- `reason: per-process-limit` — a daemon hit ITS OWN cap. Routine.
- `reason: vm-pageshortage` / `highwater` — real system-wide pressure.

**Finding the field is its own trap.** `reason` sits on the KILLED
process inside a `processes` array that can run to hundreds of entries
— on one machine it was entry 264 of 665. A walk that samples the first
few and reports "no reason field" has truncated its own search, which is
rule 4 wearing a different hat. Grep the raw file for the reason strings
rather than sampling a decoded prefix.

**Never promote `per-process-limit` to evidence of memory pressure.** It
means what it says regardless of what the machine looked like at the
time: one measured event fired with **6 GB free**. And do not judge this
from a median across events — inspect the distribution and the outliers,
because the counterexample is usually already printed in your own output,
unread. Count per VICTIM, not per event: 20 kills of one 16 MB daemon is
that daemon looping on its own cap, not a machine under load.

Cross-checking `launchctl` for SIGKILL (`exit = -9`) only counts when the
two victim lists OVERLAP. Jetsam is not the only sender of SIGKILL; on
one machine the two sets were disjoint, so it corroborated nothing.

**RSS is not the footprint, and the footprint may not be reclaimable.**
For a GUI process run `footprint <pid>` or `vmmap -summary <pid>`. On
Apple Silicon, `IOAccelerator` and `IOSurface` regions are GPU surfaces
in unified memory: Dirty, Reclaimable 0, so the compressor cannot touch
them and no scrollback or cache setting affects them. One terminal
emulator held 1.5 GB that way. Blur, transparency and custom shaders are
the usual source, and their CPU cost lands on `WindowServer` — attribute
it there, not to the app.

Rate matters more than totals: divide `decompressions` by uptime in
seconds. Every decompression is CPU work AND a stalled thread, so a
sustained rate explains heat and slowness with one number.

### E. Disk (a near-full boot volume stalls the whole machine)

`/bin/df -h / /System/Volumes/Data`,
`tmutil listlocalsnapshots /`, whether a backup is running, `mdutil -as`
and whether `mds`/`mds_stores` are reindexing.

### F. Log flood — both a symptom and a cause

```bash
/usr/bin/log show --start "YYYY-MM-DD HH:MM:00" \
    --end "YYYY-MM-DD HH:MM:59" --style compact | wc -l
```

Break down elevated windows by emitter:

```bash
… --style compact | awk 'NR>1{print $4}' | sed 's/\[.*//' \
    | sort | uniq -c | sort -rn | head
```

### G. Crash loops and leftovers

Reports per process over 7 days in `/Library/Logs/DiagnosticReports`
AND `~/Library/Logs/DiagnosticReports`; `launchctl list` for non-zero
exits and respawns; `systemextensionsctl list` (endpoint security, VPN
and AV extensions are a steady heat source); LaunchAgents left behind
by uninstalled apps.

### H. Sleep and wake

`pmset -g assertions` for what prevents sleep, dark wake count from
`pmset -g log`. A laptop that never sleeps runs hot.

### I. Post-upgrade analysis daemons

`mediaanalysisd`, `photoanalysisd`, `photolibraryd`,
`spotlightknowledged`, `modelmanagerd`, Apple Intelligence indexing.
Distinguish "mid-job, will finish" from "stuck looping for weeks" by
how far back their activity goes, not by the fact that they are running.

### J. Beta overhead

`buildVariant: CustomerSeed` enables AutoBugCapture, DiagnosticRequest
and Tailspin captures (37 MB each is normal). Count them, estimate the
disk-write cost, and check `softwareupdate -l` for a newer build.

## Measured baselines

From Nick's Mac mini (Mac16,10, 16 GB, macOS 27 beta) on 2026-08-18.
Use for comparison, re-measure rather than trusting the age of these.

| Metric | Normal | In trouble |
| --- | --- | --- |
| unified log messages/min | ~12,000 | 118,000 (10x), 3.18M at boot |
| `vm_stat` page size | 16384 bytes | — |
| free pages under pressure | — | ~7,000 pages (110 MB) |

## Output format

1. **Verdict** — throttling/failing, or warm-but-fine. Name the single
   measurement that decides it.
2. **Ranked causes**, each with evidence (numbers, timestamps, process
   names), labelled CONFIRMED / LIKELY / RULED OUT.
3. **What could not be determined and why** — say "inconclusive"
   explicitly. An unrun query must never become a clean bill of health.
4. **Root-only commands** in one block for the user to run with `!`.
5. **Recommended actions** ordered by effect ÷ risk, each with the
   command and the expected result. Do not run them.

Reply in Traditional Chinese; keep commands, flags and identifiers in
English.

## Worked example — Mac mini, 2026-08-18

Symptom: froze, power button held 15 s, restarted. Verdict: **not a
panic — a hang under a full boot volume.**

| Time | Evidence |
| --- | --- |
| 20:28:43 | kernel: `Failed to open corefile … (low disk space)` |
| 20:29:48 | `No space could be purged at urgency 2` |
| 20:31:13 | `No space could be purged at urgency 3` (ceiling) |
| 20:31:12 | two `MemoryResourceException` autobugcaptures |
| 20:38–20:41 | log rate 10x normal |
| 20:43–20:44 | repeated `coreaudiod` HAL overloads |
| 20:44:25 | log stops mid-sentence — forced power-off |
| 20:45:07 | boot; zero `*panic*` reports anywhere |

Cause: 31 GB of interrupted-write pack files in the yadm repo filled
the volume, so a 16 GB machine could neither grow swap nor purge
caches, and every page-out blocked on a disk with no room. The
age-based pack cleanup in `~/daily-maintenance-lib.sh` exists to stop
this recurring — see the **dotfiles-maintenance** skill.

## Worked example — MacBook, 2026-08-19 (steady-state)

Symptom: hotter and slower over weeks, no crashes. Verdict: **memory
overload, not heat.** Heat and slowness were two symptoms of one cause.

The deciding number was a **rate**, not a total: 68.2M decompressions
over 28.75 h uptime = **659/s sustained**. Supporting: free 0.08 GB on
a 16 GB machine, compressor 6.76 GB holding 14.41 GB, so a ~23 GB
working set in 16 GB of RAM.

**The 28 JetsamEvents were retracted from this verdict, and the
retraction is the lesson.** They were first filed as the headline
evidence on a median free of 118 MB. Reading the `reason` field showed
all 29 were `per-process-limit`, 20 of them one 16 MB daemon looping on
its own cap — and one fired with 6 GB free. That outlier had been
printed in the investigator's own output and passed over, because a
median was computed instead of the distribution being looked at. The
verdict survived on `vm_stat` and the decompression rate alone; the
evidence base got narrower and more honest.

Second cause, independent of the first: **8 HAL virtual audio drivers**
in `/Library/Audio/Plug-Ins/HAL/`, at least 3 belonging to uninstalled
apps, all loaded into one `coreaudiod` — 5.6% of a core all day, plus
two `PreventUserIdleSystemSleep` assertions so the laptop never idled.
Orphaned drivers outlive the app that installed them; check that
directory on any Mac that runs hot.

Also found: two identical `powermetrics` daemons from iStat Menus, each
waking the SoC every 2 s — the power meter costing power.

Ruled out with evidence, all of which the hot-and-slow story would have
predicted: 124 GB free, zero APFS snapshots, no backup running,
Spotlight at 0.4% (not reindexing), post-upgrade analysis daemons at
~0 s cumulative, no respawn storm, and the beta already current.
