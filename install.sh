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
  --list           List available skills and exit
  --dry-run        Print what would be installed
  -h, --help       Show this help

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

to_install=()
if [[ "${#selected[@]}" -gt 0 ]]; then
  for name in "${selected[@]}"; do
    line="$(available | awk -F'\t' -v n="$name" '$1 == n')"
    [[ -n "$line" ]] || die "unknown skill: $name (see --list)"
    to_install+=("$line")
  done
else
  while IFS= read -r line; do
    [[ "${line#*$'\t'}" == cmux-dev && "$include_dev" -eq 0 ]] && continue
    to_install+=("$line")
  done < <(available)
fi

[[ "$dry_run" -eq 1 ]] || mkdir -p "$dest_dir"
for line in "${to_install[@]}"; do
  name="${line%%$'\t'*}"
  plugin="${line#*$'\t'}"
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'Would install %s -> %s/%s\n' "$name" "$dest_dir" "$name"
    continue
  fi
  rm -rf "${dest_dir:?}/$name"
  cp -R "$source_dir/plugins/$plugin/skills/$name" "$dest_dir/$name"
  printf 'Installed %s -> %s/%s\n' "$name" "$dest_dir" "$name"
done

[[ "$dry_run" -eq 1 ]] || printf '\nRestart Claude Code (or run /reload-plugins) to pick up the skills.\n'
