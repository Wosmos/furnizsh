# Claude Code extras

Optional. Only relevant if you use [Claude Code](https://claude.com/claude-code).
Nothing here is part of the terminal setup — skip the whole folder if you don't
use it, or pass `--no-claude` to the installer.

| File | What it does | Platforms |
|---|---|---|
| `cc-alert.sh` | Desktop notification when a task finishes or needs your permission | **macOS only** |
| `statusline.sh` | Custom statusline: model, context use, cost, rate limits | macOS, Linux, WSL |

`install.sh` installs `statusline.sh` everywhere and `cc-alert.sh` only on
macOS — putting the alert hook on Linux would just leave a script that errors
the moment Claude Code fires it. Neither is installed on native Windows;
`install.ps1` doesn't touch `~/.claude` at all.

---

## cc-alert.sh

**macOS only.** It's built on `osascript`, `afplay` and `say` — no dependencies
beyond what ships with the OS, but also no portable equivalent. On Linux you'd
want `notify-send`; that isn't implemented here.

Fires a dialog + sound + spoken phrase when:

- **A task completes** — but only if the turn ran longer than
  `CC_ALERT_MIN_SECONDS` (default 90), so quick replies don't spam you.
- **Claude needs permission or input** — rate-limited by `CC_ALERT_COOLDOWN`
  unless the pending action is flagged destructive.

It stays quiet while you're already looking at the terminal hosting the session,
which is the part that makes it usable day to day. The dialog shows the project
name, status, the tool or command awaiting approval, a one-line summary of your
last prompt, how long you were away, and an **Open Project** button that jumps
straight to the editor window for that folder.

### Install

The furnizsh installer copies it to `~/.claude/hooks/cc-alert.sh`. Then wire it
into a project:

```bash
cd your-project
~/.claude/hooks/cc-alert.sh --install
```

That adds the `Stop` and `Notification` hooks to
`.claude/settings.local.json`. To remove them:

```bash
~/.claude/hooks/cc-alert.sh --uninstall
```

### Manual mode

Useful in your own scripts:

```bash
~/.claude/hooks/cc-alert.sh "Build finished" "All 240 tests passed" "build is done"
```

### Configuration

Set these inline, in `~/.claude/hooks/cc-alert.env` for machine-wide defaults,
or in `<project>/.claude/cc-alert.env` per project.

| Variable | Default | What |
|---|---|---|
| `CC_ALERT_MIN_SECONDS` | `90` | minimum turn duration before a completion alert fires |
| `CC_ALERT_COOLDOWN` | `20` | seconds between routine notification alerts |
| `CC_ALERT_APP` | — | editor app name for the "Open Project" button |
| `CC_ALERT_SILENT` | — | `1` disables the spoken phrase |
| `CC_ALERT_ALWAYS` | — | `1` alerts even when you're looking at the terminal |
| `CC_ALERT_DRYRUN` | — | `1` prints instead of showing UI |
| `CC_ALERT_SOUND_STOP` | `Glass` | sound for completion alerts |
| `CC_ALERT_SOUND_NOTIFY` | `Sosumi` | sound for routine notifications |
| `CC_ALERT_SOUND_PRIORITY` | `Basso` | sound for destructive-action alerts |
| `CC_ALERT_VOICE` | system default | `say -v` voice name |
| `CC_ALERT_QUIET_START` / `_END` | unset | `HH:MM` window to suppress alerts; both unset disables the feature |
| `CC_ALERT_SUGGEST_THRESHOLD` | `3` | repeats before it suggests a `permissions.allow` rule |

`head -40 cc-alert.sh` is the authoritative list — it's documented in the file
header and that's what gets updated first.

Logs to `~/.claude/hooks/cc-alert.log`; repeated-permission counts live in
`~/.claude/hooks/.cc-alert-freq`.

---

## statusline.sh

Reads Claude Code's session JSON on stdin and renders a one-line status showing
the model, context window use, session cost and rate-limit state.

Wire it into `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

---

## A note on scope

These are here because the terminal cheatsheet references the notification hook,
and a guide that mentions something without shipping it is annoying. They're
deliberately isolated in this folder — no other part of furnizsh depends on
them, and the installer asks before touching `~/.claude/`.
