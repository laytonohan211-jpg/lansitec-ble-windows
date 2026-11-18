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

## Field regression report — Windows 1.5.4 (2026-11-03)
- User reports worse discovery/connection and a drop DURING Livestock parameter reads, not idle after success. Do not describe 1.5.4 as a verified stability fix.
- Capture: valid responses B001 through B011 (15 queried IDs, non-contiguous). First failure B012: writeCharacteristic Unknown error; B013 then reports disconnected. B012 is documented uint16 inactivity minutes, so do not label it invalid or remove it without firmware evidence.
- Root cause unresolved: need same-device Android comparison and timestamps/native Windows HRESULT. Current native catch-all suppresses WinRT error details; current reader continues after transport failure until disconnect event/three failures.
- Next diagnostic change should stop a snapshot on the first transport error, record timestamp/model/firmware/native HRESULT, and compare against pre-1.5.4 retention behavior. Avoid blind command retries, configuration writes or claiming a fix from CI alone. Scan suspension on return also needs recovery review.
- User asked whether Android succeeds on this same tracker; answer pending.

## Windows 1.5.5 — Livestock regression follow-up (2026-11-03)
- Same tracker reads completely on Android (confirmed by user). Windows-specific investigation; this does not prove which native/driver operation is faulty.
- Roll back 1.5.4 MaintainConnection/session injection, including previously modified dependency caches. Keep explicit scan hold; resume device scanning after returning/failing once disconnected.
- Space Livestock commands by at least 200 ms after the previous exchange. Abort automatic snapshot on FIRST exchange error, without sending subsequent queries or retrying writes.
- Diagnostics include relative timestamps, selected device, firmware/region info when read, link loss, and the original Windows HRESULT for failed native writes instead of catch-all Unknown error.
- Added regression: failure at B012 must not send B013 or special queries. Existing automatic read/write/readback tests retained.
- Android unchanged: currently working. Shared error-stop/diagnostic improvements pending assessment for next Android release. Windows-specific delay/WinRT rollback not automatically copied.
- Released: windows-1.5.5-build.8, commit 8bfe031382f17a9f83fd79d340ef4a89a4ff0f49, workflow 41623010275. 76 Flutter tests and 5 decoder vectors passed; installation and launch verified in CI. Installer SHA256: 1fa4133365784b24a93c1170ef1d2496aea3d000055a6fe2453e0f7a169ed027. Real-device stability not verified.

## Prossimo upgrade Android e Windows — assistenza sugli errori di connettività (in attesa)
Solo in caso di errore di connessione già rilevato o disconnessione inattesa, indicare come usare «Copia diagnostico» nell’app, anche dopo la caduta del collegamento, e come incollare il report in una mail a alessandro.paperi@lansitec.com. Descrivere il sintomo osservato senza attribuire cause non verificate. Nessun avviso per annullamento o disconnessione volontaria, nessun nuovo controllo in background, passaggio obbligatorio o invio automatico. Prima del rilascio verificare che il report destinato al supporto non esponga password. Stato: pianificato per entrambe le piattaforme, non implementato.

