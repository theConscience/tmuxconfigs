#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/tmuxinator"
adopt_existing=false

case "${1:-}" in
  "") ;;
  --adopt) adopt_existing=true ;;
  *)
    echo "Usage: $0 [--adopt]" >&2
    exit 2
    ;;
esac

mkdir -p "$config_dir"

link_config() {
  local source_path="$1"
  local destination_path="$2"

  if [[ -L "$destination_path" ]]; then
    if [[ "$(readlink "$destination_path")" == "$source_path" ]]; then
      echo "linked: $destination_path"
      return
    fi

    echo "refusing to replace different symlink: $destination_path" >&2
    return 1
  fi

  if [[ -e "$destination_path" ]]; then
    if [[ "$adopt_existing" == true ]] && [[ -f "$destination_path" ]] && cmp -s "$source_path" "$destination_path"; then
      rm -- "$destination_path"
    else
      echo "refusing to replace existing file: $destination_path" >&2
      echo "use --adopt only when its contents already match the repository" >&2
      return 1
    fi
  fi

  ln -s "$source_path" "$destination_path"
  echo "created: $destination_path -> $source_path"
}

link_config "$repo_dir/.tmux.conf" "$HOME/.tmux.conf"

for source_path in "$repo_dir"/*.yml; do
  link_config "$source_path" "$config_dir/$(basename "$source_path")"
done
