---
name: menubar-progress
description: Show the progress of long-running work (builds, crawls, data jobs, deploys, batches of subtasks, background agents) in the macOS menu bar so the user can glance at it without asking. Use whenever you start something that runs longer than a couple of minutes, or several processes in parallel, and the user would otherwise ask "how is it going?".
---

# Report long-running work to the menu bar

The user cannot see your background processes. One line in the menu bar
(`🎃 2/6 41%`) answers "how is it going?" before they ask. Each task is one JSON
file; the `mbp` CLI writes it, a tiny menu bar app renders all of them.

## How

1. Make sure the app runs: `${CLAUDE_PLUGIN_ROOT}/bin/mbp start` (idempotent, builds on first run).
2. Pick the lightest way to feed a task:
   - **A command with a clear end**: wrap it. Running → ok/fail by exit code.

     ```bash
     ${CLAUDE_PLUGIN_ROOT}/bin/mbp wrap build --group ci --icon 🔨 -- make -j4
     ```

   - **A process that logs progress** (`123/4567`, `42%`, JSON events): follow its log in the background.

     ```bash
     ${CLAUDE_PLUGIN_ROOT}/bin/mbp tail crawl /tmp/crawl.log --group crawl --icon 🕷 \
       --pattern '(?P<done>\d+)/(?P<total>\d+)' --ok 'finished' --fail 'ERROR' --pid <pid>
     ```

   - **Steps you drive yourself** (a list of subtasks, a migration in batches): update as you go.

     ```bash
     ${CLAUDE_PLUGIN_ROOT}/bin/mbp set migrate --group db --done 3 --total 10 --text "batch 3: users"
     ${CLAUDE_PLUGIN_ROOT}/bin/mbp ok migrate --text "10 batches, 0 errors" --ttl 3600
     ```

   - **Anything else**: a feeder script that writes `$MBP_DIR/<id>.json` (schema below) is fine.
3. Tell the user in one line what is on the menu bar (group, icon).

## Rules

- One `--group` per job, one task per parallel unit (journal, shard, service). The menu bar shows
  `<icon><finished>/<count> <avg %>` per group, so 2-8 tasks in a group read best.
- `--open` a log file or URL, so a click on the menu item shows details.
- Finish every task: `mbp ok` / `mbp fail` (or `wrap`/`tail` do it). A running task with no
  update for 10 minutes is shown as stale (⏸), which is a signal, not a state to leave behind.
- `--ttl` on finished tasks keeps the menu clean; `mbp clear --finished` drops them now.
- Never put secrets into `--text`: the state dir is plain files.

## Task file

`$MBP_DIR` (default `~/.local/state/mbp`), one `<id>.json` per task:

```json
{"id": "kit", "title": "kit", "group": "pumpkins", "icon": "🎃", "state": "running",
 "done": 326, "total": 403, "text": "crawl · ~5m left", "open": "/tmp/kit.log",
 "ttl": 3600, "updated": 1763895000}
```

`state`: `running` | `wait` | `ok` | `fail`. Write via a temp file + rename.
