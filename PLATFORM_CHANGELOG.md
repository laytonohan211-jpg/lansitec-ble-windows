# Cross-platform change register

Updated: 2026-11-03. Android source: android-release. Windows source: github-windows.

## Requirements recovered from the conversation

| Requirement | Android | Windows 1.5.3 change | Evidence / limit |
|---|---|---|---|
| Scan inside the app; select a connected device | 1.5.2 | retained | Scan coordinator and device route |
| One connectivity/model selection: Cat-1, NB, LoRaWAN, BLE beacon; detected fields overridable | 1.5.1+ | ported | profile_selection.dart + peripheral_characteristics_page.dart |
| LoRa Gateway, Badge, Asset, Container, Flex, Label, Helmet, Livestock | 1.5.0+ | ported | lorawan_protocol/setup + Livestock modules |
| Remove custom Trusstor; no detached LoRa catalog button | 1.5.1+ | ported | no catalog entry in scanner; custom commands rejected |
| Read available parameters automatically; generate commands; send and verify where documented | supported profiles | ported/retained | Livestock ACK plus readback; cellular/beacon existing readback. Legacy LoRa full decode/firmware ACK still undocumented |
| Livestock tracking, motion, asset filter, geofence, regional info, commands, decoder | 1.5.0+ | ported | Windows JS runtime, bundled identical decoder; never Android-only method channel on Windows |
| Beacon automatic GATT read/configuration | existing | retained | beacon_snapshot and regression tests |
| Tracking reply/double ASCII decoding fix | existing | retained | snapshot/response regression tests |
| Detect Bluetooth enabled after return without restart | existing | retain Windows adapter refresh | windows_bluetooth_state and connection_readiness |
| Strongest RSSI first, stable ties, refresh every 3 seconds, device identity preserved | 1.5.2 | retained | stable_scan_stream; keys by device ID |
| Printed number/name/address filtering, ignoring separators | 1.5.2 | retained | device_search; only identifiers actually broadcast can match |
| Configuration JSON for support | 1.5.2 | retained | cellular tracker menu exports last-read network/tracking values; Copy JSON; not a file/share-sheet export |
| Missing/contradictory docs reported in chat, not UI | required | retained | UI shows operational state only |
| Ready-to-install Android APK / Windows installer | signed APK delivered | released; CI passed | physical BLE validation still needed |

## Release history and outstanding work
- Android 1.5.0: LoRa profiles and Livestock added. Windows port was omitted.
- Android 1.5.1: unified profile selection, removal of Trusstor and detached catalog. Windows port was omitted.
- Android/Windows 1.5.2: number search, RSSI ordering every 3 seconds, cellular configuration JSON. Windows still lacked LoRa and unified entry: this release was NOT feature-parity complete.
- Windows 1.5.3: brings in Android shared profiles/flow, adds Windows Livestock decoder adapter and tests, preserves desktop-specific adapters. Build status: passed — 74 Flutter tests, 5 decoder vectors, Windows installer and application startup verified in CI.
- Android remains 1.5.2 for this Windows catch-up; no new APK is required for an unchanged Android implementation.

Known limits shared with Android: FF84 full read/ack formats for legacy LoRa; undocumented BLE transports for UWB/PT100/temperature-humidity/Valve/Contact Tracing; Valve heartbeat and UWB interval ambiguities; Helmet offline-cache ambiguity; Contact Tracing reserved POS. Do not invent support. JSON UI currently covers cellular trackers, as in Android 1.5.2.

## Release procedure
1. Compare shared lib and test files, not just version numbers. Classify every difference as intended platform adapter, shared feature to port, or blocked by evidence.
2. Update this register before release, including pending platform work.
3. Run platform regression suites, decoder vectors, build, and applicable installation/start checks.
4. Record exact commit, workflow, artifact, signature/checksum and hardware-test limits after success.

Release evidence: Windows code commit 108f9435a9e9f37dba9d09184f0321bca66d1d07; workflow 41612107497; release windows-1.5.3-build.5. Installer SHA256: 3252a52629bc9a43ad4c29e92039a9b9ff20730c278eb464042d8907c72e651d. Realtek/device hardware not tested. Local parity check: zero unreviewed shared differences; eight desktop adapters reviewed.

## Windows 1.5.4 — connection retention (2026-11-03)
- Request: device disconnects around 10 seconds after a successful complete parameter read.
- Windows-only WinRT 0.0.18 patch: retain GattSession with MaintainConnection while the selected connection is owned; disable retention and close on disconnect/cleanup. Never retain a cancelled connection. No configuration command replay or artificial configuration keepalive.
- Suspend scans for the entire connection/configuration route and reject duplicate Connect attempts. Release suspension on return, cancellation or error; scanning remains available from the list.
- Correction to diagnosis: Connect already stopped the devices-page scan. New guard prevents competing/background scan starts during a session.
- Android: no native WinRT patch applicable. Scan-session guard is a pending shared improvement to assess/port on the next Android update. Existing Android build unchanged.
- Build passed: 75 Flutter tests, 5 decoder vectors, native WinRT compilation, installer and application launch checks. Realtek and physical-device idle stability require user testing; this is a targeted mitigation, not a confirmed hardware fix.

Windows 1.5.4 evidence: code commit e910def551f29f2fe1d560a54543ead625744062; workflow 41619823390; release windows-1.5.4-build.7. Installer SHA256 9e3fab81c917fac660b0c771dea11e36499e85077b54d322bb95bf3fdd081a21. Build log confirms WinRT retention patch applied. No automatic configuration replay.
