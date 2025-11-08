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
