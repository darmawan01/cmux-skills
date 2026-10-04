---
name: cmux-diagnostics
description: "Run end-user cmux diagnostics. Use when cmux hooks, notifications, session restore, settings, browser automation, socket access, CLI control, or agent resume behavior is not working, or when the user asks for a cmux health check, doctor report, or support-safe debug summary."
---

# cmux Diagnostics

Collect and interpret support-safe cmux diagnostics for end users. Default to read-only checks. Never dump hook config files, session stores, prompt logs, tokens, or environment secrets.

## Quick report

Run the bundled read-only script first, from whichever install path exists:

```bash
skills/cmux-diagnostics/scripts/cmux-diagnostics            # cmux checkout
~/.claude/skills/cmux-diagnostics/scripts/cmux-diagnostics  # install.sh copy
"$(find ~/.claude/plugins/cache -path '*cmux-diagnostics/scripts/cmux-diagnostics' -type f | head -n 1)"  # plugin install
```

Add `--include-context` only when workspace names, cwd paths, and current cmux identifiers are relevant to the reported issue.

## What to check

1. **CLI and socket health**: `command -v cmux`, `cmux ping`, `cmux capabilities --json`. If socket commands fail, check whether the agent is running inside a cmux terminal and whether socket automation is enabled.
2. **Settings health**: `cmux-settings validate` and `cmux-settings get terminal.autoResumeAgentSessions` (the `cmux-settings` skill's `scripts/` helper, next to this skill). When `terminal.autoResumeAgentSessions` is false, cmux restores panes but does not resume saved agent sessions.
3. **Claude Code hooks**: Claude Code has no `cmux hooks setup` entry. Inside a cmux terminal, cmux puts a `claude` shim (`$TMPDIR/cmux-cli-shims/<surface>/claude`, backed by `cmux-claude-wrapper`) on PATH; it injects `--session-id` and `--settings` so hooks report back to cmux. If `command -v claude` resolves to the real binary instead (often a shell profile that prepends `~/.local/bin` after cmux's shell integration ran), notifications, sidebar status, and session resume stay silent. The script's `claude wrapper` section reports this. For other agents, use `cmux hooks setup --agent <name>` or bare `cmux hooks setup`. Run install or uninstall commands only after the user agrees.
4. **Session restore evidence**: `ls -lh ~/.cmuxterm/*-hook-sessions.json 2>/dev/null`. Missing stores usually mean the agent has not run inside cmux since hooks were installed, hooks are disabled, or the integration does not support resume capture.
5. **Notification path**: `cmux notify "cmux diagnostic test"`, only when the user is ready for a visible test notification.

## Interpretation

- `cmux` not found: the CLI is not installed or not on PATH for this shell.
- `cmux ping` fails: the app is closed, unreachable through the current socket path, or automation access is disabled.
- No `CMUX_WORKSPACE_ID` or `CMUX_SURFACE_ID`: the command is running outside a cmux terminal. Some hooks intentionally no-op there.
- `claude wrapper: shadowed`: the real `claude` binary precedes the cmux shim on PATH, so Claude Code runs without cmux hooks. Move the PATH edit in the shell profile above cmux's shell integration, or guard it with `[[ -z $CMUX_SURFACE_ID ]]`.
- Hook config but no session store: run one supported agent inside cmux after installing hooks, then re-check.
- Session store but no agents on restore: check `terminal.autoResumeAgentSessions` and whether the saved executable still exists on PATH.
- Settings validation fails: fix the config first. Invalid config makes later symptoms misleading.

## Rules

- Stay read-only until the user asks to fix something.
- Never print raw hook files, session JSON, prompt logs, shell history, tokens, or API keys. Summarize file presence, size, modified time, and marker presence instead.
- Prefer a narrow fix: for Claude Code, reorder PATH so the cmux shim wins inside cmux terminals; for other agents, `cmux hooks setup --agent <name>` over reinstalling every integration.
- After a fix, rerun the diagnostic script and report the changed lines.
