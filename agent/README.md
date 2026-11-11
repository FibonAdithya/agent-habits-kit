# When you let an agent run commands on its own

Everything else in this kit works in any AI tool. This folder is for the next step: an agent that
runs commands on your computer by itself, for example Claude Code. Here, a written rule is a sign:
the agent can still skip it on a hard task. A lock removes the option.

## What a lock is

A lock is a small script that the agent tool runs before each command the agent wants to run. The
script reads the command and either lets it through or refuses it. When it refuses, it tells the
agent why and what to do instead, and the agent reads that message.

`guard-commands.sh` is a lock for Claude Code. It is written as a
[PreToolUse hook](https://code.claude.com/docs/en/hooks) on the Bash tool.

## What it refuses

| It refuses | Why | Override marker |
|---|---|---|
| `git add -A`, `git add .`, `git commit -a` | Saves everything in the folder, including build leftovers. | `# allow-git-add-all` |
| `pkill`, `killall` | Stops every program with a matching name, which can include the agent's own session. | `# allow-kill-pattern` |
| `git commit` with build leftovers or files over 1 MB, staged or added in the same command | Large or generated files do not belong in the project's history. | `# allow-large-commit` |
| `git checkout --theirs` / `--ours`, `git restore --theirs` / `--ours` | Keeps one whole side of a conflict and throws away the other side's changes. | `# allow-conflict-side` |
| `git push --force` without `--force-with-lease` | Overwrites the remote copy, whatever is there. | `# allow-force-push` |

To run a refused command on purpose, add its marker to the end of the command. The marker is
visible to anyone who reads the agent's commands, so an override is never silent. Use one only
when you have read the refusal and the command is what you meant, for example a deliberate commit
of a large file that belongs in the project.

## Requirements

- `bash` and [`jq`](https://jqlang.org/download/).
- Linux or macOS. It is written for both, but has only been tested on Linux. Windows is not covered.
- The tests also need `git`, Python 3 and pytest.

## Install

1. Copy this `agent` folder somewhere permanent on your computer.
2. Add the block in [`settings-snippet.json`](settings-snippet.json) to your Claude Code settings
   file, `~/.claude/settings.json` for all your projects
   ([settings files](https://code.claude.com/docs/en/settings)). Change
   `/path/to/agent-habits-kit/agent/guard-commands.sh` to the real path. If the file already has a
   `"hooks"` section, add the `PreToolUse` entry to it instead of adding a second one.
3. Restart Claude Code.

## Check it is on

Do this once after installing, in a test folder:

1. Ask the agent to run `git add -A`.
2. The command should be refused with a message that starts `BLOCKED:`.

If the command runs, the lock is off. The most common reason is that `jq` is missing: the lock then
lets every command through, and Claude Code shows a hook error notice that says
`jq not found, so this lock is OFF`. Install `jq` and check again.

## What it does not do

- It fails open: if something unexpected goes wrong inside the script, the command is allowed. It
  catches common mistakes; it cannot guarantee that a refused command never runs.
- It only sees commands the agent runs through its shell tool. It does not see file edits.
- It matches the command text. A command written in an unusual form may get past it, for example
  `bash -c "git add -A"` or `/usr/bin/pkill`.
- It does not size the contents of a folder named in `git add`, only files and folder names.
- It can refuse a harmless command whose text contains a refused one, for example a commit message
  that mentions `git add -A`. Reword the command, or add the override marker.

Claude Code also has its own deny rules, which need no script, for example
`"deny": ["Bash(git push *)"]` under `"permissions"` in the same settings file
([permissions](https://code.claude.com/docs/en/permissions)). Use them for commands you never want
run. The lock is for commands that are usually a mistake, where the agent needs to be told what to
do instead.

## Run the tests

From the kit's folder, with Python 3 and pytest installed:

```
python3 -m pytest agent/tests
```
