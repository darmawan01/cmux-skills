#!/usr/bin/env python3
"""Copy upstream cmux skills into the two Claude Code plugins and adapt them.

usage: claudeify.py <upstream skills dir> <repo root>

Every text patch asserts its anchor exists, so an upstream rewording fails the
sync loudly instead of silently shipping Codex-only instructions.
"""
import shutil
import sys
from pathlib import Path

# End users of the cmux app. Everything else upstream is for contributors
# working inside a manaflow-ai/cmux checkout and goes to the cmux-dev plugin.
USER_SKILLS = {
    "cmux",
    "cmux-browser",
    "cmux-capture",
    "cmux-cloud-vm",
    "cmux-cua",
    "cmux-custom-sidebar",
    "cmux-customization",
    "cmux-diagnostics",
    "cmux-keyboard-shortcuts",
    "cmux-markdown",
    "cmux-settings",
    "cmux-workspace",
}

# Finds the cmux-settings helper in a cmux checkout, a ~/.claude/skills copy,
# or a Claude Code plugin install.
SETTINGS_RESOLVER = """\
```bash
if [[ -z "${CMUX_SETTINGS:-}" ]]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  CMUX_SETTINGS="$(find "$root/skills/cmux-settings/scripts" \\
      "$HOME/.claude/skills/cmux-settings/scripts" \\
      "$HOME/.claude/plugins/marketplaces/cmux-skills" \\
      "$HOME/.claude/plugins/cache" \\
      -path '*cmux-settings/scripts/cmux-settings' -type f -perm -u+x 2>/dev/null | head -n 1)"
  [[ -n "$CMUX_SETTINGS" ]] || {
    echo "cmux-settings helper not found; install the cmux plugin from darmawan01/cmux-skills" >&2
    exit 1
  }
fi
```"""

INSTALL_SNIPPET = """\
```bash
claude plugin marketplace update cmux-skills
claude plugin update cmux@cmux-skills
# or, for a ~/.claude/skills copy:
curl -fsSL https://raw.githubusercontent.com/darmawan01/cmux-skills/main/install.sh | bash -s -- --skill cmux-browser
```"""


def patch(path: Path, old: str, new: str, count: int = 1) -> None:
    text = path.read_text()
    found = text.count(old)
    if found != count:
        sys.exit(f"claudeify: expected {count} match(es) in {path}, found {found}:\n{old}")
    path.write_text(text.replace(old, new))


