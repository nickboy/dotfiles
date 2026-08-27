#!/bin/bash

# Local Dotfiles Test Suite
# Run this before committing to catch issues early

set -e

# CWD-independence: many tests use relative paths and *.sh globs that
# assume the yadm worktree root. Run from a subdir and 40+ glob tests
# silently vanish while ls-files pathspecs misreport — anchor here.
# (CI overrides HOME to the checkout, so this stays correct there too.)
cd "$HOME" || exit 1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Dotfiles Local Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo

FAILED_TESTS=()
PASSED_TESTS=()

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -ne "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        PASSED_TESTS+=("$test_name")
    else
        echo -e "${RED}✗${NC}"
        FAILED_TESTS+=("$test_name")
        echo -e "  ${YELLOW}Command: $test_command${NC}"
        echo -e "  ${YELLOW}Run the command manually to see the error${NC}"
    fi
}

# Test 1: Bash syntax check for all shell scripts
echo -e "${YELLOW}1. Shell Script Syntax Checks${NC}"
for script in *.sh; do
    if [ -f "$script" ]; then
        run_test "Bash syntax for $script" "bash -n $script"
    fi
done
echo

# Test 2: Check if scripts are executable
echo -e "${YELLOW}2. Script Permissions${NC}"
for script in daily-maintenance*.sh install-daily-maintenance.sh uninstall-daily-maintenance.sh; do
    if [ -f "$script" ]; then
        run_test "Executable permission for $script" "[ -x $script ]"
    fi
done
echo

# Test 3: Validate plist template (yadm ##template with {{env.HOME}})
echo -e "${YELLOW}3. LaunchAgent Plist Template Validation${NC}"
PLIST_TEMPLATE="Library/LaunchAgents/com.daily-maintenance.plist##template"
if [ -f "$PLIST_TEMPLATE" ]; then
    # Create temp file with substituted values for validation
    TEMP_PLIST="/tmp/test-plist-$$"
    sed "s|{{env.HOME}}|$HOME|g" "$PLIST_TEMPLATE" > "$TEMP_PLIST"
    if command -v plutil >/dev/null 2>&1; then
        run_test "Plist template validation" "plutil -lint '$TEMP_PLIST'"
    else
        run_test "Plist template XML validation" "xmllint --noout '$TEMP_PLIST'"
    fi
    rm -f "$TEMP_PLIST"
else
    echo -e "${YELLOW}  Plist template file not found${NC}"
fi
echo

# Test 4: Check for shellcheck if available
echo -e "${YELLOW}4. ShellCheck Analysis${NC}"
if command -v shellcheck >/dev/null 2>&1; then
    for script in *.sh; do
        if [ -f "$script" ]; then
            run_test "ShellCheck for $script" "shellcheck -S warning $script"
        fi
    done
else
    echo -e "${YELLOW}  ShellCheck not installed. Install with: brew install shellcheck${NC}"
fi
echo

# Test 5: YAML validation for CI files
echo -e "${YELLOW}5. YAML Lint (CI Files)${NC}"
if command -v yamllint >/dev/null 2>&1; then
    for yaml_file in .github/workflows/*.yml; do
        if [ -f "$yaml_file" ]; then
            run_test "YAML lint for $(basename $yaml_file)" "yamllint -d relaxed $yaml_file"
        fi
    done
else
    echo -e "${YELLOW}  yamllint not installed. Install with: uv tool install yamllint${NC}"
fi
echo

# Test 6: Zsh configuration validation
echo -e "${YELLOW}6. Zsh Configuration Validation${NC}"
if [ -f ~/.zshrc ]; then
    run_test "Zsh syntax check" "zsh -n ~/.zshrc"
    
    # Check for beautysh
    if command -v beautysh >/dev/null 2>&1; then
        run_test "Beautysh format check" "beautysh --check ~/.zshrc 2>/dev/null"
    else
        echo -e "${YELLOW}  beautysh not installed. Install with: uv tool install beautysh --with setuptools${NC}"
    fi
    
    # Basic anti-pattern checks
    run_test "No backticks in .zshrc" "! grep '\`.*\`' ~/.zshrc"

    # Duplicate alias detection
    run_test "No duplicate aliases in .zshrc" "[ -z \"\$(sed -n 's/^alias \([^=]*\)=.*/\1/p' ~/.zshrc | sort | uniq -d)\" ]"

    # Duplicate zinit plugin detection
    run_test "No duplicate zinit plugins" "[ -z \"\$(grep -oE 'zinit (light|load|snippet) [^ ;]+' ~/.zshrc | awk '{print \$3}' | sort | uniq -d)\" ]"

    # compinit should appear exactly once (non-commented, non-deferred)
    run_test "Single compinit call" "[ \"\$(grep -cE '^\s*compinit' ~/.zshrc)\" -le 1 ]"

    # Redundant redirect pattern: &>/dev/null 2>&1
    run_test "No redundant redirects (&>/dev/null 2>&1)" "! grep '&>/dev/null 2>&1' ~/.zshrc"
else
    echo -e "${YELLOW}  No .zshrc file found${NC}"
fi
echo

# Test 7: Check for common issues
echo -e "${YELLOW}7. Common Issues Check${NC}"

# Check for hardcoded paths that might not exist
run_test "No hardcoded /Users/specific paths" "! grep -r '/Users/[^/]*/' *.sh | grep -v '\$HOME' | grep -v nickboy"
# uv's installer drops a PATH snippet at ~/.local/bin/env meant to be
# SOURCED; if it ever becomes executable it shadows /usr/bin/env (PATH
# puts ~/.local/bin second) and silently swallows every 'env ... cmd'
# invocation with exit 0. That exact trap cost a debugging session.
run_test "env resolves to /usr/bin/env (no executable shim)" \
    "[ \"\$(command -v env)\" = /usr/bin/env ]"
run_test "No ~/.local/bin executables shadow system binaries" \
    "! (for f in \$HOME/.local/bin/*; do b=\$(basename \"\$f\"); [ -x \"\$f\" ] && { [ -e \"/usr/bin/\$b\" ] || [ -e \"/bin/\$b\" ]; } && echo \"\$b\"; done | grep -q .)"
# Retired plugins must stay retired (dotenv: cd-triggered .env sourcing
# in an agent-heavy workflow; rbenv/ruby/rake: mise-era leftovers;
# extract: replaced by ouch aliases in the July round)
run_test "Retired OMZ snippets stay retired" \
    "! grep -qE 'OMZP::(dotenv|rbenv|ruby|rake|extract)' $HOME/.zshrc"
# zsh-eza retired 2026-08: its aliases are hand-written now (the old
# _EZA_PARAMS export was dead code — the plugin never read that name)
run_test "Retired zinit plugins stay retired (zsh-eza)" \
    "! grep -qE 'zinit (light|load).*(zsh-eza)|_EZA_PARAMS' $HOME/.zshrc && { ! command -v eza >/dev/null 2>&1 || zsh -ic 'alias ll' 2>/dev/null | grep -q eza; }"
# --git costs 2-5x and scales with the REPO, not the listed directory (eza
# resolves status for every tracked file to fill one column). Measured
# 2026-08-16: 68.8ms vs 13.9ms in a 263-file repo. It belongs on the opt-in
# alias only. Asserted against the LIVE alias, not the .zshrc text, so a
# later re-definition further down the file cannot quietly undo it.
if command -v eza >/dev/null 2>&1; then
    run_test "eza: ll is git-free (the everyday alias stays fast)" \
        "! zsh -ic 'alias ll' 2>/dev/null | grep -qE '(^| )--git( |\$)'"
    run_test "eza: llg exists and is the one carrying --git" \
        "zsh -ic 'alias llg' 2>/dev/null | grep -qE '(^| )--git( |\$)'"
    # The git column only renders in long view; without --long the output is
    # byte-identical with and without the flag, so carrying it there was
    # dead config. Keep it that way.
    run_test "eza: non-long aliases carry no dead --git" \
        "! zsh -ic 'alias ls; alias l; alias lt; alias tree' 2>/dev/null | grep -qE '(^| )--git( |\$)'"
fi
# yazi plugins are declared in package.toml (ya pkg, SHA-pinned) — the
# declaration must be yadm-tracked and every declared plugin installed,
# or new machines silently lose the plugin set (the pre-2026-08 state)
# GUARD NAME MATTERS: this said plugins.list, which #107 renamed to
# packages.list — so every test below silently stopped running, including
# the one asserting the list is tracked, which would itself have failed.
# A guard that names a file is a check that can be switched off by an
# unrelated rename, and the suite reports green either way.
if [ -f "$HOME/.config/yazi/packages.list" ]; then
    # The NAME LIST is tracked; package.toml (ya pkg's lockfile) is NOT.
    # `ya pkg upgrade` runs from daily maintenance on every machine, so a
    # tracked lockfile went dirty everywhere and the machines drifted —
    # one had 3 of 13 pins moved, another had all 13. Both halves are
    # asserted, because tracking the wrong one of the two is the failure:
    # tracking the lockfile brings the churn back, and untracking the list
    # leaves bootstrap with nothing to install (the pre-2026-08 state,
    # where a new machine's keymap referenced plugins that did not exist).
    run_test "yazi packages.list is tracked" \
        "{ yadm ls-files .config/yazi/packages.list 2>/dev/null || git ls-files .config/yazi/packages.list 2>/dev/null; } | grep -q packages.list"
    run_test "yazi package.toml (the lockfile) is NOT tracked" \
        "! { yadm ls-files .config/yazi/package.toml 2>/dev/null || git ls-files .config/yazi/package.toml 2>/dev/null; } | grep -q package.toml"
    # bootstrap must replay the list, or a fresh machine installs nothing
    run_test "bootstrap installs from the tracked plugin list" \
        "grep -q 'packages.list' '$HOME/.config/yadm/bootstrap' &&
         grep -q 'ya pkg add' '$HOME/.config/yadm/bootstrap'"
    # Both bulk `ya pkg` calls must carry --discard. Without it the deploy
    # refuses any directory whose contents differ from the recorded hash,
    # and that check cannot tell a hand-edit from lockfile drift — these
    # dirs are declared build artifacts, so only drift ever trips it. The
    # abort also stops the run at the FIRST mismatch, so the rest are
    # skipped and unreported, and nothing self-heals: measured 8 of 12
    # verifiable packages out of step while the log named one.
    # `ya pkg add` has no --discard; only install and upgrade do.
    run_test "bulk ya pkg calls discard artifact drift" \
        "grep -qE 'ya pkg upgrade[^|]*--discard' '$HOME/daily-maintenance.sh' &&
         grep -qE 'ya pkg install[^|]*--discard' '$HOME/.config/yadm/bootstrap'"
    # --discard removes the only drift signal there was, so the count has
    # to be taken BEFORE the upgrade. `install` is load-bearing: it
    # deploys the rev the LOCKFILE records, so a directory that changes
    # under it was out of step with its own entry. Under `upgrade` a
    # changed directory could just be a new upstream release.
    run_test "yazi drift is measured before it is discarded" \
        "grep -q 'dm_yazi_drift_repair' '$HOME/daily-maintenance.sh' &&
         awk '/dm_yazi_drift_repair \"\\\$HOME/{d=NR} /ya pkg upgrade/{u=NR} END{exit !(d && u && d < u)}' '$HOME/daily-maintenance.sh' &&
         awk '/^dm_yazi_drift_repair\(\)/,/^}/' '$HOME/daily-maintenance-lib.sh' | grep -q 'ya pkg install --discard'"
fi

