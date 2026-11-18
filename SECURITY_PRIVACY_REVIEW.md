# Security and privacy release assessment — IN PROGRESS

Target markets: EU and USA. Organization supplied: Lansitec. Contact: alessandro.paperi@lansitec.com.
Full legal entity and address, applicable US states/customer context and controller/processor roles require confirmation. This is not a legal compliance declaration, independent audit or release authorization.

## Verified source observations
- Local BLE scan/configuration processes device names, addresses, RSSI, configuration fields, SIM/device identifiers and potentially position-bearing payloads/logs.
- Guided reusable profiles exclude network username/password fields via an allowlist. Hive stores profiles and batch-device history without an encryption cipher in the observed openBox calls. Full storage/data-flow inventory remains pending.
- Log export masks only selected keyword-bearing lines; this is not reliable anonymization. Reports contain device names/addresses. Configuration JSON export intentionally includes network credentials and needs privacy-safe default handling.
- Remote Config explicitly performs GET /prod-api/captchaImage at https://asset.lansitec.com:8060 with the entered name. Server-side purpose, access controls, retention, hosting and international transfers have NOT been verified. Do not claim the whole application is offline or that no data leaves the device.
- UI uses GoogleFonts runtime-capable styling. Phase 1 replaces it with platform TextStyle to remove that code path without adding font downloads.
- Android currently uses guidedtest application identity and locally signed test releases. Do not silently replace signing keys: migration/update continuity needs planning.
- Pinned FlutterBluePlus 2.0.2 license in tmp/fbp/LICENSE requires a commercial license for for-profit organizations with >=50 employees worldwide. Eligibility/licensing requires company confirmation, including customer redistribution scope review.

## Phase 1 source changes (BUILT IN ISOLATED CI, NOT RELEASED)
Both platforms: no runtime GoogleFonts calls in text_styles.dart; disabled router diagnostics; HTTP verbose logger restricted to debug builds and body/header logging disabled; explicit per-request disclosure/confirmation for Remote Config; mounted guards for its asynchronous result handlers.
Android manifests: disable application backup and cleartext HTTP. Device-to-device migration behavior still needs platform testing; this flag alone is not proof against every transfer mechanism.

## Release gates still open
1. Dependency and native-component inventory/SBOM, vulnerability triage and license notices.
2. Complete storage/export/log/network inventory; sanitized export default and clear/delete controls; retention and backup behavior tests.
3. BLE malformed-input tests, size/resource limits, decoder review and regression/performance measurements on Windows Realtek and Android.
4. Build workflow immutable dependencies/minimal permissions, isolated signing secrets, protected publication and verified artifact hashes.
5. Signing/distribution decision and continuity; trusted Windows publisher signature cannot be represented by a free self-signed certificate.
6. Corporate privacy facts: legal entity/address, support mailbox handling/retention/access and server location/subprocessors; finalize notice after facts are confirmed. UE/USA alone is insufficient to assert every law applies or is met.
7. Build, test and verify both installable artifacts. Existing delivered version remains 1.6.2; no new official/security-certified release exists yet.

## Dependency check evidence, 2026-11-17
OSV querybatch against pinned hosted Pub dependencies: Android 92 packages, Windows 95 packages, no matches returned. Results: DEPENDENCY_AUDIT.json; reproducer: tools/audit_pub_dependencies.py. This does not cover native/transitive Gradle/runtime artifacts or unknown vulnerabilities.

## Isolated validation builds
Security-review branches contain phase-1 changes and remote opt-in regression test. CI publication steps removed and contents permission reduced to read. Production release branches unchanged. Runs Android 44031398734, Windows 44031389962: both completed successfully. This evidence covers phase 1 only; the later candidate requires new validation.

User confirmation 2026-11-17: Lansitec has fewer than 50 employees and already pays for BLE use in products. Do not equate unspecified BLE payments with a FlutterBluePlus commercial license. The >=50 employee trigger in the reviewed dependency license is not met according to this statement; full notices/redistribution review remains separate.

## User-confirmed operating model — 2026-11-17
- No app remote online service wanted. Removed Remote Config request implementation, its HTTP client registration and endpoint from both local source trees; navigation now displays local Support instructions. Existing /remote route retained internally for compatibility, with no request action.
- Diagnostic sharing is optional and user-initiated through normal email. Reports are retained in Lansitec company systems with other commercial correspondence; internal access is limited to Alessandro Paperi and, when necessary, his supervisors.
- Do not describe ordinary email as exempt from privacy duties, anonymous, encrypted end-to-end or automatically deleted. No retention period was supplied. Mail/database providers, processing locations and applicable transfer arrangements have not been verified.
- User supplied https://aiqicha.baidu.com/company_detail_23688837403266 ; inaccessible to research tool. Official company source https://www.lansitec.com/privacy/ and /legal/ lists Lansitec Technology Co., Ltd., Room 501, No. 21 Huashen Avenue, Nanjing, Jiangsu 210012, China. This is a website-derived candidate, not registry verification or confirmation of the app controller's full registered name.
- App contact: alessandro.paperi@lansitec.com. Support page explains copying/reviewing reports and voluntary email; does not transmit or launch email.
- Updated local test replaces superseded Remote opt-in test. New changes NOT built or released; earlier phase-1 CI results do not validate this revision.

## Phase 2 evidence and residual risk — 2026-11-18
Implementation and review detail: PLATFORM_CHANGELOG.md, 1.6.3 candidate entry. The earlier remote-server observations describe removed code, not the current local Support implementation.
- Refreshed OSV hosted-Pub check: 92 Android / 95 Windows, zero matched advisories. Native/Gradle checks separate.
- Reviewed Android decoder: only bundled allowlisted scripts; hex/length validation; WebView network/file/content loads disabled; 5-second timeout and destruction. Reviewed Windows decoder: allowlisted bundled scripts; quoted hex input <=8192 chars, XHR disabled, runtime disposed. Decoder input fuzz/boundary checks pass in Node, not proof of native engine memory safety.
- flutter_js 0.8.7 Windows package ships quickjs_c_bridge.dll. Its Windows CMake installs the bundled binary rather than downloading at build time. The archive's Android build references QuickJS CONFIG_VERSION 2020-11-08, but this does not establish the Windows DLL version or patch status. That native binary cannot be honestly marked fully audited from a Pub advisory query. Production assurance requires verified provenance/maintenance or a validated replacement.
- Storage inventory: Hive guided_preferences_v1 (allowlisted reusable network settings, profiles, nicknames), updated_devices and failed_devices (batch history). Credentials are excluded from saved profile allowlist; read configuration/logs otherwise remain in memory. User-triggered clipboard/CSV exports leave app storage and are the user's responsibility to review/delete. No new encryption/migration claim.
- Current transport support has no remote backend. Optional email handling remains outside app: access per user statement, retention/provider/processing-country facts still incomplete. Draft notice is not a compliance certification.
- References: https://mas.owasp.org/MASVS/ ; https://developer.android.com/studio/publish/app-signing . Use a control-by-control assessment; do not claim OWASP certification or immunity to malware.

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

