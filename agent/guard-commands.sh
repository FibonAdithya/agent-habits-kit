#!/usr/bin/env bash
# A lock for an AI agent's shell commands. The agent tool runs this before each command
# (a Claude Code PreToolUse hook on the Bash tool). It refuses five kinds of command, each of
# which has done real damage when an agent ran it on its own:
#   1. `git add -A` / `git add .` / `git commit -a`  -> saved 85 MB of build leftovers in one commit
#   2. `pkill` / `killall` (stop programs by name)  -> stopped the agent's own shell mid-task
#   3. `git commit` with build leftovers or files over 1 MB staged
#   4. `git checkout/restore --theirs/--ours`       -> threw away the other side's changes
#   5. `git push --force` without --force-with-lease -> can overwrite someone else's work
#
# Each refusal says why and what to do instead. To run a refused command on purpose, append its
# override marker (shown in the message), so anyone reading the agent's commands can see it.
#
# Exit 2 = refuse (the message on stderr goes to the agent). Exit 0 = allow.
# It fails open: if something unexpected goes wrong, the command is allowed. It is a safety net,
# not a guarantee. Needs bash and jq. Works on Linux; written for macOS too, but untested there.
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-commands: jq not found, so this lock is OFF and every command is allowed. Install jq." >&2
  exit 0
fi

payload=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$cmd" ] && exit 0

# A command starts at the beginning of the line or after ; & | or (.
ANCHOR='(^|[;&|(])[[:space:]]*'
ARGS='([[:space:]]+[^;&|[:space:]]+)*'

has() { printf '%s' "$cmd" | grep -qE "$1"; }
optout() { printf '%s' "$cmd" | grep -qF "$1"; }

# ---- 1. saving everything at once --------------------------------------------
if ! optout '# allow-git-add-all'; then
  if has "${ANCHOR}(sudo[[:space:]]+)?git${ARGS}[[:space:]]+add${ARGS}[[:space:]]+(-A|--all|\.|:/)([[:space:]]|\$)"; then
    echo "BLOCKED: 'git add -A/--all/./:/' stages everything, including build leftovers." >&2
    echo "Stage explicit paths instead: git add path/to/file.py path/to/other.js" >&2
    echo "Check first with: git status --short" >&2
    echo "Override (rare, deliberate) by appending: # allow-git-add-all" >&2
    exit 2
  fi
  if has "${ANCHOR}(sudo[[:space:]]+)?git${ARGS}[[:space:]]+commit${ARGS}[[:space:]]+(-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|\$)"; then
    echo "BLOCKED: 'git commit -a/--all' stages every tracked change." >&2
    echo "Stage explicit paths, then commit without -a." >&2
    echo "Override by appending: # allow-git-add-all" >&2
    exit 2
  fi
fi

# ---- 2. stopping programs by name --------------------------------------------
if ! optout '# allow-kill-pattern'; then
  if has "${ANCHOR}(sudo[[:space:]]+)?(pkill|killall)([[:space:]]|\$)"; then
    echo "BLOCKED: pkill/killall match by name and can stop the agent's own shell." >&2
    echo "Stop the exact process instead: kill -TERM \"\$PID\" (or kill -- -\"\$PGID\")." >&2
    echo "Find the PID first: pgrep -fa <pattern>   # read-only, safe" >&2
    echo "Override by appending: # allow-kill-pattern" >&2
    exit 2
  fi
fi

# ---- 3. build leftovers or large files staged for commit ---------------------
if has "${ANCHOR}(sudo[[:space:]]+)?git${ARGS}[[:space:]]+commit([[:space:]]|\$)" && ! optout '# allow-large-commit'; then
  # Find the repo, most reliable first: `git -C <dir>`, then the last `cd <dir>` in the command
  # (agents often run `cd <repo> && git commit`), then the agent's folder, then $PWD.
  unquote() { sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"; }
  session_cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)

  dir=$(printf '%s' "$cmd" \
    | grep -oE 'git[[:space:]]+-C[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:];&|]+)' \
    | head -1 | sed -E 's/^git[[:space:]]+-C[[:space:]]+//' | unquote)

  if [ -z "$dir" ]; then
    dir=$(printf '%s' "$cmd" \
      | grep -oE '(^|[;&|])[[:space:]]*cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:];&|]+)' \
      | tail -1 | sed -E 's/^[;&|]?[[:space:]]*cd[[:space:]]+//' | unquote)
  fi

  case "$dir" in
    "~"|"~/"*) dir="$HOME${dir#\~}" ;;
  esac
  # A relative `cd` target is relative to the agent's folder.
  case "$dir" in
    ""|/*) : ;;
    *) [ -n "$session_cwd" ] && dir="$session_cwd/$dir" ;;
  esac

  [ -z "$dir" ] && dir="$session_cwd"
  [ -z "$dir" ] && dir=$PWD
  staged=$(git -C "$dir" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
  if [ -n "$staged" ]; then
    bad=""
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      case "$f" in
        */target/*|target/*|*__pycache__/*|*/node_modules/*|node_modules/*|\
        */.venv/*|.venv/*|*/venv/*|venv/*|*.pyc|*.pt|*.pth|*.ckpt|*.safetensors|*.so|*.o|*.egg-info/*)
          bad="$bad  build leftover: $f"$'\n' ; continue ;;
      esac
      sz=$(git -C "$dir" cat-file -s ":$f" 2>/dev/null || echo 0)
      if [ "$sz" -gt 1048576 ] 2>/dev/null; then
        bad="$bad  $((sz / 1024)) KB: $f"$'\n'
      fi
    done <<< "$staged"
    if [ -n "$bad" ]; then
      echo "BLOCKED: staged files look like build leftovers or are over 1 MB:" >&2
      printf '%s' "$bad" >&2
      echo "Unstage them (git restore --staged <path>) and add them to .gitignore," >&2
      echo "or, if this large file belongs in the repo, append: # allow-large-commit" >&2
      exit 2
    fi
  fi
fi

# ---- 4. taking one whole side of a conflict ----------------------------------
if ! optout '# allow-conflict-side'; then
  if has "${ANCHOR}(sudo[[:space:]]+)?git${ARGS}[[:space:]]+(checkout|restore)${ARGS}[[:space:]]+--(theirs|ours)([[:space:]]|=|\$)"; then
    echo "BLOCKED: 'git checkout/restore --theirs/--ours' takes one whole side of the file and throws" >&2
    echo "away the other side's changes, including the ones that did not conflict." >&2
    echo "Settle each conflict instead: open the file, keep both sides' other changes, then" >&2
    echo "git add <path> and run the tests again." >&2
    echo "Override (rare, deliberate) by appending: # allow-conflict-side" >&2
    exit 2
  fi
fi

# ---- 5. force-push without a lease -------------------------------------------
if ! optout '# allow-force-push'; then
  if has "${ANCHOR}(sudo[[:space:]]+)?git${ARGS}[[:space:]]+push${ARGS}[[:space:]]+(--force|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]]|\$)" \
     && ! optout '--force-with-lease'; then
    echo "BLOCKED: 'git push --force' / '-f' overwrites the remote, whatever is there." >&2
    echo "Use --force-with-lease, which refuses if someone else pushed in the meantime." >&2
    echo "Override by appending: # allow-force-push" >&2
    exit 2
  fi
fi

exit 0
