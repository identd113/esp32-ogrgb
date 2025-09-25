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
