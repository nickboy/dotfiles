#!/bin/bash

# Shared library for the daily-maintenance scripts
# (install-daily-maintenance.sh, uninstall-daily-maintenance.sh,
#  daily-maintenance-control.sh). Source it, don't execute it:
#   source "$(dirname "${BASH_SOURCE[0]}")/daily-maintenance-lib.sh"

# Colors for output
# shellcheck disable=SC2034  # consumers use different subsets of the palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Shared paths
LAUNCHAGENT_DIR="$HOME/Library/LaunchAgents"
# yadm-native template ('yadm alt' regenerates the real plist from it on
# every clone/pull; {{env.HOME}} expands to the actual home directory)
PLIST_TEMPLATE="$LAUNCHAGENT_DIR/com.daily-maintenance.plist##template"
PLIST_FILE="$LAUNCHAGENT_DIR/com.daily-maintenance.plist"
MAINTENANCE_SCRIPT="$HOME/daily-maintenance.sh"
CONTROL_SCRIPT="$HOME/daily-maintenance-control.sh"
LOG_DIR="$HOME/Library/Logs"
LOG_PATH="$LOG_DIR/daily-maintenance.log"
ERROR_LOG_PATH="$LOG_DIR/daily-maintenance-error.log"

# Print ✓/✗ for an exit code. Under 'set -e' call it only with a literal
# status you already own the control flow for — 'cmd; print_status $?'
# aborts the script before the ✗ branch can ever print.
print_status() {
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ask a y/n question. When stdin is not a TTY (piped yadm bootstrap, CI),
# silently take the default instead of aborting on read EOF — a bare
# 'read -p' under 'set -e' kills the whole installer in that case.
# Usage: if prompt_yes_no "Continue?" n; then ... fi
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local reply
    if [ ! -t 0 ]; then
        echo "$prompt (y/n) -> non-interactive, defaulting to '$default'"
        [ "$default" = "y" ]
        return
    fi
    read -p "$prompt (y/n) " -n 1 -r reply
    echo
    [[ $reply =~ ^[Yy]$ ]]
}

# Modern launchctl (bootstrap/bootout/enable) instead of load/unload.
# Evidence, 2026-07-10: the agent sat "disabled" in launchd's override DB;
# plain 'launchctl load' failed with "Load failed: 5" yet still EXITED 0,
# so the old '|| launchctl load -w' fallback never fired and the schedule
# was silently dead since 2026-07-03. bootstrap/bootout return real exit
# codes, and dm_load clears the disabled override first.
DM_LABEL="com.daily-maintenance"
DM_DOMAIN="gui/$(id -u)"

dm_loaded() {
    launchctl print "$DM_DOMAIN/$DM_LABEL" >/dev/null 2>&1
}

dm_load() {
    # Clear a persisted disable flag (e.g. from an old 'unload -w'),
    # then bootstrap the job into the GUI domain.
    launchctl enable "$DM_DOMAIN/$DM_LABEL" 2>/dev/null || true
    launchctl bootstrap "$DM_DOMAIN" "$PLIST_FILE"
}

dm_unload() {
    launchctl bootout "$DM_DOMAIN/$DM_LABEL"
}

# Pure predicate: did a herdr version bump land while a server is live?
# $1 = version before upgrade, $2 = after, $3 = socket path override
# (defaults to the real socket). No side effects — the caller decides
# how to notify. Unit-tested in test-dotfiles.sh.
dm_herdr_strand_detected() {
    local before="$1" after="$2"
    local sock="${3:-$HOME/.config/herdr/herdr.sock}"
    [ -n "$before" ] && [ "$before" != "$after" ] && [ -S "$sock" ]
}

# Remove half-written packs left behind by an INTERRUPTED pack write.
# git labels them "garbage" in count-objects and never removes them, so
# they accumulate — 17.2GB on this machine, invisible to every
# general-purpose cleaner because a .git/objects directory looks like
# legitimate repo data.
#
# THE GUARD IS AGE, and two earlier guards were both wrong:
#
#   ps -grep for "git gc" matched any process whose COMMAND LINE merely
#   mentioned the string, including the shell running the check — 4 false
#   matches measured with no gc running, so it was stuck ON forever.
#
#   `[ -f gc.pid ]` is wrong in BOTH directions. tmp_pack_* is written by
#   `index-pack` (the receiving side of fetch/clone/pull) and by
#   `pack-objects`, and NEITHER takes that lock — so a maintenance run
#   racing a `yadm pull` would delete the pack an in-flight fetch is
#   still writing. And a KILLED gc leaves gc.pid behind, which is exactly
#   the interruption that produces this garbage, so the cleanup would be
#   blocked permanently by the very event it exists to clean up after.
#   git itself never trusts that file's existence: it parses "<pid>
#   <host>" and checks the process is alive.
#
# Age settles all of it. An in-flight temp pack is seconds old; garbage
# from a killed operation is hours or days old. Age is robust against
# every producer rather than the one that happens to take a lock, and no
# stale lock can jam it.
#
# `find -delete` also fixes a false success: `rm -f <glob>` overflows
# ARG_MAX at the volumes that motivated this, and the old code reported
# "removed N" unconditionally afterwards.
DM_PACK_GARBAGE_MIN_AGE_MIN=${DM_PACK_GARBAGE_MIN_AGE_MIN:-60}

