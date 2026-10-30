# Repository Guidelines

## Scope
These instructions apply to the entire repository unless a more specific `AGENTS.md` is added in a subdirectory.

## Development notes
- This project contains ESPHome YAML configuration for an ESP32-S3 based status light. The primary entry point is `config/ogrgb.yaml`.
- Secrets live in `secrets.yaml`, which is ignored by git. Use `secrets.example.yaml` as a template when you need local credentials.
- Keep YAML indentation at two spaces and prefer ESPHome-style lowercase keys with underscores.
- When modifying MQTT topics or substitutions, ensure the associated comments in `README.md` stay in sync.

## Validation
- There are no automated tests, but you should run `esphome config config/ogrgb.yaml` to validate configuration changes when possible.
- If you do not have ESPHome installed locally, document in your PR description that the validation command was not run.

## Scripts

Scripts marked **destructive** change or delete data, so confirm before running them. Scripts marked **sudo** need root. Scripts marked **launchd** or **cron** run on a schedule and are not normally run by hand.


| Script | What it does | Arguments |
|---|---|---|
| `config/upload.sh` | Keeps the device awake, waits for it to answer ping, then uploads over the air. | none |
| `config/test_ogrgb.sh` | Integration test over MQTT: four color scenarios and a deep sleep and wake cycle. | none |
| `scripts/install_esphome_latest.sh` | Installs or upgrades ESPHome with pip. | env `PYTHON_BIN` (default python3) |

## ESPHome upgrade notes (2026.4 to 2026.10)

The device reports ESPHome `2026.3.2`. These notes come from the release pages on esphome.io, checked 2026-10-30. Each page was truncated, so the lists may be incomplete. Check a page again before relying on it.

### Must change before upgrading
- **2026.10.0, `[light] Replace restore_mode with restore_state` (#18997, breaking).** `restore_mode` is deprecated, not removed, and all its values still work. `config/ogrgb.yaml` uses `restore_mode: RESTORE_DEFAULT_OFF` (line 158), which is the same as `restore_state: all`. Migrate it when convenient. Omitting both keys changes the default in 2026.10, so do not just delete the line.
- **2026.5.0, `[esphome][ota] Disable loop while idle, wake on listening-socket activity` (#15636, breaking).** This changes how OTA behaves while the device is idle, which affects `upload.sh`. Test an OTA upload on the device after the upgrade.
- **2026.5.0, `[core] decouple main loop cadence from scheduler wake timing` (#15792, breaking).** The sleep logic depends on 3 s and 10 s timers, so test the wake cycle after the upgrade.
- **2026.7.0, `[light] Preserve brightness on turn-off` (#17103, breaking).** The recompute script sets brightness before each turn-on, so this should not matter, but check the LED after the upgrade.

### Worth adding
- **2026.8.0, `[deep_sleep] Add on_wake automation triggers` (#17569).** Could publish a wake event, which would make the wake cycle visible in MQTT.
- **2026.8.0, `[safe_mode] Prevent OTA rollback when entering deep sleep` (#17699).** Matters for OTA safety, because the device sleeps soon after waking.
- **2026.10.0, `[esphome][ota][core] Compress OTA uploads on ESP32` (#19037).** Needs no config change, and shortens the upload while the device is awake.
- **2026.10.0, `[deep_sleep] disable loop` (#18962).** Could cut idle CPU time between wakes. Check the change before using it, since the wake logic depends on the loop.
- **2026.7.0, `[esp32] Add software OTA downgrade protection` (#17315).** Stops an accidental flash of an older image.

### Not relevant to this device
NVS in PSRAM, the ESP8266 and host toolchains, `esp32_ble_tracker`, `speaker` and `remote_receiver`, the API and `web_server` changes, and the Zigbee and Modbus work.
