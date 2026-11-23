# menubar-progress

See how the long-running work your coding agent (**Claude Code, Codex, OpenCode, pi**), or
you, started is going, right in the macOS menu bar: builds, crawls, data jobs, deploys,
batches of subtasks, parallel background runs.

Without this you keep asking "how is it going?", and the agent has to stop, read logs and
answer. With this, one glance is enough:

```text
🎃3/6 41%  🔨1/1  🕷0/2 87%❌
```

Click it to see every task:

```text
🎃 pumpkins
✅ kit           ready in 17m
✅ flowers       ready in 28m
▶︎ market        ▓░░░░░░░░░░░   4%  crawl 322/7882 · ~8h24m left
▶︎ pharmacies    ▓▓▓▓▓▓▓▓▓▓░░  81%  crawl 326/403 · ~5m left
```

## How it works

Every task is **one JSON file** in a state dir (default `~/.local/state/mbp`). A tiny native
menu bar app (one Swift file, no dependencies, no Xcode project) re-reads the dir every 2 seconds
and renders what is there. Anything that can write a file can report progress: the `mbp` CLI,
a feeder script in any language, a CI job, `jq` in a shell loop.

That makes it independent of the agent: it keeps working after the session ends, survives
restarts, and several agents (or people) can report into the same menu bar.

## Install

| Harness | How |
|---|---|
| **Claude Code** | `/plugin install menubar-progress --marketplace savchenko-dev/menubar-progress` |
| **Codex / OpenCode / pi / none** | `git clone https://github.com/savchenko-dev/menubar-progress && ./menubar-progress/install.sh codex opencode pi` |

`install.sh` copies the files to `~/.config/menubar-progress`, links `mbp` into
`~/.local/bin`, builds the app and installs the skill for each listed harness.
`--uninstall` reverses it. Needs macOS, `python3` and `swiftc` (Xcode Command Line Tools).
The CLI and the file format work on Linux too; only the menu bar app is macOS-only.

Then:

```bash
mbp start        # builds on first run, then launches; idempotent
```

## The CLI

```bash
# A command with a clear end: running -> ok/fail by exit code
mbp wrap build --group ci --icon 🔨 -- make -j4

# A process that logs progress: follow the log, parse N/M (or your regex), stop on ok/fail/pid exit
mbp tail crawl /tmp/crawl.log --group crawl --icon 🕷 \
  --pattern '(?P<done>\d+)/(?P<total>\d+)' --ok 'finished' --fail 'ERROR' --pid 4242

# Steps you drive yourself
mbp set migrate --group db --icon 🗄 --done 3 --total 10 --text "batch 3: users" --open /tmp/migrate.log
mbp ok migrate --text "10 batches, 0 errors" --ttl 3600
mbp fail migrate --text "batch 7: lock timeout"

mbp list [--json]                 # what is tracked
mbp rm <id>...                    # drop tasks
mbp clear [--group G] [--finished]
mbp start | stop | status | build
```

`tail` takes named groups `done`, `total`, `text`, or the first two groups as done/total.
Default pattern is `N/M`. For a percentage use `--pattern '(?P<done>\d+)%' --total 100`.

## Task file

```json
{"id": "kit", "title": "kit", "group": "pumpkins", "icon": "🎃", "state": "running",
 "done": 326, "total": 403, "text": "crawl · ~5m left", "open": "/tmp/kit.log",
 "ttl": 3600, "updated": 1763895000}
```

| Field | Meaning |
|---|---|
| `id` | Unique name; the file is `<id>.json` |
| `title` | Label in the menu (default: `id`) |
| `group`, `icon` | Tasks with the same group share a header and one menu bar counter: `<icon><finished>/<count> <avg %>` |
| `state` | `running`, `wait`, `ok`, `fail` |
| `done`, `total` | Progress bar and percentage |
| `text` | Free-form status line |
| `open` | Path or URL opened on click |
| `ttl` | Seconds after finishing before the app drops the task |
| `updated` | Unix time of the last write. A running task without updates for 10 minutes is shown as stale (⏸) |

Write it through a temp file and `rename`, so the app never reads half a file. Set `MBP_DIR`
to use another dir (one per project, a shared one for a team box, etc.).

## Feeders

For a process with structured logs, a small feeder is often nicer than `tail`: parse the events,
keep one task per parallel unit, compute an ETA. Write the JSON files directly or call
`mbp set`. The skill tells agents to do exactly that when `wrap` and `tail` don't fit.

## For agents

`skills/menubar-progress/SKILL.md` teaches the agent when to use it (anything longer than a few
minutes, or several things in parallel), which mode to pick (`wrap`, `tail`, `set`, a feeder), and
to always finish its tasks. It pairs well with
[wait-for](https://github.com/savchenko-dev/wait-for): wait-for wakes the agent when a job ends,
menubar-progress shows the user how it is going in the meantime.

## License

MIT
