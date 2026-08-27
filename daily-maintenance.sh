#!/bin/bash

# Daily Maintenance Script
# This script runs various update and backup commands

# Track last run time
LAST_RUN_FILE="$HOME/.daily-maintenance-last-run"
CURRENT_DATE=$(date +%Y-%m-%d)

# Check if we're running from launchd with --auto flag
if [[ "$1" == "--auto" ]]; then
    # Check if already ran today
    if [ -f "$LAST_RUN_FILE" ]; then
        LAST_RUN=$(cat "$LAST_RUN_FILE")
        if [ "$LAST_RUN" == "$CURRENT_DATE" ]; then
            echo "Daily maintenance already completed today ($CURRENT_DATE)"
            exit 0
        fi
    fi
fi

# --- Concurrency lock -------------------------------------------------------
# RunAtLoad (login catch-up) and the 9AM StartCalendarInterval can fire close
# together; without a lock both runs proceed and contend on zinit/bob/nvim
# state. mkdir is atomic; the PID + age check clears stale locks left behind
# by a crash or power loss (otherwise maintenance silently never runs again).
LOCK_DIR="$HOME/.cache/dotfiles/daily-maintenance.lock"
LOCK_MAX_AGE_SECONDS=21600  # 6 hours

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_DIR")"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid"
        trap 'rm -rf "$LOCK_DIR"' EXIT
        return 0
    fi

    local pid lock_mtime now age
    pid=$(cat "$LOCK_DIR/pid" 2>/dev/null)
    lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$((now - lock_mtime))

    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$age" -lt "$LOCK_MAX_AGE_SECONDS" ]; then
        echo "Daily maintenance already running (pid $pid, lock age ${age}s); exiting."
        exit 0
    fi

    echo "Clearing stale lock (pid ${pid:-unknown} not alive or age ${age}s > ${LOCK_MAX_AGE_SECONDS}s)"
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid"
        trap 'rm -rf "$LOCK_DIR"' EXIT
        return 0
    fi
    echo "Could not acquire lock after clearing stale one; exiting."
    exit 1
}
acquire_lock

# --- Log rotation ------------------------------------------------------------
# launchd appends to StandardOutPath/StandardErrorPath forever. Rotate with
# copy+truncate (not rename) because THIS process is writing to the same fd:
# truncating keeps the O_APPEND fd valid, a rename would send the whole run
# into the .1 file.
rotate_log() {
    local log_file="$1"
    local max_bytes=$((5 * 1024 * 1024))  # 5 MB
    local size
    [ -f "$log_file" ] || return 0
    size=$(stat -f %z "$log_file" 2>/dev/null || echo 0)
    if [ "$size" -gt "$max_bytes" ]; then
        cp "$log_file" "$log_file.1" 2>/dev/null && : > "$log_file"
        echo "Rotated $(basename "$log_file") (${size} bytes -> ${log_file##*/}.1)"
    fi
}
rotate_log "$HOME/Library/Logs/daily-maintenance.log"
rotate_log "$HOME/Library/Logs/daily-maintenance-error.log"

echo "========================================="
echo "Starting daily maintenance: $(date)"
echo "========================================="

# Set up PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Shared helpers (dm_herdr_strand_detected lives here so it can be
# unit-tested by test-dotfiles.sh)
# shellcheck source=daily-maintenance-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/daily-maintenance-lib.sh"

# Set up timeout command (macOS uses gtimeout from coreutils)
if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
else
    TIMEOUT_CMD=""
fi

# Function to run command with optional timeout.
#
# --foreground when a TTY is attached, and only then. Without it, timeout puts
# the command in its own process group, which means a `sudo` further down (a
# cask that removes a launchctl service, say) cannot take control of the
# terminal: the password prompt appears with echo still ON and the typed
# password never reaches sudo. The symptom is a prompt that shows your
# keystrokes and then rejects them, which looks like a wrong password.
#
# The trade-off is real, which is why this is conditional: with --foreground
# only the direct child is timed out, so a stalled grandchild can hang the run.
# That protection matters most in the unattended launchd run, and there is no
# TTY there anyway (nor anyone to answer a prompt), so the strict form is used.
run_with_timeout() {
    local seconds="$1"
    shift
    if [ -z "$TIMEOUT_CMD" ]; then
        "$@"
    elif [ -t 0 ] && [ -t 1 ]; then
        $TIMEOUT_CMD --foreground "$seconds" "$@"
    else
        $TIMEOUT_CMD "$seconds" "$@"
    fi
}

BOB_REPO="https://github.com/MordechaiHadad/bob"
BOB_BRANCH="dev"
BOB_BIN="$HOME/.cargo/bin/bob"
BOB_SHA_CACHE="$HOME/.cache/dotfiles/bob-dev-sha"

