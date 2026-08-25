#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/tmuxinator"
adopt_existing=false
install_plugins=false

for argument in "$@"; do
  case "$argument" in
    --adopt) adopt_existing=true ;;
    --plugins) install_plugins=true ;;
    *)
      echo "Usage: $0 [--adopt] [--plugins]" >&2
      exit 2
      ;;
  esac
done

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

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
mkdir -p "$bin_dir"
link_config "$repo_dir/bin/tx" "$bin_dir/tx"
link_config "$repo_dir/bin/tmux-new" "$bin_dir/tmux-new"

if [[ "$install_plugins" == true ]]; then
  tpm_dir="$HOME/.tmux/plugins/tpm"
  if [[ ! -d "$tpm_dir/.git" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi
  "$tpm_dir/bin/install_plugins"
fi
