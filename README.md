# esp32-ogrgb

## Overview
The **ogrgb** project packages an [ESPHome](https://esphome.io/) firmware for an ESP32-S3 status light that mirrors the state of an [OpenGarage](https://opengarage.io/) door controller. On every wake cycle the node connects to Wi-Fi and MQTT, reads the most recent garage and controller topics, drives a single WS2812 RGB pixel, publishes its consolidated state, and then returns to deep sleep to conserve power.

The firmware targets an `esp32-s3-devkitc-1` board with the LED on GPIO48. PlatformIO release options, reduced Wi-Fi TX power, and MQTT retain usage keep reconnections fast while minimising flash and power consumption.

## Capabilities at a glance
* **Deep-sleep cycle:** Wakes for roughly three seconds, handles messaging, and sleeps for thirty seconds by default.
* **Retained telemetry:** Publishes a compact JSON state, last colour, light status, and online/offline presence with QoS1 retain so automations immediately see the latest values.
* **Maintenance lock:** An `online_lock` topic keeps the device awake for troubleshooting, with an automatic timeout after three minutes.
* **Boot accounting:** Maintains a retained `boots` counter inside the JSON payload to monitor reset frequency.
* **Minimal logging:** Default logger level is `WARN` with the UART disabled (`baud_rate: 0`) to reduce noise and power draw when battery powered.

## Firmware workflow
1. Wake from reset or deep sleep and block the deep-sleep component while connectivity is being established.
2. Join Wi-Fi using credentials from `secrets.yaml` and hold the radio in `HIGH` power-save mode with `fast_connect` enabled.
3. Establish the MQTT session, publish the retained birth message, and wait up to five seconds for retained topic updates. The firmware tracks whether it has seen each expected topic (`online_lock`, OpenGarage status, and door state) before proceeding.
4. Recompute the indicator colour based on the latest topics, drive the LED, and publish both the colour (only when it changes) and a condensed JSON state payload that includes the rolling boot count.
5. If all required topics have been seen and `online_lock` is **false**, allow the device to re-enter deep sleep (`3s` active window, `30s` sleep). Otherwise remain awake until the lock clears or the timeout script releases it.

## LED behaviour
The lone WS2812 element reflects both the garage door and OpenGarage controller status. Colours only update when a real change occurs, reducing unnecessary MQTT chatter.

| Garage door | OpenGarage | LED colour | Notes |
|-------------|------------|------------|-------|
| Open        | Online     | Green      | Normal operation; deep sleep resumes once all topics are processed. |
| Open        | Offline    | Blue       | Garage is open but the OpenGarage controller is unreachable. |
| Closed      | Online     | Off        | Nothing to display; LED is powered down to save energy. |
| Closed      | Offline    | Red        | Controller appears offline while the door is closed. |

## Configuration & settings
Most installation-specific values live in `secrets.yaml` or ESPHome substitutions.

| Setting | Location | Description |
| --- | --- | --- |
| `device_name` | YAML substitutions | MQTT topic root (defaults to `ogrgb`). |
| `wifi.ssid` / `wifi.password` | `secrets.yaml` | Wi-Fi credentials with optional `fast_connect` for hidden SSIDs. |
| `wifi.power_save_mode` | ESPHome YAML | Uses `HIGH` power-save mode to reduce draw between MQTT bursts. |
| `wifi.output_power` | ESPHome YAML | Limits transmit power to ~17 dBm, adequate for nearby access points. |
| `ota.password` | `secrets.yaml` | Password required for ESPHome OTA updates. |
| `mqtt.broker` / `mqtt.port` | `secrets.yaml` | Address of the MQTT broker to connect to. |
| `logger.level` | ESPHome YAML | Defaults to `WARN` with `baud_rate: 0` to silence the UART. |
| `deep_sleep.run_duration` | ESPHome YAML | Active window before re-entering sleep (default three seconds). |
| `deep_sleep.sleep_duration` | ESPHome YAML | Deep-sleep interval between wake cycles (default thirty seconds). |
| `${device_name}/online_lock` | MQTT topic | Setting to `true` keeps the board awake; automatically clears after roughly three minutes. |

## MQTT API
All MQTT traffic is namespaced under `${device_name}` (default `ogrgb`). Retained messages ensure that Home Assistant or other automation services can discover the last known state immediately after the device reconnects.

### Subscribed topics
| Topic | Payload | Purpose |
| --- | --- | --- |
| `My OpenGarage/OUT/STATUS` | `online` / other | Reports whether the OpenGarage controller is reachable. |
| `${device_name}/light_control` | `on` / `off` | Indicates if the garage door is open. |
| `${device_name}/online_lock` | `true` / `false` | Enables the maintenance lock that prevents deep sleep. |

### Published topics
| Topic | Payload | Notes |
| --- | --- | --- |
| `${device_name}/status` | `online` / `offline` | Birth/will messages sent on connect and before sleeping, retained. |
| `${device_name}/light/light_status` | `on` / `off` | Mirrors the light component on/off state, retained. |
| `${device_name}/light/light_color` | `green`, `blue`, `none`, `red` | Updated only when the colour changes, retained. |
| `${device_name}/state` | JSON | Compact payload `{ "door_open": bool, "og_online": bool, "color": str, "boots": n }`, retained. |

These topics simplify integration with Home Assistant, Node-RED, or any MQTT-aware automation platform. Automations can command maintenance mode via `${device_name}/online_lock`, read the most recent retained state, and react whenever the LED state changes.
=======
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