## Android and Windows 1.6.0+26 — device Log & Debug (2026-11-05)
- Requirement: show the firmware Log and Debug characteristic as UTF-8 with timestamps, matching the supplied LightBlue examples, on both platforms.
- Shared files: lib/modules/guided/log_debug_page.dart, device_setup_page.dart, lorawan_setup_page.dart, livestock_setup_page.dart. Cellular mapping verified against GATT cat1.txt (FF16) and gatt nbiot.txt (FF15); LoRa mapping FF86 retained from supplied GATT tracker document. Never use a cellular reboot characteristic as the log.
- Explicit entry from device setup; live notification subscription only while this screen is open, Read again, start/stop, Clear, Copy diagnostics. Last 500 received messages retained in memory, UI updates at most four times/second, no polling/configuration writes. Page-owned notifications cleaned up; pre-existing subscriptions preserved. Logs remain visible/copiable after link loss. Firmware determines available output; there is no invented status or diagnosis. Raw UTF-8 is shown, including firmware-specific content; labelled credential lines are omitted from copied log reports, not a guarantee of anonymization of arbitrary firmware output.
- Support guidance: existing connection failure offers Copy diagnostics and the support email; unexpected connection loss shows dismissible instructions. No email is sent. Deliberate leave/cancel/reboot does not trigger this hint. Existing cellular diagnostic traces do not contain network field values; labelled secret lines are additionally filtered. Configuration JSON remains a separate explicit credential-containing export.
- Shared port: Android now receives the scan-session guard/recovery and first-error-stop/timestamp diagnostics for Livestock. Windows retains its 200ms pacing, native HRESULT fix and rollback of MaintainConnection. Android native decoder, Windows decoder runtime, Bluetooth readiness, pairing and export-directory adapters preserved.
- Affected support/port files: disconnect_guard.dart, peripherals_page.dart, ble_scan_coordinator.dart; tests log_debug_test.dart, livestock_test.dart, connection_scan_hold_test.dart. Version/report strings and Windows installer updated.
- Parity review: tools/check_platform_parity.py reports zero unexplained differences. Eight manual adapters reviewed: desktop window/theme, native adapter readiness, two export pages, batch pairing, raw characteristic export, main decoder and Livestock decoder/pacing.
- Android 1.6.0+26: 80 Flutter tests and 5 decoder vectors passed, workflow 42012296739, code commit 2b0f73791f52c77865fc24ddaab3ad1e64c85053. Unsigned intermediate android-1.6.0-build.12 downloaded and SHA256 verified, then signed locally with the existing app certificate (19077dde8f7728a00d10022d798e8242305207a13a98c55131f769ab81397be9). APK v1/v2/v3 signature, alignment, package name and version verified. Installable APK: dist/android-1.6.0/Ls_BLE_Guided_1.6.0_Android.apk; the unsigned GitHub intermediate is NOT an installable release.
- Windows 1.6.0+26: 81 Flutter tests and 5 decoder vectors passed, workflow 42012286947, code commit 18c9529ef39ef80b7e67e450333308eb6fab8590. Native build, installer installation and application launch passed. Release windows-1.6.0-build.10. Downloaded installer product version 1.6.0 and SHA256 f98f8002390d866819694762774dafe1bd077bfb2708cfd12cd9a78512d32666 verified.
- Physical-device log streaming and Realtek behavior must still be checked on hardware. No new background scanning, keepalive or automatic retries were added.

## Android and Windows 1.6.1+27 — initial battery snapshot (2026-11-06)
- User capture: LoRa Livestock FFF0/FF8C Battery Level is read-only UTF-8 "85%"; FFF0/FF86 Log confirmed. Earlier Livestock code read only standard 2A19 and therefore missed this firmware field.
- Shared battery_info.dart reads the verified Livestock field, standard 180F/2A19 (one byte 0–100), or a read-only proprietary field explicitly described by 2901 as Battery Level/Battery Percentage with textual percentage 0–100. No voltage conversion, arbitrary-byte percentage, unknown default or write. FF8C retains its advertising-interval meaning in the legacy LoRa map; not globally relabelled.
- Discovery remains automatic through discoverServices. Optional self-describing battery lookup is serial, limited to four descriptor reads (one-second timeout each), without retry/background work, to bound startup cost. Descriptions outside that budget or absent/ambiguous/unsupported values may remain unavailable. No claim of complete proprietary-protocol understanding from UUID discovery.
- Integrated into the existing initial/manual snapshots for cellular, LoRaWAN, Livestock and beacon pages, with Battery row and clearing on disconnection. Protocol documentation missing/conflicting meanings recorded here/chat, not shown as diagnostic theories in the UI.
- Files: lib/modules/guided/battery_info.dart, device_setup_page.dart, lorawan_setup_page.dart, livestock_setup_page.dart, beacon_snapshot.dart; test/guided/battery_info_test.dart; version strings, workflows, Windows installer. Existing Log & Debug and Windows timing/native adapter unchanged.
- Android 1.6.1+27: 85 Flutter tests + 5 decoder vectors passed; workflow 42175952501, commit 3497a05d2f380c72c5cd5a3361c6aa27b59272de. Intermediate android-1.6.1-build.13 downloaded and both ZIP/APK hashes checked. Signed locally with the existing certificate; v1/v2/v3 signature, zip alignment, package identity and versionCode 27/versionName 1.6.1 verified. Installable: dist/android-1.6.1/Ls_BLE_Guided_1.6.1_Android.apk.
- Windows 1.6.1+27: 86 Flutter tests + 5 decoder vectors passed; workflow 42175923218, commit ff4ac7c6ef581059f3ba66ddf8f295ba14bd8239. Compilation, installer installation and app launch passed. Release windows-1.6.1-build.11. Downloaded installer version 1.6.1 verified; SHA256 08620e5dc34e3a400f77d341e585ed3486d71ca0b860c16d418c44f4a87c0f69.
- Parity: zero unexplained differences; eight existing adapters retained (desktop theme, readiness, export directories, batch pairing, raw GATT export, decoder runtime and Windows Livestock pacing). Physical device readings still require hardware verification.

