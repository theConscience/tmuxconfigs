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

## Verify

```sh
./verify.sh
```

The check renders every tmuxinator project and loads `.tmux.conf` in a temporary
tmux server. Missing project roots are reported as warnings because some
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
