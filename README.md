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

## Project conventions

All tracked projects follow the same baseline:

- the root can be overridden with `@settings["root"]` or the first argument;
- named layouts replace terminal-size-specific layout strings;
- panes have stable titles and every window declares its focused pane;
- OpenCode, Codex, and Claude resume their latest session, fall back to a new
  session, and show a useful message when the client is unavailable;
- multi-repository workspaces use window-level roots where every pane targets
  the same child repository.

Run `ruby tools/modernize-configs.rb` after importing an older config. The
command is idempotent. New configs should be created with `tmux-new`.

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

## Optional project roots

The following valid configs currently have no default directory on this
machine. They can still be started by supplying an existing root:

| Project | Missing default root |
| --- | --- |
| `ca-ai` | `~/web_dev/repos/projects/channel-admin-ai-task` |
| `cf-ai` | `~/web_dev/repos/projects/covenant-fighters-ai-task` |
| `cloudblue-spa-customer` | `~/Documents/web_dev/repos/work/cloudblue/spa-customer` |
| `corona-travel-ai` | `~/web_dev/repos/work/unihotel/corona-travel-ai-task` |
| `hardcore-fp-v1` | `~/web_dev/repos/learn/fp/hardcore_fn_programming_drboolean_v1/immutube` |
| `svg-hero` | `~/web_dev/repos/projects/svg-hero` |
| `uh-ai` | `~/web_dev/repos/work/unihotel/unihotel_org-ai-task` |