## Android and Windows 1.6.2+28 — mail feedback, 2026-11-16
- Source: Re update2 GNSS position received Re Re Tracker Testing.msg and attached analysis. Verified vendor instruction mqtts:// + port 8883 and customer report that prefix was not retained. Exact TLS root cause and motion-only GNSS configuration remain unconfirmed; no automatic diagnosis or motion preset added.
- Both source trees: allow explicit mqtts:// address, retain separate port validation and existing write/readback comparison; describe that storage is not a TLS connection. Added heartbeat/GNSS and model-specific sequence-number guidance, and layered connectivity investigation/report instructions without speculative classifiers or background operations.
- Files: mqtt_address.dart, device_setup_page.dart, help_page.dart. Android 87 Flutter tests and Windows 88 Flutter tests passed, plus 5 decoder vectors each. Workflows Android 43795891186 / Windows 43795883865 passed. Windows installation and application startup verified in CI. Final code commits: Android d8a8d11f99da7732416effa47c15d8edd6c9dc55; Windows 3abd0c350506c5127fb5ff0c65258520e23ec5dd. Artifacts: windows-1.6.2-build.13 and Android unsigned intermediate android-1.6.2-build.15 (local signing required).

- Product scope: cellular changes shared across all supported Cat-1 and NB-IoT/LTE-M tracker/gateway profiles. LoRaWAN setup and Livestock setup additionally expose collapsed transport-specific reporting guidance; no cellular MQTT/TLS writes applied to LoRaWAN or beacons. Existing beacon guidance preserved. Zero unreviewed platform differences; existing platform adapters unchanged. No real-device TLS or motion-only GNSS behavior claimed verified.
- Download verification: Windows installer SHA256 f86c86c85736c79acda18c0693f0775f47cb637299b4ee4d629438c9102ae0c5 and product version 1.6.2 confirmed. Android intermediate ZIP/APK hashes checked; signed APK identity/version 1.6.2+28, v1/v2/v3 signatures and alignment verified with existing certificate. Installable: dist/android-1.6.2/Ls_BLE_Guided_1.6.2_Android.apk.

## Security/privacy preparation — 2026-11-17, NOT RELEASED
- Scope EU/USA, Lansitec, contact alessandro.paperi@lansitec.com. See SECURITY_PRIVACY_REVIEW.md for evidence, unresolved requirements and release gates.
- Shared source changes: text_styles.dart, go_router.dart, dio_client.dart, remote_page.dart. Android manifest backup/cleartext hardening. Tests/builds still pending, delivered app remains 1.6.2.

## Offline support operating model — 2026-11-17 (pending release)
- Requirement: no remotely managed online service; diagnostics only by voluntary normal email to app contact.
- Both Android and Windows: replace Remote request UI with local Support instructions, remove server endpoint/client registration; retain internal route for compatibility.
- Files: lib/modules/remote/remote_page.dart, lib/modules/main/main_page.dart, lib/locator.dart, lib/constants/app_constants.dart, test/guided/privacy_remote_test.dart; SECURITY_PRIVACY_REVIEW.md records user-confirmed handling/access and unresolved retention/entity verification.
- Android and Windows version: still 1.6.2 working trees; NOT shipped. Shared changes identical; parity checked separately. Flutter test/build of this revision pending, no new artifacts.
- No BLE transport, pacing, scan order or configuration protocol changes. This does not establish complete privacy compliance or guarantee removal of sensitive data from existing reports.

