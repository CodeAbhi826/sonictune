#!/usr/bin/env bash
# scripts/test.sh — run tests, linters, and type checker.
#
# Usage:
#   ./scripts/test.sh              # run all checks
#   ./scripts/test.sh --fast       # skip type checking (faster)
#   ./scripts/test.sh --unit-only  # just unit tests

set -euo pipefail

cd "$(dirname "$0")/.."

FAST=0
UNIT_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --fast) FAST=1 ;;
        --unit-only) UNIT_ONLY=1 ;;
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

if ! command -v uv &>/dev/null; then
    echo "Error: uv not installed. Run ./scripts/setup-dev.sh first."
    exit 1
fi

echo "=== Ruff check ==="
uv run ruff check src tests
echo "✓ Linting passed"

echo ""
echo "=== Ruff format check ==="
uv run ruff format --check src tests
echo "✓ Format check passed"

if [[ $FAST -eq 0 ]]; then
    echo ""
    echo "=== Mypy ==="
    uv run mypy src
    echo "✓ Type checking passed"
fi

echo ""
if [[ $UNIT_ONLY -eq 1 ]]; then
    echo "=== Pytest (unit only) ==="
    uv run pytest tests --ignore=tests/integration -v
else
    echo "=== Pytest ==="
    uv run pytest -v
fi
echo "✓ Tests passed"

echo ""
echo "✅ All checks passed!"
