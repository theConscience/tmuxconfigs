# Agent instructions for `tmuxconfigs`

This repository is the entry point into every other workspace in the portfolio.
A broken profile costs a whole working session, so changes here are small,
verified, and reversible.

## Always verify

```sh
./verify.sh
```

`verify.sh` runs the style audit, renders every tmuxinator profile, checks that
positional arguments cannot hijack a project root, verifies that the `tx`
launcher still resolves the repository through its installed symlink, and loads
`.tmux.conf` in a temporary tmux server. It takes about 30 seconds. Never report
a config change as done without a passing run.

For a faster inner loop while editing:

```sh
ruby tools/audit-configs.rb                      # conventions only
TMUXINATOR_CONFIG="$PWD" tmuxinator debug NAME   # render one profile
```

Always pass `TMUXINATOR_CONFIG="$PWD"` when rendering by hand. Without it
tmuxinator reads `~/.config/tmuxinator`, which is a symlink farm that may point
at a different checkout, and you will validate a file you did not edit.

## Roots

Every profile resolves its root as:

```erb
<%= @settings["root"] || [@args[0]].compact.map { |a| File.expand_path(a) }.find { |p| File.directory?(p) } || File.expand_path("~/default/path") %>
```

Keep that shape. It lets `tx PROJECT /path/to/worktree` override the root while
ignoring launcher and service arguments that tmuxinator forwards as `@args[0]`.

A profile whose default root does not exist on this machine must be listed in
`tools/root-policies.txt` with a policy word, and the human-readable rationale
must be added to the table in `README.md`. The two files are kept in sync by
hand; `verify.sh` treats a listed profile as an expected absence and anything
else as a warning.

## Do not delete profiles

Missing roots are lifecycle states — dynamic worktrees, offline references,
learning projects awaiting recovery — not dead files. Never remove or rename a
profile without an explicit decision from the repository owner. `tmux-configs.yml`
is kept alongside `tmux-configs-workbench.yml` as the legacy entry point on
purpose.

## Creating and modernizing profiles

- New profile: `bin/tmux-new NAME ROOT [DEV_COMMAND] [CHECK_COMMAND]`, which
  renders `templates/project.yml.template`. Do not hand-write a profile from
  scratch.
- Imported or older profile: `ruby tools/modernize-configs.rb`. It is idempotent
  and safe to re-run.
- Shared conventions, enforced by the audit: named layouts instead of
  size-specific layout strings, stable pane titles, an explicit `focused_pane`
  per window, `exec "$SHELL"` so panes survive the command that opened them,
  `command -v` guards around optional tools, and AI panes that resume the last
  session before falling back to a new one.
- A pane that opens a task document should read `next_ref` from the project's
  `.project-status.yml` instead of hardcoding a file name, so the profile does
  not need editing after each finished task. See `slavic-core.yml`.

## Symlinks

`bootstrap.sh` links `*.yml` into `~/.config/tmuxinator` and `bin/tx`,
`bin/tmux-new` into `~/.local/bin`. After adding a file that users are meant to
launch, check that the link exists and points into this checkout:

```sh
ls -l ~/.config/tmuxinator/NAME.yml ~/.local/bin/tx
./bootstrap.sh          # re-links; refuses to replace foreign files
```

`bootstrap.sh` never overwrites a regular file or a differently-targeted
symlink. Do not work around that with `rm` — report the conflict instead.

## Working on this repository

Use the dedicated cockpit so maintenance never mixes with product sessions:

```sh
tx tmux-configs-workbench
```

It provides overview, AI clients, config catalog, verification, git history, and
a scratch window whose `render` pane debugs the profile from the current
checkout.

## Git

The active branch is `macos-air`. Commit only what the task asked for, keep the
working tree clean at the end of a task, and do not push without being asked.