# Function to self-update Bob from its git dev branch.
#
# Why dev and not master/crates.io: upstream has shipped the proxy
# permission fix (commit c18ba0a, "Changed: permissions to be write for
# nvim proxy") on the dev branch, but not yet on master, crates.io, or
# any tagged release. Homebrew lags the same way. We pin to dev until
# the next release cuts.
#
# SHA caching: `cargo install --git --force` rebuilds every run (~1min),
# so we short-circuit when the remote dev HEAD matches the cached SHA.
# The cache lives at ~/.cache/dotfiles/bob-dev-sha and is seeded on the
# first successful build. If the cache is missing we still run cargo,
# which is the correct no-op for a fresh machine.
update_bob_self() {
    echo ""
    echo "----------------------------------------"
    echo "Task: Bob self-update (cargo git dev)"

    if ! command -v cargo >/dev/null 2>&1; then
        echo "Status: ⚠ SKIPPED (cargo not installed)"
        return 0
    fi

    local remote_sha
    remote_sha=$(run_with_timeout 15 git ls-remote "$BOB_REPO.git" "refs/heads/$BOB_BRANCH" 2>/dev/null | awk '{print $1}')
    if [ -z "$remote_sha" ]; then
        echo "Status: ⚠ SKIPPED (could not reach $BOB_REPO)"
        return 0
    fi

    # Read the cached SHA, but only trust it if it's a well-formed
    # 40-char hex string. An empty or corrupt cache file (e.g. from a
    # killed run, disk-full, or manual mis-edit) gets discarded so the
    # next equality check fails cleanly and we rebuild.
    local cached_sha=""
    if [ -f "$BOB_SHA_CACHE" ]; then
        cached_sha=$(cat "$BOB_SHA_CACHE" 2>/dev/null)
        [[ "$cached_sha" =~ ^[0-9a-f]{40}$ ]] || cached_sha=""
    fi

    if [ -x "$BOB_BIN" ] && [ "$cached_sha" = "$remote_sha" ]; then
        echo "Status: ✓ up to date (${remote_sha:0:7})"
        return 0
    fi

    echo "Command: cargo install --git $BOB_REPO --branch $BOB_BRANCH --locked --force"
    echo -n "Status: "
    if ! run_with_timeout 300 cargo install --git "$BOB_REPO" --branch "$BOB_BRANCH" --locked --force >/dev/null 2>&1; then
        echo "✗ FAILED"
        FAILED_COMMANDS+=("bob self-update (cargo install)")
        return 1
    fi
    # Atomic cache write: a kill between the open and the final byte
    # would otherwise leave a half-written cache file that fails the
    # hex regex on the next run (forcing a redundant rebuild).
    mkdir -p "$(dirname "$BOB_SHA_CACHE")"
    printf '%s\n' "$remote_sha" > "$BOB_SHA_CACHE.tmp" \
        && mv "$BOB_SHA_CACHE.tmp" "$BOB_SHA_CACHE"
    echo "✓ built ${remote_sha:0:7}"
}

# Function to update Bob (Neovim version manager) nightly.
#
# Root causes this fixes:
#   1. `bob use` writes the proxy at ~/.local/share/bob/nvim-bin/nvim
#      with mode 555, so the NEXT `bob use` cannot overwrite it and
#      errors with "Failed to copy file". `chmod u+w` before every
#      `bob use` is the fix. (Fixed upstream on dev, kept defensively.)
#   2. `bob update nightly` warns "nightly is not installed" when the
#      tracked install is only a legacy hash-suffixed dir. `bob install
#      nightly` is the idempotent replacement that works in both states.
#   3. Legacy `nightly-<hash>/` dirs from older bob versions accumulate
#      forever; current bob installs into a single `nightly/` dir and
#      `bob rollback` does not need the hash dirs. GC'd unconditionally.
update_bob_nightly() {
    local bob_bin="$BOB_BIN"
    # bob's dev branch moved its data dir to the macOS-native location
    # in July 2026 — prefer it, fall back to the legacy path (the wrong
    # target made the chmod proxy-fix a no-op and left nightly wedged)
    local bob_dir="$HOME/Library/Application Support/bob"
    [ -d "$bob_dir" ] || bob_dir="$HOME/.local/share/bob"
    local nvim_proxy="$bob_dir/nvim-bin/nvim"

    echo ""
    echo "----------------------------------------"
    echo "Task: Bob (Neovim version manager) nightly update"

    if [ ! -x "$bob_bin" ]; then
        echo "Status: ⚠ SKIPPED (bob not installed)"
        return 0
    fi

    # A running nvim has the proxy binary mmap'd; overwriting it would
    # hit ETXTBSY regardless of file permissions. Skip the whole phase
    # rather than risk a corrupt proxy.
    local nvim_pids
    nvim_pids=$(pgrep -x nvim 2>/dev/null | tr '\n' ' ')
    if [ -n "$nvim_pids" ]; then
        echo "Status: ⚠ SKIPPED (nvim running, pids: ${nvim_pids% })"
        return 0
    fi

    # Make the proxy writable so `bob use` can overwrite it. Bob ships
    # it at mode 555 - this is the whole reason this function exists.
    if [ -e "$nvim_proxy" ]; then
        chmod u+w "$nvim_proxy" 2>/dev/null || true
    fi

    echo "Command: bob install nightly"
    echo -n "Status: "
    if ! "$bob_bin" install nightly >/dev/null 2>&1; then
        echo "✗ FAILED"
        FAILED_COMMANDS+=("bob install nightly")
        return 1
    fi
    echo "✓ SUCCESS"

    echo "Command: bob use nightly"
    echo -n "Status: "
    if ! "$bob_bin" use nightly >/dev/null 2>&1; then
        echo "✗ FAILED"
        FAILED_COMMANDS+=("bob use nightly")
        return 1
    fi
    echo "✓ SUCCESS"

    # Prove the new build actually launches via the proxy.
    echo "Command: $nvim_proxy --version"
    echo -n "Status: "
    local nvim_version
    nvim_version=$(run_with_timeout 5 "$nvim_proxy" --version 2>/dev/null | head -1)
    if [[ "$nvim_version" != NVIM* ]]; then
        echo "✗ FAILED (unexpected: ${nvim_version:-<empty>})"
        FAILED_COMMANDS+=("bob: nvim verification failed")
        return 1
    fi
    echo "✓ $nvim_version"

    # GC: remove every legacy `nightly-<hash>` dir. Current bob installs
    # into `nightly/` only, so anything hash-suffixed is an orphan from
    # an older bob version. We `rm -rf` directly instead of calling
    # `bob uninstall` - tested empirically, `bob uninstall nightly-<hash>`
    # misinterprets the name and deletes the ACTIVE nightly/ dir while
    # reporting success. Bob reads installs from the filesystem on each
    # invocation, so filesystem removal is the whole story.
    #
    # The prefix check is a belt-and-braces guard against a malformed
    # $bob_dir. Only runs after verification passes.
    local -a legacy=()
    local dir
    for dir in "$bob_dir"/nightly-*; do
        [ -d "$dir" ] && legacy+=("$dir")
    done

    if [ "${#legacy[@]}" -eq 0 ]; then
        return 0
    fi

    echo "Command: rm -rf legacy nightly hash-dirs (${#legacy[@]})"
    echo -n "Status: "
    local erased=0
    local failed=0
    for dir in "${legacy[@]}"; do
        if [[ "$dir" != "$bob_dir"/nightly-* ]]; then
            failed=$((failed + 1))
            echo ""
            echo "  ⚠ refusing to remove unexpected path: $dir"
            continue
        fi
        if rm -rf "$dir" 2>/dev/null; then
            erased=$((erased + 1))
        else
            failed=$((failed + 1))
            echo ""
            echo "  ⚠ could not remove $(basename "$dir")"
        fi
    done
    if [ "$failed" -eq 0 ]; then
        echo "✓ erased $erased legacy build(s)"
    else
        echo "⚠ erased $erased, failed $failed"
        FAILED_COMMANDS+=("bob: GC partial ($failed failed)")
    fi
}

