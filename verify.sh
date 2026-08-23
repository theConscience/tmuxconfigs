#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checked=0
warnings=0

if ! command -v tmuxinator >/dev/null 2>&1; then
  echo "tmuxinator is not installed" >&2
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
