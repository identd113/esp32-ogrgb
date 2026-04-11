#!/usr/bin/env bash
# ogrgb integration test
# Tests all 4 color scenarios and the deep sleep / wake cycle.

BROKER="synology.local"
PORT="1883"
DEVICE="ogrgb"
OG_TOPIC="My OpenGarage/OUT/STATUS"
PUB="/opt/homebrew/opt/mosquitto/bin/mosquitto_pub"
SUB="/opt/homebrew/opt/mosquitto/bin/mosquitto_sub"

PASS=0
FAIL=0
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

pub() {
    $PUB -h "$BROKER" -p "$PORT" -t "$1" -m "$2" -r -q 1
}

# Wait for a specific retained-skipped message on a topic containing a pattern.
# Usage: wait_for msg_pattern topic timeout_seconds label
wait_for() {
    local pattern="$1" topic="$2" timeout="$3" label="$4"
    local result
    result=$($SUB -h "$BROKER" -p "$PORT" -t "$topic" -C 1 -W "$timeout" -R 2>/dev/null)
    if echo "$result" | grep -q "$pattern"; then
        echo -e "  ${GREEN}PASS${RESET} $label"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}FAIL${RESET} $label (got: ${result:-<timeout>})"
        FAIL=$((FAIL+1))
    fi
}

# Wait for status (will message / birth message) — these are retained so don't skip
wait_for_status() {
    local expected="$1" timeout="$2" label="$3"
    local result
    # Drain stale retained then wait for next publish
    result=$($SUB -h "$BROKER" -p "$PORT" -t "$DEVICE/status" -C 1 -W "$timeout" -R 2>/dev/null)
    if [ "$result" = "$expected" ]; then
        echo -e "  ${GREEN}PASS${RESET} $label"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}FAIL${RESET} $label (got: ${result:-<timeout>})"
        FAIL=$((FAIL+1))
    fi
}

scenario() {
    local label="$1" door="$2" og="$3" expected_color="$4"
    echo "  Scenario: $label"
    pub "$OG_TOPIC"             "$og"
    pub "$DEVICE/light_control" "$door"
    wait_for "\"color\":\"$expected_color\"" "$DEVICE/state" 10 "  color=$expected_color"
}

echo ""
echo "=============================="
echo "  ogrgb Integration Test"
echo "=============================="

# ── Step 1: ensure device is awake ────────────────────────────────────────────
echo ""
echo "[1] Setting online_lock=true and waiting for device to come online..."
pub "$DEVICE/online_lock" "true"

# Check retained status first — device may already be online
current=$($SUB -h "$BROKER" -p "$PORT" -t "$DEVICE/status" -C 1 -W 3 2>/dev/null)
if [ "$current" = "online" ]; then
    echo -e "  ${GREEN}PASS${RESET} device already online"
    PASS=$((PASS+1))
else
    # Device is sleeping — skip retained and wait up to 40s for live birth message
    echo "  Device offline, waiting up to 40s for wake..."
    result=$($SUB -h "$BROKER" -p "$PORT" -t "$DEVICE/status" -C 1 -W 40 -R 2>/dev/null)
    if [ "$result" = "online" ]; then
        echo -e "  ${GREEN}PASS${RESET} device came online"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}FAIL${RESET} device did not come online within 40s"
        FAIL=$((FAIL+1))
        echo "  Cannot continue — aborting."
        exit 1
    fi
fi

# ── Step 2: color scenarios ───────────────────────────────────────────────────
echo ""
echo "[2] Color scenarios..."

scenario "door=open,  og=online  → green" "on"  "online"  "green"
scenario "door=open,  og=offline → blue"  "on"  "offline" "blue"
scenario "door=closed,og=online  → none"  "off" "online"  "none"
scenario "door=closed,og=offline → red"   "off" "offline" "red"

# Restore realistic state before sleep test
pub "$OG_TOPIC"             "online"
pub "$DEVICE/light_control" "off"

# ── Step 3: deep sleep / wake cycle ──────────────────────────────────────────
echo ""
echo "[3] Deep sleep / wake cycle..."

echo "  Releasing online_lock → device should sleep..."
pub "$DEVICE/online_lock" "false"

wait_for_status "offline" 20 "device went to sleep (status=offline)"

echo "  Waiting for device to wake after sleep_duration=30s (up to 45s)..."
wait_for_status "online"  45 "device woke up (status=online)"

echo ""
echo "  Verifying state published after wake..."
wait_for "\"color\"" "$DEVICE/state" 10 "state published after wake"

# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================="
TOTAL=$((PASS+FAIL))
if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}ALL $TOTAL TESTS PASSED${RESET}"
else
    echo -e "  ${RED}$FAIL/$TOTAL TESTS FAILED${RESET}"
fi
echo "=============================="
echo ""

# Leave device in clean state
pub "$OG_TOPIC"             "online"
pub "$DEVICE/light_control" "off"
pub "$DEVICE/online_lock"   "false"
