#!/bin/sh
# claude-pane-marker — pane membership for Claude sessions.
#
# Sourced by claude-statusline (the writer) and claude-copy-last (the
# reader). ONE definition of where markers live, what they are called, and
# how a conversation is ranked. Two copies of these expressions would be a
# divergence waiting to happen, and a silent one: a mismatch does not error,
# it just looks like "there are no markers".
#
# WHY THIS EXISTS
# herdr tracks at most ONE Claude session per pane, and 0.8.0 refuses to
# replace an existing registration when the new session reports
# session_start_source "startup" — which is what every new session reports.
# (Verified against the running server: startup is rejected, resume/compact/
# clear are accepted, and a rejected write still answers {"type":"ok"}.)
# So the SECOND session in a pane — most often a background job, which
# inherits HERDR_PANE_ID from the pane it was launched from — is invisible
# to herdr forever, and claude-copy-last would copy the first session's
# transcript perfectly: the wrong conversation. Observed live in two panes
# at once, each with a foreground session and a background job.
#
# WHAT A MARKER IS, AND IS NOT
# One empty file per (pane, session) pair saying only "this session lives in
# this pane". It carries NO freshness meaning. Every live session's
# statusline ticks, so marker mtime separates live from dead — which is not
# the question anyone is asking. Ordering comes from the last user turn in
# each transcript instead: it needs no writer, so it cannot go stale, and it
# cannot be wrong about a session that stopped rendering.
#
# WHY NOT /tmp
# This file decides which conversation reaches your clipboard, so it is
# trusted input, not an advisory cache. /tmp is world-writable: any local
# process could pre-create a marker and steer the answer. The other markers
# this repo writes stay in /tmp because they are advisory — do not "tidy"
# them back together.

# Override exists for the test suite; nothing else should set it.
claude_pane_marker_dir() {
    printf '%s' "${CLAUDE_PANE_MARKER_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-pane}"
}

# Pane ids contain ':' (w1:p3); session ids are uuids. '--' separates the
# two halves so the reader can split a filename back apart, and session ids
# never contain it.
claude_pane_marker_key() {
    printf '%s' "$1" | tr -c 'A-Za-z0-9._' '-'
}

claude_pane_marker_file() {   # $1 pane id, $2 session id
    printf '%s/%s--%s' "$(claude_pane_marker_dir)" "$(claude_pane_marker_key "$1")" "$2"
}

# 0700 explicitly: the directory is trusted input, so it must not be
# group- or world-writable even if the user's umask is loose.
claude_pane_marker_write() {   # $1 pane id, $2 session id
    [ -n "${1:-}" ] && [ -n "${2:-}" ] || return 1
    _cpm_dir=$(claude_pane_marker_dir)
    if [ ! -d "$_cpm_dir" ]; then
        # chmod separately rather than `mkdir -m`: with -p, -m applies only
        # to the deepest directory (SC2174), and the mode here is a security
        # property, not a preference — it must not depend on that subtlety.
        mkdir -p "$_cpm_dir" 2>/dev/null || return 1
        chmod 700 "$_cpm_dir" 2>/dev/null || return 1
    fi
    _cpm_file=$(claude_pane_marker_file "$1" "$2")
    # Membership does not change once true, so the common path is a single
    # `kill -0` and no write at all. Rewrite only when the marker is
    # missing, empty (written by an older version), or names a pid that is
    # gone — that last case makes a marker self-healing across a restart
    # rather than leaving a permanently unverifiable claim behind.
    _cpm_pid=$(claude_pane_marker_pid "$1" "$2")
    if [ -n "$_cpm_pid" ] && kill -0 "$_cpm_pid" 2>/dev/null; then
        return 0
    fi
    _cpm_new=$(claude_pane_session_pid || true)
    if [ -n "$_cpm_new" ]; then
        printf 'pid=%s\n' "$_cpm_new" > "$_cpm_file" 2>/dev/null || return 1
    else
        # No pid resolvable — still record membership. An unverifiable
        # marker is worth more than none: it degrades to the behaviour
        # before pids were recorded, rather than losing the pane entirely.
        [ -e "$_cpm_file" ] || : > "$_cpm_file" 2>/dev/null || return 1
    fi
    return 0
}

