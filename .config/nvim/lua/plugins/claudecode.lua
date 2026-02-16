return {
  {
    "coder/claudecode.nvim",
    opts = {
      -- Terminal settings
      terminal = {
        -- 40% width instead of default 30% — gives Claude more room for
        -- markdown, code blocks, and file paths
        split_width_percentage = 0.40,

        -- Start Claude in the git repo root, not the current file's directory
        -- This means @file references resolve correctly from project root
        git_repo_cwd = true,

        -- Don't show the exit tip after closing native terminal
        show_native_term_exit_tip = false,
      },

      -- Diff behavior optimized for vibe coding review flow
      diff_opts = {
        -- Open diffs in a new tab so Claude terminal stays undisturbed
        open_in_new_tab = true,

        -- Keep focus in Claude terminal after diff opens
        -- So you can press Enter to accept/reject without switching windows
        keep_terminal_focus = true,

        -- Hide the Claude terminal split in the diff tab (full screen diff)
        hide_terminal_in_new_tab = true,
      },

      -- After sending a file/selection via <leader>as, focus Claude terminal
      -- so you can immediately type your prompt
      focus_after_send = true,
    },
  },
}
