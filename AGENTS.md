# Repository Guidelines

## Scope
These instructions apply to the entire repository unless a more specific `AGENTS.md` is added in a subdirectory.

## Development notes
- This project contains ESPHome YAML configuration for an ESP32-S3 based status light. The primary entry point is `config/ogrgb.yaml`.
- Secrets live in `secrets.yaml`, which is ignored by git. Use `secrets.example.yaml` as a template when you need local credentials. On this Mac, `config/secrets.yaml` is a symlink to `~/Documents/esphome/ogrgb/secrets.yaml`.
- Keep YAML indentation at two spaces and prefer ESPHome-style lowercase keys with underscores.
- When modifying MQTT topics or substitutions, ensure the associated comments in `README.md` stay in sync.

## Current behaviour
The light shows the garage door state. The device wakes, reads from the broker, updates the light, publishes its state, and sleeps for 30 seconds.

**Subscribes to**
- `ogrgb/online_lock` (retained, set by you): keeps the device awake for diagnostics when `true`.
- `My OpenGarage/OUT/STATUS` (retained, published by OpenGarage): `og_online`.
- `My OpenGarage/OUT/STATE` (live, not retained, about every 18 s): door state. `OPEN` means open.

**Publishes**
- Retained: `ogrgb/status`, `ogrgb/wake`, `ogrgb/light/light_status`, `ogrgb/light/light_color`, `ogrgb/state`, `ogrgb/flags`.
- Not retained: `ogrgb/logs` (only while `online_lock` is `true`).

**Wait rules**
- The door state is saved in flash, so it survives deep sleep. A cold boot (power-on or reset) clears it.
- Door unknown (first boot or after a power cut): wait up to 60 seconds for the door message.
- Door known: wait 2 seconds plus an extra time. The extra time grows by 2 seconds each wake with no door message, and resets to 0 once it would pass 60 seconds, or when a message arrives.
- The device sleeps only after all three inputs have arrived on the wake, or after the wait ends.

**Homebridge side**
- The `GarageOpen` tile (mqttthing, on the Synology) publishes taps to `ogrgb/light_control`. The device ignores that topic.
- The `Garage` accessory (homebridge-og) reads OpenGarage over HTTP at `10.0.2.151:12300`.
- `mqttthing` can set retain per publish via `mqttPubOptions`. It has no QoS setting.

## Validation
- There are no automated tests, but you should run `esphome config config/ogrgb.yaml` to validate configuration changes when possible.
- On this Mac, ESPHome `2026.10.1` is installed in `~/.venv-esphome`. Run `~/.venv-esphome/bin/esphome config config/ogrgb.yaml`.
- Compile with `~/.venv-esphome/bin/esphome compile config/ogrgb.yaml`. The first run downloads ESP-IDF, which takes a while.
- If you do not have ESPHome installed locally, document in your PR description that the validation command was not run.

## Status
- The uploaded firmware is from commit `133400a`. Changes made after it (door input, wait rules, flags snapshot) are not yet flashed.
- `mqttthing` loading on the production Homebridge is unverified. The `home-automation-engineer` agent note says it errors on load.

## Scripts

Scripts marked **destructive** change or delete data, so confirm before running them. Scripts marked **sudo** need root. Scripts marked **launchd** or **cron** run on a schedule and are not normally run by hand.


| Script | What it does | Arguments |
|---|---|---|
| `config/upload.sh` | Keeps the device awake, waits for it to answer ping, then uploads over the air. | none |
| `config/test_ogrgb.sh` | Integration test over MQTT: four color scenarios and a deep sleep and wake cycle. | none |
| `scripts/install_esphome_latest.sh` | Installs or upgrades ESPHome with pip. Fails inside a virtual environment. | env `PYTHON_BIN` (default python3) |

## ESPHome upgrade notes (2026.4 to 2026.10)

The device reports ESPHome `2026.3.2`. These notes come from the release pages on esphome.io, checked 2026-10-30. Each page was truncated, so the lists may be incomplete. Check a page again before relying on it.

### Done in the config
- `min_version` is `2026.8.0`, because `on_wake` needs it.
- `rgb_order` is replaced with `channel_colors: GRB`.
- `cpu_frequency: 80MHz` is set on the `esp32:` block. The S3 otherwise runs at 240 MHz.
- `restore_mode: RESTORE_DEFAULT_OFF` is still used on the light. It's deprecated but works. `restore_state: all` is the equivalent. Omitting both keys changes the default in 2026.10, so do not just delete the line.

### Still to test after flashing
- **2026.5.0, `[esphome][ota] Disable loop while idle` (#15636, breaking):** OTA behaviour while idle could change `upload.sh`.
- **2026.5.0, `[core] decouple main loop cadence` (#15792, breaking):** the wait timers depend on loop timing.
- **2026.7.0, `[light] Preserve brightness on turn-off` (#17103, breaking):** check the LED after turning off and on.

### Worth adding
- **2026.8.0, `[safe_mode] Prevent OTA rollback when entering deep sleep` (#17699).** Matters for OTA safety, because the device sleeps soon after waking.
- **2026.10.0, `[esphome][ota][core] Compress OTA uploads on ESP32` (#19037).** Needs no config change, and shortens the upload while the device is awake.
- **2026.10.0, `[deep_sleep] disable loop` (#18962).** Could cut idle CPU time between wakes. Check the change before using it, since the wake logic depends on the loop.
- **2026.7.0, `[esp32] Add software OTA downgrade protection` (#17315).** Stops an accidental flash of an older image.

### Not relevant to this device
NVS in PSRAM, the ESP8266 and host toolchains, `esp32_ble_tracker`, `speaker` and `remote_receiver`, the API and `web_server` changes, and the Zigbee and Modbus work.