# WHY THE MARKER IS NOT EMPTY
# A marker's pane key can be correct from the reader's point of view and
# still be false in fact: HERDR_PANE_ID is INHERITED, so a session running
# somewhere else can write a marker for a pane it does not occupy. Filtering
# cannot catch that — the marker names the very pane being read, so it is
# admitted correctly — and the candidate count corroborates the lie, because
# "2 in pane" is exactly what a legitimate co-resident pair looks like.
#
# Nor can it be caught by re-reading the process's own HERDR_PANE_ID: that
# is where the marker came from, so the two agree by construction. It needs
# an INDEPENDENT witness, and there is one — the process tree. Verified on a
# live pane: both the foreground session and a background job descend from
# the pane's shell_pid, so ancestry distinguishes a session that really runs
# in a pane from one that merely inherited its name.
#
#   pid 25550 (background job) <- 25530 <- 12409 <- 56402 (-zsh) = shell_pid
#   pid  4883 (background job) <- 25530 <- 12409 <- 56402 (-zsh) = shell_pid
#
# So the marker records the session's pid, which is what makes that check
# possible at all.

# The statusline is a grandchild of the session process, so walk up to the
# nearest ancestor that IS claude rather than assuming a fixed depth.
claude_pane_session_pid() {
    _cpm_p="${PPID:-}"
    _cpm_hops=0
    while [ -n "$_cpm_p" ] && [ "$_cpm_p" != 0 ] && [ "$_cpm_p" != 1 ]; do
        case $(ps -o comm= -p "$_cpm_p" 2>/dev/null) in
            *claude) printf '%s' "$_cpm_p"; return 0 ;;
        esac
        _cpm_hops=$((_cpm_hops + 1))
        if [ "$_cpm_hops" -gt 8 ]; then return 1; fi
        _cpm_p=$(ps -o ppid= -p "$_cpm_p" 2>/dev/null | tr -d ' ')
    done
    return 1
}

# 0 if $1 is $2 or descends from it. Bounded so a cycle or a ps that
# misbehaves cannot spin.
claude_pane_pid_descends_from() {   # $1 pid, $2 ancestor pid
    _cpm_p="${1:-}"
    _cpm_target="${2:-}"
    [ -n "$_cpm_p" ] && [ -n "$_cpm_target" ] || return 1
    _cpm_hops=0
    while [ -n "$_cpm_p" ] && [ "$_cpm_p" != 0 ] && [ "$_cpm_p" != 1 ]; do
        if [ "$_cpm_p" = "$_cpm_target" ]; then return 0; fi
        _cpm_hops=$((_cpm_hops + 1))
        if [ "$_cpm_hops" -gt 12 ]; then return 1; fi
        _cpm_p=$(ps -o ppid= -p "$_cpm_p" 2>/dev/null | tr -d ' ')
    done
    return 1
}

claude_pane_marker_pid() {   # $1 pane id, $2 session id -> pid, or nothing
    _cpm_file=$(claude_pane_marker_file "${1:-}" "${2:-}")
    [ -f "$_cpm_file" ] || return 0
    sed -n 's/^pid=\([0-9][0-9]*\)$/\1/p' "$_cpm_file" 2>/dev/null | head -n 1 || true
}

# A session id read out of a filename is UNVALIDATED INPUT, and it is used
# downstream in two glob contexts (`find -name "$id.jsonl"` and a `case`
# pattern). A marker named `w1-p3--*` would yield the id `*`, and
# `-name "*.jsonl"` then matches the first transcript found anywhere under
# the projects root — a wrong answer, silently, from a file this design has
# declared trusted.
#
# Only the same user can create such a file, so this is not a privilege
# boundary. It is worth the line anyway: the test suite writes into this
# directory, and "same user" has already left a phantom marker in a live
# pane once. Trusting the directory's PERMISSIONS says nothing about its
# CONTENTS.
claude_pane_marker_sessions() {   # $1 pane id -> session ids, one per line
    _cpm_dir=$(claude_pane_marker_dir)
    _cpm_key=$(claude_pane_marker_key "${1:-}")
    [ -n "$_cpm_key" ] || return 0
    for _cpm_f in "$_cpm_dir/$_cpm_key"--*; do
        [ -e "$_cpm_f" ] || continue
        _cpm_sid=${_cpm_f##*--}
        case "$_cpm_sid" in
            '' | *[!0-9A-Za-z_-]*) continue ;;
        esac
        printf '%s\n' "$_cpm_sid"
    done
}

