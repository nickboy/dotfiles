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
3. **A name can resolve to something other than the binary you mean —
   in BOTH directions.** `log` is a zsh builtin in the non-interactive
   shell, so `log show …`
   hits the builtin, prints "too many arguments", exits 1 — and since a
   pipeline's status is its LAST command's, `log show … | wc -l` prints
   0 and exits 0. Always spell it `/usr/bin/log`.

   The reverse costs just as much: a program that EXECS — `timeout`,
   `xargs`, `nohup`, `sudo` — cannot see functions or aliases, so
   wrapping a shell-resolved name silently probes something else.
   `timeout 25 command claude` ran NOTHING (`command` is a builtin) and
   `timeout 25 claude` would have missed the wrapper function this
   machine defines. Resolve the path first: `zsh -lc 'whence -p claude'`.
4. **A failed query is not a negative result.** Before writing "nothing
   found", prove the query landed: directory exists, is readable, is
   non-empty; the tool produced output at all under a broader filter.
   Otherwise write "inconclusive".
5. **A `log show` predicate can match your own command line**, because
   your command is itself logged. Check hits against your own shell
   activity before believing a recent one.
6. **sudo needs a password and will hang.** Test once with
   `sudo -n true`, run BARE — rule 3 defeats this check inside a
   pipeline, where `sudo -n true | head -1` exits 0 while the bare form
   exits 1. If it fails, do not run sudo — collect every root-only
   command into one block for the user to run with `!`.
7. **`pgrep` and `ps -o ucomm=` are not supersets of each other**, and
   the mismatch fails silently. One machine: `ps` showed `ghostty` while
   `pgrep -x ghostty` returned nothing, and `pgrep -x claude` found pids
   that `ps ucomm==claude` did not. An empty substitution turns
   `footprint $(pgrep -x X)` into an argless `footprint`, whose error
   ("try as root?") points at permissions rather than at the real fault.
   Guard EVERY variable that comes from a command substitution — not
   just the one you happened to think of. The same investigation added
   a non-empty check for one pid and then failed identically on the next.
8. **Every baseline, threshold and "X means Y" carries its SAMPLE and
   the machine it came from, and an n=1 claim says n=1.** Rule 4 polices
   what you READ; this one polices what you WRITE, and it is where this
   file has failed most often. "171 idle-exits means real but not acute
   pressure" survived because it was stated without its sample; written
   as "(n=1, Mac16,10, 16 GB)" it invites the control measurement that
   refuted it. Inherited knowledge counts as n=0 until measured on the
   hardware in front of you — `pmset -g therm` was Intel-era fact that
   had never been checked on Apple Silicon.
9. **Some diagnostic commands stream forever** and will hang the shell
   until it times out, producing no output at all: `pmset -g thermlog`,
   `log stream`, `fs_usage` without `-t`, `top` without `-l`,
   `powermetrics` without `-n`. Always bound them.

## Post-mortem: what took the machine down

### Step 0 — The cheap high-prior causes, BEFORE any log work

```bash
/bin/df -h / /System/Volumes/Data
GIT_DIR=$(yadm introspect repo) git count-objects -vH   # size-pack
```

**A full boot volume presents as below-userspace unresponsiveness.** It
stalls SSH, WindowServer and audio alike, so every symptom points at the
kernel and every careful argument built from those symptoms points away
from the answer. This step exists because that argument was built once,
here: SSH being unresponsive was used to place the cause below userspace,
the macOS beta was ranked first suspect and an upstream issue was read and
excluded — all sound reasoning, and the answer was a full disk that ten
seconds of `df` would have shown. The reasoning was not wrong so much as
unnecessary.

The second command is here because the volume filled from a place no
general-purpose cleaner can see: git garbage in the yadm repo, 31 GB on a
machine whose tracked content is 2 MB.

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

**No panic report + machine had to be force-restarted = it HUNG** — but
only once you have checked the machine could have WRITTEN one. A panic
report is a file, and writing it needs room. On the machine in the worked
example below, the kernel logged `Failed to open corefile of size 1024 MB
(low disk space)` sixteen minutes before the outage, which means the
absence of a report on that volume proves nothing about whether a panic
occurred. Grep the log for `corefile` before drawing the inference.

