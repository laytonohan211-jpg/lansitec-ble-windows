# Android 1.5.0 (20)

LoRaWAN Livestock Tracker now has a dedicated profile for protocol 990-01211 v1.2: automatic individual parameter queries, write acknowledgements followed by query/readback, tracking, motion alarms, asset filter, polygon geofence, commands and supplied 5.4.0 uplink decoder. No setting is written on connection.

BLE guided profiles: Bluetooth Gateway, Badge, Asset, Container, Flex, Tracking Label, Helmet and Livestock. Existing cellular and beacon functionality is retained.

LoRaWAN tools also generate documented downlinks for UWB Tracker/Anchor, PT100, temperature/humidity, Rotary Valve, Contact Tracing and Trusstor Asset Tracker. These tools produce server downlinks; they do not imply an undocumented BLE transport.

Sources reviewed: Badge/Asset payload v6; Gateway payload v3; Container 990-00121; Flex v1.10; Helmet v0.22; Tracking Label v3.0; PT100 v1.24; temperature/humidity v1.27; UWB Anchor v0.42 and Tracker v0.46; Rotary Valve v1.1; Contact Tracing v2.71; Trusstor Asset v5.32; Livestock 990-01211 v1.2 and 990-01210 user manual.

## Internal unresolved items (not shown in application UI)

- Valve heartbeat: 1-byte field/range conflicts with the 6-hour 0x02D0 default. Heartbeat writing is withheld; registration/reboot remain available.
- UWB Tracker position interval: stated bit width conflicts with the 32-bit range. Writing that parameter is withheld.
- No documented BLE command transport in the selected PT100, temperature/humidity, UWB, Valve, Contact Tracing and Trusstor references. Only documented LoRaWAN downlinks are offered for those profiles.
- Contact Tracing POS is reserved and explicitly must not be changed. The complete 0x9 configuration is withheld; command operations remain available.
- Helmet 0xB is used for both UUID and offline-cache commands. This release does not add the ambiguous cache editor.
- Livestock GNSS acquisition time is fixed at 180 seconds, not writable; no editor is presented.
- Device-specific regional firmware validates the Livestock DR/TX power commands. Acceptance must be acknowledged and read back; no fabricated successful state.

The application UI contains operational states and validated controls, not document-quality warnings. Missing measured values are shown as a dash. Hardware validation remains required on real devices.
