# tmuxconfigs

Personal tmux and tmuxinator configuration. The active macOS setup lives on the
`macos-air` branch.

## Install

```sh
git clone --branch macos-air git@github.com:theConscience/tmuxconfigs.git
cd tmuxconfigs
./bootstrap.sh
```

The bootstrap script creates `~/.tmux.conf` and `~/.config/tmuxinator/*.yml`
symlinks. It refuses to overwrite existing files or different symlinks.

To migrate existing regular config files whose contents already match this
repository, use the guarded adoption mode:

```sh
./bootstrap.sh --adopt
```

Install TPM plugins, including automatic tmux session restore, with:

```sh
./bootstrap.sh --plugins
```

## Launcher

`bootstrap.sh` installs two commands into `~/.local/bin`:

```sh
tx                         # choose a project and worktree with fzf
tx vue3                    # start the default vue3 workspace
tx vue3 /path/to/worktree  # override the project root
tmux-new app ~/src/app     # create a config from the shared template
```

Generated and modernized projects use portable roots, named panes, adaptive
layouts, explicit focus, persistent shells, and resumable AI clients.

For maintaining this repository itself, use the dedicated workbench session:

```sh
tx tmux-configs-workbench
```

It opens an overview, resumable AI clients, a config catalog, verification, git
history, and a scratch workspace without disturbing product sessions. Pass
another checkout as the root when needed:

```sh
tx tmux-configs-workbench /path/to/tmuxconfigs
```

For portfolio planning in the Obsidian vault, use:

```sh
tx v-notes-ai
```

The workspace opens the vault dashboard, resumable AI clients, an editor, and
terminal views for project notes, open tasks, roadmaps, and recent changes. Its
default root is `~/STORAGE/V_Notes` and can be overridden with an existing
directory.

## Project conventions

All tracked projects follow the same baseline:

- the root can be overridden with `@settings["root"]` or an existing directory
  passed as the first argument; launcher/service arguments are ignored;
- named layouts replace terminal-size-specific layout strings;
- panes have stable titles and every window declares its focused pane;
- OpenCode, Codex, and Claude resume their latest session, fall back to a new
  session, and show a useful message when the client is unavailable;
- multi-repository workspaces use window-level roots where every pane targets
  the same child repository.

Run `ruby tools/modernize-configs.rb` after importing an older config. The
command is idempotent. New configs should be created with `tmux-new`.

Coding agents working in this repository follow [AGENTS.md](AGENTS.md): always
run `./verify.sh`, keep `tools/root-policies.txt` and the README table in sync,
and never delete a profile without an explicit decision.

## Session restore

`tmux-resurrect` and `tmux-continuum` save sessions every 15 minutes and restore
them when tmux starts. Install them with `./bootstrap.sh --plugins`. The standard
TPM bindings remain available: `prefix + Ctrl-s` saves and `prefix + Ctrl-r`
restores a snapshot.

## Verify

```sh
./verify.sh
```

The check renders every tmuxinator project and loads `.tmux.conf` in a temporary
tmux server. It also enforces the shared config conventions. Missing project
roots are reported as warnings because some
argument-driven `*-ai` configurations intentionally point at temporary working
directories.

After changing `.tmux.conf`, reload it in a running tmux session:

```sh
tmux source-file ~/.tmux.conf
```

Parameterized projects accept an alternate root as their first argument:

```sh
tmuxinator start ca-ai /path/to/project
```

## Profile lifecycle and optional roots

Missing roots listed in `tools/root-policies.txt` are intentional lifecycle
states, not broken YAML. They are still rendered and checked by `verify.sh`.

| Project | Policy | Meaning |
| --- | --- | --- |
| `ca-ai` | `worktree-dynamic` | Channel Admin task worktree; pass its generated `channel-admin-<task>` directory. |
| `cf-ai` | `worktree-dynamic` | Covenant Fighters helper creates `covenant-fighters-ai-<task>` and passes it explicitly. |
| `cloudblue-spa-customer` | `reference-offline` | Reference Vue code that is not checked out on this machine. |
| `corona-travel-ai` | `worktree-legacy` | Legacy single-repo AI worktree convention; no current automatic creator was found. |
| `uh-ai` | `worktree-legacy` | Legacy Unihotel single-repo AI worktree convention; no current automatic creator was found. |
| `hardcore-fp-v1` | `learning-recovery` | FP learning project exists remotely and awaits a local restore and modernization audit. |
| `svg-hero` | `learning-recovery` | Only the tmuxinator profile was recovered; the project source still needs to be found. |

`unihotel-ai` is deliberately not in this list: its existing parent root opens
both `unihotel_org` and `corona-travel` for the current cross-repository Corona
workflow.