Where the inference does hold, the kernel never faulted and was starved
instead, which points at resources (disk, memory, I/O) rather than at a
crashing driver. Where it does not, say **inconclusive**.

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
sudo powermetrics -n 3 -i 1000 --samplers cpu_power,gpu_power,thermal
```

**There is no `smc` sampler** — passing one fails the whole command. Do
not trust that sentence either: enumerate them, which needs no root and
re-derives on any machine, where a pasted list only ages.

```bash
powermetrics --help | sed -n '/following samplers are supported/,/^$/p'
powermetrics --help | grep '^    all '   # the group, one line
```

(A `/sampler/,/^$/` range does NOT work: it matches the `--samplers`
FLAG description higher up and stops at the blank line right after it,
returning four lines of unrelated help. Verified — it is the same
early-terminating-range mistake as everything else here.)

Not a desktop artefact — `battery` is enumerated on a machine that has
none, so the list is not hardware-filtered. `smc` is an Intel-era
sampler, same family as `pmset -g therm` above. **That is the general
form worth carrying to other tools**: a mechanism inherited from Intel
Macs does not error on Apple Silicon, it answers emptily, and an empty
answer reads as a clean bill of health.

That also means **fan RPM and die temperature are not available here**;
get fans from a third-party tool if you need them. What you do get is the
`thermal` sampler's thermal PRESSURE level (Nominal / Fair / Serious /
Critical), which is the Apple Silicon answer to the Intel speed-limit
counters, plus package watts and frequency residency from `cpu_power`.
A fanless Air runs hot by design, so temperature was never the verdict
anyway. Until this runs, thermal status is **inconclusive** — those words.

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
time: one measured event fired with **6 GB free**.

**That is not licence to ignore the free number in the same report.** The
two fields answer different questions and neither overwrites the other. A
per-process-limit kill at 7,080 free pages — 110 MB, measured — is two
independent facts: that daemon hit its own cap, AND the machine was low.
Report both. Collapsing them in either direction loses half the report.

**Do not judge any of this from a median across events** — inspect the
distribution and the outliers,
because the counterexample is usually already printed in your own output,
unread. Count per VICTIM, not per event: 20 kills of one 16 MB daemon is
that daemon looping on its own cap, not a machine under load.

**Ask launchd instead of parsing reports.** `launchctl print <service>`
prints `last exit reason = JETSAM_REASON_*` outright — no `.ips` file, no
hundreds-of-entries array, nothing that can be truncated. Prefer it to
everything above; it is the same answer without the trap.

**Jetsam has layers, and the mild layer writes no report at all.**
`MEMORY_IDLE_EXIT` reclaims idle daemons and restarts them on demand and
produces NO `JetsamEvent*.ips`. So a SIGKILL victim absent from the
reports says nothing about Jetsam's innocence — it is a fact about the
REPORTING layer. One machine had 171 `MEMORY_IDLE_EXIT` against 2
`PERPROCESSLIMIT`, and its two victim lists were disjoint for exactly
that reason.

**The idle-exit count is not a pressure signal without a baseline.** It
is tempting to read a big number as pressure; measure a second machine
first. 171 over 28.75 h of uptime looked meaningful until a same-RAM
machine with no complaint gave **298 over 3 h** — nine times the uptime
and 40% fewer. Note also that this is a snapshot of each service's LAST
exit, not a count of events, so it cannot be normalised by uptime at
all. Treat `MEMORY_IDLE_EXIT` as housekeeping.

**RSS is not the footprint, and the footprint may not be reclaimable.**
For a GUI process run `footprint <pid>` or `vmmap -summary <pid>`. On
Apple Silicon, `IOAccelerator` and `IOSurface` regions are GPU surfaces
in unified memory: Dirty, Reclaimable 0, so the compressor cannot touch
them and no scrollback or cache setting affects them. One terminal
emulator held 1.5 GB that way. Blur, transparency and custom shaders are
the usual source, and their CPU cost lands on `WindowServer` — attribute
it there, not to the app.

**JetsamEvent reports carry a full process table**, so a week of them is
a free time series of any process's memory. Pull `rpages` per pid to
settle "is this growing?" without waiting. Compare WITHIN one pid: flat
with occasional step changes is design cost, monotonic growth is a leak.
A cross-pid comparison is meaningless if the app restarted in between.

Rate matters more than totals: divide `decompressions` by uptime in
seconds. Every decompression is CPU work AND a stalled thread, so a
sustained rate explains heat and slowness with one number.

### E. Disk (a near-full boot volume stalls the whole machine)

`/bin/df -h / /System/Volumes/Data`,
`tmutil listlocalsnapshots /`, whether a backup is running, `mdutil -as`.

**Do not clear Spotlight on the parent's CPU.** The work happens in
`mdworker_shared` children that are spawned and killed continuously, so
`mds` itself sits near idle while the machine churns — measure the spawn
and kill RATE, not the parent's cumulative time. Then beware the opposite
error: summing worker lifetimes is an upper bound, not a cost. One
machine's workers summed to "1.85 cores equivalent" while sampling the
live ones showed under 1%. A tightly clustered median lifetime (42 s
there) is a timeout signature — workers spawned and reclaimed without
ever being given work.

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

## When a program will not start

Two traps met on 2026-08-30, both of which produce confident wrong answers.

**`sample` on a single-file bundled binary shows only `_dyld_start`.** That
looks like "stuck in the dynamic linker" and is not evidence of anything —
Bun and similar bundlers embed a runtime whose frames do not symbolicate,
so the stack is truncated rather than short. Do not build a theory on it.

The discriminating experiment, when a binary hangs and nothing else
explains it — vary ONE thing at a time and let each result exclude a class:

```bash
codesign --verify --strict "$b"     # content and signature intact?
env -i HOME=/tmp/probe PATH=/usr/bin:/bin "$b" --version   # config? env?
cp "$b" "$(dirname "$b")/copy" && "$(dirname "$b")/copy" --version
```

If a byte-identical copy IN THE SAME DIRECTORY runs while the original
hangs, then path, directory, content and environment are all excluded and
what is left is the INODE. Give it a fresh one by copying over it, and
re-verify the signature afterwards. Measured once on a 302 MB cask binary
after an interrupted upgrade; clearing `com.apple.quarantine` did not help
and `com.apple.provenance` cannot be removed.

**A hang and a non-zero exit are different diagnoses.** A tool that exits
non-zero is rejecting something it can see, usually its config. A tool that
never returns has not reached its own code, so nothing it can see is
relevant. Bound every launch check and report the two separately.

## Before you run an A/B

**State what each hypothesis PREDICTS before you run anything. If they
predict the same observation, it is not a test.** A null from a
non-discriminating test must be written **inconclusive**, never "ruled
out" — it closes a question it never opened.

This is the dominant failure mode in this repo's history, five instances
of one shape: a lock that could not cover the writers it needed to, an
end-to-end check that sampled a single case, a diff that could only ever
have shown nothing, a deliberate break that changed nothing so its
survival proved nothing, and the A/B below. A claim from n=1 is wrong but
CHECKABLE — the next machine refutes it. A test whose arms predict the
same thing is wrong and UNCHECKABLE.

So ask what MECHANISM connects the variable you are about to change to
the metric you are about to read. **A variable that cannot move the
metric produces a null that reads exactly like "ruled out"** — worse than
no experiment, because it looks like one was done.

A real example, caught before it ran: the plan was to vary the number of
terminal panes and watch GPU surface bytes. But those panes are drawn by
a multiplexer INSIDE one window and allocate no surfaces of their own —
`windows: 1`. The null was structural, guaranteed before the first
measurement, and would have been written up as "pane count is not the
cause".

Then check the metric can actually respond in the direction you expect.
Allocated GPU surfaces are not released on a config reload, so BYTES
cannot answer "does this setting cost anything" — but WindowServer's CPU
per unit time can, because a per-frame effect stops costing per-frame
work the moment it is off. Rate over total, again.

And change one thing the intended way: reload the config rather than
restarting the app, or the effect you measure is the restart.

## Measured baselines

From Nick's Mac mini (Mac16,10, 16 GB, macOS 27 beta) on 2026-08-18.
Use for comparison, re-measure rather than trusting the age of these.

All n=1, with the command that produced each, so the next machine can be
measured rather than compared against a remembered number.

| Metric | Normal | In trouble |
| --- | --- | --- |
| log msgs/min | ~12,000 | 118,000 (10x); 3.18M at boot |
| page size | 16384 B | — |
| free pages | — | ~7,000 (110 MB) |
| jetsam idle-exits | 298 at 3 h uptime | not a signal at all |
| decompressions/s | — | 659 sustained |

```bash
/usr/bin/log show --start "…" --end "…" --style compact | wc -l
vm_stat | head -1                              # page size
vm_stat | awk '/Pages free/{print $3}'
launchctl dumpstate | grep -c JETSAM_REASON_MEMORY_IDLE_EXIT
vm_stat | awk '/decompress/{print $2}'         # divide by uptime seconds
```

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
