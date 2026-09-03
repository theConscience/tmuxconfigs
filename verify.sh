#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checked=0
warnings=0

if ! command -v tmuxinator >/dev/null 2>&1; then
  echo "tmuxinator is not installed" >&2
  exit 1
fi

ruby "$repo_dir/tools/audit-configs.rb"

# Launchers are installed as symlinks, so they must still resolve the repo.
launcher_dir="$(mktemp -d "${TMPDIR:-/tmp}/tmuxconfigs-launchers.XXXXXX")"
trap 'rm -rf "$launcher_dir"' EXIT
ln -s "$repo_dir/bin/tx" "$launcher_dir/tx"
if ! diff -u <("$repo_dir/bin/tx" --list) <("$launcher_dir/tx" --list); then
  echo "tx resolves a different config directory through a symlink" >&2
  exit 1
fi
if "$launcher_dir/tx" --list | grep -q '^\.'; then
  echo "tx lists a hidden metadata file as a project" >&2
  exit 1
fi

for config_path in "$repo_dir"/*.yml; do
  project_name="$(basename "$config_path" .yml)"

  if ! rendered="$(TMUXINATOR_CONFIG="$repo_dir" tmuxinator debug "$project_name" 2>&1)"; then
    echo "invalid tmuxinator config: $project_name" >&2
    echo "$rendered" >&2
    exit 1
  fi

  project_root="$(printf '%s\n' "$rendered" | sed -n 's/^cd //p' | head -n 1)"

  # Some tmuxinator aliases forward their own positional arguments to ERB.
  # A project name must not be mistaken for a relative root directory.
  if ! guarded_rendered="$(TMUXINATOR_CONFIG="$repo_dir" tmuxinator debug "$project_name" "$project_name" 2>&1)"; then
    echo "invalid tmuxinator config with service argument: $project_name" >&2
    echo "$guarded_rendered" >&2
    exit 1
  fi
  guarded_root="$(printf '%s\n' "$guarded_rendered" | sed -n 's/^cd //p' | head -n 1)"
  if [[ "$guarded_root" != "$project_root" ]]; then
    echo "unsafe positional root override: $project_name ($project_root -> $guarded_root)" >&2
    exit 1
  fi

  if [[ -n "$project_root" ]] && [[ ! -d "$project_root" ]]; then
    echo "warning: $project_name root does not exist: $project_root" >&2
    warnings=$((warnings + 1))
  fi

  checked=$((checked + 1))
done

socket_name="tmuxconfigs-verify-$$"
tmux -L "$socket_name" -f "$repo_dir/.tmux.conf" new-session -d -s tmuxconfigs-verify
tmux -L "$socket_name" kill-server

echo "verified $checked tmuxinator configs and .tmux.conf ($warnings root warnings)"
