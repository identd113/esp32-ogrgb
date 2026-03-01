#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"

run_pip_install() {
  if ! "$PYTHON_BIN" -m pip install --user --upgrade "$@"; then
    echo "[warn] pip could not install: $*" >&2
    return 1
  fi
}

echo "[install] Checking pip availability"
"$PYTHON_BIN" -m pip --version

echo "[install] Trying to refresh pip tooling (optional)"
if ! run_pip_install pip setuptools wheel; then
  echo "[warn] continuing without pip tooling refresh"
fi

echo "[install] Installing newest ESPHome release"
run_pip_install esphome

echo "[install] ESPHome version"
"$PYTHON_BIN" -m esphome version
