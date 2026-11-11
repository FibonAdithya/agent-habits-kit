"""Tests for agent/guard-commands.sh. Each test sends the hook the JSON an agent tool sends."""
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "guard-commands.sh"
BASH = shutil.which("bash")


def run_guard(command, cwd=None, path=None, raw=None):
    """Run the hook on one command. cwd is the agent's folder (an empty temp folder by default)."""
    cwd = cwd or tempfile.mkdtemp()
    payload = raw if raw is not None else json.dumps({"tool_input": {"command": command}, "cwd": str(cwd)})
    env = dict(os.environ)
    if path is not None:
        env["PATH"] = str(path)
    return subprocess.run([BASH, str(SCRIPT)], input=payload, capture_output=True, text=True,
                          cwd=cwd, env=env, timeout=30)


REFUSE_CASES = [
    "git add -A", "git add .", "git add --all", "cd x && git add :/", "git commit -am msg",
    "pkill -f python", "killall node", "sudo pkill x",
    "git checkout --theirs file.py", "git restore --ours f",
    "git push --force", "git push -f origin main",
]
ALLOW_CASES = [
    "git add src/a.py", "git add -p", "git add ./src", "git commit -m msg",
    'echo "git add -A"', "npkill", "pgrep -fa python", "kill -TERM 1234",
    "git checkout main", "git push --force-with-lease", "ls",
]
OVERRIDES = [("git add -A", "# allow-git-add-all"), ("pkill x", "# allow-kill-pattern"),
             ("git checkout --theirs f", "# allow-conflict-side"),
             ("git push -f", "# allow-force-push")]


@pytest.mark.parametrize("c", REFUSE_CASES)
def test_refuses(c):
    r = run_guard(c)
    assert r.returncode == 2 and "BLOCKED:" in r.stderr


@pytest.mark.parametrize("c", ALLOW_CASES)
def test_allows(c):
    r = run_guard(c)
    assert r.returncode == 0, r.stderr


@pytest.mark.parametrize("c,marker", OVERRIDES)
def test_override(c, marker):
    assert run_guard(f"{c}  {marker}").returncode == 0


def _repo_with_staged(root, name, size):
    """A git repo at root with one staged file of size bytes."""
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    f = root / name
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_bytes(b"x" * size)
    subprocess.run(["git", "-C", str(root), "add", name], check=True)
    return root


def test_large_file_refused(tmp_path):
    repo = _repo_with_staged(tmp_path, "big.bin", 1_100_000)
    r = run_guard("git commit -m x", cwd=repo)
    assert r.returncode == 2 and "big.bin" in r.stderr


def test_large_file_override(tmp_path):
    repo = _repo_with_staged(tmp_path, "big.bin", 1_100_000)
    assert run_guard("git commit -m x  # allow-large-commit", cwd=repo).returncode == 0


def test_small_file_allowed(tmp_path):
    repo = _repo_with_staged(tmp_path, "small.txt", 10)
    assert run_guard("git commit -m x", cwd=repo).returncode == 0


def test_artifact_path_refused(tmp_path):
    repo = _repo_with_staged(tmp_path, "node_modules/x.js", 10)
    r = run_guard("git commit -m x", cwd=repo)
    assert r.returncode == 2 and "node_modules/x.js" in r.stderr


def test_large_file_found_via_cd(tmp_path):
    repo = _repo_with_staged(tmp_path / "repo", "big.bin", 1_100_000)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    assert run_guard(f"cd {repo} && git commit -m x", cwd=elsewhere).returncode == 2


def test_missing_jq_warns_and_allows(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for tool in ("bash", "cat", "grep", "sed", "head", "tail"):
        found = shutil.which(tool)
        if found:
            (bin_dir / tool).symlink_to(found)
    r = run_guard("git add -A", path=bin_dir)
    assert r.returncode == 0
    assert "jq" in r.stderr and "OFF" in r.stderr


def test_empty_input_allows():
    assert run_guard("", raw="").returncode == 0


def test_no_scp_check():
    assert run_guard("scp a b").returncode == 0
