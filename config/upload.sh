#!/usr/bin/env bash
# Wait for ogrgb to wake, then OTA upload.

BROKER="synology.local"
DEVICE="ogrgb"
HOST="ogrgb.local"
PUB="/opt/homebrew/opt/mosquitto/bin/mosquitto_pub"

echo "Setting online_lock=true to keep device awake after wake..."
$PUB -h "$BROKER" -p 1883 -t "$DEVICE/online_lock" -m "true" -r -q 1

echo "Waiting for $HOST to respond to ping..."
until ping -c 1 -W 1 "$HOST" &>/dev/null; do
    printf "."
    sleep 1
done

echo ""
echo "$HOST is up — starting OTA upload..."
esphome upload ogrgb.yaml --device "$HOST"

echo "Releasing online_lock..."
$PUB -h "$BROKER" -p 1883 -t "$DEVICE/online_lock" -m "false" -r -q 1
