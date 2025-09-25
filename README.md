# esp32-ogrgb

ESPHome configuration for an ESP32-S3 based status light that mirrors the state of
an OpenGarage controller via MQTT. The device wakes up briefly, processes any
messages it missed while sleeping, publishes its state, and then returns to deep
sleep unless it is locked online for diagnostics.

## Repository layout

```
config/
  ogrgb.yaml          # Main ESPHome configuration
secrets.example.yaml  # Template for your local secrets
```

Create a `secrets.yaml` (ignored by git) next to this README by copying the
example file and filling in the real credentials:

```bash
cp secrets.example.yaml secrets.yaml
# …edit secrets.yaml…
```

## Prerequisites

Install ESPHome using pip (Python 3.11+) or run it in Docker:

```bash
pip install --user esphome
# or
docker pull ghcr.io/esphome/esphome
```

You will also need:

- An ESP32-S3 module (tested with the ESP32-S3-DevKitC-1) wired to a WS2812 LED
  on GPIO48.
- An MQTT broker that exposes the topics referenced below.
- The Wi-Fi credentials for the network the device should join.

## Building and flashing

1. Connect the ESP32 via USB and put it in download mode if required by your
   board.
2. Run ESPHome from the repository root:

   ```bash
   esphome run config/ogrgb.yaml
   ```

   The command builds the firmware and opens the serial log. You can append
   `--device /dev/ttyUSB0` to pick a specific serial port.

3. Subsequent deployments can use `esphome upload config/ogrgb.yaml` for faster
   OTA updates.

If you prefer Docker:

```bash
docker run --rm -it \
  -v "$(pwd)":/config \
  --device=/dev/ttyUSB0 \  # adjust to match your serial adapter
  ghcr.io/esphome/esphome \
  run config/ogrgb.yaml
```

## MQTT interface

The configuration expects the following MQTT topics:

| Topic                             | Direction | Payloads | Purpose                                    |
| --------------------------------- | --------- | -------- | ------------------------------------------ |
| `ogrgb/online_lock`               | Inbound   | `true`/`false` | Keeps the device awake for diagnostics |
| `My OpenGarage/OUT/STATUS`        | Inbound   | `online`/`offline` | State published by the OpenGarage hub |
| `ogrgb/light_control`             | Inbound   | `on`/`off` | Garage door contact sensor status      |
| `ogrgb/status`                    | Outbound  | `online`/`offline` | Device birth/will message             |
| `ogrgb/light/light_status`        | Outbound  | `on`/`off` | Mirrors the LED's power state          |
| `ogrgb/light/light_color`         | Outbound  | `red`/`green`/`blue`/`none` | Current color / effect             |
| `ogrgb/state`                     | Outbound  | JSON      | Consolidated state and boot counter      |
| `ogrgb/globals/*` (legacy)        | Outbound  | booleans  | Retained per-flag state for monitoring    |

Adjust the `substitutions.device_name` value in `config/ogrgb.yaml` if you want
to change the MQTT topic prefix.

## Behavior summary

- The device boots, prevents deep sleep, and waits for MQTT to connect.
- When connected it resets the state bitmask, republishes retained topics, and
  schedules a sleep once all required messages have been seen.
- The WS2812 LED uses the following colors:
  - **Green** – Door open and OpenGarage online
  - **Blue** – Door open while OpenGarage is offline
  - **Red** – Door closed while OpenGarage offline
  - **Off** – Door closed and OpenGarage online
- A retained JSON payload on `<device>/state` summarizes the current status and
  boot counter for dashboards.
- Setting `<device>/online_lock` to `true` keeps the device awake for three
  minutes; leaving it `true` longer automatically clears the lock so the device
  can return to deep sleep.

## Troubleshooting tips

- If compilation fails with missing ESP-IDF packages, ensure you are using the
  ESPHome Docker image or have the ESP-IDF toolchain installed locally.
- When OTA uploads stall, retry with a serial cable using `esphome run` to force
  a wired flash and capture logs.
- Increase `run_duration` in `config/ogrgb.yaml` if your network is slow to
  deliver retained MQTT messages before the device goes back to sleep.

## License

This project is licensed under the [MIT License](LICENSE).
