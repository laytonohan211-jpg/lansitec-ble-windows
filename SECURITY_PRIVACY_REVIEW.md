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