# Function to run command and check status
run_command() {
    local description="$1"
    shift

    echo ""
    echo "----------------------------------------"
    echo "Task: $description"
    echo "Command: $*"
    echo -n "Status: "

    # Execute the args directly ("$@" keeps quoting intact; the old
    # 'local command="$*"; $command' re-split every argument)
    if "$@"; then
        echo "✓ SUCCESS"
        return 0
    else
        local exit_code=$?
        if [ "$exit_code" -eq 124 ]; then
            # exit 124 = killed by run_with_timeout's watchdog, not a
            # failure of the command itself — keep the two distinguishable
            echo "✗ TIMED OUT (killed by watchdog after the time limit, exit 124)"
        else
            echo "✗ FAILED (exit code: $exit_code)"
        fi
        return $exit_code
    fi
}

# Keep track of failures
FAILED_COMMANDS=()

# Run your daily maintenance commands
# 900s timeout: a stalled network otherwise hangs the whole run (the other
# network steps are already wrapped; brew was the only unguarded one)
# herdr LEFT Homebrew 2026-08-05 (self-updater managed; see
# docs/herdr-setup.md), so brew can no longer change its version and
# this check is normally a no-op. It stays as a TRIPWIRE: if a brew
# copy is ever mistakenly reinstalled (shadow-racing ~/.local/bin) and
# auto-upgraded, the version delta below catches it the same morning.
# 'herdr --version' reads the binary only — it never auto-starts a server.
HERDR_VERSION_BEFORE="$(herdr --version 2>/dev/null || true)"
if ! run_command "Homebrew formula upgrade" run_with_timeout 900 brew upgrade --yes; then
    FAILED_COMMANDS+=("brew upgrade")
fi

# Tripwire evaluation (see the capture comment above): herdr's wire
# protocol refuses attach on ANY version mismatch, so an unexpected bump
# strands a still-running server. NEVER kill it here — the owner may be
# in a live session, and no herdr CLI may be called (it could auto-start
# a server inheriting this launchd environment). Detect via the socket
# and notify; agent panes resume natively after the owner restarts.
HERDR_VERSION_AFTER="$(herdr --version 2>/dev/null || true)"
if dm_herdr_strand_detected "$HERDR_VERSION_BEFORE" "$HERDR_VERSION_AFTER"; then
    echo "herdr upgraded ($HERDR_VERSION_BEFORE -> $HERDR_VERSION_AFTER) with a live server."
    echo "Attach will be refused until the server restarts (herdr server stop; herdr)."
    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "herdr upgraded" \
            -message "Server still on $HERDR_VERSION_BEFORE. When convenient: herdr server stop, then herdr (agents auto-resume)." \
            >/dev/null 2>&1 || true
    fi
fi