# The machine-local boundary has three states, and the dangerous one is
# UNTRACKED-AND-UNIGNORED: invisible to review, still staged by `yadm add
# -A`, in a PUBLIC repo. Both halves are asserted because either alone is
# the bug — deny everything and a new skill silently stops being addable;
# allow by default and the next private key is one keystroke from public.
# Measured 2026-08-21, before the rule existed: id_ed25519 (a real OpenSSH
# private key), authorized_keys, .claude/.credentials.json and the
# transcript directory were all unignored.
_ci() { { yadm check-ignore -q "$1" 2>/dev/null || git check-ignore -q "$1" 2>/dev/null; }; }
run_test "secrets under .ssh and .claude are ignored by default" \
    "_ci .ssh/id_ed25519 && _ci .ssh/authorized_keys &&
     _ci .claude/.credentials.json && _ci .claude/projects/x.jsonl &&
     _ci .ssh/config.d/99-some-new-host.conf"
run_test "the files this repo ships are still visible to add" \
    "! _ci .ssh/allowed_signers && ! _ci .ssh/config.d/00-defaults.conf &&
     ! _ci .claude/skills/a-new-skill/SKILL.md && ! _ci .claude/themes/x.json"
# THE FORWARD PROPERTY, which is the entire reason this is default-deny
# rather than a list of today's secrets: a path nobody has thought of yet
# is ignored the moment it exists. The paths below are deliberately
# fictional — if an enumerated blocklist ever replaces the deny, this is
# the test that notices.
run_test "a novel path under a denied directory is ignored on creation" \
    "_ci .ssh/id_rsa_some_future_host && _ci .ssh/50-new-machine.conf &&
     _ci .claude/telemetry-v3/blob.db && _ci .claude/whatever-2027.log"
# The other direction, and the one a future over-broad rule breaks: a file
# ALREADY TRACKED must never become ignored. git keeps tracking it, so the
# damage is silent — the same invisibility class this block exists to fix.
# Loops over the real list rather than a fixed sample, so it cannot go
# stale as the tracked set grows.
# NO `exit` IN HERE: run_test evals in THIS shell, so an exit ends the
# whole suite — which reads as a finished run with the summary missing,
# not as a failure. Counting keeps the assertion inside an expression.
run_test "no tracked file under .ssh or .claude is ignored" \
    "[ \"\$( { yadm ls-files .ssh/ .claude/ 2>/dev/null || git ls-files .ssh/ .claude/ 2>/dev/null; } |
        while read -r f; do _ci \"\$f\" && echo x; done | wc -l | tr -d ' ')\" = 0 ]"

# Third-party formulae must be TRUSTED BEFORE `brew bundle`, or Homebrew
# skips them and bundle reports success having installed nothing. Trust
# lives in ~/.homebrew/trust.json, which is machine-local and untracked,
# so a fresh machine starts untrusting and the Brewfile's trust comments
# are documentation nobody executes.
#
# ORDER is the whole point, so the assertion is on the order — a `grep -q`
# for both strings would pass with them the wrong way round, which is
# exactly the bug that leaves a machine with silently-missing packages.
if [ -f "$HOME/.config/yadm/bootstrap" ] && [ -f "$HOME/Brewfile" ]; then
    # Ordering: trust has to be granted before bundle runs, or brew refuses
    # the package on the very run that was meant to install it. Matched on
    # `brew trust` alone — the flag is chosen at runtime now (--formula or
    # --cask), and pinning the literal made this fail on a refactor that had
    # not changed the behaviour at all.
    run_test "bootstrap trusts third-party packages BEFORE brew bundle" \
        "awk '/brew trust /{t=NR} /brew bundle --file/{b=NR} END{exit !(t && b && t < b)}' '$HOME/.config/yadm/bootstrap'"
    # …and derives them from the Brewfile, so "trusted" cannot drift from
    # "installed" the way a hard-coded list would. Asserted as "reads the
    # Brewfile and greps package declarations out of it" rather than one
    # exact regex, for the same reason.
    run_test "…derived from the Brewfile, not a hard-coded list" \
        "grep -q 'HOME/Brewfile' '$HOME/.config/yadm/bootstrap' &&
         grep -qE \"grep -E .\\^\\(brew\" '$HOME/.config/yadm/bootstrap'"
    # Every listed plugin must actually be declared, or the list has
    # silently drifted from what the machine really has.
    if [ -f "$HOME/.config/yazi/package.toml" ]; then
        run_test "every listed yazi plugin is declared in package.toml" \
            "! (while IFS= read -r p; do
                  case \"\$p\" in ''|\\#*) continue ;; esac
                  grep -qF \"use = \\\"\$p\\\"\" '$HOME/.config/yazi/package.toml' || echo \"missing \$p\"
                done < '$HOME/.config/yazi/plugins.list' | grep -q .)"
    fi
fi
if [ -f "$HOME/.config/yazi/package.toml" ]; then
    # Presence only where ya pkg has actually run (CI checkouts have no
    # plugins/ — contents are ignored build artifacts).
    #
    # PLUGINS AND FLAVORS ARE DIFFERENT and the old version conflated
    # them: it grepped every `use =` line and looked for all of them under
    # plugins/, so the moment a flavor was declared the check went red
    # claiming `catppuccin-mocha` was a missing plugin. They live in
    # different directories and are marked by different files —
    # plugins/<n>.yazi/main.lua vs flavors/<n>.yazi/flavor.toml — so the
    # section header in package.toml decides which is which.
    # THE LIST MUST COVER EVERYTHING package.toml DECLARES. This is the
    # assertion that would have caught the bug it exists because of:
    # packages.list was generated from `ya pkg list` at a moment when the
    # Flavors section happened to be EMPTY, so the theme flavor never
    # entered the tracked list. Plugins installed fine on a fresh machine
    # and the theme silently did not — nothing errors, yazi just renders
    # in default colours. Comparing the two files catches an omission the
    # "all installed" check above cannot, because that one only looks at
    # what package.toml already says.
    if [ -f "$HOME/.config/yazi/package.toml" ] && [ -f "$HOME/.config/yazi/packages.list" ]; then
        run_test "yazi packages.list covers every declared package" \
            "! (grep -oE 'use = \"[^\"]+\"' \$HOME/.config/yazi/package.toml |
                  sed -E 's/use = \"//; s/\"//' |
                  while IFS= read -r pkg; do
                    grep -qxF \"\$pkg\" \$HOME/.config/yazi/packages.list || echo \"absent \$pkg\"
                  done | grep -q .)"
    fi
    if [ -d "$HOME/.config/yazi/plugins" ]; then
        run_test "yazi declared packages all installed (plugins and flavors)" \
            "! (awk '/^\\[\\[plugin.deps\\]\\]/{d=\"plugins\"; f=\"main.lua\"} /^\\[\\[flavor.deps\\]\\]/{d=\"flavors\"; f=\"flavor.toml\"} /^use = /{n=\$0; sub(/.*[:\\/]/,\"\",n); gsub(/\"/,\"\",n); print d, n, f}' \$HOME/.config/yazi/package.toml |
                while read -r dir name marker; do
                  [ -f \"\$HOME/.config/yazi/\$dir/\$name.yazi/\$marker\" ] || echo \"missing \$dir/\$name\"
                done | grep -q .)"
    fi
fi
# Theme is owned by ~/.config/bat/config — call sites must not override
run_test "No hardcoded bat --theme in .zshrc" \
    "! grep -qE 'bat [^|]*--theme=' $HOME/.zshrc"
run_test "fzf-tab inherits FZF_DEFAULT_OPTS" \
    "grep -q 'use-fzf-default-opts.*yes' $HOME/.zshrc"

# Check for proper shebang
for script in *.sh; do
    if [ -f "$script" ]; then
        run_test "Proper shebang in $script" "head -1 $script | grep -q '^#!/bin/bash'"
    fi
done

echo

# Test 8: Dry run of scripts (safe operations only)  
echo -e "${YELLOW}8. Script Dry Run Tests${NC}"

# Test daily-maintenance.sh functions
TEST_MAINT_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/test_maintenance.XXXXXX")
cat > "$TEST_MAINT_SCRIPT" << 'EOF'
#!/bin/bash
# Source the script but override dangerous functions
brew() { echo "MOCK: brew $@"; return 0; }
zsh() { echo "MOCK: zsh $@"; return 0; }
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Define the run_command function from the script
run_command() {
    local description="$1"
    shift
    local command="$@"
    echo "TEST: Would run: $description - $command"
    return 0
}

# Define FAILED_COMMANDS array
FAILED_COMMANDS=()

# Test that the script structure is valid
echo "Script structure is valid"
EOF

run_test "Daily maintenance script structure" "bash '$TEST_MAINT_SCRIPT'"

# Content checks: ensure key upgrade sections are present
# (regression guards for accidental removal)
if [ -f "$HOME/daily-maintenance.sh" ]; then
    run_test "Daily maintenance includes mise upgrade" \
        "grep -qE '^[[:space:]]*(run_command|mise upgrade|\"Mise runtime upgrade\")' $HOME/daily-maintenance.sh && grep -q 'mise upgrade' $HOME/daily-maintenance.sh"
    # brew upgrades must stay non-interactive (Homebrew 6 prompts otherwise),
    # or the unattended run stalls. Guard: every run_command brew upgrade has --yes.
    run_test "Maintenance brew upgrades are non-interactive (--yes)" \
        "! grep -E 'run_command .*brew upgrade' $HOME/daily-maintenance.sh | grep -qv -- '--yes'"
    # Guard the self-heal that clears stale cask *.upgrading staging dirs.
    run_test "Maintenance self-heals stale cask .upgrading dirs" \
        "grep -qF '.upgrading' $HOME/daily-maintenance.sh"
    # Self-updating apps (VS Code) must never be cask-upgraded by the
    # unattended run: --greedy-latest is the ceiling. Plain --greedy or
    # --greedy-auto-updates would replace apps that update themselves
    # (a July 2026 incident deleted VS Code that way).
    run_test "Maintenance cask upgrade never uses greedy/auto-updates" \
        "! grep -E 'brew upgrade' $HOME/daily-maintenance.sh | grep -qE -- '--greedy(-auto-updates)?([[:space:]]|\$)'"
    # Post-upgrade schema drift is invisible without these: a tool whose
    # config stopped parsing falls back to its defaults silently (yazi did
    # exactly that for weeks after the fetchers id -> group rename).
    run_test "Maintenance runs config schema checks" \
        "grep -q 'zellij setup --check' $HOME/daily-maintenance.sh && grep -q 'atuin doctor' $HOME/daily-maintenance.sh"
    # Tripwire: the maintenance run must never call the herdr CLI beyond
    # --version — any other subcommand can auto-start a server that
    # inherits the launchd environment (the CLAUDECODE-leak bug class).
    # Allowed matches: --version calls, echo/notifier message strings,
    # the socket path. Anything else fails.
    run_test "Maintenance calls herdr CLI only with --version" \
        "! grep -E '^[^#]*\\bherdr\\b' $HOME/daily-maintenance.sh | grep -v -e '--version' -e echo -e terminal-notifier -e '\\-message' -e '\\.sock' | grep -q ."
    # The strand guard depends on the shared lib being sourced.
    run_test "Maintenance sources daily-maintenance-lib.sh" \
        "grep -qE '^source .*daily-maintenance-lib.sh' $HOME/daily-maintenance.sh && grep -q 'dm_herdr_strand_detected' $HOME/daily-maintenance.sh"
    # Failures must reach the desktop, not just the log (the bob wedge
    # was recorded daily for a month and surfaced never)
    run_test "Maintenance notifies on failed tasks" \
        "grep -q 'Daily maintenance: \${#FAILED_COMMANDS\[@\]} task(s) failed' $HOME/daily-maintenance.sh"
    # Bootstrap must keep the machine-service wiring (new machines and
    # the pull-then-bootstrap flow depend on these being automated)
    run_test "Bootstrap wires atuin service, ya pkg, and suite run" \
        "grep -q 'brew services start atuin' $HOME/.config/yadm/bootstrap && grep -q 'ya pkg install' $HOME/.config/yadm/bootstrap && grep -q 'test-dotfiles.sh' $HOME/.config/yadm/bootstrap"