## 1.6.3 security/privacy candidate — 2026-11-18 (validation in progress)
- Both targets: offline Support replaces Remote; removes endpoint and HTTP client registration. JSON support exports omit known usernames/passwords; review remains necessary for identifiers/settings. CSV exports quote/escape every field and neutralize formula prefixes. Device logs capped at 8 KiB per entry, existing row caps retained; keyword filtering extended to common credential/identifier labels. LoRa diagnostics use the same filter. Support provides local profile/nickname deletion and bundled license access.
- Android: main manifest removes Internet permission with manifest-merger override; existing no-backup/no-cleartext controls retained. Official package identity com.lansitec.bleguided is separate from guidedtest, label Ls BLE Guided; existing test install and data are not migrated or removed. Protected new local release key created outside repository; recovery backup remains an organizational gate.
- Both decoder wrappers: reject empty/odd/non-hex/oversized Livestock input even when called directly. Local deterministic Node validation: 820 malformed/random/boundary cases across four families and 5 existing Livestock vectors passed. This is not a native-engine vulnerability certification.
- CI: action commit SHAs pinned after resolving upstream tags; checkout credentials not persisted; build permission read only; no automatic publication. Windows fails rather than installing an unpinned fallback compiler. Dependency/license inventories generated with builds. Toolchain binaries/host images still require maintenance.
- Versions: Android and Windows candidate 1.6.3+29; not yet released. Initial candidate runs 44221872312 (Android), 44221881827 (Windows); follow-up needed for official Android identity and decoder boundary tests.
- Shared files: remote/main UI, locator/constants, utils/safe_export.dart, guided/device_setup_page.dart, log_debug_page.dart, lorawan_setup_page.dart, livestock_setup_page.dart, config CSV exporters, raw characteristic CSV exporter/bloc, tests privacy_remote/safe_export/decoder_security, manifests, build workflows, tools/release_inventory.py, tools/dependency-inventory.gradle, pubspec, version labels. Windows installer version updated. Exact commit file lists provide full changes.
- Eight platform adapters reviewed: blue_app and scan/home Bluetooth readiness untouched; export-directory differences retained in failed/updated/raw-detail pages; guided_page only version text; Livestock Windows 200 ms pacing and JS runtime adapter retained while both copy actions gain filtering. No BLE transport patch or configuration replay added.
- Remaining limitations: raw diagnostic text is not reliably anonymizable; device identifiers/location may remain. Hive metadata is protected by OS account/app storage, not a new app encryption layer. Physical Realtek/device testing not performed. Full native-binary provenance, recovery backup, trusted Windows publisher signing and company privacy retention/processing arrangements are not certified by this candidate.

## Final candidate validation — 2026-11-18
- Windows 1.6.3+29: code commit 9c041799522f9f0d7c3d8024843c97ddc296ec4e; workflow 44222654543; 93 Flutter tests, 820 decoder boundary cases and 5 existing decoder vectors passed. Build, installer and CI startup checks passed. Local portable startup 10 seconds passed; no TCP connection observed in that one snapshot (not a full traffic audit). All 16 packaged Windows PE binaries have ASLR/DEP flags; other hardening differs by library.
- Windows installer SHA256: 7192b943603a95f594c067d0517f002a48f58c42cbf2f5b590feaab6c2ce2bc0. Installer is NOT Authenticode-signed; no claim of trusted publisher reputation. Local: dist/windows-1.6.3-candidate/Ls_BLE_Guided_Windows_Setup.exe.
- Android 1.6.3+29: code commit bf4f3042694b9c2a13f40060d84092e99e0bd796; workflow 44223591299; 92 Flutter tests, 820 decoder boundary cases and 5 existing decoder vectors passed. Release APK built; resolved native JVM dependency graph inventory generated. Earlier runs failed only in inventory-generation code and are superseded, not reported as successful releases.
- Signed Android APK: com.lansitec.bleguided, versionCode 29. New separate app approved by user. Signature v1/v2/v3 and 16 KB zip alignment verified; signer SHA256 50ad350a6db6526fb0cd8c0cc8ad2bfc5950630307f9ede0d21d06c5275096fb. APK SHA256 5a5c33f9b4cfd05ad931d9700869ef3cab24e44a1e59d7f89f2efa6d5ca310b7. Final manifest has no INTERNET permission, no debuggable flag, allowBackup=false, usesCleartextTraffic=false. Exported profile-installer receiver requires android.permission.DUMP; startup provider is not exported. No QuickJS library packaged in Android. Installation/run on a physical Android device not performed here.
- Maven OSV: 47 resolved runtime components, no advisories matched. Pub check: Android 92 / Windows 95 hosted packages, no advisories matched. These findings do not certify Flutter engine or native C/C++ binaries.
- Current selected source scan: 285 text files, zero matches for checked high-confidence private-key/GitHub-token/AWS-ID patterns; not a full git-history or credential audit. Build inventories: Android 97 / Windows 100 total Dart components including SDK and non-hosted entries. Three Flutter SDK subpackages lack root LICENSE files but Flutter's BSD license is included; complete native redistribution/provenance review remains open.
- Microsoft Defender custom scans completed for both candidate directories; zero matching threat detections with signature 1.463.349.0. Not an assurance of zero malware/vulnerabilities. Evidence stored alongside artifacts.
- Parity: zero unreviewed shared differences; eight adapters reviewed as above. No native BLE transport changes, no lost shared LoRa/automatic-read/battery/log features claimed from a version bump alone.
- Distribution state: source candidates on GitHub security-review branches; no new public official release. Connector has no release-attachment mutation, local GitHub credentials unavailable, browser navigation timed out. Installables provided locally; do not claim GitHub release assets uploaded.
- Release remains a validated CANDIDATE. Broad-distribution gates: protected signing-key recovery backup, completed corporate privacy facts/policy, native runtime/license maintenance review, physical acceptance. No certification of every advanced cybersecurity requirement is claimed.