# Self-heal: remove leftover *.upgrading cask staging dirs from a previously
# interrupted/failed upgrade, so they can't block this run with an
# "already an App at ..." error.
caskroom="$(brew --prefix)/Caskroom"
if [ -d "$caskroom" ]; then
    leftovers="$(find "$caskroom" -maxdepth 2 -name '*.upgrading' -type d 2>/dev/null)"
    if [ -n "$leftovers" ]; then
        echo "Removing stale cask .upgrading leftovers:"
        echo "$leftovers"
        find "$caskroom" -maxdepth 2 -name '*.upgrading' -type d -exec rm -rf {} + 2>/dev/null
    fi
fi

# Upgrade casks. --greedy-latest also covers version-less (:latest) casks that
# plain "brew upgrade" skips; --yes skips Homebrew 6's confirmation prompt so
# the run stays unattended. Verified via --dry-run: auto_updates apps
# (VS Code) are NOT touched at this level -- that needs --greedy or
# --greedy-auto-updates, which must never be added here (a self-updated
# app can drift past the cask checksum; test-dotfiles.sh asserts this).
if ! run_command "Homebrew cask upgrade (greedy-latest)" run_with_timeout 900 brew upgrade --cask --greedy-latest --yes; then
    FAILED_COMMANDS+=("brew upgrade --cask --greedy-latest")
    # Most common cause of a cask failure: its app in /Applications is owned by
    # root (usually from a past "sudo brew"), so Homebrew needs sudo to replace
    # it. Surface the one-line fix instead of a cryptic "already an App" error.
    echo "Hint: a failed cask is often a root-owned /Applications app."
    echo "      Check: ls -ld \"/Applications/<App>.app\""
    echo "      Fix:   sudo chown -R \"$(whoami):staff\" \"/Applications/<App>.app\"  (never run 'sudo brew')"
fi

