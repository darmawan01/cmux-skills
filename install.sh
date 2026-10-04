#!/usr/bin/env bash
# Copy cmux skills into a Claude Code skills directory.
# Prefer the plugin install (see README); use this for project-local installs
# or when you want plain ~/.claude/skills copies.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Install cmux skills for Claude Code.

Options:
  --dest DIR       Destination directory. Default: ~/.claude/skills
  --project        Install into ./.claude/skills of the current directory
  --source DIR     Local checkout of darmawan01/cmux-skills. Default: this checkout, or GitHub when piped
  --ref REF        GitHub ref to download when no local checkout is available. Default: main
  --dev            Also install contributor skills (cmux-dev plugin)
  --skill NAME     Install one skill. Repeat for several. Default: all end-user skills
  --uninstall      Remove cmux skill copies from the destination instead of installing
  --force          Install copies even when the matching Claude Code plugin is installed
  --list           List available skills and exit
  --dry-run        Print what would be installed
  -h, --help       Show this help

Copies duplicate the Claude Code plugin. When the cmux (or cmux-dev) plugin is
installed and covers the destination, install.sh skips that plugin's skills and
removes copies a previous run left there. Pass --force to keep both.

Examples:
  curl -fsSL https://raw.githubusercontent.com/darmawan01/cmux-skills/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/darmawan01/cmux-skills/main/install.sh | bash -s -- --dev
  ./install.sh --project --skill cmux --skill cmux-browser
EOF
}

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

dest_dir="$HOME/.claude/skills"
source_dir=""
ref="${CMUX_SKILLS_REF:-main}"
include_dev=0
list_only=0
uninstall=0
force=0
dry_run=0
selected=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) [[ $# -ge 2 ]] || die "--dest requires a directory"; dest_dir="$2"; shift 2 ;;
    --project) dest_dir="$PWD/.claude/skills"; shift ;;
    --source) [[ $# -ge 2 ]] || die "--source requires a directory"; source_dir="$2"; shift 2 ;;
    --ref) [[ $# -ge 2 ]] || die "--ref requires a value"; ref="$2"; shift 2 ;;
    --dev) include_dev=1; shift ;;
    --skill) [[ $# -ge 2 ]] || die "--skill requires a name"; selected+=("$2"); shift 2 ;;
    --list) list_only=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --force) force=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

if [[ -z "$source_dir" ]]; then
  script_path="${BASH_SOURCE[0]:-}"
  if [[ -n "$script_path" && -f "$script_path" && -d "$(dirname -- "$script_path")/plugins" ]]; then
    source_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
  else
    command -v curl >/dev/null 2>&1 || die "missing required command: curl"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "https://codeload.github.com/darmawan01/cmux-skills/tar.gz/$ref" |
      tar -xz -C "$tmp" --strip-components=1
    source_dir="$tmp"
  fi
fi
[[ -d "$source_dir/plugins/cmux/skills" ]] || die "not a cmux-skills checkout: $source_dir"

# name<TAB>plugin for every available skill
available() {
  local plugin dir
  for plugin in cmux cmux-dev; do
    for dir in "$source_dir/plugins/$plugin/skills"/*/; do
      [[ -f "$dir/SKILL.md" ]] && printf '%s\t%s\n' "$(basename "$dir")" "$plugin"
    done
  done
}

if [[ "$list_only" -eq 1 ]]; then
  available | awk -F'\t' '{ printf "%-26s %s\n", $1, ($2 == "cmux" ? "end-user" : "contributor (--dev)") }'
  exit 0
fi

# Prints "yes" when <plugin>@cmux-skills is installed in a scope that already
# loads into sessions using $dest_dir: user scope covers every destination, a
# project/local scope covers that project's .claude/skills.
plugin_covers_dest() {
  local registry="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
  [[ -f "$registry" ]] || return 1
  command -v python3 >/dev/null 2>&1 || { grep -q "\"$1@cmux-skills\"" "$registry"; return; }
  python3 - "$registry" "$1@cmux-skills" "$dest_dir" <<'PY'
import json, os, sys
registry, key, dest = sys.argv[1:]
try:
    entries = json.load(open(registry)).get("plugins", {}).get(key, [])
except (OSError, ValueError):
    sys.exit(1)
dest = os.path.realpath(dest)
for entry in entries:
    if entry.get("scope") == "user":
        sys.exit(0)
    project = entry.get("projectPath")
    if project and dest == os.path.realpath(os.path.join(project, ".claude", "skills")):
        sys.exit(0)
sys.exit(1)
PY
}

# A destination dir is a cmux-skills copy if its SKILL.md declares the same name.
is_copy() {
  [[ -f "$dest_dir/$1/SKILL.md" ]] && grep -qx "name: $1" "$dest_dir/$1/SKILL.md"
}

remove_copy() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'Would remove %s/%s\n' "$dest_dir" "$1"
  else
    rm -rf "${dest_dir:?}/$1"
    printf 'Removed %s/%s\n' "$dest_dir" "$1"
  fi
}

to_install=()
if [[ "${#selected[@]}" -gt 0 ]]; then
  for name in "${selected[@]}"; do
    line="$(available | awk -F'\t' -v n="$name" '$1 == n')"
    [[ -n "$line" ]] || die "unknown skill: $name (see --list)"
    to_install+=("$line")
  done
else
  while IFS= read -r line; do
    [[ "${line#*$'\t'}" == cmux-dev && "$include_dev" -eq 0 && "$uninstall" -eq 0 ]] && continue
    to_install+=("$line")
  done < <(available)
fi

if [[ "$uninstall" -eq 1 ]]; then
  for line in "${to_install[@]}"; do
    name="${line%%$'\t'*}"
    is_copy "$name" && remove_copy "$name"
  done
  exit 0
fi

covered=()
if [[ "$force" -eq 0 ]]; then
  for plugin in cmux cmux-dev; do
    plugin_covers_dest "$plugin" || continue
    covered+=("$plugin")
    printf 'Plugin %s@cmux-skills is installed; skipping its skills (use --force to copy anyway).\n' "$plugin"
    # Clean every copy of this plugin's skills, not only the selected ones.
    while IFS= read -r line; do
      [[ "${line#*$'\t'}" == "$plugin" ]] || continue
      name="${line%%$'\t'*}"
      is_copy "$name" && remove_copy "$name"
    done < <(available)
  done
fi

for line in "${to_install[@]}"; do
  name="${line%%$'\t'*}"
  plugin="${line#*$'\t'}"
  [[ " ${covered[*]:-} " == *" $plugin "* ]] && continue
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'Would install %s -> %s/%s\n' "$name" "$dest_dir" "$name"
    continue
  fi
  mkdir -p "$dest_dir"
  rm -rf "${dest_dir:?}/$name"
  cp -R "$source_dir/plugins/$plugin/skills/$name" "$dest_dir/$name"
  printf 'Installed %s -> %s/%s\n' "$name" "$dest_dir" "$name"
done

[[ "$dry_run" -eq 1 ]] || printf '\nRestart Claude Code (or run /reload-plugins) to pick up the changes.\n'