def adapt(skills: Path) -> None:
    # Codex app UI metadata; Claude Code reads only SKILL.md frontmatter.
    for meta in skills.glob("*/agents/openai.yaml"):
        meta.unlink()
        if not any(meta.parent.iterdir()):
            meta.parent.rmdir()

    # Claude Code never auto-reads a skill's AGENTS.md; surface it as a reference.
    browser = skills / "cmux-browser"
    (browser / "AGENTS.md").rename(browser / "references" / "agent-instructions.md")
    patch(
        browser / "SKILL.md",
        "## Deep-dive references\n\n| Reference | When to Use |\n|-----------|-------------|\n",
        "## Deep-dive references\n\n| Reference | When to Use |\n|-----------|-------------|\n"
        "| [references/agent-instructions.md](references/agent-instructions.md) | Ground rules for any agent driving cmux browser surfaces |\n",
    )
    patch(
        browser / "SKILL.md",
        """The repository copies are the source of truth: `.claude/skills/cmux-browser`
and `.agents/skills/cmux-browser` point at `skills/cmux-browser`. Do not edit a
mirror by hand. The supported Vercel installer (pinned here to the reviewed
`skills` 1.5.23 release) refreshes both global Claude Code and Codex discovery
roots and copies the complete skill (including references and templates):

```bash
# From this checkout while developing the skill:
npx --yes skills@1.5.23 add . --global --yes --skill cmux-browser --agent claude-code codex --copy

# From the published repository after the change is merged:
npx --yes skills@1.5.23 add manaflow-ai/cmux --global --yes --skill cmux-browser --agent claude-code codex --copy
```

Restart an agent session after a refresh if it cached the previous document.
The repository's `skills.sh` remains available for a Codex-only destination;
pass its `--dest` explicitly when that is the installation path:

```bash
./skills.sh --dest "$HOME/.codex/skills" --skill cmux-browser
```
""",
        f"""This copy is distributed for Claude Code by `darmawan01/cmux-skills`, which
tracks `skills/` in `manaflow-ai/cmux`. Do not edit an installed copy by hand.
Refresh it with:

{INSTALL_SNIPPET}

Start a fresh Claude Code session (or run `/reload-plugins`) after a refresh if
the previous document was cached.
""",
    )
    patch(
        browser / "references" / "surface-discovery.md",
        "contract before continuing. The installer is pinned to the reviewed `skills`\n1.5.23 release:",
        "contract before continuing:",
    )
    patch(
        browser / "references" / "surface-discovery.md",
        "npx --yes skills@1.5.23 add manaflow-ai/cmux --global --yes --skill cmux-browser --agent claude-code codex --copy\n",
        "claude plugin marketplace update cmux-skills && claude plugin update cmux@cmux-skills\n",
    )

    # cmux-settings helper lookups.
    shortcuts = skills / "cmux-keyboard-shortcuts" / "SKILL.md"
    text = shortcuts.read_text()
    start = text.index("```bash\nif [[ -z \"${CMUX_SETTINGS:-}\" ]]; then")
    end = text.index("```\n", text.index("\nfi\n", start)) + 3
    shortcuts.write_text(text[:start] + SETTINGS_RESOLVER + text[end:])
    patch(
        shortcuts,
        "- Use `skills/cmux-settings/scripts/cmux-settings` for every read/write.",
        "- Use the `cmux-settings` skill's `scripts/cmux-settings` helper (located by the snippet below) for every read/write.",
    )

    custom = skills / "cmux-customization" / "SKILL.md"
    patch(
        custom,
        "use the settings helper (`~/.codex/skills/...` if the user installed with `skills.sh`).\n\n   ```bash\n"
        "   ~/.agents/skills/cmux-settings/scripts/cmux-settings list-supported\n"
        "   ~/.agents/skills/cmux-settings/scripts/cmux-settings set browser.openTerminalLinksInCmuxBrowser true\n"
        "   ~/.agents/skills/cmux-settings/scripts/cmux-settings validate\n   ```",
        "use the settings helper shipped in the `cmux-settings` skill.\n\n   ```bash\n"
        "   CMUX_SETTINGS=\"$(find \"$HOME/.claude/skills/cmux-settings/scripts\" \"$HOME/.claude/plugins/cache\" -path '*cmux-settings/scripts/cmux-settings' -type f 2>/dev/null | head -n 1)\"\n"
        "   \"$CMUX_SETTINGS\" list-supported\n"
        "   \"$CMUX_SETTINGS\" set browser.openTerminalLinksInCmuxBrowser true\n"
        "   \"$CMUX_SETTINGS\" validate\n   ```",
    )

    diag = skills / "cmux-diagnostics"
    patch(
        diag / "SKILL.md",
        "skills/cmux-diagnostics/scripts/cmux-diagnostics            # cmux checkout\n"
        "~/.agents/skills/cmux-diagnostics/scripts/cmux-diagnostics  # installed skill\n"
        "~/.codex/skills/cmux-diagnostics/scripts/cmux-diagnostics   # Codex-only skills.sh install\n",
        "skills/cmux-diagnostics/scripts/cmux-diagnostics            # cmux checkout\n"
        "~/.claude/skills/cmux-diagnostics/scripts/cmux-diagnostics  # install.sh copy\n"
        "\"$(find ~/.claude/plugins/marketplaces/cmux-skills ~/.claude/plugins/cache -path '*cmux-diagnostics/scripts/cmux-diagnostics' -type f | head -n 1)\"  # plugin install\n",
    )
    patch(
        diag / "SKILL.md",
        "(from `~/.agents/skills/cmux-settings/scripts/`, or `~/.codex/skills/...` for a `skills.sh` install)",
        "(the `cmux-settings` skill's `scripts/` helper, next to this skill)",
    )
    patch(
        diag / "SKILL.md",
        "3. **Hook installation**: `cmux hooks setup --agent codex`, `--agent opencode`, or bare `cmux hooks setup` "
        "(installs supported agents found on PATH, skips missing ones). Run install or uninstall commands only after the user agrees.",
        "3. **Claude Code hooks**: Claude Code has no `cmux hooks setup` entry. Inside a cmux terminal, cmux puts a "
        "`claude` shim (`$TMPDIR/cmux-cli-shims/<surface>/claude`, backed by `cmux-claude-wrapper`) on PATH; it injects "
        "`--session-id` and `--settings` so hooks report back to cmux. If `command -v claude` resolves to the real binary "
        "instead (often a shell profile that prepends `~/.local/bin` after cmux's shell integration ran), notifications, "
        "sidebar status, and session resume stay silent. The script's `claude wrapper` section reports this. For other "
        "agents, use `cmux hooks setup --agent <name>` or bare `cmux hooks setup`. Run install or uninstall commands only "
        "after the user agrees.",
    )
    patch(
        diag / "SKILL.md",
        "- Prefer a narrow fix such as `cmux hooks setup --agent codex` over reinstalling every integration.",
        "- Prefer a narrow fix: for Claude Code, reorder PATH so the cmux shim wins inside cmux terminals; for other "
        "agents, `cmux hooks setup --agent <name>` over reinstalling every integration.",
    )
    patch(
        diag / "SKILL.md",
        "- Hook config but no session store:",
        "- `claude wrapper: shadowed`: the real `claude` binary precedes the cmux shim on PATH, so Claude Code runs "
        "without cmux hooks. Move the PATH edit in the shell profile above cmux's shell integration, or guard it with "
        "`[[ -z $CMUX_SURFACE_ID ]]`.\n- Hook config but no session store:",
    )
    script = diag / "scripts" / "cmux-diagnostics"
    patch(
        script,
        'elif [[ ! -x "$settings_helper" && -x "$HOME/.codex/skills/cmux-settings/scripts/cmux-settings" ]]; then\n'
        '  settings_helper="$HOME/.codex/skills/cmux-settings/scripts/cmux-settings"\n',
        'elif [[ ! -x "$settings_helper" && -x "$HOME/.claude/skills/cmux-settings/scripts/cmux-settings" ]]; then\n'
        '  settings_helper="$HOME/.claude/skills/cmux-settings/scripts/cmux-settings"\n',
    )
    patch(
        script,
        'section "hook configs"\n',
        """section "claude wrapper"
claude_first="$(command -v claude 2>/dev/null || true)"
claude_shim="$(type -a -p claude 2>/dev/null | grep -m 1 -E '/cmux-cli-shims/|/Resources/bin/claude$' || true)"
if [[ -z "$claude_first" ]]; then
  printf 'claude wrapper: claude not on PATH\\n'
elif [[ -z "${CMUX_SURFACE_ID:-}" ]]; then
  printf 'claude wrapper: n/a (outside a cmux terminal)\\n'
elif [[ -z "$claude_shim" ]]; then
  printf 'claude wrapper: missing (no cmux shim on PATH; first claude is %s)\\n' "$(safe_path "$claude_first")"
elif [[ "$claude_first" == "$claude_shim" ]]; then
  printf 'claude wrapper: active (%s)\\n' "$(safe_path "$claude_shim")"
else
  printf 'claude wrapper: shadowed (%s precedes %s)\\n' "$(safe_path "$claude_first")" "$(safe_path "$claude_shim")"
fi

section "hook configs"
""",
    )

    patch(
        skills / "cmux-settings" / "SKILL.md",
        "~/.codex/skills/cmux-settings/scripts/cmux-settings <subcommand>   # installed Codex skill\n",
        "~/.claude/skills/cmux-settings/scripts/cmux-settings <subcommand>  # install.sh copy\n"
        "\"$(find ~/.claude/plugins/marketplaces/cmux-skills ~/.claude/plugins/cache -path '*cmux-settings/scripts/cmux-settings' -type f | head -n 1)\" <subcommand>  # plugin install\n",
    )

    # Illustrative examples: show the agent this copy is installed for.
    patch(
        skills / "cmux-cloud-vm" / "SKILL.md",
        '`cmux vm agent --machine <id> --agent codex --no-open -- "<task>"`',
        '`cmux vm agent --machine <id> --agent claude --no-open -- "<task>"`',
    )
    patch(
        skills / "cmux-markdown" / "SKILL.md",
        "To instruct coding agents in a project, add to its `AGENTS.md`:",
        "To instruct coding agents in a project, add to its `CLAUDE.md` (or `AGENTS.md`):",
    )