# Clean broken completion symlinks before zinit update
ZINIT_COMPLETIONS="$HOME/.local/share/zinit/completions"
if [ -d "$ZINIT_COMPLETIONS" ]; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Clean broken completion symlinks"
    echo -n "Status: "
    # Find and remove broken symlinks
    broken_count=$(find "$ZINIT_COMPLETIONS" -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
    if [ "$broken_count" -gt 0 ]; then
        find "$ZINIT_COMPLETIONS" -type l ! -exec test -e {} \; -delete 2>/dev/null
        rm -f "$HOME/.zcompdump"*  # Force zcompdump regeneration
        echo "✓ Cleaned $broken_count broken symlinks"
    else
        echo "✓ No broken symlinks found"
    fi
fi

# For zinit, we need to ensure it's available
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [ -f "$ZINIT_HOME/zinit.zsh" ]; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Zinit update"
    echo "Command: zinit update --all --quiet"
    echo -n "Status: "

    # Run zinit update by sourcing directly (avoid zsh -i which can hang)
    if zsh -c "source '$ZINIT_HOME/zinit.zsh' && zinit update --all --quiet" >/dev/null 2>&1; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("zinit update")
    fi
else
    echo "Warning: zinit not found, skipping zinit update"
fi

# Update Oh-My-Zsh (provides macos plugin and OMZ libs)
OMZ_HOME="$HOME/.oh-my-zsh"
if [ -d "$OMZ_HOME" ]; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Oh-My-Zsh update"
    echo "Command: $OMZ_HOME/tools/upgrade.sh"
    echo -n "Status: "

    if env ZSH="$OMZ_HOME" DISABLE_UPDATE_PROMPT=true sh "$OMZ_HOME/tools/upgrade.sh" >/dev/null 2>&1; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("oh-my-zsh update")
    fi
else
    echo "Warning: Oh-My-Zsh not found, skipping OMZ update"
fi

update_bob_self
update_bob_nightly

# Mise-managed runtimes (node, python, ruby, go)
# `mise upgrade` keeps pinned ranges (e.g. python 3.13.x patches) without
# jumping major versions. Use `--bump` manually if you want to move to 3.14.
if command -v mise >/dev/null 2>&1; then
    if ! run_command "Mise runtime upgrade" mise upgrade; then
        FAILED_COMMANDS+=("mise upgrade")
    fi
else
    echo "Warning: mise not found, skipping runtime upgrade"
fi

# --- yadm repo hygiene ------------------------------------------------------
# The yadm bare repo grew to 31GB on this machine while the real content was
# 2MB. Two causes, both invisible to every general-purpose cleaner — mole's
# "Large files" scan reported "Nothing to clean" with 26GB sitting there,
# because to any such tool a .git/objects directory is legitimate repo data:
#
#   17.2GB  objects/pack/tmp_pack_*  — half-written packs left by a `git gc`
#                                      or repack that was KILLED partway.
#                                      git labels them "garbage" in
#                                      count-objects and never removes them.
#   8.6GB   unreachable loose objects — aborted adds, dropped stashes.
#
# It nearly filled a 228GB disk, and a full disk is what stopped every tool
# on this machine from working at all.
#
# tmp_pack_* removal is guarded on no git process running: deleting those
# from UNDER a live repack is how you corrupt a repo. `git gc` itself is
# left to the human — running it unattended is what created this mess, and
# an interrupted gc makes the problem bigger, not smaller.
if command -v yadm >/dev/null 2>&1; then
    _ym_dir=$(yadm introspect repo 2>/dev/null)
    if [ -n "$_ym_dir" ] && [ -d "$_ym_dir" ]; then
        _ym_stats=$(GIT_DIR="$_ym_dir" git count-objects -v 2>/dev/null)
        _ym_garbage=$(printf '%s\n' "$_ym_stats" | awk '/^size-garbage:/{print $2+0}')
        _ym_loose=$(printf '%s\n' "$_ym_stats" | awk '/^size:/{print $2+0}')
        _ym_garbage=${_ym_garbage:-0}; _ym_loose=${_ym_loose:-0}

        if [ "$_ym_garbage" -gt 0 ] 2>/dev/null; then
            dm_pack_garbage_clean "$_ym_dir" || true
        fi

        # Loose objects: run PLAIN `git gc`, whose default expiry is
        # 2.weeks.ago. That was the false dichotomy in the first version —
        # it framed the choice as `--prune=now` (which destroys the
        # `git fsck --unreachable` net that recovered real work here) or
        # never pruning at all (which leaves an unbounded pile that simply
        # refills). git's own default keeps a fortnight of unreachable
        # objects and reclaims what is older, so the net survives by
        # construction and the steady state is bounded.
        #
        # Warning only about what SURVIVES a gc, because a daily entry in
        # FAILED_COMMANDS that no safe action can clear turns the whole
        # maintenance report into noise.
        if [ "$_ym_loose" -gt 1048576 ] 2>/dev/null; then
            echo "yadm repo: $((_ym_loose / 1048576))GB loose objects, running git gc (keeps 2 weeks)"
            GIT_DIR="$_ym_dir" run_with_timeout 600 git gc >/dev/null 2>&1 || true
            _ym_loose=$(GIT_DIR="$_ym_dir" git count-objects -v 2>/dev/null | awk '/^size:/{print $2+0}')
            if [ "${_ym_loose:-0}" -gt 1048576 ] 2>/dev/null; then
                echo "⚠️  $((_ym_loose / 1048576))GB of loose objects survived gc — younger than the"
                echo "    2-week expiry, or still reachable. Inspect before forcing anything:"
                echo "    GIT_DIR=$_ym_dir git fsck --unreachable | head"
                FAILED_COMMANDS+=("yadm repo still $((_ym_loose / 1048576))GB loose after gc")
            fi
        fi
        unset _ym_dir _ym_stats _ym_garbage _ym_loose
    fi
fi

# Update yazi packages (plugins and flavors)
if command -v ya >/dev/null 2>&1; then
    # Count the drift before repairing it, because --discard removes the
    # only signal we had. See dm_yazi_drift_repair for why the signal was
    # worth converting rather than keeping.
    if drift=$(dm_yazi_drift_repair "$HOME/.config/yazi"); then
        echo "Yazi: $drift"
    fi

    # --discard is REQUIRED, not a convenience. `ya pkg` refuses to deploy
    # over a directory whose contents differ from the hash it recorded, and
    # that check has no way to distinguish a hand-edit from a lockfile that
    # drifted out of step with the tree. These directories are declared
    # build artifacts (.gitignore, and the bootstrap that rebuilds them), so
    # there is no hand-edit to protect — the guard only fires on drift.
    #
    # Its failure mode is not one red task. The abort stops the whole run at
    # the FIRST mismatched package, so every package after it is skipped and
    # never reported: measured 8 of 12 verifiable packages out of step while
    # the log named only `git.yazi`. And it cannot self-heal, so the same
    # failure repeats every day until someone runs the command by hand.
    if ! run_command "Yazi package upgrade" ya pkg upgrade --discard; then
        FAILED_COMMANDS+=("ya pkg upgrade")
    fi
else
    echo "Warning: ya not found, skipping yazi package upgrade"
fi

# Update LazyVim plugins
if command -v nvim >/dev/null 2>&1; then
    echo ""
    echo "----------------------------------------"
    echo "Task: LazyVim plugin updates"
    echo "Command: nvim --headless '+Lazy! sync' +qa"
    echo -n "Status: "

    # Run Neovim in headless mode to update LazyVim plugins
    # --headless: Run without UI
    # '+Lazy! sync': Run Lazy sync command (! means no prompts)
    # +qa: Quit all windows
    # timeout: Prevent hanging from async plugin operations
    if run_with_timeout 120 nvim --headless "+Lazy! sync" +qa 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("LazyVim update")
    fi

    # Update treesitter parsers
    # This keeps parsers in sync with nvim-treesitter queries
    # Required for noice.nvim cmdline and other treesitter-dependent plugins
    echo ""
    echo "----------------------------------------"
    echo "Task: Treesitter parser updates"
    echo "Command: nvim --headless '+TSUpdate' +qa"
    echo -n "Status: "

    if run_with_timeout 120 nvim --headless "+TSUpdate" "+sleep 10" +qa 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("Treesitter update")
    fi
else
    echo "Warning: Neovim not found, skipping LazyVim updates"
fi

# Clean up old Homebrew versions and cache
if command -v brew >/dev/null 2>&1; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Homebrew cleanup"
    echo "Command: brew cleanup --prune=all"
    echo -n "Status: "
    
    # Run cleanup to remove old versions and clear cache
    # --prune=all removes all cache entries
    if brew cleanup --prune=all 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("brew cleanup")
    fi

    echo ""
    echo "----------------------------------------"
    echo "Task: Remove orphaned dependencies"
    echo "Command: brew autoremove"
    echo -n "Status: "

    if brew autoremove 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("brew autoremove")
    fi
fi

# --- Config schema checks ---------------------------------------------------
# Daily auto-upgrades can silently break a tool's config schema: a past yazi
# upgrade renamed a config field and yazi fell back to preset settings for
# weeks without saying a word. Each check below asks the tool itself to parse
# its tracked config, so a schema break surfaces the day the upgrade lands
# instead of months later.
# Verified 2026-08-04: 'yazi --version' exits 1 on a broken yazi.toml
# (0 when clean), so it does catch the id->group class of breakage.
echo ""
echo "----------------------------------------"
echo "Task: Config schema checks"

if command -v yazi >/dev/null 2>&1; then
    echo -n "Status: yazi (yazi --version) "
    if yazi --version >/dev/null 2>&1; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("schema check: yazi")
    fi
fi

if command -v zellij >/dev/null 2>&1; then
    echo -n "Status: zellij (zellij setup --check) "
    if zellij setup --check >/dev/null 2>&1; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("schema check: zellij")
    fi
fi

if command -v atuin >/dev/null 2>&1; then
    echo -n "Status: atuin (atuin doctor) "
    if atuin doctor >/dev/null 2>&1; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("schema check: atuin")
    fi
fi

# Parse .tmux.conf on a throwaway server socket so a live session is never
# touched; the server is killed again immediately.
if command -v tmux >/dev/null 2>&1; then
    echo -n "Status: tmux (throwaway-server parse) "
    if tmux -L schemacheck -f "$HOME/.tmux.conf" new-session -d 2>/dev/null \
        && tmux -L schemacheck kill-server 2>/dev/null; then
        echo "✓ SUCCESS"
    else
        echo "✗ FAILED"
        FAILED_COMMANDS+=("schema check: tmux")
    fi
fi

# --- Time Machine backup age ------------------------------------------------
# AutoBackup was turned off 2026-08-16 so local snapshots would stop consuming
# the internal disk while the T7 is unplugged. That trade puts backups back on
# human memory — which is exactly how the previous gap reached ELEVEN MONTHS
# (2025-09-16 → 2026-08-15, found by a health check, not by noticing).
# This is the replacement for remembering.
#
# Source is SnapshotDates, NOT `tmutil latestbackup`: that command needs the
# destination MOUNTED, so it fails precisely when the warning matters most.
# LastBackupActivity is no good either — it records attempts, so it reads
# "today" even when nothing was backed up. SnapshotDates holds completed
# backups per destination, and is untouched by `tmutil deletelocalsnapshots`
# (verified 2026-08-16 after deleting all 7 local snapshots). The plist is
# world-readable, so this needs no sudo.
# Both overridable so test-dotfiles.sh can point at a fixture plist and drive
# the stale/never/no-destination branches without touching real backup state.
TM_PLIST="${TM_PLIST:-/Library/Preferences/com.apple.TimeMachine.plist}"
# 30 days: the backup target is an external T7 that is not always plugged in,
# so a weekly threshold would cry wolf on ordinary travel and get ignored —
# the failure mode that matters here is a warning nobody reads. The gap this
# guards against was 330 days, so 30 still catches it an order of magnitude
# earlier while only firing when something is genuinely wrong.
TM_WARN_DAYS="${TM_WARN_DAYS:-30}"
if [ -r "$TM_PLIST" ] && [ -x /usr/libexec/PlistBuddy ]; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Time Machine backup age"

    tm_latest=0
    tm_i=0
    tm_alert=""
    while /usr/libexec/PlistBuddy -c "Print :Destinations:$tm_i:DestinationID" \
            "$TM_PLIST" >/dev/null 2>&1; do
        tm_date=$(/usr/libexec/PlistBuddy \
            -c "Print :Destinations:$tm_i:SnapshotDates" "$TM_PLIST" 2>/dev/null \
            | sed -n 's/^ *\([A-Z][a-z][a-z] .*\)$/\1/p' | tail -1)
        if [ -n "$tm_date" ]; then
            # LC_ALL=C because launchd hands this script a minimal environment
            # and the month/day names in the plist are always English.
            tm_epoch=$(LC_ALL=C date -j -f "%a %b %d %H:%M:%S %Z %Y" \
                "$tm_date" +%s 2>/dev/null)
            # %Z rejects NUMERIC zone abbreviations, and PlistBuddy renders the
            # date in whatever zone the Mac is currently in. Singapore, Kuala
            # Lumpur, Bangkok, Ho Chi Minh and Dubai all print "+08"/"+07"/"+04"
            # and fail to parse; Taipei, Tokyo, Sydney and London are fine.
            # Auto-timezone is on, so a flight is enough to trigger it.
            #
            # Without this line an unparseable date and a genuinely never-backed-
            # up destination produce the SAME message, and the output points away
            # from the cause. The real fix is to stop round-tripping through a
            # formatted string (plutil emits ISO-8601 UTC, no zone abbreviation
            # anywhere); that is a parsing change and gets its own commit.
            if [ -z "$tm_epoch" ]; then
                echo "  ⚠️  Could not parse backup date: $tm_date"
                echo "      (numeric zone abbreviation? %Z cannot read those)"
            fi
            if [ -n "$tm_epoch" ] && [ "$tm_epoch" -gt "$tm_latest" ]; then
                tm_latest="$tm_epoch"
            fi
        fi
        tm_i=$((tm_i + 1))
    done

    if [ "$tm_i" -eq 0 ]; then
        echo "  No Time Machine destination configured — nothing to check."
    elif [ "$tm_latest" -eq 0 ]; then
        echo "  ⚠️  A destination is configured but has NEVER completed a backup."
        tm_alert="Time Machine has never completed a backup"
    else
        tm_age=$(( ( $(date +%s) - tm_latest ) / 86400 ))
        echo "  Last completed backup: $(date -r "$tm_latest" '+%Y-%m-%d %H:%M')" \
             "(${tm_age}d ago, warn at ${TM_WARN_DAYS}d)"
        if [ "$tm_age" -ge "$TM_WARN_DAYS" ]; then
            echo "  ⚠️  Stale — connect the T7 and run: tmutil startbackup"
            tm_alert="Last backup was ${tm_age} days ago"
        fi
    fi

    # Its own notification rather than FAILED_COMMANDS: nothing here FAILED,
    # and folding it into the failure list would report a healthy run as
    # broken (and bury the one line that matters under task names).
    if [ -n "$tm_alert" ] && command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier \
            -title "Time Machine: backup is stale" \
            -message "$tm_alert — connect the T7, then: tmutil startbackup" \
            >/dev/null 2>&1 || true
    fi
fi

# --- Orphaned LaunchAgents / LaunchDaemons ----------------------------------
# An uninstaller that removes the .app but leaves its LaunchAgent behind
# creates a job that fails at every login, forever, and tells nobody: launchd
# records a non-zero exit and moves on. Two were found on 2026-08-16 by
# scanning for this by hand — com.jetbrains.toolbox (exit 78 at every boot
# since the app was removed) and com.symless.synergy3 — plus com.logi
# .cp-dev-mgr the day before. All three were left by app removals.
#
# The check is the whole reason this is automated: a silently failing job
# produces no symptom the owner would ever notice, so it needs something that
# looks on a schedule rather than a habit of looking.
#
# Only ABSOLUTE program paths are judged. A relative path (Contents/Helpers/…)
# is resolved against a bundle this script cannot identify, and guessing would
# report every well-formed BTM agent as broken.
# On a centrally managed machine the system-wide dirs belong to the management
# stack, not to you. An entry there is reinstated after removal, and taking the
# wrong one out can break enrolment — so the advice printed below ("bootout,
# then delete") is actively harmful there. It is also aimed at the gui/ domain,
# which is not where a LaunchDaemon lives. Judge only the agents the user owns,
# unless a scope was set explicitly. `profiles` needs no sudo and answers in
# well under a second; if it is missing or silent we keep the full scan.
if [ -z "${LAUNCHD_SCAN_DIRS:-}" ] &&
   profiles status -type enrollment 2>/dev/null | grep -q "MDM enrollment: Yes"; then
    LAUNCHD_SCAN_DIRS="$HOME/Library/LaunchAgents"
    LAUNCHD_SCOPE_NOTE="managed machine — scanning your own LaunchAgents only"
fi
LAUNCHD_SCAN_DIRS="${LAUNCHD_SCAN_DIRS:-/Library/LaunchAgents /Library/LaunchDaemons $HOME/Library/LaunchAgents}"
if [ -x /usr/libexec/PlistBuddy ]; then
    echo ""
    echo "----------------------------------------"
    echo "Task: Orphaned LaunchAgents/Daemons"
    [ -n "${LAUNCHD_SCOPE_NOTE:-}" ] && echo "  (${LAUNCHD_SCOPE_NOTE})"

    orphan_count=0
    stale_count=0
    orphan_names=""
    for scan_dir in $LAUNCHD_SCAN_DIRS; do
        [ -d "$scan_dir" ] || continue
        for plist in "$scan_dir"/*.plist; do
            [ -f "$plist" ] || continue
            prog=$(/usr/libexec/PlistBuddy -c "Print :Program" "$plist" 2>/dev/null)
            if [ -z "$prog" ]; then
                prog=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null)
            fi
            # BundleProgram is the third documented way to name the executable.
            # No plist on this machine uses it today (checked all 36), so this
            # costs nothing now and stops the scan going blind if one appears.
            if [ -z "$prog" ]; then
                prog=$(/usr/libexec/PlistBuddy -c "Print :BundleProgram" "$plist" 2>/dev/null)
            fi
            case "$prog" in
                /*) ;;      # absolute — judgeable
                *)  continue ;;
            esac
            # TWO CAUSES WEAR THIS SYMPTOM AND THEY NEED OPPOSITE REMEDIES.
            # A program missing because the app was uninstalled is an
            # orphan: delete it. A program missing because a VERSIONED path
            # moved — a Homebrew Cellar directory replaced by an upgrade —
            # is a working service with a stale path, and deleting it
            # throws the service away. Measured here 2026-08-26:
            # com.nickboy.herddeck.daemon named
            # /opt/homebrew/Cellar/bun/1.3.14/bin/bun and stopped the day
            # bun became 1.4.0, while the binary sat at
            # /opt/homebrew/bin/bun the entire time. Printing one remedy
            # for both would have had the service deleted.
            #
            # The tell is cheap: does a binary of the same NAME still
            # exist? PATH here has /opt/homebrew/bin (set in the plist AND
            # at the top of this script) but NOT ~/.local/bin or
            # ~/.cargo/bin, so those are probed directly rather than
            # trusted to a PATH that launchd trims.
            verdict=$(dm_launchd_classify "$prog")
            if [ "$verdict" != "ok" ]; then
                label=$(basename "$plist" .plist)
                prog_name=$(basename "$prog")
                replacement=""
                case "$verdict" in
                    stale\ *)           replacement=${verdict#stale } ;;
                    stale-unrelated\ *) replacement=${verdict#stale-unrelated } ;;
                esac
                if [ -n "$replacement" ]; then
                    echo "  ⚠️  $label — STALE PATH, not an orphan"
                    echo "      → $prog (missing)"
                    case "$verdict" in
                        stale-unrelated\ *)
                            echo "      → a program named $prog_name exists at $replacement,"
                            echo "        but NOT in the same install tree — verify before repointing" ;;
                        *)
                            echo "      → $prog_name is at $replacement — repoint, do not delete" ;;
                    esac
                    stale_count=$((stale_count + 1))
                else
                    echo "  ⚠️  $label"
                    echo "      → $prog (missing)"
                    orphan_count=$((orphan_count + 1))
                    orphan_names="${orphan_names}${orphan_names:+, }${label}"
                fi
            fi
        done
    done

    if [ "$stale_count" -gt 0 ]; then
        echo ""
        echo "  Repointing one: plutil -replace ProgramArguments.0 -string <new path>"
        echo "  <plist>, then bootout and bootstrap it. Prefer the stable symlink"
        echo "  (/opt/homebrew/bin/x) over a Cellar path, or the next upgrade"
        echo "  breaks it again the same way."
    fi
    if [ "$orphan_count" -eq 0 ]; then
        [ "$stale_count" -eq 0 ] && \
            echo "  None — every plist points at a program that exists."
    else
        echo ""
        echo "  Removing one: launchctl bootout gui/\$(id -u)/<label>, then delete"
        echo "  the plist — bootout alone lets it return at the next login."
        # Its own notification, not FAILED_COMMANDS: no task here failed, and
        # burying this in the failure list is how it stayed invisible before.
        if command -v terminal-notifier >/dev/null 2>&1; then
            terminal-notifier \
                -title "$orphan_count orphaned launchd job(s)" \
                -message "$orphan_names — see: ml" \
                >/dev/null 2>&1 || true
        fi
    fi
fi

# --- Machine-local extras ---------------------------------------------------
# Deliberately the LAST step. Anything here is specific to one machine — a work
# laptop needs steps touching remote hosts and corp tooling that must never land
# in this public repo — so it runs after everything shared has already
# succeeded, and a failure costs nothing but a line in the summary.
#
# Skipped under --auto: a launchd run has nobody present to answer an
# interactive prompt (2FA, sudo), and a blocked prompt would hang the timer.
LOCAL_EXTRAS="$HOME/.daily-maintenance.local"
if [ -f "$LOCAL_EXTRAS" ]; then
    if [[ "${1:-}" == "--auto" ]]; then
        echo ""
        echo "Skipping machine-local extras (--auto: nobody to answer prompts)"
    elif ! run_command "Machine-local extras" source "$LOCAL_EXTRAS"; then
        FAILED_COMMANDS+=("machine-local extras")
    fi
fi

echo ""
echo "========================================="
if [ ${#FAILED_COMMANDS[@]} -eq 0 ]; then
    echo "✓ Daily maintenance completed successfully!"
    # Record successful run
    echo "$CURRENT_DATE" > "$LAST_RUN_FILE"
else
    echo "⚠ Daily maintenance completed with errors:"
    for cmd in "${FAILED_COMMANDS[@]}"; do
        echo "  - $cmd failed"
    done
    # A failure that only lands in the log can stay silent for weeks —
    # the bob-nightly wedge lived in this branch for a month while the
    # log dutifully recorded it every day. Surface failures where the
    # owner actually looks.
    if command -v terminal-notifier >/dev/null 2>&1; then
        # Banner text truncates on long lists: lead with the 'ml' hint
        # (the part that must survive), cap the list at three tasks.
        FAIL_PREVIEW=$(printf '%s; ' "${FAILED_COMMANDS[@]:0:3}")
        if [ ${#FAILED_COMMANDS[@]} -gt 3 ]; then
            FAIL_PREVIEW="${FAIL_PREVIEW}+$(( ${#FAILED_COMMANDS[@]} - 3 )) more"
        fi
        terminal-notifier \
            -title "Daily maintenance: ${#FAILED_COMMANDS[@]} task(s) failed" \
            -message "details: ml — ${FAIL_PREVIEW}" \
            >/dev/null 2>&1 || true
    fi
    # Still record the run even with errors
    echo "$CURRENT_DATE" > "$LAST_RUN_FILE"
fi
echo "Time: $(date)"
echo "=========================================="
