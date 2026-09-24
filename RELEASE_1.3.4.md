# Ls BLE Guided Windows 1.3.4

- Scan results update at most once per second. Existing devices keep their row position when RSSI changes; unnamed devices remain visible and searchable by Bluetooth address.
- Windows Bluetooth readiness queries the actual radio state when checking, returning to the app and every two seconds while active. No restart is required after enabling Bluetooth.
- FF11 readback handles both ASCII hex and the double ASCII-hex encoding captured on 2026-09-24. The captured B005 response decodes to a Bluetooth scan duration of 9 seconds. Missing values are no longer attributed to firmware without evidence.
- Beacon automatic setup also recognizes partial documented FFF0 profiles (UUID/Major/Minor, or UUID/interval/power), while excluding cellular profiles. Unknown profiles are rediscovered once on entry; a refresh and copy-diagnostics button are available.
- Beacon settings are read on entry, sequentially; an unreadable setting no longer prevents subsequent fields from loading. Known profile reads no longer compete with background descriptor reads. Supported values use normal units and writes retain readback verification.
- Windows connection no longer attempts Android bond operations or waits for Android bond state.

## Verification and limits

Regression tests cover the captured FF11 response, invalid/truncated responses, scan pacing and row stability, live Windows state reads and partial beacon detection. Existing beacon widget tests verify automatic first read, numeric editing and write/readback.

The supplied Android source and original Windows source have identical beacon snapshot, value codec and profile detection modules. No newer Android beacon implementation was available to import. For a beacon exposing a different GATT profile, its device diagnostics are still needed; unsupported characteristics are not guessed or written. Physical BLE operation and Windows radio off/on must be checked on the user's Realtek adapter.

No configuration writes are performed automatically on connection. Automatic setup means profile recognition, reading current settings and generating the documented bytes when the user applies an edit.