def main() -> None:
    upstream, root = Path(sys.argv[1]), Path(sys.argv[2])
    names = sorted(p.name for p in upstream.iterdir() if (p / "SKILL.md").is_file())
    unknown_user = USER_SKILLS - set(names)
    if unknown_user:
        sys.exit(f"claudeify: USER_SKILLS lists skills upstream no longer has: {sorted(unknown_user)}")

    staging = root / ".sync-staging"
    shutil.rmtree(staging, ignore_errors=True)
    shutil.copytree(upstream, staging, ignore=shutil.ignore_patterns("README.md", ".DS_Store"))
    adapt(staging)

    for plugin in ("cmux", "cmux-dev"):
        shutil.rmtree(root / "plugins" / plugin / "skills", ignore_errors=True)
        (root / "plugins" / plugin / "skills").mkdir(parents=True)
    for name in names:
        plugin = "cmux" if name in USER_SKILLS else "cmux-dev"
        shutil.move(str(staging / name), root / "plugins" / plugin / "skills" / name)
        print(f"  {plugin:8} {name}")
    shutil.rmtree(staging)

    leftovers = [
        str(p.relative_to(root))
        for p in (root / "plugins").rglob("*")
        # link-policy.sh is provider-aware and already handles Claude roots.
        if p.is_file() and p.name != "link-policy.sh" and ".codex/skills" in p.read_text(errors="ignore")
    ]
    if leftovers:
        sys.exit(f"claudeify: Codex-only paths remain in: {leftovers}")


if __name__ == "__main__":
    main()