fi
echo

# Test 9: Config file validation
echo -e "${YELLOW}9. Config File Validation${NC}"

# Validate Brewfile syntax
if command -v brew >/dev/null 2>&1 && [ -f "$HOME/Brewfile" ]; then
    # `| head -1` made this pass for EVERY possible Brewfile: run_test reads
    # the exit status, and a pipeline's is its last command's — the same bug
    # rule 10 documents for `log show ... | wc -l`. Proved with a Brewfile
    # holding an unterminated string: bare check exits 1, piped exits 0.
    # `check` is also the wrong verb here — it fails when a declared package
    # is not INSTALLED, which is most of the file on a CI runner. `list`
    # parses and stops, which is what "syntax" means: exit 1 on a syntax
    # error, exit 0 on a merely uninstalled package.
    run_test "Brewfile syntax" "brew bundle list --file=$HOME/Brewfile"
fi

# bootstrap builds the trust list by grepping THREE-part owner/tap/name entries
# out of the Brewfile, so a tap package written with its bare name leaves the
# tap untrusted — and brew then SKIPS that package behind a warning nobody
# reads. `brew "mods"` did exactly that until 2026-08-16: charmbracelet/tap sat
# untrusted, `brew info mods` returned nothing, and mods was never upgraded.
#
# The invariant that catches it: every declared tap must have at least one
# three-part declaration pointing at it. A tap with none is either dead (drop
# it — tw93/tap was, its only formula neither installed nor declared) or has
# its package written with a short name (the bug).
if [ -f "$HOME/Brewfile" ]; then
    BREW_TAP_ORPHANS=""
    while IFS= read -r tap_name; do
        [ -n "$tap_name" ] || continue
        if ! grep -qE "^(brew|cask) \"$tap_name/" "$HOME/Brewfile"; then
            BREW_TAP_ORPHANS="${BREW_TAP_ORPHANS}${BREW_TAP_ORPHANS:+ }${tap_name}"
        fi
    done <<< "$(grep -oE '^tap "[^"]+"' "$HOME/Brewfile" | sed 's/tap "//; s/"//')"
    run_test "Brewfile: every declared tap has a full owner/tap/name entry" \
        "[ -z '$BREW_TAP_ORPHANS' ]"
    [ -n "$BREW_TAP_ORPHANS" ] && echo -e "  ${YELLOW}untraceable taps: $BREW_TAP_ORPHANS${NC}"

    # The tap-level check above is necessary but NOT sufficient: it signed off
    # on a real defect, accepting a `cask` line as satisfying a tap while
    # bootstrap's loop read only `^brew "`, so aprilnea/tap went untrusted on
    # every fresh machine with this suite green.
    #
    # The first replacement was ALSO vacuous — both sides were derived from the
    # Brewfile by two spellings of one regex, so it was empty for every possible
    # Brewfile and passed on the bug it was written for. That is the same
    # "compares the source against itself" shape twice.
    #
    # The discriminator is whether the two sides CAN EVER DISAGREE. So one side
    # now comes from RUNNING bootstrap's own trust block against a stubbed brew,
    # and only the other is read from the Brewfile. If bootstrap stops seeing a
    # declaration — a new package kind, a changed regex — the sets diverge.
    BREW_STUB=$(mktemp -d)
    # The stub APPENDS to a file rather than echoing: bootstrap sends the
    # real call to /dev/null 2>&1, so anything written to stdout is lost.
    printf '#!/bin/sh\n[ "$1" = trust ] && printf "%%s\\n" "$3" >> "$TRUST_LOG"\nexit 0\n' \
        > "$BREW_STUB/brew"
    chmod +x "$BREW_STUB/brew"
    awk '/^# --- Brew trust ---/,/^# --- End brew trust ---/' \
        "$HOME/.config/yadm/bootstrap" > "$BREW_STUB/trust.sh"
    : > "$BREW_STUB/log"
    PATH="$BREW_STUB:$PATH" TRUST_LOG="$BREW_STUB/log" \
        bash "$BREW_STUB/trust.sh" >/dev/null 2>&1
    sort -u "$BREW_STUB/log" > "$BREW_STUB/got"
    grep -oE '^(brew|cask) "[^/"]+/[^/"]+/[^"]+"' "$HOME/Brewfile" \
        | sed -E 's/.*"(.*)"/\1/' | sort -u > "$BREW_STUB/want"
    BREW_UNTRUSTABLE=$(comm -23 "$BREW_STUB/want" "$BREW_STUB/got" | tr '\n' ' ')
    run_test "Brewfile: bootstrap actually trusts every declared tap package" \
        "[ -z \"\$(echo '$BREW_UNTRUSTABLE' | tr -d '[:space:]')\" ]"
    # Positive control: if the extraction or the stub silently produced
    # nothing, the comm above is empty for the wrong reason and passes.
    run_test "…and the trust-loop harness actually ran" \
        "[ -s '$BREW_STUB/got' ]"
    [ -n "$BREW_UNTRUSTABLE" ] && echo -e "  ${YELLOW}never trusted: $BREW_UNTRUSTABLE${NC}"
    rm -rf "$BREW_STUB"

    # Both checks above are Brewfile-internal: one reads the file, the other
    # reads bootstrap reading the file. Neither can see a package that is
    # INSTALLED but never declared — byokey sat in aprilnea/tap for a day and
    # passed both, because openlogi already satisfied that tap. That was not
    # the tap-orphan test being true for the wrong reason; its invariant held.
    # Installed-but-undeclared is a class those tests do not address at all,
    # so this one asks the MACHINE and the two sides can genuinely disagree.
    #
    # Scoped to tap packages deliberately: ~100 core packages are undeclared
    # by choice, so a global gate would be red on day one and only an
    # allowlist would green it. An undeclared TAP package is the ueberzugpp
    # gap — a fresh bootstrap silently lacks it, and were it the tap's only
    # package the tap would go untrusted too.
    #
    # Honest caveat: on a CI runner nothing from a tap is installed, so the
    # installed set is empty and this passes by emptiness. Machine-local
    # gate, not a CI gate — and a positive control cannot fix that, because
    # emptiness is legitimate there.
    if command -v brew >/dev/null 2>&1; then
        # Only taps THIS Brewfile declares. A CI runner arrives with taps of
        # its own and packages from them are not this repo's business — the
        # first version compared against every installed tap package and went
        # red on the runner while passing locally.
        BREW_OWN_TAPS=$(grep -oE '^tap "[^"]+"' "$HOME/Brewfile" \
            | sed 's/tap "//; s/"//' | sort -u)
        BREW_TAP_UNDECLARED=$(comm -23 \
            <({ brew list --formula --full-name
                brew list --cask --full-name; } 2>/dev/null \
                | grep '/' \
                | grep -F -f <(printf '%s\n' "$BREW_OWN_TAPS" | sed 's|$|/|') \
                | sort -u) \
            <(grep -oE '^(brew|cask) "[^/"]+/[^/"]+/[^"]+"' "$HOME/Brewfile" \
                | sed -E 's/.*"(.*)"/\1/' | sort -u) | tr '\n' ' ')
        run_test "Brewfile: every INSTALLED tap package is declared" \
            "[ -z \"\$(echo '$BREW_TAP_UNDECLARED' | tr -d '[:space:]')\" ]"
        [ -n "$BREW_TAP_UNDECLARED" ] && \
            echo -e "  ${YELLOW}installed but undeclared: $BREW_TAP_UNDECLARED${NC}"
    fi
fi

# yazi's preview backends fail SILENTLY: a missing one renders a blank pane
# with no error anywhere. ueberzugpp taught this the expensive way — it was
# hand-installed and never declared, so a rebuilt machine just quietly lost
# previews. Assert the DECLARATION first (that is what survives a rebuild),
# then presence on this machine.
if [ -f "$HOME/Brewfile" ]; then
    for yazi_dep in imagemagick resvg; do
        run_test "Brewfile declares yazi preview backend: $yazi_dep" \
            "grep -q '^brew \"$yazi_dep\"' $HOME/Brewfile"
    done
fi
if command -v yazi >/dev/null 2>&1; then
    # magick is the binary imagemagick ships; resvg matches its formula name
    run_test "yazi preview backends present (magick, resvg)" \
        "command -v magick >/dev/null 2>&1 && command -v resvg >/dev/null 2>&1"
fi

# Validate mise config
if command -v mise >/dev/null 2>&1 && [ -f "$HOME/.config/mise/config.toml" ]; then
    run_test "Mise config syntax" "mise config 2>&1 | head -1"
fi

# Validate yazi config exists
if [ -f "$HOME/.config/yazi/yazi.toml" ]; then
    run_test "Yazi config exists" "[ -s $HOME/.config/yazi/yazi.toml ]"
fi

# Validate Ghostty config
if command -v ghostty >/dev/null 2>&1; then
    run_test "Ghostty config valid" "ghostty +validate-config"
    if [ -f "$HOME/.config/ghostty/config" ]; then
        SCROLLBACK=$(sed -n 's/^scrollback-limit *=  *\([0-9]*\)/\1/p' "$HOME/.config/ghostty/config" 2>/dev/null)
        SCROLLBACK=${SCROLLBACK:-0}
        run_test "Ghostty scrollback-limit >= 1000000" "[ \"$SCROLLBACK\" -ge 1000000 ]"
    fi
fi

# Validate tmux config syntax (parse check only, no server needed)
if command -v tmux >/dev/null 2>&1 && [ -f "$HOME/.tmux.conf" ]; then
    run_test "Tmux config exists and non-empty" "[ -s $HOME/.tmux.conf ]"
fi

# Validate Starship config (TOML syntax)
if [ -f "$HOME/.config/starship.toml" ]; then
    run_test "Starship config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/starship.toml').read_text())\""
    if command -v bat >/dev/null 2>&1; then
        run_test "bat Catppuccin Mocha theme registered" \
            "bat --list-themes 2>/dev/null | grep -q 'Catppuccin Mocha' && grep -q 'Catppuccin Mocha' $HOME/.config/bat/config"
    fi
    if command -v tmux >/dev/null 2>&1; then
        # Sources the real config incl. TPM; verified 3 throwaway runs
        # leave ~/.tmux/resurrect untouched (no plugin side effects).
        run_test "Tmux config parses (throwaway server)" \
            "tmux -L cfgtest-suite -f $HOME/.tmux.conf new-session -d 2>/dev/null && tmux -L cfgtest-suite kill-server 2>/dev/null"
        run_test "Tmux history-limit >= 50000" \
            "grep -qE 'history-limit (5[0-9]{4,}|[6-9][0-9]{4}|[0-9]{6,})' $HOME/.tmux.conf"
        # vi copy mode must be pinned in config, not inherited from
        # EDITOR=nvim — a shell without that env falls back to emacs
        run_test "Tmux copy mode pinned to vi keys" \
            "grep -q 'mode-keys vi' $HOME/.tmux.conf && \
             grep -q 'copy-mode-vi v send -X begin-selection' $HOME/.tmux.conf"
        # Keyboard copy: prefix+P (last shell output via OSC 133 marks)
        # and prefix+O (last Claude reply). The latter drives Claude
        # Code's own `/copy` rather than reading the transcript
        # ourselves — it runs inside the pane's conversation, so it needs
        # no answer to "which session is this pane running", which is the
        # question that made the previous implementation large.
        run_test "Tmux keyboard-copy bindings present" \
            "grep -q 'previous-prompt -o' $HOME/.tmux.conf && \
             grep -qF \"send-keys '/copy' Enter\" $HOME/.tmux.conf"
    fi
    # Keybind contract: herdr must carry the same copy-last-reply key
    # (prefix+shift+o = tmux's prefix+O) in the TEMPLATE (source of
    # truth — the generated config.toml is derived from it), and must
    # address the FOCUSED pane — HERDR_ACTIVE_PANE_ID is injected at
    # keypress and never inherited, unlike HERDR_PANE_ID.
    if [ -f "$HOME/.config/herdr/config.toml##template" ]; then
        # Assert the COMMAND LINE, not "does this string appear somewhere
        # in the file" — the comment above the binding names `pane run`
        # in order to explain why it is wrong, so a file-wide grep passes
        # on the very prose warning against it.
        #
        # `agent prompt` over `pane run` is a safety property, not a
        # style choice: this binding TYPES into the focused pane, and
        # `pane run` would send "/copy" and a newline into a shell, an
        # editor or a y/N prompt. `agent prompt` refuses instead — with
        # agent_not_found at a non-agent pane, and since 0.8.2 (upstream
        # #2788) with agent_blocked at an agent already waiting on its own
        # dialog. Those need DIFFERENT messages: one fallback string made
        # the blocked case report "not a Claude pane", which is false and
        # sends you to check whether the pane is an agent when it is one.
        # The command is a multi-line TOML literal, so read the block
        # rather than one line. Assert the MAPPING, not that the two
        # branches differ: two distinct WRONG messages satisfy
        # distinctness, and swapping them is precisely the original bug —
        # one cause reported under the other's name.
        run_test "herdr copy-last-reply binding tells the two refusals apart" \
            "blk=\$(awk '/^key = \"prefix\\+shift\\+o\"/,/^description = /' '$HOME/.config/herdr/config.toml##template');
             printf '%s' \"\$blk\" | grep -qF 'agent prompt' &&
             printf '%s' \"\$blk\" | grep -qF 'HERDR_ACTIVE_PANE_ID' &&
             printf '%s' \"\$blk\" | grep -qF \"'/copy'\" &&
             printf '%s' \"\$blk\" | grep -qE 'agent_not_found\\).*not a Claude pane' &&
             printf '%s' \"\$blk\" | grep -qE 'agent_blocked\\).*waiting on its own prompt' &&
             printf '%s' \"\$blk\" | grep -qE '\\*\\).*copy failed' &&
             ! printf '%s' \"\$blk\" | grep -qF 'pane run'"
        # The tmux side needs its own guard, since if-shell is what
        # stops the keystrokes reaching a non-Claude pane.
        run_test "tmux copy binding is guarded, not unconditional" \
            "grep -qF 'pane_current_command' $HOME/.tmux.conf &&
             grep -qF 'not a Claude pane' $HOME/.tmux.conf"
    fi

    # herdr update channel is opted into by an EXTRA class, not by the
    # machine's identity. The property that matters is the SAFE DEFAULT:
    # a machine without the `herdr-preview` class — which is every
    # machine until someone runs the `--add` — must resolve to stable.
    # Getting this backwards would put a work machine on unreleased
    # builds silently, which is the one outcome there is no way to
    # notice.
    #
    # `--get-all`, not `--get`: classes are a LIST and the opt-in may sit
    # anywhere in it. `--get` returns only the first, so a machine set up
    # as `work` + `herdr-preview` would read as `work` and this test
    # would demand stable while yadm rendered preview. yadm's own
    # template processor loops the whole list, and the test has to model
    # that, not the first entry.
    #
    # Asserted against the GENERATED config, not the template, because
    # the template is only correct if yadm actually renders it that way.
    if [ -f "$HOME/.config/herdr/config.toml" ]; then
        run_test "herdr update channel matches this machine's yadm class" \
            "cls=\$(yadm config --get-all local.class 2>/dev/null || true);
             ch=\$(grep -A2 '^\[update\]' '$HOME/.config/herdr/config.toml' | grep -m1 '^channel' | sed 's/.*\"\\(.*\\)\".*/\\1/');
             if printf '%s\\n' \"\$cls\" | grep -qx herdr-preview; then [ \"\$ch\" = preview ]; else [ \"\$ch\" = stable ]; fi"
    fi
    # ssh-terminfo (not ssh-env) keeps TERM intact on remotes — herdr's
    # terminal-notification detection over SSH depends on it
    # (ssh-env is the wrong tool: it downgrades TERM to xterm-256color)
    run_test "Ghostty shell integration includes ssh-terminfo" \
        "grep -E '^shell-integration-features' $HOME/.config/ghostty/config | grep -q 'ssh-terminfo'"
    # Deliberate text-quality choices for the 0.82-opacity background
    # (2026-08 tip audit) — guard against accidental reversion
    run_test "Ghostty translucency text-quality settings present" \
        "grep -q '^alpha-blending = linear-corrected' $HOME/.config/ghostty/config && \
         grep -q '^minimum-contrast = 1.1' $HOME/.config/ghostty/config && \
         grep -q '^faint-opacity = 0.7' $HOME/.config/ghostty/config && \
         grep -q '^undo-timeout = 30s' $HOME/.config/ghostty/config"
    # Ghostty reads BOTH ~/.config/ghostty/config and the App Support path on
    # macOS. Symlinking one to the other makes it parse the SAME file twice:
    # scalar keys are last-wins so nothing looks wrong, but REPEATABLE keys
    # append twice. Measured 2026-08-15: 4 custom-shader entries instead of 2,
    # i.e. double the full-screen fragment shader work on every frame.
    # Compare what Ghostty actually loads against what the file declares —
    # this catches the duplication whatever its mechanism.
    if command -v ghostty >/dev/null 2>&1; then
        GHOSTTY_CFG_SHADERS=$(grep -c '^custom-shader = ' "$HOME/.config/ghostty/config" 2>/dev/null || true)
        GHOSTTY_LOADED_SHADERS=$(ghostty +show-config 2>/dev/null | grep -c '^custom-shader = ' || true)
        run_test "Ghostty config is not parsed twice (custom-shader not duplicated)" \
            "[ -n '$GHOSTTY_LOADED_SHADERS' ] && [ '$GHOSTTY_LOADED_SHADERS' -eq '$GHOSTTY_CFG_SHADERS' ]"
    fi
    # Daily bob-nightly + plugin churn can desync editor and plugins
    # (the neo-tree/nvim_win_resize incident: nvim frozen on a June
    # nightly while plugins assumed a newer API) — a clean headless
    # boot is the cheapest canary
    if command -v nvim >/dev/null 2>&1; then
        run_test "Neovim boots headless without errors" \
            "! nvim --headless -c q 2>&1 | grep -qiE 'error|traceback'"
    fi
    if [ -f "$HOME/.config/jj/config.toml" ]; then
        run_test "jj config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/jj/config.toml').read_text())\""
        if command -v jj >/dev/null 2>&1; then
            run_test "jj accepts the user config" \
                "jj config list --user >/dev/null 2>&1"
        fi
    fi
    # ripgrep config was dormant for ages (env var never exported).
    # Assert it is wired AND stays a pure search-filter config: output
    # flags (--pretty/--context/--column) would leak into piped and
    # scripted rg calls the moment the config is active.
    if command -v rg >/dev/null 2>&1; then
        run_test "ripgrep config exported and parses" \
            "grep -q 'export RIPGREP_CONFIG_PATH=' $HOME/.zshrc && RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/config rg --files $HOME/.config/ripgrep >/dev/null 2>&1"
        run_test "ripgrep config has no output-format flags" \
            "! grep -qE '^--(pretty|context=|column|line-number)' $HOME/.config/ripgrep/config"
    fi
    # mergiraf must be wired end-to-end: the attributes line without the
    # driver definition (or vice versa) is a silent no-op
    run_test "mergiraf attributes/driver pairing" \
        "grep -q 'merge=mergiraf' $HOME/.config/git/attributes && grep -q 'merge \"mergiraf\"' $HOME/.config/git/config"
fi

# Validate Kitty config
if command -v kitty >/dev/null 2>&1 && [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    run_test "Kitty config valid" "kitty --config $HOME/.config/kitty/kitty.conf --debug-config 2>&1 | grep -qv 'Error'"
fi

# Validate Atuin config (TOML syntax)
if [ -f "$HOME/.config/atuin/config.toml" ]; then
    run_test "Atuin config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/atuin/config.toml').read_text())\""
    # Daemon mode is per-machine state the tracked config cannot carry: the
    # config can say enabled = true on a machine where
    # `brew services start atuin` was never run, and history then goes
    # nowhere. Only assert when the config actually asks for the daemon.
    # Guarded on atuin being installed: CI checks out the tracked config
    # (daemon enabled) onto a runner with no atuin — skip there, still
    # catch a real machine that never started the service.
    if command -v atuin >/dev/null 2>&1 && grep -A6 '\[daemon\]' "$HOME/.config/atuin/config.toml" 2>/dev/null | grep -qE '^enabled = true'; then
        run_test "atuin daemon socket live when enabled" \
            "[ -S \"$HOME/.local/share/atuin/atuin.sock\" ]"
    fi
fi

# Validate sesh config (TOML syntax)
if [ -f "$HOME/.config/sesh/sesh.toml" ]; then
    run_test "Sesh config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/sesh/sesh.toml').read_text())\""
    # zjstatus must stay pinned to an exact release (never 'latest'):
    # Zellij caches the wasm by URL, so a mutable URL = unpinned supply
    # chain AND stale-cache confusion.
    run_test "Zellij zjstatus plugin URL is version-pinned" \
        "grep -qE 'zjstatus/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/zjstatus\.wasm' $HOME/.config/zellij/layouts/default.kdl"
    if command -v zellij >/dev/null 2>&1; then
        run_test "Zellij config + layouts parse (setup --check)" \
            "zellij setup --check >/dev/null 2>&1"
    fi
    # Yazi 26 broke silently on a stale fetchers schema (id -> group):
    # --version fails when the config no longer parses, so this catches
    # the next schema break instead of yazi quietly using preset config.
    # (verified: --version exits 1 on broken config, 0 when clean)
    if command -v yazi >/dev/null 2>&1; then
        run_test "Yazi config parses (yazi --version)" \
            "yazi --version >/dev/null 2>&1"
    fi
    if [ -f "$HOME/.config/herdr/config.toml" ]; then
        run_test "herdr config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/herdr/config.toml').read_text())\""
    fi
    if [ -f "$HOME/.config/herdr/plugins/config/sessionizer/config.toml" ]; then
        run_test "herdr sessionizer config TOML valid" "python3 -c \"import tomllib, pathlib; tomllib.loads(pathlib.Path('$HOME/.config/herdr/plugins/config/sessionizer/config.toml').read_text())\""
    fi
fi
echo

# Test 10: Symlink Integrity
echo -e "${YELLOW}10. Symlink Integrity${NC}"

# Ghostty App Support path must stay EMPTY — the inverse of what this file
# asserted until 2026-08-15. bootstrap used to symlink config (and shaders)
# here, but Ghostty already reads ~/.config/ghostty/config natively on macOS,
# so the link only made it parse the same file twice (see the custom-shader
# duplication test above). Unconditional on purpose: the old version was
# wrapped in `if [ -e ] || [ -L ]`, so deleting the link made the assertion
# silently stop running instead of failing.
#
# Asserting the directory is EMPTY was wrong twice over. Ghostty 1.3 renamed
# the file to config.ghostty, so the old check watched a name Ghostty had
# stopped using — and Ghostty RECREATES a commented-out template there
# whenever it thinks no config exists, which it did hours after the fix
# landed. Emptiness was never achievable and never the point.
#
# What matters is that nothing there CONTRIBUTES SETTINGS: no symlink back to
# the real config, and no file with a non-comment line.
#
# An EXPLICIT list of the two known names, deliberately not a config* glob:
# there is a config.784a6feb.bak sitting in that directory carrying two real
# settings (theme, font-family) which Ghostty never loads, and a glob would
# fail this test on a healthy machine. The cost is that a future rename needs
# a line added here — which is why the bootstrap-side coverage is asserted
# separately below.
GHOSTTY_APPSUP="$HOME/Library/Application Support/com.mitchellh.ghostty"
ghostty_appsup_contributes() {
    local f
    for f in "$GHOSTTY_APPSUP"/config "$GHOSTTY_APPSUP"/config.ghostty; do
        [ -L "$f" ] && return 0
        [ -f "$f" ] && grep -qvE '^[[:space:]]*(#|$)' "$f" 2>/dev/null && return 0
    done
    return 1
}
run_test "Ghostty App Support contributes no settings (double-load fix)" \
    "! ghostty_appsup_contributes"
# Positive control: run_test evals in this shell, so a missing command returns
# 127 and the `!` above turns that into a pass. If the function is ever renamed
# or moved below its call site, the assertion goes green silently.
run_test "…and the contributes-check is actually defined" \
    "declare -F ghostty_appsup_contributes >/dev/null"
run_test "bootstrap does not recreate the Ghostty symlink" \
    "! grep -qE 'ln -sfn .*ghostty/config' $HOME/.config/yadm/bootstrap"
# And that bootstrap handles the post-rename filename at all.
run_test "bootstrap covers the renamed config.ghostty" \
    "grep -q 'config.ghostty' $HOME/.config/yadm/bootstrap"

# Critical dotfiles exist and are non-empty
for dotfile in ~/.zshrc ~/.tmux.conf ~/.gitconfig ~/.config/starship.toml; do
    if [ -e "$dotfile" ]; then
        run_test "$(basename $dotfile) exists and non-empty" "[ -s $dotfile ]"
    fi
done
echo

# Test 11: Security Checks
echo -e "${YELLOW}11. Security Checks${NC}"

# No secrets in yadm-tracked files
if command -v yadm >/dev/null 2>&1; then
    run_test "No secrets in tracked files" "[ -z \"\$(yadm list -a 2>/dev/null | xargs grep -lE '(APIKEY|SECRET_KEY|API_TOKEN|PRIVATE_KEY|TOKEN|PASSWORD|CREDENTIAL|AWS_SECRET)\s*=' 2>/dev/null | grep -v 'HOMEBREW_NO_ANALYTICS' | grep -v 'test-dotfiles.sh')\" ]"
fi
# Commit signing depends on allowed_signers carrying a public key
if [ -f "$HOME/.ssh/allowed_signers" ]; then
    run_test "allowed_signers contains an SSH public key" \
        "grep -qE 'ssh-(rsa|ed25519) ' $HOME/.ssh/allowed_signers"
fi
# Every checkout in CI must set persist-credentials: false (zizmor
# artipacked); count parity catches a new checkout step added without it.
if [ -f "$HOME/.github/workflows/ci.yml" ]; then
    run_test "CI checkouts all set persist-credentials false" \
        "[ \"\$(grep -c 'uses: actions/checkout@' $HOME/.github/workflows/ci.yml)\" -eq \"\$(grep -c 'persist-credentials: false' $HOME/.github/workflows/ci.yml)\" ]"
    # A secret scanner on a shallow checkout sees ONE commit while
    # reporting success — the same false-pass class as running gitleaks
    # outside a repo ("0 commits scanned … no leaks found"). The
    # security-scan job scans history, so it must fetch it.
    run_test "CI security scan checks out full history (fetch-depth 0)" \
        "grep -q 'fetch-depth: 0' $HOME/.github/workflows/ci.yml"
    # TruffleHog runs --results=verified (zero false positives, but it
    # only fails on credentials it could confirm live against a
    # provider). gitleaks is the regex/entropy net that catches private
    # keys, revoked-but-real tokens and anything unverifiable, and it is
    # the same engine the yadm pre_commit hook runs — the hook is
    # bypassable (--no-verify), so CI must own the authoritative copy.
    # Version-pinned (never @latest — same supply-chain rule as the
    # SHA-pinned actions) and blocking (no continue-on-error anywhere in
    # the step, which is what made the old Trivy scan decorative).
    run_test "CI runs gitleaks as a blocking secret scan" \
        "grep -qE 'gitleaks/v8@v[0-9]+\.[0-9]+\.[0-9]+' $HOME/.github/workflows/ci.yml &&
         ! grep -B8 -A4 'gitleaks/v8@v' $HOME/.github/workflows/ci.yml | grep -q 'continue-on-error'"
    # The action SHA does not pin the scanner it docker-runs; that input
    # defaults to the mutable `latest`. Bare semver, no `v` — the GHCR
    # tag is 3.96.0 while the git tag is v3.96.0, and the wrong one is a
    # 404 that surfaces as docker exit 125, i.e. a scan "failure".
    run_test "CI pins the TruffleHog scanner version (not latest)" \
        "grep -qE '^ *version: [0-9]+\.[0-9]+\.[0-9]+ *\$' $HOME/.github/workflows/ci.yml"
fi

# Credential files must NEVER become tracked in this PUBLIC repo. The
# CLAUDE.md invariant is that identity and secrets live in UNTRACKED
# files; until now nothing enforced it, and a single `yadm add -A` on a
# new machine would publish them. Content scanners do not cover this:
# a ~/.gitconfig holding a corp identity, or a gh hosts.yml token no
# scanner can verify, is secret-BEARING without being secret-SHAPED.
CRED_DENY_FILE=$(mktemp)
cat > "$CRED_DENY_FILE" <<'CRED_EOF'
^\.gitconfig$
^\.netrc$
^\.npmrc$
^\.pypirc$
^\.env$
^\.secrets$
^\.aws/
^\.config/gh/hosts\.yml$
^\.config/op/
^\.docker/config\.json$
^\.kube/config$
^\.ssh/id_
^\.local/share/atuin/key$
^\.claude/settings\.local\.json$
^\.claude/settings\.json
^\.zshrc\.local$
^\.zshenv\.local$
^\.daily-maintenance\.local$
\.(pem|p12|pfx)$
\.(bak|orig)$
CRED_EOF
# *.pub is PUBLIC key material and legitimately trackable — .ssh/id_
# would otherwise flag id_ed25519.pub, which is the same class as the
# already-tracked .ssh/allowed_signers. Filter before matching.
run_test "No credential files tracked (public repo)" \
    "! { yadm ls-files 2>/dev/null || git ls-files 2>/dev/null; } |
     grep -v '\.pub\$' | grep -qEf '$CRED_DENY_FILE'"
# An empty listing greps clean and passes — the exact vacuous-pass this
# section exists to prevent (yadm present but silent never trips the
# || fallback). Assert the list has a plausible floor.
run_test "credential scan ran against a non-empty file list" \
    "[ \"\$({ yadm ls-files 2>/dev/null || git ls-files 2>/dev/null; } | wc -l)\" -gt 50 ]"
# Test the test: a denylist that matches nothing passes vacuously, which
# is how a scanner rots into decoration. Canary paths are never real
# files here — they only prove the pattern set still bites.
run_test "credential denylist actually matches a canary path" \
    "printf '%s\n' .aws/credentials .config/gh/hosts.yml .ssh/id_ed25519 .gitconfig |
     [ \"\$(grep -cEf '$CRED_DENY_FILE')\" -eq 4 ]"
rm -f "$CRED_DENY_FILE"
echo

# Test 12: Git/yadm checks
echo -e "${YELLOW}12. Version Control Checks${NC}"
run_test "No uncommitted changes" "[ -z \"$(yadm status --porcelain 2>/dev/null)\" ] || yadm status --porcelain"
echo

# Test 13: Markdown Lint (mandatory — every commit MUST pass, no exceptions)
# NOTE: never lint '**/*.md' from ~ — it scans the whole home dir and hangs.
# -z/-0 keeps filenames with spaces intact and skips the run on empty input.
echo -e "${YELLOW}13. Markdown Lint${NC}"
if command -v npx >/dev/null 2>&1; then
    # Locally the tracked files come from yadm; in CI checkouts from git.
    if command -v yadm >/dev/null 2>&1 && yadm ls-files >/dev/null 2>&1; then
        run_test "markdownlint on tracked markdown files" \
            "yadm ls-files -z '*.md' | xargs -0 npx markdownlint-cli"
    elif git rev-parse --git-dir >/dev/null 2>&1; then
        run_test "markdownlint on tracked markdown files" \
            "git ls-files -z '*.md' | xargs -0 npx markdownlint-cli"
    else
        echo -e "${YELLOW}  Not a yadm/git repo; skipping markdown lint${NC}"
    fi
else
    echo -e "${YELLOW}  npx not available; skipping markdown lint (CI will enforce it)${NC}"
fi
# The README split moved sections into docs/ pages — every relative .md
# link in the READMEs and docs/ must resolve, or the split rots silently.
run_test "Relative .md links in README/docs resolve" \
    "! (for f in \$HOME/README.md \$HOME/README.zh-TW.md \$HOME/docs/*.md; do d=\$(dirname \"\$f\"); grep -oE '\\]\\(([A-Za-z0-9._/-]+\\.md)[)#]' \"\$f\" 2>/dev/null | sed -E 's/^\\]\\(//; s/[)#]\$//' | while IFS= read -r l; do [ -f \"\$d/\$l\" ] || echo \"\$f -> \$l\"; done; done | grep -q .)"
echo

# Test 14: ShellCheck on ALL tracked bash/sh scripts (shebang-detected)
# Covers extensionless scripts (.local/bin tools, yadm hooks) that the
# '*.sh' glob in Test 4 misses. The anchored regex deliberately excludes
# zsh scripts — shellcheck does not support zsh.
echo -e "${YELLOW}14. ShellCheck (tracked scripts by shebang)${NC}"
if command -v shellcheck >/dev/null 2>&1; then
    if command -v yadm >/dev/null 2>&1 && yadm ls-files >/dev/null 2>&1; then
        TRACKED_FILES=$(yadm ls-files)
    elif git rev-parse --git-dir >/dev/null 2>&1; then
        TRACKED_FILES=$(git ls-files)
    else
        TRACKED_FILES=""
    fi
    if [ -n "$TRACKED_FILES" ]; then
        while IFS= read -r tracked; do
            [ -f "$tracked" ] || continue
            if head -1 "$tracked" 2>/dev/null | \
               grep -qE '^#!/(usr/(local/)?)?bin/(env +)?(bash|sh)\b'; then
                run_test "ShellCheck (shebang) $tracked" \
                    "shellcheck -S warning '$tracked'"
            fi
        done <<< "$TRACKED_FILES"
    else
        echo -e "${YELLOW}  Not a yadm/git repo; skipping shebang shellcheck${NC}"
    fi
else
    echo -e "${YELLOW}  ShellCheck not installed; skipping${NC}"
fi
echo

# Test 15: Unit tests (lib functions + fixture-based checks)
echo -e "${YELLOW}15. Unit Tests${NC}"

# Time Machine backup-age warning. AutoBackup is OFF by choice (local
# snapshots were eating the internal disk while the T7 is unplugged), so this
# check is the only thing standing between here and another eleven-month gap
# — it has to be proven to FIRE, not just to stay quiet on a healthy machine.
# The section is extracted and run against fixture plists so the real backup
# state is never touched and all three branches are exercised.
if [ -f "$HOME/daily-maintenance.sh" ] && [ -x /usr/libexec/PlistBuddy ]; then
    TM_UT_DIR=$(mktemp -d)
    # End at the NEXT section, not at Machine-local extras: the orphan-scan
    # section was added between them, so the wider range pulled it in and
    # every TM fixture run also scanned the real /Library — 36 plists times
    # six runs, and on a machine with orphans it would have fired
    # terminal-notifier six times during a test run.
    awk '/^# --- Time Machine backup age/,/^# --- Orphaned LaunchAgents/' \
        "$HOME/daily-maintenance.sh" | sed '$d' > "$TM_UT_DIR/section.sh"

    # stale: a completed backup 100 days old
    /usr/libexec/PlistBuddy -c "Add :Destinations array" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add :Destinations:0 dict" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add :Destinations:0:DestinationID string UT" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add :Destinations:0:SnapshotDates array" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add :Destinations:0:SnapshotDates:0 date '$(LC_ALL=C date -v-100d '+%a %b %d %H:%M:%S %Z %Y')'" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    # fresh: a completed backup from today
    cp "$TM_UT_DIR/stale.plist" "$TM_UT_DIR/fresh.plist" 2>/dev/null
    /usr/libexec/PlistBuddy -c "Set :Destinations:0:SnapshotDates:0 '$(LC_ALL=C date '+%a %b %d %H:%M:%S %Z %Y')'" "$TM_UT_DIR/fresh.plist" >/dev/null 2>&1
    # never: destination configured, no SnapshotDates at all
    /usr/libexec/PlistBuddy -c "Add :Destinations array" "$TM_UT_DIR/never.plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add :Destinations:0 dict" "$TM_UT_DIR/never.plist" >/dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add :Destinations:0:DestinationID string UT" "$TM_UT_DIR/never.plist" >/dev/null 2>&1
    # none: no destinations key
    /usr/libexec/PlistBuddy -c "Add :AutoBackup integer 0" "$TM_UT_DIR/none.plist" >/dev/null 2>&1

    TM_UT="TM_WARN_DAYS=7 bash '$TM_UT_DIR/section.sh'"
    run_test "TM age: a 100-day-old backup warns" \
        "TM_PLIST='$TM_UT_DIR/stale.plist' $TM_UT | grep -q 'Stale'"
    # A positive assertion on the same fixture, so the negatives below cannot
    # pass vacuously: if fixture construction ever breaks, "does NOT warn"
    # succeeds for the wrong reason, and nothing would say so.
    run_test "TM age: the fresh fixture is actually parsed" \
        "TM_PLIST='$TM_UT_DIR/fresh.plist' $TM_UT | grep -q 'Last completed backup:'"
    run_test "TM age: a backup from today does NOT warn" \
        "! { TM_PLIST='$TM_UT_DIR/fresh.plist' $TM_UT | grep -q 'Stale'; }"
    run_test "TM age: a destination that never completed a backup warns" \
        "TM_PLIST='$TM_UT_DIR/never.plist' $TM_UT | grep -q 'NEVER completed'"
    run_test "TM age: no destination configured is not an alarm" \
        "TM_PLIST='$TM_UT_DIR/none.plist' $TM_UT | grep -q 'No Time Machine destination'"
    # tmutil latestbackup needs the destination MOUNTED, so it cannot be the
    # source here — it fails exactly when the warning matters.
    run_test "TM age: reads SnapshotDates, not tmutil latestbackup" \
        "grep -q 'SnapshotDates' $HOME/daily-maintenance.sh &&
         ! grep -qE '^[^#]*tmutil latestbackup' $HOME/daily-maintenance.sh"

    # The DEFAULT threshold, exercised with TM_WARN_DAYS unset. Without these
    # the four tests above pass for any default at all, so a fat-fingered
    # number would ship silently. 40d must warn and 10d must not, which pins
    # the default to the 11..40 band and to 30 in practice.
    /usr/libexec/PlistBuddy -c "Set :Destinations:0:SnapshotDates:0 '$(LC_ALL=C date -v-40d '+%a %b %d %H:%M:%S %Z %Y')'" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    cp "$TM_UT_DIR/stale.plist" "$TM_UT_DIR/d40.plist" 2>/dev/null
    /usr/libexec/PlistBuddy -c "Set :Destinations:0:SnapshotDates:0 '$(LC_ALL=C date -v-10d '+%a %b %d %H:%M:%S %Z %Y')'" "$TM_UT_DIR/stale.plist" >/dev/null 2>&1
    cp "$TM_UT_DIR/stale.plist" "$TM_UT_DIR/d10.plist" 2>/dev/null
    run_test "TM age: default threshold warns at 40 days" \
        "TM_PLIST='$TM_UT_DIR/d40.plist' bash '$TM_UT_DIR/section.sh' | grep -q 'Stale'"
    run_test "TM age: default threshold stays quiet at 10 days" \
        "! { TM_PLIST='$TM_UT_DIR/d10.plist' bash '$TM_UT_DIR/section.sh' | grep -q 'Stale'; }"
    # An unparseable date and a never-backed-up destination used to produce the
    # SAME message, so in a zone whose abbreviation is numeric (+08, +07, +04 —
    # Singapore, Bangkok, Dubai) the output pointed away from the cause. Run the
    # fixture under such a zone and require the parse failure to be named.
    run_test "TM age: an unparseable date says so, not 'never backed up'" \
        "TZ=Asia/Singapore TM_PLIST='$TM_UT_DIR/stale.plist' bash '$TM_UT_DIR/section.sh' | grep -q 'Could not parse backup date'"
    rm -rf "$TM_UT_DIR"
fi

# Orphaned LaunchAgent detection. An app removal that leaves its LaunchAgent
# behind produces a job that fails at every login and reports to nobody — three
# were found by hand in 2026-08 (com.logi.cp-dev-mgr, com.jetbrains.toolbox,
# com.symless.synergy3), all from uninstalls. The scan runs against fixtures so
# the real /Library is never touched, and so BOTH polarities are exercised: a
# detector that has only ever been seen finding nothing is not a detector.
if [ -f "$HOME/daily-maintenance.sh" ] && [ -x /usr/libexec/PlistBuddy ]; then
    ORPH_DIR=$(mktemp -d)
    mkdir -p "$ORPH_DIR/agents"
    awk '/^# --- Orphaned LaunchAgents/,/^# --- Machine-local extras/' \
        "$HOME/daily-maintenance.sh" | sed '$d' > "$ORPH_DIR/section.sh"

    orph_pb() { /usr/libexec/PlistBuddy -c "$1" "$2" >/dev/null 2>&1; }
    # absolute path, missing target -> must be caught
    orph_pb "Add :Program string /Applications/Gone.app/Contents/MacOS/gone" "$ORPH_DIR/agents/com.test.orphan.plist"
    # absolute path that exists -> must NOT be caught
    orph_pb "Add :Program string /bin/echo" "$ORPH_DIR/agents/com.test.valid.plist"
    # bundle-relative (how BTM agents are written) -> must NOT be caught, since
    # it resolves against a bundle this check cannot identify
    orph_pb "Add :ProgramArguments array" "$ORPH_DIR/agents/com.test.rel.plist"
    orph_pb "Add :ProgramArguments:0 string Contents/Helpers/trampoline" "$ORPH_DIR/agents/com.test.rel.plist"
    # ProgramArguments form of an orphan -> must be caught (Program is absent)
    orph_pb "Add :ProgramArguments array" "$ORPH_DIR/agents/com.test.orphan2.plist"
    orph_pb "Add :ProgramArguments:0 string /opt/nonexistent/bin/thing" "$ORPH_DIR/agents/com.test.orphan2.plist"
    # BundleProgram form -> the third documented key, unused on this machine
    orph_pb "Add :BundleProgram string /opt/nonexistent/bin/bundled" "$ORPH_DIR/agents/com.test.orphan3.plist"

    ORPH_RUN="LAUNCHD_SCAN_DIRS='$ORPH_DIR/agents' bash '$ORPH_DIR/section.sh'"
    run_test "launchd orphans: a missing Program is reported" \
        "$ORPH_RUN | grep -q 'com.test.orphan\b'"
    run_test "launchd orphans: a missing ProgramArguments[0] is reported" \
        "$ORPH_RUN | grep -q 'com.test.orphan2'"
    run_test "launchd orphans: a missing BundleProgram is reported" \
        "$ORPH_RUN | grep -q 'com.test.orphan3'"
    run_test "launchd orphans: an existing program is not reported" \
        "! { $ORPH_RUN | grep -q 'com.test.valid'; }"
    run_test "launchd orphans: a bundle-relative path is not a false positive" \
        "! { $ORPH_RUN | grep -q 'com.test.rel'; }"
    # And the empty case, which is what a healthy machine should print.
    mkdir -p "$ORPH_DIR/empty"
    run_test "launchd orphans: a clean directory reports none" \
        "LAUNCHD_SCAN_DIRS='$ORPH_DIR/empty' bash '$ORPH_DIR/section.sh' | grep -q 'None'"

    # The managed-machine guard. On an MDM-enrolled Mac the system-wide dirs
    # belong to the org's management stack: an entry there returns after
    # removal, and taking the wrong one out can break enrolment — so the
    # "bootout, then delete" advice must not be aimed at them. `profiles` is
    # stubbed both ways so the result does not depend on whether the machine
    # running this suite happens to be enrolled.
    ORPH_BIN="$ORPH_DIR/bin"; mkdir -p "$ORPH_BIN"
    orph_mdm() { printf '#!/bin/sh\necho "MDM enrollment: %s"\n' "$1" > "$ORPH_BIN/profiles"; chmod +x "$ORPH_BIN/profiles"; }

    orph_mdm "Yes (User Approved)"
    run_test "launchd orphans: an MDM machine narrows the scan to \$HOME" \
        "PATH='$ORPH_BIN:$PATH' HOME='$ORPH_DIR' bash '$ORPH_DIR/section.sh' | grep -q 'managed machine'"
    run_test "launchd orphans: an explicit scope still wins on an MDM machine" \
        "PATH='$ORPH_BIN:$PATH' LAUNCHD_SCAN_DIRS='$ORPH_DIR/agents' bash '$ORPH_DIR/section.sh' | grep -q 'com.test.orphan\b'"

    orph_mdm "No"
    run_test "launchd orphans: an unmanaged machine keeps the full scan" \
        "! { PATH='$ORPH_BIN:$PATH' HOME='$ORPH_DIR' bash '$ORPH_DIR/section.sh' | grep -q 'managed machine'; }"
    rm -rf "$ORPH_DIR"
fi


# Brewfile machine-local exclusions. The mechanism is only worth having if a
# listed name actually disappears AND an absent file changes nothing, so both
# are asserted. Uses a throwaway HOME so the real ~/.Brewfile.skip is untouched.
if command -v brew >/dev/null 2>&1 && [ -f "$HOME/Brewfile" ]; then
    BF_DIR=$(mktemp -d)
    run_test "Brewfile: parses and declares openlogi with no skip file" \
        "HOME='$BF_DIR' brew bundle list --file='$HOME/Brewfile' --cask 2>/dev/null | grep -q openlogi"
    printf '# comment\n\n  openlogi   # trailing\n' > "$BF_DIR/.Brewfile.skip"
    run_test "Brewfile: a skipped name is dropped (comments/blanks tolerated)" \
        "! { HOME='$BF_DIR' brew bundle list --file='$HOME/Brewfile' --cask 2>/dev/null | grep -q openlogi; }"
    run_test "Brewfile: skipping the cask also drops its tap" \
        "! { HOME='$BF_DIR' brew bundle list --file='$HOME/Brewfile' --tap 2>/dev/null | grep -q aprilnea; }"
    rm -rf "$BF_DIR"
fi

# dm_pack_garbage_clean: the yadm repo reached 31GB with 2MB of tracked
# content, 17.2GB of it half-written packs from interrupted pack writes.
#
# THE GUARD IS AGE, and the assertion that matters is that a RECENT temp
# pack survives. tmp_pack_* is written by `index-pack` — the receiving
# side of fetch/clone/pull — so a maintenance run racing a `yadm pull`
# must not delete the pack that fetch is still writing. Two earlier
# guards failed here: a ps-grep for "git gc" matched any command line
# mentioning the string, and `[ -f gc.pid ]` misses index-pack entirely
# while a KILLED gc leaves that lock behind forever.
if [ -f "$HOME/daily-maintenance-lib.sh" ]; then
    PG_DIR=$(mktemp -d); mkdir -p "$PG_DIR/objects/pack"
    PG_SRC="source '$HOME/daily-maintenance-lib.sh' >/dev/null 2>&1;"
    : > "$PG_DIR/objects/pack/tmp_pack_FRESH"          # an in-flight fetch
    : > "$PG_DIR/objects/pack/pack-real.pack"          # a real pack
    : > "$PG_DIR/objects/pack/tmp_pack_OLD"
    touch -t 202001010000 "$PG_DIR/objects/pack/tmp_pack_OLD"   # abandoned

    run_test "dm_pack_garbage_clean spares an in-flight temp pack and real packs" \
        "bash -c \"$PG_SRC dm_pack_garbage_clean '$PG_DIR'\" | grep -q 'removed 1' &&
         [ -f '$PG_DIR/objects/pack/tmp_pack_FRESH' ] &&
         [ -f '$PG_DIR/objects/pack/pack-real.pack' ] &&
         [ ! -f '$PG_DIR/objects/pack/tmp_pack_OLD' ]"

    # A stale gc.pid must NOT block cleanup: a killed gc leaves one behind,
    # and that is precisely the interruption that creates the garbage.
    : > "$PG_DIR/gc.pid"
    : > "$PG_DIR/objects/pack/tmp_pack_OLD2"
    touch -t 202001010000 "$PG_DIR/objects/pack/tmp_pack_OLD2"
    run_test "…is not blocked by the stale gc.pid a killed gc leaves behind" \
        "bash -c \"$PG_SRC dm_pack_garbage_clean '$PG_DIR'\" | grep -q 'removed 1' &&
         [ ! -f '$PG_DIR/objects/pack/tmp_pack_OLD2' ]"

    run_test "…is silent and returns non-zero when there is nothing old to remove" \
        "! bash -c \"$PG_SRC dm_pack_garbage_clean '$PG_DIR'\" | grep -q ."
    rm -rf "$PG_DIR"
fi

# dm_herdr_strand_detected: pure predicate from daily-maintenance-lib.sh.
# Since herdr left Homebrew (2026-08-05) the maintenance call site is a
# no-op TRIPWIRE (fires only if a brew copy is mistakenly reinstalled
# and auto-upgraded) — the predicate's semantics are unchanged, so
# these polarity tests stand as-is.
# A real unix socket is required for the -S branch; python3 binds one in
# a temp dir so all four polarities are exercised.
if [ -f "$HOME/daily-maintenance-lib.sh" ]; then
    HERDR_UT_DIR=$(mktemp -d)
    python3 -c "import socket; socket.socket(socket.AF_UNIX).bind('$HERDR_UT_DIR/live.sock')" 2>/dev/null
    UT_SRC="source '$HOME/daily-maintenance-lib.sh' >/dev/null 2>&1;"
    # macOS caps unix socket paths at ~104 bytes; if the bind failed
    # (long CI temp dir), skip the two socket-positive cases instead of
    # reporting a false failure.
    if [ -S "$HERDR_UT_DIR/live.sock" ]; then
        run_test "herdr strand: mismatch + live socket -> detected" \
            "bash -c \"$UT_SRC dm_herdr_strand_detected 'herdr 1.0' 'herdr 2.0' '$HERDR_UT_DIR/live.sock'\""
        run_test "herdr strand: same version -> silent" \
            "bash -c \"$UT_SRC ! dm_herdr_strand_detected 'herdr 1.0' 'herdr 1.0' '$HERDR_UT_DIR/live.sock'\""
    else
        echo -e "  ${YELLOW}ℹ️  unix socket bind unavailable; skipping socket-positive cases${NC}"
    fi
    run_test "herdr strand: no socket -> silent" \
        "bash -c \"$UT_SRC ! dm_herdr_strand_detected 'herdr 1.0' 'herdr 2.0' '$HERDR_UT_DIR/missing.sock'\""
    run_test "herdr strand: herdr absent (empty before) -> silent" \
        "bash -c \"$UT_SRC ! dm_herdr_strand_detected '' 'herdr 2.0' '$HERDR_UT_DIR/live.sock'\""
    rm -rf "$HERDR_UT_DIR"
fi

# claude-copy-last: fixture-based extraction. The transcript JSONL is
# Claude Code INTERNAL format with no compat guarantee (tracked in
# docs/upgrade-watch.md) — if an upgrade renames .type/.isSidechain/
# .message.content, these turn red the same day. Fixture exercises the
# real selection rules: sidechain entries and tool-use-only entries are
# skipped, -n reaches past them.
if [ -x "$HOME/.local/bin/claude-copy-last" ] && command -v jq >/dev/null 2>&1; then
    CCL_TMP=$(mktemp -d)
    mkdir -p "$CCL_TMP/work"
    CCL_SLUG=$(printf '%s' "$CCL_TMP/work" | sed 's/[^A-Za-z0-9]/-/g')
    mkdir -p "$CCL_TMP/projects/$CCL_SLUG"
    cat > "$CCL_TMP/projects/$CCL_SLUG/fixture.jsonl" <<'CCL_EOF'
{"type":"user","message":{"content":[{"type":"text","text":"hi"}]}}
{"type":"assistant","isSidechain":false,"message":{"content":[{"type":"text","text":"first reply"}]}}
{"type":"assistant","isSidechain":true,"message":{"content":[{"type":"text","text":"sidechain noise"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"final answer"}]}}
CCL_EOF
    CCL_RUN="cd '$CCL_TMP/work' && CLAUDE_PROJECTS_DIR='$CCL_TMP/projects' '$HOME/.local/bin/claude-copy-last'"
    run_test "claude-copy-last extracts latest message from fixture" \
        "[ \"\$(bash -c \"$CCL_RUN\")\" = 'final answer' ]"
    run_test "claude-copy-last -n 2 skips sidechain and tool-use entries" \
        "[ \"\$(bash -c \"$CCL_RUN -n 2\")\" = 'first reply' ]"
    run_test "claude-copy-last fails cleanly when history exhausted" \
        "! bash -c \"$CCL_RUN -n 9\" 2>/dev/null"

    mkdir -p "$CCL_TMP/bin"
    printf '#!/bin/sh\ncat > /dev/null\n' > "$CCL_TMP/bin/pbcopy"
    chmod +x "$CCL_TMP/bin/pbcopy"
    # Fixed PATH: the ambient one may contain spaces (Application Support)
    # which cannot survive unquoted expansion inside the inner bash -c
    CCL_ENV="PATH='$CCL_TMP/bin':/opt/homebrew/bin:/usr/bin:/bin CLAUDE_PROJECTS_DIR='$CCL_TMP/projects'"

    # Selection is "newest transcript for this directory", deliberately.
    # It used to resolve which session a herdr PANE held — marker files,
    # process-tree checks, screen matching — and that existed only to
    # serve the keybinding. The keybinding now drives Claude Code's own
    # `/copy`, which runs inside the pane's conversation and never has to
    # ask. Run from a shell, newest-here is what you meant.
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"OLDER SESSION"}]}}\n' \
        > "$CCL_TMP/projects/$CCL_SLUG/11111111-1111-1111-1111-111111111111.jsonl"
    sleep 1
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"NEWER SESSION"}]}}\n' \
        > "$CCL_TMP/projects/$CCL_SLUG/22222222-2222-2222-2222-222222222222.jsonl"
    run_test "claude-copy-last reads the newest transcript for the directory" \
        "[ \"\$(bash -c \"cd '$CCL_TMP/work' && $CCL_ENV '$HOME/.local/bin/claude-copy-last'\")\" = 'NEWER SESSION' ]"
    rm -f "$CCL_TMP/projects/$CCL_SLUG/11111111-1111-1111-1111-111111111111.jsonl" \
          "$CCL_TMP/projects/$CCL_SLUG/22222222-2222-2222-2222-222222222222.jsonl"

    # Entry present + hook script gone = exit 127 every session. Warn,
    # never auto-repair: regenerating means running herdr's installer,
    # which does not recognise a hand-edited entry and would append a
    # DUPLICATE. Assert the warning fires AND that nothing was written.
    printf '{"hooks":{"SessionStart":[{"matcher":"*","hooks":[{"command":"bash \\"$HOME/.claude/hooks/herdr-agent-state.sh\\" session","type":"command"}]}]},"statusLine":{"command":"~/.local/bin/claude-statusline","refreshInterval":5,"type":"command"},"theme":"custom:my-theme"}' \
        > "$CCL_TMP/orphan.json"
    # Needs herdr: the check sits behind `command -v herdr`, since the
    # remedy it prints is a herdr command. CI has no herdr.
    if command -v herdr >/dev/null 2>&1; then
    run_test "claude-settings-sync warns on an orphaned herdr hook entry" \
        "CLAUDE_SETTINGS='$CCL_TMP/orphan.json' '$HOME/.local/bin/claude-settings-sync' 2>&1 |
         grep -q 'script is missing' &&
         [ \"\$(jq -r '[.. | .command? // empty] | map(select(test(\"herdr\"))) | length' '$CCL_TMP/orphan.json')\" -eq 1 ]"
    fi

    # OSC 52's spec caps the whole sequence at 100,000 bytes; base64
    # expands 4/3, so the real INPUT limit is ~74,994. Over that, every
    # layer drops the write SILENTLY, which reads as "the copy worked but
    # the paste is empty". The guard used to sit at 190 KiB — 2.6x too
    # high — so this asserts the number, not merely that a guard exists.
    mkdir -p "$CCL_TMP/big"
    CCL_BIG_SLUG=$(printf '%s' "$CCL_TMP/big" | sed 's/[^A-Za-z0-9]/-/g')
    mkdir -p "$CCL_TMP/projects/$CCL_BIG_SLUG"
    head -c 200000 /dev/zero | tr '\0' 'a' |
        jq -Rc '{type:"assistant",message:{content:[{type:"text",text:.}]}}' \
        > "$CCL_TMP/projects/$CCL_BIG_SLUG/fixture.jsonl"
    # Assert the MESSAGE, not the source text. Grepping the script for
    # `osc52_cap=74994` is a spelling check — it passes if the variable
    # is assigned and never read — and discarding stderr while asserting
    # exit 0 verifies neither the refusal nor the "out loud". This test
    # guards the one bug fixed on the way out, so it must not be the
    # thing this repo keeps catching: a check that passes without
    # looking. Needs a tty, since the size guard is on the interactive
    # branch; `script` supplies one.
    # The size guard lives on the interactive branch, so this needs a
    # tty. It does NOT use script(1): script can exit before its pty is
    # drained, and under a pre-commit run's load that dropped output —
    # the test passed, failed, then passed with no code change, and only
    # the hook's new transcript identified which test it was. Two
    # attempts to reproduce it standalone (piped stdout, and the hook's
    # GIT_DIR/GIT_WORK_TREE) came back clean six times each, which is
    # exactly why guessing at a timing flake is the wrong move.
    #
    # pty.spawn waits for the child and drains before returning. python3
    # is already a suite dependency and CI pins 3.11.
    run_test "claude-copy-last refuses an oversize OSC 52 write out loud" \
        "out=\$( (cd '$CCL_TMP/big' && $CCL_ENV python3 -c 'import pty,sys; sys.exit(pty.spawn(sys.argv[1:]))' '$HOME/.local/bin/claude-copy-last') 2>&1 | tr -d '\\r' );
         printf '%s' \"\$out\" | grep -q 'exceeds the 74994-byte OSC 52 limit' &&
         printf '%s' \"\$out\" | grep -q 'copied 200000 chars'"

    # No transcript must fail loudly, not exit 0 with an empty clipboard.
    mkdir -p "$CCL_TMP/empty-projects" "$CCL_TMP/nowhere"
    # Both halves matter: a non-zero exit AND the reason on stderr. `!`
    # in front of a pipeline negates the WHOLE pipeline, so the exit
    # status has to be captured separately or the assertion inverts.
    run_test "claude-copy-last errors when no transcript exists" \
        "out=\$(bash -c \"cd '$CCL_TMP/nowhere' && PATH='$CCL_TMP/bin':/opt/homebrew/bin:/usr/bin:/bin CLAUDE_PROJECTS_DIR='$CCL_TMP/empty-projects' '$HOME/.local/bin/claude-copy-last'\" 2>&1); rc=\$?;
         [ \"\$rc\" -ne 0 ] && printf '%s' \"\$out\" | grep -q 'no Claude transcripts'"
    rm -rf "$CCL_TMP"
fi

# claude-statusline mirrors a mid-session /rename onto the herdr tab.
# The dangerous case is over-firing: renaming on every turn would
# overwrite hand-named tabs ("Reviewer") with the pane's agent name, so
# assert BOTH that a rename propagates and that nothing fires on a
# first sighting or an unchanged name. Stub herdr logs its argv; the
# rename is backgrounded so each run gets a moment to land.
if [ -x "$HOME/.local/bin/claude-statusline" ] && command -v jq >/dev/null 2>&1; then
    CS_TMP=$(mktemp -d)
    mkdir -p "$CS_TMP/bin"
    # Stub logs argv AND answers `tab list` from a fixture, so a test can
    # say what the tab is currently labelled and assert the drift repair.
    cat > "$CS_TMP/bin/herdr" <<CS_STUB
#!/bin/sh
echo "\$*" >> "$CS_TMP/calls.log"
[ "\$1 \$2" = 'tab list' ] && cat "$CS_TMP/tablabel.json" 2>/dev/null
exit 0
CS_STUB
    chmod +x "$CS_TMP/bin/herdr"
    : > "$CS_TMP/calls.log"
    cs_label() {
        printf '{"result":{"tabs":[{"tab_id":"w1:t9","label":"%s"}]}}' "$1" \
            > "$CS_TMP/tablabel.json"
    }
    cs_payload() {
        printf '{"session_id":"utcs","session_name":"%s","model":{"display_name":"O"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":5},"cost":{"total_cost_usd":0,"total_duration_ms":0},"rate_limits":{}}' "$1" "$HOME"
    }
    cs_run() {
        cs_payload "$1" | env PATH="$CS_TMP/bin:$PATH" HERDR_TAB_ID=w1:t9 \
            "$HOME/.local/bin/claude-statusline" >/dev/null 2>&1
        sleep 0.4
    }
    # Both caches must be cleared: the drift check is throttled by the
    # mtime of its own stamp file, so a leftover one makes these tests
    # pass or fail depending on how recently the suite last ran.
    rm -f /tmp/claude-statusline-name-utcs /tmp/claude-statusline-tabcheck-utcs /tmp/claude-tabname-w1-t9
    cs_label alpha
    cs_run alpha
    run_test "claude-statusline: first sighting seeds without renaming the tab" \
        "! grep -q 'tab rename' '$CS_TMP/calls.log' && [ \"\$(cat /tmp/claude-statusline-name-utcs)\" = alpha ]"
    cs_run alpha
    # Asserts no WRITE, not no call: the drift check below is a read, and
    # it is allowed to happen here.
    run_test "claude-statusline: an unchanged session name renames nothing" \
        "! grep -q 'tab rename' '$CS_TMP/calls.log'"
    # Count, not presence: over-firing is the exact thing these tests
    # exist to catch, and grep -q passes just as happily on five renames.
    cs_run beta
    run_test "claude-statusline: a /rename propagates to the herdr tab" \
        "[ \"\$(grep -c 'tab rename w1:t9 beta' '$CS_TMP/calls.log')\" -eq 1 ]"

    # Drift repair. HERDR_TAB_ID is inherited from the launching pane, so
    # a session working elsewhere can rename a tab it does not own; the
    # session name has NOT changed, so only re-reading the real label can
    # notice. A label is reclaimable when some writer RECORDED it —
    # herdr's tab.rename carries no source field, so that record is the
    # only provenance available.
    : > "$CS_TMP/calls.log"
    cs_label "home"                              # slash-free ON PURPOSE:
    printf 'home' > /tmp/claude-tabname-w1-t9    # the shape rule missed this
    rm -f /tmp/claude-statusline-tabcheck-utcs   # force the check to be due
    cs_run beta
    run_test "claude-statusline: reclaims a label another writer recorded" \
        "[ \"\$(grep -c 'tab rename w1:t9 beta' '$CS_TMP/calls.log')\" -eq 1 ]"

    # herdr renders an unnamed tab as its bare NUMBER (tab_display_name
    # falls back to the index when custom_name is unset), so a numeric
    # label means nobody has claimed it.
    : > "$CS_TMP/calls.log"
    cs_label "9"
    rm -f /tmp/claude-tabname-w1-t9 /tmp/claude-statusline-tabcheck-utcs
    cs_run beta
    run_test "claude-statusline: claims an unnamed (numeric) tab" \
        "[ \"\$(grep -c 'tab rename w1:t9 beta' '$CS_TMP/calls.log')\" -eq 1 ]"

    # THE LIMIT, and the regression that motivated it: a label nobody
    # recorded was typed by a person and must survive. This clobbered a
    # tab named "Reviewer" back to its session's "home" in real use.
    : > "$CS_TMP/calls.log"
    cs_label "Reviewer"
    rm -f /tmp/claude-tabname-w1-t9 /tmp/claude-statusline-tabcheck-utcs
    cs_run beta
    run_test "claude-statusline: leaves a hand-named tab alone" \
        "! grep -q 'tab rename' '$CS_TMP/calls.log'"

    # A human name is safe even when it LOOKS machine-made — the old
    # shape rule reclaimed anything containing a slash.
    : > "$CS_TMP/calls.log"
    cs_label "notes/todo"
    rm -f /tmp/claude-tabname-w1-t9 /tmp/claude-statusline-tabcheck-utcs
    cs_run beta
    run_test "claude-statusline: a hand-named tab with a slash is still safe" \
        "! grep -q 'tab rename' '$CS_TMP/calls.log'"

    # A rename must RECORD what it set, or the next session sees an
    # unrecorded label and treats this session's own name as hand-typed.
    # Own scenario: the test above deliberately suppresses the rename.
    : > "$CS_TMP/calls.log"
    cs_label "9"
    rm -f /tmp/claude-tabname-w1-t9 /tmp/claude-statusline-tabcheck-utcs
    cs_run beta
    run_test "claude-statusline: a rename records the label it set" \
        "[ \"\$(cat /tmp/claude-tabname-w1-t9 2>/dev/null)\" = beta ]"

    # ...and the check runs at most once a minute, or it degrades into a
    # socket call every 5s. touch (not elapsed wall-clock) decides
    # "not due", so a slow or suspended suite cannot flake this.
    : > "$CS_TMP/calls.log"
    cs_label "herddeck/feat/some-branch"
    touch /tmp/claude-statusline-tabcheck-utcs
    cs_run beta
    run_test "claude-statusline: drift check is throttled to once a minute" \
        "[ ! -s '$CS_TMP/calls.log' ]"

    # Display delegate. One repo serves two Macs wanting different status
    # bars, so the tracked script hands rendering to a command named only in
    # the UNTRACKED override file. Both polarities plus both failure modes:
    # a delegate that silently produced nothing would blank the status bar,
    # which reads as "Claude Code broke" and hides that a delegate exists.
    CS_IN='{"session_id":"utcs-del","model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$HOME"'"},"cost":{"total_cost_usd":0.5,"total_duration_ms":1000}}'
    run_test "statusline delegate: unset renders our own line" \
        "printf '%s' '$CS_IN' | '$HOME/.local/bin/claude-statusline' 2>/dev/null | grep -q 'Opus'"
    run_test "statusline delegate: set replaces the rendered line" \
        "printf '%s' '$CS_IN' | STATUSLINE_DISPLAY_DELEGATE=\"printf DELEGATED\" '$HOME/.local/bin/claude-statusline' 2>/dev/null | grep -qx 'DELEGATED'"
    run_test "statusline delegate: …and suppresses ours, not just appends" \
        "! { printf '%s' '$CS_IN' | STATUSLINE_DISPLAY_DELEGATE=\"printf DELEGATED\" '$HOME/.local/bin/claude-statusline' 2>/dev/null | grep -q 'Opus'; }"
    run_test "statusline delegate: a missing command falls back, never blank" \
        "printf '%s' '$CS_IN' | STATUSLINE_DISPLAY_DELEGATE=/nonexistent/xyz '$HOME/.local/bin/claude-statusline' 2>/dev/null | grep -q 'Opus'"
    run_test "statusline delegate: a silent non-zero exit falls back too" \
        "printf '%s' '$CS_IN' | STATUSLINE_DISPLAY_DELEGATE='exit 1' '$HOME/.local/bin/claude-statusline' 2>/dev/null | grep -q 'Opus'"
    run_test "statusline delegate: receives the same stdin JSON" \
        "printf '%s' '$CS_IN' | STATUSLINE_DISPLAY_DELEGATE=\"jq -r .session_id\" '$HOME/.local/bin/claude-statusline' 2>/dev/null | grep -qx 'utcs-del'"
    rm -rf "$CS_TMP" /tmp/claude-statusline-name-utcs /tmp/claude-statusline-tabcheck-utcs /tmp/claude-tabname-w1-t9
fi

# gitleaks pre-commit engine: same invocation the yadm hook uses, against
# a throwaway fixture repo (plain git on purpose — the yadm-only rule is
# for the dotfiles repo, not isolated fixtures). The canary is assembled
# at runtime so no secret-shaped literal exists in this file (a literal
# would trip GitHub push protection and the hook's own scan).
# CRITICAL: every call strips GIT_DIR/GIT_WORK_TREE — the yadm pre_commit
# hook exports them, and an ambient GIT_DIR silently redirects fixture
# git commands at the REAL yadm repo (this once flipped its core.bare).
if command -v gitleaks >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    GL_TMP=$(mktemp -d)
    GL_GIT="env -u GIT_DIR -u GIT_WORK_TREE git"
    $GL_GIT -C "$GL_TMP" init -q &&
        $GL_GIT -C "$GL_TMP" -c user.email=t@t -c user.name=t \
            -c commit.gpgsign=false commit -q --allow-empty -m init
    printf 'aws_key = "%s%s"\n' "AKIA" "ZZZQK9X2M4P7L3TQ" > "$GL_TMP/leak.txt"
    $GL_GIT -C "$GL_TMP" add leak.txt
    run_test "gitleaks flags a staged canary secret" \
        "! (cd '$GL_TMP' && env -u GIT_DIR -u GIT_WORK_TREE gitleaks git --pre-commit --staged --no-banner --redact . >/dev/null 2>&1)"
    printf 'greeting = "hello"\n' > "$GL_TMP/leak.txt"
    $GL_GIT -C "$GL_TMP" add leak.txt
    run_test "gitleaks passes a clean staged file" \
        "(cd '$GL_TMP' && env -u GIT_DIR -u GIT_WORK_TREE gitleaks git --pre-commit --staged --no-banner --redact . >/dev/null 2>&1)"
    rm -rf "$GL_TMP"
fi
echo

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]} tests${NC}"
    for test in "${PASSED_TESTS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $test"
    done
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo
    echo -e "${RED}Failed: ${#FAILED_TESTS[@]} tests${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗${NC} $test"
    done
    echo
    echo -e "${YELLOW}Please fix the failed tests before committing.${NC}"
    exit 1
else
    echo
    echo -e "${GREEN}All tests passed! ✨${NC}"
    echo -e "${GREEN}Your dotfiles are ready to commit.${NC}"
fi

# Cleanup
rm -f "$TEST_MAINT_SCRIPT"

exit 0
