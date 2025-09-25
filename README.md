# esp32-ogrgb

## Overview
The **ogrgb** project packages an [ESPHome](https://esphome.io/) firmware for a tiny ESP32-S3 based status light that mirrors the
state of an [OpenGarage](https://opengarage.io/) door controller. On every wake cycle the board connects to Wi-Fi and MQTT,
collects the latest garage and controller status, drives a single WS2812 RGB pixel, publishes its consolidated state, and then
returns to deep sleep to conserve power.

The firmware targets an `esp32-s3-devkitc-1` board and expects a single LED on GPIO48. It ships with ESP-IDF, release build
settings, and Wi-Fi tuning that keep the binary small and connection latency low.

## Firmware workflow
1. Wake from reset or deep sleep and prevent sleeping while connectivity is established.
2. Join Wi-Fi using credentials from `secrets.yaml` (`wifi_ssid`, `wifi_password`).
3. Establish the MQTT session, publish the retained birth message, and wait briefly for retained topic updates.
4. Recompute the indicator colour based on the most recent MQTT messages and publish a compact JSON state payload.
5. If `online_lock` is **false**, allow the device to re-enter deep sleep (`3s` active window, `30s` sleep).
6. If `online_lock` is **true**, remain awake for maintenance until the lock is cleared or the three minute auto-timeout fires.

## LED behaviour
The lone WS2812 element reflects both the garage door and OpenGarage controller status. Colours only update when a real change
occurs, reducing unnecessary MQTT chatter.

| Garage door | OpenGarage | LED colour | Notes |
|-------------|------------|------------|-------|
| Open        | Online     | Green      | Normal operation, device will deep sleep after publishing. |
| Open        | Offline    | Blue       | Garage is open but the OpenGarage controller is unreachable. |
| Closed      | Online     | Off        | Nothing to display; LED is powered down to save energy. |
| Closed      | Offline    | Red        | Controller appears offline while the door is closed. |

## Configuration & settings
Most values that change per installation live in `secrets.yaml` or ESPHome substitutions.

| Setting | Location | Description |
| --- | --- | --- |
| `device_name` | YAML substitutions | MQTT topic root (defaults to `ogrgb`). |
| `wifi.ssid` / `wifi.password` | `secrets.yaml` | Wi-Fi credentials with optional `fast_connect` for hidden SSIDs. |
| `wifi.power_save_mode` | ESPHome YAML | Uses `HIGH` power save mode to reduce draw between MQTT bursts. |
| `wifi.output_power` | ESPHome YAML | Limits transmit power to 17 dBm, adequate for close-range APs. |
| `ota.password` | `secrets.yaml` | Password required for OTA updates initiated by ESPHome. |
| `mqtt.broker` / `mqtt.port` | `secrets.yaml` | Address of the MQTT broker to connect to. |
| `deep_sleep.run_duration` | ESPHome YAML | Active window before re-entering sleep (3 seconds). |
| `deep_sleep.sleep_duration` | ESPHome YAML | Deep-sleep interval between wake cycles (30 seconds). |
| `online_lock` command | MQTT topic | Setting `${device_name}/online_lock` to `true` keeps the board awake with logging. Automatically clears after three minutes. |

## MQTT API
All MQTT traffic is namespaced under `${device_name}` (default `ogrgb`). Retained messages ensure that Home Assistant or other
automation services can discover the last known state immediately after the device reconnects.

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
| `${device_name}/light/light_status` | `on` / `off` | Reflects whether the LED output is currently active, retained. |
| `${device_name}/light/light_color` | `green`, `blue`, `none`, `red` | Updated only when the colour changes, retained. |
| `${device_name}/state` | JSON | Compact payload: `{ "door_open": bool, "og_online": bool, "color": str, "boots": n }`, retained. |

These topics simplify integration with Home Assistant, Node-RED, or any MQTT-aware automation platform. Automations can command
maintenance mode via `${device_name}/online_lock`, read the most recent retained state, and react whenever the LED state changes.
