#!/usr/bin/env python3
"""Run SonicTune tests and visual inspection inside an E2B cloud sandbox.

Usage:
  python scripts/e2b_runner.py --check                 validate E2B_API_KEY
  python scripts/e2b_runner.py --test [--pytest ...]   run the test suite in a sandbox
  python scripts/e2b_runner.py --app [--timeout 600]   launch the app (VNC-able sandbox)

Requires E2B_API_KEY in .env at the repo root (or in the environment).
"""

import argparse
import os
import sys
from pathlib import Path

from e2b import Sandbox

ROOT = Path(__file__).resolve().parent.parent
REMOTE = "/home/user/sonictune"


def load_env() -> dict:
    env = dict(os.environ)
    env_file = ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                env[key.strip()] = value.strip()
    return env


SKIP_PARTS = {
    ".git", ".venv", "venv", "env", "__pycache__", "node_modules",
    ".pytest_cache", ".mypy_cache", ".ruff_cache", "build", "dist",
    ".eggs", ".devcontainer",
}


def upload_project(sandbox: Sandbox, dest: str = REMOTE) -> int:
    """Upload the local repo tree, skipping VCS/venv/build directories."""
    count = 0
    for path in sorted(ROOT.rglob("*")):
        rel = path.relative_to(ROOT)
        if any(p in SKIP_PARTS or p.endswith(".egg-info") for p in rel.parts):
            continue
        if path.is_file():
            target = f"{dest}/{rel}"
            sandbox.files.write(target, path.read_bytes())
            count += 1
    print(f"[upload] {count} files -> {dest}")
    return count


def run_cmd(sandbox: Sandbox, cmd: str) -> str:
    result = sandbox.commands.run(cmd)
    print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.exit_code != 0:
        raise RuntimeError(f"command failed ({result.exit_code}): {cmd}")
    return result.stdout


def install_deps(sandbox: Sandbox) -> None:
    run_cmd(sandbox, "sudo apt-get update -qq")
    run_cmd(sandbox, "sudo apt-get install -y -qq xvfb xauth libmpv-dev libgl1 libegl1 ffmpeg >/dev/null 2>&1 || true")
    run_cmd(sandbox, "python3 -m venv /home/user/venv")
    run_cmd(sandbox, "/home/user/venv/bin/pip install -q --upgrade pip")
    run_cmd(sandbox, f"/home/user/venv/bin/pip install -q -e '{REMOTE}[dev]'")
    run_cmd(sandbox, "/home/user/venv/bin/pip install -q pytest-playwright pyvirtualdisplay")
    run_cmd(sandbox, "/home/user/venv/bin/playwright install --with-deps chromium >/dev/null 2>&1 || true")


def run_tests(args) -> None:
    pytest_args = args.pytest or ""
    sandbox = Sandbox.create(timeout=args.timeout, metadata={"task": "sonictune-test"})
    try:
        upload_project(sandbox)
        install_deps(sandbox)
        cmd = (
            f"cd {REMOTE} && QT_QPA_PLATFORM=offscreen "
            f"/home/user/venv/bin/pytest tests/ -p no:cacheprovider {pytest_args}"
        )
        run_cmd(sandbox, cmd)
    finally:
        sandbox.kill()


def run_app(args) -> None:
    sandbox = Sandbox.create(
        timeout=args.timeout, display=True,
        metadata={"task": "sonictune-visual"},
    )
    try:
        upload_project(sandbox)
        install_deps(sandbox)
        run_cmd(sandbox, "Xvfb :99 -screen 0 1280x800x24 &")
        run_cmd(
            sandbox,
            f"cd {REMOTE} && DISPLAY=:99 /home/user/venv/bin/python -m sonictune.app --no-mpris --no-discord &",
        )
        try:
            vnc = sandbox.get_host(6080)
            print(f"[vnc] inspect the running app at: {vnc}")
        except Exception as exc:
            print(f"[vnc] unavailable: {exc}")
        print("[app] sandbox is running; Ctrl-C to stop.")
        while True:
            input()
    except KeyboardInterrupt:
        pass
    finally:
        sandbox.kill()


PASSTHROUGH_KEYS = [
    "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "OPENCODE_PROVIDER",
]


def run_opencode(args) -> None:
    """Run opencode headlessly inside an E2B 'opencode' template sandbox."""
    prompt = args.prompt or "Run the test suite and summarize the result."
    envs = {}
    for key in PASSTHROUGH_KEYS:
        value = load_env().get(key) or os.environ.get(key)
        if value:
            envs[key] = value
    sandbox = Sandbox.create("opencode", timeout=args.timeout, envs=envs,
                             metadata={"task": "sonictune-opencode"})
    try:
        if args.directory:
            run_cmd(sandbox, f"git clone {args.directory} /home/user/repo 2>/dev/null || true")
            workdir = "/home/user/repo"
        else:
            workdir = "/home/user"
        run_cmd(sandbox, f"cd {workdir} && timeout {args.timeout} opencode run \"{prompt}\" --print-logs")
    finally:
        sandbox.kill()


def check_key() -> int:
    env = load_env()
    key = env.get("E2B_API_KEY", "")
    if not key:
        print("E2B_API_KEY not found in .env or environment.", file=sys.stderr)
        return 1
    if not key.startswith("e2b_"):
        print(f"Warning: key prefix is '{key[:6]}…' — expected 'e2b_'", file=sys.stderr)
    try:
        info = Sandbox.create(timeout=60, metadata={"task": "key-check"})
        sandbox_id = info.sandbox_id
        info.kill()
        print(f"E2B_API_KEY OK (sandbox {sandbox_id} created and killed)")
        return 0
    except Exception as exc:
        print(f"E2B_API_KEY check failed: {exc}", file=sys.stderr)
        return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="E2B sandbox runner for SonicTune")
    parser.add_argument("--check", action="store_true", help="validate the E2B API key")
    parser.add_argument("--test", action="store_true", help="run the test suite in a sandbox")
    parser.add_argument("--app", action="store_true", help="launch the app in a sandbox")
    parser.add_argument("--opencode", action="store_true",
                        help="run opencode headlessly in an 'opencode' sandbox")
    parser.add_argument("--prompt", help="prompt for --opencode")
    parser.add_argument("--directory", help="git URL to clone for --opencode")
    parser.add_argument("--pytest", nargs="+", help="extra args passed to pytest")
    parser.add_argument("--timeout", type=int, default=900, help="sandbox timeout in seconds")
    args = parser.parse_args()

    env = load_env()
    os.environ.setdefault("E2B_API_KEY", env.get("E2B_API_KEY", ""))

    if args.check:
        return check_key()
    if args.test:
        run_tests(args)
        return 0
    if args.app:
        run_app(args)
        return 0
    if args.opencode:
        run_opencode(args)
        return 0
    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
