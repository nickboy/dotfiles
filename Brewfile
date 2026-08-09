# Homebrew requires third-party taps to be trusted before it will load their
# formulae, and an untrusted one makes every brew command print a warning and
# skip the package. Trust the individual formulae rather than whole taps:
# `brew trust <tap>` also covers every formula the tap adds in future, which is
# a lot of standing permission for a personal repo.
#
#   brew trust --formula jstkdng/programs/ueberzugpp
#   brew trust --formula smudge/smudge/nightlight
#   brew trust --formula yakitrak/yakitrak/notesmd-cli
#
# Kept on Homebrew rather than moved to a runtime manager on purpose. A tap
# pins a URL and a sha256 in a formula you can read, and refuses to load until
# you say so; that visible gate plus an auditable pin is worth more than one
# fewer tap. mise carries bun as a core tool, but the download source and
# checksum are compiled into mise, there is no per-install gate, and its
# verification settings are per-backend (node.verify and go checksums are on,
# locked_verify_provenance is off) with nothing bun-specific.

tap "charmbracelet/tap"
tap "oven-sh/bun"
tap "smudge/smudge"
tap "tw93/tap"
tap "yakitrak/yakitrak"
# Code searching, linting, rewriting
brew "ast-grep"
# Network bandwidth utilization tool
brew "bandwhich"
# Bourne-Again SHell, a UNIX command interpreter (v5, needed by tmux-which-key)
brew "bash"
# Clone of cat(1) with syntax highlighting and Git integration
brew "bat"
# Resource monitor (modern top/htop replacement)
brew "btop"
# Apple Silicon power/thermal monitor, no sudo (CPU/GPU/ANE)
brew "macmon"
# Fast JavaScript runtime, bundler, and package manager
brew "bun"
# Versatile and fast Unicode/ASCII/ANSI graphics renderer
brew "chafa"
# Human-friendly cut alternative
brew "choose-rust"
# Cross-platform make
brew "cmake"
# GNU core utilities (provides gtimeout, gdate, etc.)
brew "coreutils"
# Claude Code usage and cost tracker
brew "ccusage"
# Dependency Manager for PHP
brew "composer"
# Command-line DNS client for humans
brew "doggo"
# Disk usage analyzer (modern du replacement)
brew "duf"
# Disk usage tree (modern du replacement)
brew "dust"
# Modern, maintained replacement for ls
brew "eza"
# Simple, fast and user-friendly alternative to find
brew "fd"
# Command-line fuzzy finder written in Go
brew "fzf"
# Syntax-highlighting pager for git and diff output
brew "git-delta"
# Structural (syntax-aware) diff tool — complements delta ('git dft' alias)
brew "difftastic"
# Render markdown in the terminal
brew "glow"
# Open source programming language to build simple/reliable/efficient software
brew "go"
# Hex viewer (modern hexdump replacement)
brew "hexyl"
# Command-line benchmarking tool
brew "hyperfine"
# Lightweight JSON processor (used by tmux-which-key)
brew "jq"
# CSV/TSV pager: aligned columns, sticky header, search ("less for CSV")
brew "csvlens"
# Fast, Dynamic Programming Language
brew "julia"
# Git-compatible version control system
brew "jj"
# TUI for jj (Jujutsu)
brew "jjui"
# Syntax-aware merge conflict resolver (wired as a git merge driver)
brew "mergiraf"
# Just a command runner
brew "just"
# Simple terminal UI for git commands
brew "lazygit"
# Package manager for the Lua programming language
brew "luarocks"
# AI on the command-line (pipe shell output to LLMs)
brew "mods"
# Polyglot dev tool version manager (replaces asdf/nvm/pyenv)
brew "mise"
# Ambitious Vim-fork focused on extensibility and agility
brew "neovim"
# CLI for macOS Night Shift
brew "smudge/smudge/nightlight"
# CLI to open, search, and manage Obsidian/NotesMD vaults
brew "yakitrak/yakitrak/notesmd-cli"
# Mac disk cleanup CLI (tw93)
brew "mole"
# Node kept in brew for formula deps (ccusage, pyright);
# userland Node is managed by mise
brew "node"
# Development kit for the Java programming language
brew "openjdk"
# Painless compression/decompression, auto-detects formats (extract/x aliases)
brew "ouch"
# Terminal HTTP client TUI (Postman-style; requests stored as plain YAML)
brew "posting"
# Highly capable, feature-rich programming language
brew "perl"
# Execute binaries from Python packages in isolated environments
brew "pipx"
# Modern replacement for ps written in Rust
brew "procs"
# Static type checker for Python
brew "pyright"
# Search tool like grep and The Silver Searcher
brew "ripgrep"
# Intuitive find & replace CLI (sed alternative)
brew "sd"
# Interactive find-and-replace TUI (serpl successor)
brew "scooter"
# Tool to find ROP sequences in PE/Elf/Mach-O x86/x64 binaries
brew "rp"
# Extremely fast Python linter, written in Rust
brew "ruff"
# Safe, concurrent, practical language
brew "rust"
# Rust toolchain installer
brew "rustup"
# Static analysis and linting for Bash/Shell scripts
brew "shellcheck"
# Secret scanner; staged-diff scan runs in the yadm pre_commit hook
brew "gitleaks"
# Security audit for GitHub Actions workflows (also runs in CI)
brew "zizmor"
# Semantic linter for GitHub Actions workflows (also runs in CI)
brew "actionlint"
# Cross-platform prompt for any shell
brew "starship"
# NOTE: command correction is pay-respects (cargo install pay-respects,
# handled by bootstrap) — the old thefuck formula pulled in python@3.13
# Official tldr client written in Rust
brew "tlrc"
# macOS notification banners from the command line
brew "terminal-notifier"
# Fast fuzzy finder with built-in previews
brew "television"
# macOS file tagging CLI (used by yazi mactag plugin)
brew "tag"
# Zero-config log file highlighter/pager (binary: tspin)
brew "tailspin"
# Count lines of code quickly
brew "tokei"
# Terminal multiplexer
brew "tmux"
# Smart session manager for tmux
brew "sesh"
# 7-Zip (7zz) — required by yazi's compress plugin (only legacy 7z was
# present; the plugin probes 7zz first)
brew "sevenzip"
# Universal command argument completion
brew "carapace"
# Internet file retriever
brew "wget"
# HTTPie-like HTTP client written in Rust
brew "xh"
# An extremely fast Python package installer and resolver, written in Rust
brew "uv"
# Image preview backend for yazi. Declared because without it yazi still
# starts, still loads every plugin, and simply shows no images — a silent
# degradation with nothing to read. It was installed by hand here and
# missing from this file, so a fresh machine got exactly that.
brew "jstkdng/programs/ueberzugpp"
# Yet Another Dotfiles Manager
brew "yadm"
# Blazing fast terminal file manager written in Rust
brew "yazi"
# Terminal multiplexer (modern tmux alternative)
brew "zellij"
# herdr (AI-agent-aware multiplexer) is DELIBERATELY NOT in this file —
# it is managed by its own updater (~/.local/bin/herdr, install:
# curl -fsSL https://herdr.dev/install.sh | sh). Upstream disables
# 'herdr update' for brew installs, and only the self-updater supports
# LIVE HANDOFF (server replacement without killing panes). Owner call
# 2026-08-05: same class as ghostty@tip and bob — do not re-add the
# formula; a brew copy would shadow-race the self-managed binary.
# Shell extension to navigate your filesystem faster
brew "zoxide"
# Magical shell history with sync and search
brew "atuin"
# GitHub command-line tool
brew "gh"
# Neovim version manager (bob) is installed from git dev branch via cargo
# in the yadm bootstrap script. Homebrew's bob lags upstream and lacks the
# nvim proxy permission fix for nightly upgrades. See daily-maintenance.sh.
# Password manager that keeps all passwords secure behind one password
cask "1password"
# Command-line interface for 1Password
cask "1password-cli"
# Stand alone ad blocker
cask "adguard"
# Chromium based browser
cask "arc"
# Display management tool
cask "betterdisplay"
cask "font-hack-nerd-font"
cask "font-maple-mono-nf-cn"
# Ghostty is deliberately NOT managed here. The config runs
# auto-update-channel=tip and Sparkle keeps the app current by itself, so
# whichever cask brew tracks goes stale immediately and then fights the
# in-app updater. In practice brew had it pinned at the 1.3.1 stable cask
# while the app on disk had already moved to 1.3.2-main, and `brew bundle`
# failed with "Cask 'ghostty@tip' conflicts with 'ghostty'". Install it once
# from ghostty.org and let it update itself; do not re-add either cask.
# Free and open-source media player
cask "iina"
# Control your tools with a few keystrokes
cask "raycast"
# Window snapping tool
cask "rectangle-pro"
# Collection of apps available by subscription
cask "setapp"
# Sound and audio controller
cask "soundsource"
# Music streaming service
cask "spotify"
# Multiplayer code editor
cask "zed"
# Open-source code editor
cask "visual-studio-code"
