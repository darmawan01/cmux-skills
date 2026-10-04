# cmux skills for Claude Code

The [cmux](https://github.com/manaflow-ai/cmux) agent skills, packaged for
[Claude Code](https://claude.com/claude-code). Upstream ships them through a
`skills.sh` that installs into `~/.codex/skills`. This repo turns them into a
Claude Code plugin marketplace and adapts the parts that only worked for Codex.

Upstream pin: [`UPSTREAM`](UPSTREAM).

## Install

### As Claude Code plugins (recommended)

```bash
claude plugin marketplace add darmawan01/cmux-skills
claude plugin install cmux@cmux-skills        # driving the cmux app
claude plugin install cmux-dev@cmux-skills    # optional: contributing to manaflow-ai/cmux
```

Or inside a Claude Code session: `/plugin marketplace add darmawan01/cmux-skills`,
then `/plugin install cmux@cmux-skills`.

Plugin skills are namespaced, e.g. `/cmux:cmux-browser`. Claude also loads
them on its own when a task matches the skill description.

Update with `claude plugin marketplace update cmux-skills && claude plugin update cmux@cmux-skills`.

### As plain skills (`~/.claude/skills`)

```bash
curl -fsSL https://raw.githubusercontent.com/darmawan01/cmux-skills/main/install.sh | bash
```

`install.sh` options: `--dev` (contributor skills too), `--skill NAME` (repeat for
several), `--project` (install into `./.claude/skills`), `--dest DIR`, `--list`, `--dry-run`.

## What's included

### `cmux` plugin: using the app

| [`cmux`](plugins/cmux/skills/cmux/SKILL.md) | End-user control of cmux topology and routing (windows, workspaces, panes/surfaces, focus, moves, reorder, identify, trigger flash). |
| [`cmux-browser`](plugins/cmux/skills/cmux-browser/SKILL.md) | End-user browser automation with cmux. |
| [`cmux-capture`](plugins/cmux/skills/cmux-capture/SKILL.md) | Screenshot or record a cmux window from the CLI, for a pull request, a bug report, or to see what the app actually looks like right now. |
| [`cmux-cloud-vm`](plugins/cmux/skills/cmux-cloud-vm/SKILL.md) | Operate cmux Cloud machines, run durable remote commands or agents, and present their workspaces or services. |
| [`cmux-cua`](plugins/cmux/skills/cmux-cua/SKILL.md) | Use only after the user explicitly asks for cmux Computer Use through the cmux-cua skill: drive real macOS apps from a cmux agent session via the bundled engine (accessibility tree + screenshots, click/type/scroll/drag, branded cursor), or explain its user-directed permission setup. Reading or discovering this skill is not consent. |
| [`cmux-custom-sidebar`](plugins/cmux/skills/cmux-custom-sidebar/SKILL.md) | Build a custom cmux sidebar from a plain-language request. |
| [`cmux-customization`](plugins/cmux/skills/cmux-customization/SKILL.md) | Customize cmux for an end user, including terminal, browser, Markdown, diff, file preview, notes, HTML, and right-sidebar viewers. |
| [`cmux-diagnostics`](plugins/cmux/skills/cmux-diagnostics/SKILL.md) | Run end-user cmux diagnostics. |
| [`cmux-keyboard-shortcuts`](plugins/cmux/skills/cmux-keyboard-shortcuts/SKILL.md) | Guide and apply cmux keyboard shortcut customization. |
| [`cmux-markdown`](plugins/cmux/skills/cmux-markdown/SKILL.md) | Open markdown files in a formatted viewer panel with live reload. |
| [`cmux-settings`](plugins/cmux/skills/cmux-settings/SKILL.md) | View and edit cmux settings in ~/.config/cmux/cmux.json, including terminal, browser, Markdown, diff, notes, HTML, file preview, and sidebar-tool behavior. |
| [`cmux-workspace`](plugins/cmux/skills/cmux-workspace/SKILL.md) | Work inside the current cmux workspace and terminal. |

### `cmux-dev` plugin: working on cmux itself

These assume you are inside a `manaflow-ai/cmux` checkout.

| [`cmux-architecture`](plugins/cmux-dev/skills/cmux-architecture/SKILL.md) | cmux package architecture, refactor layering, dependency inversion, file organization, DocC documentation, package design discipline, testability, and Swift 6 concurrency rules. |
| [`cmux-backend`](plugins/cmux-dev/skills/cmux-backend/SKILL.md) | Backend TypeScript and Cloud VM development rules for cmux. |
| [`cmux-billing`](plugins/cmux-dev/skills/cmux-billing/SKILL.md) | Stripe checkout, pricing, subscription, Pro plan, webhook, and entitlement runbook for cmux billing work. |
| [`cmux-debugging`](plugins/cmux-dev/skills/cmux-debugging/SKILL.md) | Debug logging, Debug menu, runtime pitfalls, typing-latency-sensitive paths, SwiftUI list snapshot boundaries, OS-version repros, and local visual iteration for cmux. |
| [`cmux-dev-workflow`](plugins/cmux-dev/skills/cmux-dev-workflow/SKILL.md) | Contributor workflow for native cmux setup, tagged dev builds, Xcode project normalization and sidebar extensions. |
| [`cmux-ghostty`](plugins/cmux-dev/skills/cmux-ghostty/SKILL.md) | Ghostty submodule and GhosttyKit workflow rules for cmux. |
| [`cmux-localization`](plugins/cmux-dev/skills/cmux-localization/SKILL.md) | Localization rules and audit workflow for cmux UI strings, settings rows, menus, shortcuts, schema/config text, docs, command/help text, alerts, tooltips, and web messages. |
| [`cmux-release`](plugins/cmux-dev/skills/cmux-release/SKILL.md) | cmux release workflow, version bumping, changelog updates, pretag guard, release tags, and release asset expectations. |
| [`cmux-review`](plugins/cmux-dev/skills/cmux-review/SKILL.md) | Review agent-written changes before merge, after substantial edits, or when re-reviewing a repair. |
| [`cmux-shared-behavior`](plugins/cmux-dev/skills/cmux-shared-behavior/SKILL.md) | Shared behavior and mutation-path rules for cmux. |
| [`cmux-socket-policy`](plugins/cmux-dev/skills/cmux-socket-policy/SKILL.md) | Socket command threading and focus policy for cmux CLI/socket work. |
| [`cmux-test-bisect`](plugins/cmux-dev/skills/cmux-test-bisect/SKILL.md) | Find when and why tests broke on main: bisect a Swift package suite on CI across old commits, read the failure matrix, and decide per test whether the test went stale or the code regressed. |
| [`cmux-testing`](plugins/cmux-dev/skills/cmux-testing/SKILL.md) | Choose scoped cmux verification, add behavioral tests, and validate Swift test targets and wiring. |

## Changes from upstream

All changes are made by [`scripts/claudeify.py`](scripts/claudeify.py), so they can be re-applied to any upstream ref.

- **Two plugins instead of one bundle.** Every installed skill description costs
  context in every session. App users don't need Stripe product IDs or Swift 6
  concurrency rules, so contributor skills live in a separate, optional `cmux-dev` plugin.
- **Claude Code hook diagnostics.** cmux has no `cmux hooks setup` for Claude Code.
  Instead, it puts a `claude` shim on PATH inside cmux terminals that injects hooks.
  `cmux-diagnostics` now checks for that shim and reports `active`, `missing`, or
  `shadowed`. Shadowed means a shell profile put the real `claude` binary ahead of
  the shim, so notifications and session resume stay silent.
  The upstream text pointed at `cmux hooks setup --agent codex`.
- **Helper paths.** `cmux-settings` and `cmux-diagnostics` scripts are looked up in
  `~/.claude/skills` and the Claude Code plugin cache instead of `~/.codex/skills`
  (`cmux-settings`, `cmux-keyboard-shortcuts`, `cmux-customization`, `cmux-diagnostics`).
- **Install/refresh instructions** in `cmux-browser` point at this repo.
- **`cmux-browser/AGENTS.md`** moved to `references/agent-instructions.md` and is linked from
  `SKILL.md`. Claude Code doesn't read a skill's `AGENTS.md`.
- **Codex UI metadata** (`agents/openai.yaml`) removed.
- Examples that pick an agent (`cmux vm agent --agent …`, `cmux-markdown`'s project
  instructions) use Claude. Docs for real cmux features that involve Codex, like
  `codex queue` on Cloud VMs, are unchanged.

### Optional: fewer permission prompts

The skills don't pre-approve any commands. If you trust them, allow the cmux CLI
in `~/.claude/settings.json`:

```json
{ "permissions": { "allow": ["Bash(cmux:*)"] } }
```

## Syncing with upstream

```bash
scripts/sync-upstream.sh main   # fetch manaflow-ai/cmux@main, re-apply patches, update UPSTREAM
git diff --stat
```

If upstream rewords a passage that a patch depends on, the sync fails and names the
file. Update `scripts/claudeify.py` and run it again. New upstream skills go to
`cmux-dev` unless you add them to `USER_SKILLS`.

## License

The skills come from [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux),
Copyright (c) 2024-present Manaflow, Inc., licensed under GPL-3.0-or-later. This
repository is a modified redistribution under the same license. See [LICENSE](LICENSE),
[NOTICE](NOTICE) and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
Not affiliated with or endorsed by Manaflow.
