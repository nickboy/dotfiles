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

echo "========================================="
echo "Starting daily maintenance: $(date)"
echo "========================================="

# Set up PATH to include homebrew
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Set up timeout command (macOS uses gtimeout from coreutils)
if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
else
    TIMEOUT_CMD=""
fi

# Function to run command with optional timeout
run_with_timeout() {
    local seconds="$1"
    shift
    if [ -n "$TIMEOUT_CMD" ]; then
        $TIMEOUT_CMD "$seconds" "$@"
    else
        "$@"
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

    local cached_sha=""
    [ -f "$BOB_SHA_CACHE" ] && cached_sha=$(cat "$BOB_SHA_CACHE" 2>/dev/null)

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
    mkdir -p "$(dirname "$BOB_SHA_CACHE")"
    printf '%s\n' "$remote_sha" > "$BOB_SHA_CACHE"
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
    local bob_dir="$HOME/.local/share/bob"
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
    local command="$*"
    
    echo ""
    echo "----------------------------------------"
    echo "Task: $description"
    echo "Command: $command"
    echo -n "Status: "
    
    # Run the command
    if $command; then
        echo "✓ SUCCESS"
        return 0
    else
        local exit_code=$?
        echo "✗ FAILED (exit code: $exit_code)"
        return $exit_code
    fi
}

# Keep track of failures
FAILED_COMMANDS=()

# Run your daily maintenance commands
if ! run_command "Homebrew formula upgrade" brew upgrade; then
    FAILED_COMMANDS+=("brew upgrade")
fi

if ! run_command "Homebrew cask upgrade (greedy)" brew upgrade --cask --greedy; then
    FAILED_COMMANDS+=("brew upgrade --cask --greedy")
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

# Update yazi packages (plugins and flavors)
if command -v ya >/dev/null 2>&1; then
    if ! run_command "Yazi package upgrade" ya pkg upgrade; then
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
    # Still record the run even with errors
    echo "$CURRENT_DATE" > "$LAST_RUN_FILE"
fi
echo "Time: $(date)"
echo "=========================================="
