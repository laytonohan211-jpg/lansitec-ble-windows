# Android 1.4.0 (19)

- Automatically identifies LoRaWAN GATT FF81/FF82/FF84 and reads readable fields on connection.
- Guided tracking configuration for LoRaWAN Bluetooth Gateway, Badge/Asset v5.35, and Container 990-00121. Device family must be selected explicitly because shared GATT IDs cannot distinguish command formats.
- Uses UTF-8 hexadecimal commands, with model-specific heartbeat size, byte order, flags and reboot payload.
- Does not write on connection. Complete settings must be reviewed before sending. Presets are explicitly not presented as values read from the device.
- Beacon automatic reads and typed settings carried over from 1.3.4; read failures no longer prevent other fields being read.
- BLE list coalesces updates to one per second and retains row order.
- Android refresh/resume checks the Bluetooth adapter directly.
- Cellular feedback handles ASCII-hex responses including the scan-duration field.

## Verified protocol sources

User supplied `GATT ID for LoRaWAN Trackers.jpg` (FF81–FF8D);
LoRaWAN Gateway GATT spreadsheet and Bluetooth Gateway Payload Specification;
LoRaWAN Container Tracker Payload Specification 990-00121 and User Manual 990-00120;
LoRaWAN Badge Tracker / Asset Management Tracker DataSheet v5.35.

## Boundaries

Bluetooth configuration uses the same documented command strings as each model's configuration protocol. BLE access may require pairing and the power-on configuration window. A successful BLE write acknowledges transport only. Configuration echoes do not prove settings are applied; check device uplinks after any required reboot.

Region, band, frequency, network state, and extended advertising fields are displayed as returned, with raw bytes. This release does not change LoRaWAN keys, regional radio settings, or undocumented FF89–FF8D encodings. It does not add LoRa radio hardware to a phone.

## Build and signing

Flutter 3.29.0, Java 17, Gradle 8.10.2. CI analyzes and tests before compiling an unsigned APK. Final APK is aligned and signed locally using the existing guided-test identity; the private signing key is excluded from the repository.