# Reap markers for panes that no longer exist. The per-copy janitor in
# claude-copy-last only ever visits its OWN pane's key, so when a pane is
# closed nothing reads those markers again and they persist forever — with
# no TTL by design, the directory would grow monotonically with every
# (pane, session) pair the machine has ever seen. Tiny files, so this is
# hygiene rather than a bug, but it is unbounded and nothing would notice.
#
# The condition is deliberately BOTH: pid dead AND transcript gone. A dead
# session whose transcript survives is still the correct answer for its pane
# until someone speaks there again, so its membership must not be reaped.
claude_pane_marker_sweep() {   # $1 projects root
    _cpm_dir=$(claude_pane_marker_dir)
    [ -d "$_cpm_dir" ] || return 0
    _cpm_root="${1:-$HOME/.claude/projects}"
    # Once an hour at most: this walks the directory, and the statusline
    # that calls it runs every few seconds for every live session.
    _cpm_stamp="$_cpm_dir/.swept"
    if [ -e "$_cpm_stamp" ] && [ -z "$(find "$_cpm_stamp" -mmin +60 2>/dev/null)" ]; then
        return 0
    fi
    : > "$_cpm_stamp" 2>/dev/null || return 0
    for _cpm_f in "$_cpm_dir"/*--*; do
        [ -e "$_cpm_f" ] || continue
        _cpm_sid=${_cpm_f##*--}
        case "$_cpm_sid" in
            '' | *[!0-9A-Za-z_-]*) continue ;;
        esac
        _cpm_pid=$(sed -n 's/^pid=\([0-9][0-9]*\)$/\1/p' "$_cpm_f" 2>/dev/null | head -n 1)
        if [ -n "$_cpm_pid" ] && kill -0 "$_cpm_pid" 2>/dev/null; then
            continue
        fi
        if [ -n "$(find "$_cpm_root" -maxdepth 2 -name "$_cpm_sid.jsonl" -print -quit 2>/dev/null)" ]; then
            continue
        fi
        rm -f "$_cpm_f" 2>/dev/null || true
    done
}

# The conversation you are IN is the one you spoke to most recently — not
# the one most recently WRITTEN. A session can write for hours with no human
# input: measured on a live pane, a foreground session's transcript was
# touched three hours after its last human turn while a background job in
# the same pane had one 44 minutes old. mtime picked the wrong one.
#
# Four kinds of entry are type "user" without being you, and each was
# counted before it was excluded:
#
#   tool_result       the bulk of them — 728 of 802 array-content user
#                     entries in one measured transcript. Ranking on these
#                     tracks AGENT activity, which is mtime with extra
#                     steps: naive "last user entry" read 05:17:35Z against
#                     an actual last human turn of 05:10:41Z.
#   isCompactSummary  /compact writes a type:"user" entry whose content is a
#                     STRING and whose isMeta is null, so it passes both a
#                     shape filter and an isMeta filter. Excluded
#                     unconditionally because AUTO-compaction fires at an
#                     unpredictable moment and is not a human acting.
#   isMeta            system notices.
#   isSidechain       subagent traffic; a subagent's turn must not decide
#                     who owns the pane.
#
# The shape test is "contains anything that is not a tool_result", not
# "contains a text block": a human turn can arrive as an array carrying an
# image or other block, and four such entries exist in one measured
# transcript. Shape is the wrong discriminator in both directions.
#
# Streams rather than slurps, and reads the WHOLE file: extraction wants the
# recent tail, but ordering wants the last human turn however far back it
# is. A session whose human spoke once and then ran thousands of tool calls
# would drop out of a tail window and be ranked as "never spoken to" —
# silently, and wrongly.
#
# Emits an ISO-8601 UTC timestamp, which sorts correctly as a plain string,
# so callers need no date parsing.
#
# THE RETURN CODE IS PART OF THE CONTRACT. Empty output means "this session
# has no human turn". A NON-ZERO RETURN means "I could not read this
# transcript", which is a different thing and must not be ranked as though
# it were the first. Collapsing the two would let an unreadable candidate —
# possibly the one with the most recent human turn — lose silently to a
# readable one, and the caller would print a confident age for the wrong
# session. Ranking on "unknown" is exactly as wrong as ranking on epoch
# zero; it merely fails in the other direction.
#
# Timestamps are normalised to always carry a fractional part, because the
# comparison is a string comparison: '2026-01-01T00:00:00Z' and
# '2026-01-01T00:00:00.500Z' at the same second would otherwise sort
# backwards ('.' is below 'Z' in ASCII). Both forms are known to occur.
# Normalising keeps the value a valid ISO-8601 instant, so callers can still
# hand it to a date parser.
claude_pane_last_user_turn() {   # $1 transcript path
    [ -f "${1:-}" ] || return 2
    _cpm_turns=$(jq -r '
        select(.type == "user"
               and (.isMeta != true)
               and (.isSidechain != true)
               and (.isCompactSummary != true))
        | select(((.message.content | type) == "string")
                 or ([.message.content[]?.type] | any(. != "tool_result")))
        | (.timestamp // empty)
        | if test("\\.[0-9]+Z$") then . else sub("Z$"; ".000Z") end' \
        "$1" 2>/dev/null) || return 2
    printf '%s\n' "$_cpm_turns" | tail -n 1
    return 0
}
