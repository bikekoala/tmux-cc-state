# tmux-cc-state

tmux plugin that shows Claude Code activity state per window and daily token usage in your status bar.

## Install

### TPM

```tmux
set -g @plugin 'ocherry341/tmux-cc-state'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/ocherry341/tmux-cc-state ~/.tmux/plugins/tmux-cc-state
```

Add to `~/.tmux.conf`:

```tmux
run-shell '~/.tmux/plugins/tmux-cc-state/cc.tmux'
```

### Claude Code plugin

```bash
# Add marketplace (once)
/plugin marketplace add ocherry341/tmux-cc-state

# Install
claude plugin install tmux-cc-state@tmux-cc-state
```

## Format variables

Use these placeholders in `status-left`, `status-right`, `window-status-format`, or `window-status-current-format`:

| Placeholder                  | Output                                  | Example                        |
| ---------------------------- | --------------------------------------- | ------------------------------ |
| `#{cc-state}`                | State icon                              | `●` `◆` `✓`                    |
| `#{cc_window_state}`         | State text                              | `running` `needs-input` `done` |
| `#{cc_window_bg:<fallback>}` | State color (hex), falls back when idle | `#98971a`                      |
| `#{cc-daily-token}`          | Today's total token usage               | `50M`                          |
| `#{cc-daily-cost}`           | Today's estimated cost                  | `$4.50`                        |

### Window state

When multiple CC instances run in the same window, the highest priority wins: `running` > `needs-input` > `done`. Subagent and teammate states are included.

Panes where CC has exited are cleaned up automatically.

### State colors

Defaults (gruvbox). Customize with `@cc-color-*`:

| State         | Default            | Option                  |
| ------------- | ------------------ | ----------------------- |
| `running`     | `#5faf5f` (green)  | `@cc-color-running`     |
| `needs-input` | `#d7af5f` (yellow) | `@cc-color-needs-input` |
| `done`        | `#808080` (grey)   | `@cc-color-done`        |

```tmux
set -g @cc-color-running '#98971a'
set -g @cc-color-needs-input '#d79921'
set -g @cc-color-done '#b16286'
```

### State icons

Defaults: `running` → `●`, `needs-input` → `◆`, `done` → `✓`. Customize with `@cc-state-*`:

```tmux
set -g @cc-state-running '⏳'
set -g @cc-state-needs-input '❓'
set -g @cc-state-done '✅'
```

Use `@cc-state-prefix` / `@cc-state-suffix` to add separators that only appear when state is active:

```tmux
set -g @cc-state-prefix ' '
set -g @cc-state-suffix ''
```

- Has state → `<prefix><icon><suffix>` (e.g. ` ●`)
- No state → empty string (prefix/suffix hidden too)

### Window switcher

Built-in fzf popup for switching between tmux windows. Supports vim-style navigation, search, and CC-only filtering.

| Option                         | Default | Description                    |
| ------------------------------ | ------- | ------------------------------ |
| `@cc-switcher-key`             | `C-f`   | Keybinding (with prefix)       |
| `@cc-switcher-key-no-prefix`   | —       | Keybinding (without prefix)    |
| `@cc-switcher-preview`         | `false` | Enable pane preview            |
| `@cc-switcher-width`           | `55`    | Popup width (no preview)       |
| `@cc-switcher-height`          | `10`    | Popup height (no preview)      |
| `@cc-switcher-width-preview`   | `80`    | Popup width (with preview)     |
| `@cc-switcher-height-preview`  | `20`    | Popup height (with preview)    |
| `@cc-switcher-color`           | —       | fzf `--color` string           |
| `@cc-switcher-pointer`         | `>`     | fzf pointer character          |
| `@cc-switcher-prompt`          | ` `    | fzf prompt (normal mode)       |
| `@cc-switcher-prompt-search`   | ` `    | fzf prompt (search mode)       |

```tmux
set -g @cc-switcher-key-no-prefix 'M-w'
set -g @cc-switcher-preview 'true'
set -g @cc-switcher-width-preview '90%'
set -g @cc-switcher-height-preview '80%'
set -g @cc-switcher-color 'pointer:#d79921'
set -g @cc-switcher-pointer '❯'
```

## Examples

Show a state icon next to the window name (with auto separator):

```tmux
set -g @cc-state-prefix ' '
set -ag window-status-format '#W#{cc-state}'
# running → "vim ●"   idle → "vim"
```

Color window tabs by CC state (with fallback):

```tmux
set -g  window-status-format '#[bg=#{cc_window_bg:#{@bg3}}] #I #W '
set -g  window-status-current-format '#[bg=#{cc_window_bg:#{@blue}},bold] #I #W '
```

Show daily usage in the status bar:

```tmux
set -ag status-right ' #{cc-daily-token}  #{cc-daily-cost}'
```

## Daily usage pricing

Token costs are computed from Claude Code JSONL logs using these rates (per million tokens):

| Model        | Input | Output | Cache write | Cache read |
| ------------ | ----- | ------ | ----------- | ---------- |
| Opus 4.5/4.6 | $5    | $25    | $6.25       | $0.50      |
| Opus 4       | $15   | $75    | $18.75      | $1.50      |
| Sonnet 4     | $3    | $15    | $3.75       | $0.30      |
| Haiku 4      | $1    | $5     | $1.25       | $0.10      |