dm_pack_garbage_clean() {   # $1 = GIT_DIR
    local d="$1" before after removed
    [ -n "$d" ] && [ -d "$d/objects/pack" ] || return 1
    before=$(find "$d/objects/pack" -name 'tmp_pack_*' -mmin "+$DM_PACK_GARBAGE_MIN_AGE_MIN" 2>/dev/null | wc -l | tr -d ' ')
    [ "${before:-0}" -gt 0 ] || return 1
    find "$d/objects/pack" -name 'tmp_pack_*' -mmin "+$DM_PACK_GARBAGE_MIN_AGE_MIN" -delete 2>/dev/null
    after=$(find "$d/objects/pack" -name 'tmp_pack_*' -mmin "+$DM_PACK_GARBAGE_MIN_AGE_MIN" 2>/dev/null | wc -l | tr -d ' ')
    removed=$((before - ${after:-0}))
    # Report what was ACTUALLY removed, measured, not what was attempted.
    [ "$removed" -gt 0 ] || { echo "pack garbage found but nothing could be removed"; return 1; }
    echo "removed $removed interrupted-write pack file(s) older than ${DM_PACK_GARBAGE_MIN_AGE_MIN}m"
    return 0
}

# Count and repair yazi packages whose deployed contents have drifted from
# the lockfile, BEFORE the upgrade runs. Prints the count; silent at zero.
#
# This exists because --discard removes the only signal we had. What that
# signal was, though, was a tripwire and a bad one: `ya pkg` aborts at the
# FIRST mismatch, so it named one package while seven others were equally
# out of step and stayed invisible. Converting it to a measurement keeps
# the information and drops the stop-the-world behaviour — a count above
# zero every day means something is corrupting these dirs; zero after one
# repair means it was a single desync.
#
# `install` and not `upgrade`: install deploys the rev the LOCKFILE
# records, so a directory whose contents change under it was out of step
# with its own entry. Under `upgrade` a changed directory could just be a
# new upstream release, which is not drift.
dm_yazi_fingerprint() {   # $1 = yazi config dir
    local d
    for d in "$1"/plugins/*/ "$1"/flavors/*/; do
        [ -d "$d" ] || continue
        printf '%s %s\n' \
            "$(find "$d" -type f | sort | xargs shasum 2>/dev/null | shasum | cut -d' ' -f1)" \
            "$(basename "$d")"
    done
}

dm_yazi_drift_repair() {   # $1 = yazi config dir
    local base="$1" before after n
    command -v ya >/dev/null 2>&1 || return 1
    [ -d "$base/plugins" ] || return 1
    before=$(dm_yazi_fingerprint "$base")
    ya pkg install --discard >/dev/null 2>&1 || return 1
    after=$(dm_yazi_fingerprint "$base")
    n=$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") 2>/dev/null | grep -c '^>')
    [ "${n:-0}" -gt 0 ] || return 1
    echo "repaired $n yazi package(s) whose contents had drifted from the lockfile"
    return 0
}

# Classify a launchd plist's program path. Prints one of:
#   ok            — the program exists
#   stale <path>  — gone, but a binary of the same NAME is still installed
#   orphan        — gone, and nothing by that name remains
#
# The distinction exists because the two need OPPOSITE remedies and wear
# the same symptom. A versioned Homebrew Cellar path dies on the next
# upgrade while the binary stays put at the stable symlink; deleting that
# agent throws away a working service. An uninstalled app leaves an agent
# that should go. Extracted from the scan so it can be tested by behaviour
# rather than by grepping the script that contains it.
#
# ~/.local/bin and ~/.cargo/bin are probed directly: launchd trims PATH,
# and a check that works interactively and fails under the timer is worse
# than no check.
dm_launchd_classify() {   # $1 = absolute program path
    local prog="$1" name repl d
    [ -n "$prog" ] || { echo orphan; return 0; }
    [ -e "$prog" ] && { echo ok; return 0; }
    name=$(basename "$prog")
    repl=$(command -v "$name" 2>/dev/null)
    if [ -z "$repl" ]; then
        for d in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
            [ -x "$d/$name" ] && { repl="$d/$name"; break; }
        done
    fi
    [ -n "$repl" ] && { echo "stale $repl"; return 0; }
    echo orphan
}
