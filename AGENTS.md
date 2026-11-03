# Project instructions

- User environment: Windows 11, Realtek BLE adapter. The user is not a coder.
- Be strict and practical; verify source material before making claims. Minimize unnecessary user effort.
- Keep missing or contradictory protocol documentation out of the application UI; report it in chat.

## Required from the next application update onward

User request recorded on 2026-10-26:

- Leave the currently delivered application unchanged for this request. Do not rebuild or release an APK/EXE just for this note.
- In the next application update, display BLE scan results in descending RSSI order (strongest signal first; e.g. -40 dBm before -80 dBm).
- Refresh the displayed scan results and their ordering every 3 seconds, if supported by the scanning implementation. Accumulate incoming scan events between refreshes so rows do not move on every advertisement.
- Keep ordering deterministic for equal RSSI, preserve device identity and tap targets, and do not let a refresh connect to a different device from the one the user selected.
- Apply this requirement to the shared scan flow and platform-specific implementations included in future updates. This supersedes the previous 1-second display-refresh/stable-discovery-order preference.
- The purpose is to put likely nearby devices first; signal strength is not an exact distance measurement.

## Cross-platform releases (required from 2026-11-03)
- Treat Android and Windows as two targets of the same product. Before updating either, read PLATFORM_CHANGELOG.md and compare the two source trees.
- Record every change with requirement, affected files, Android status/version, Windows status/version, validation and known limitations. A version-number bump is not evidence of feature parity.
- Carry forward all previously authorized shared features when updating the other platform. Preserve platform adapters (Windows BLE state, pairing, decoder runtime and export directories).
- Do not claim a platform feature shipped until its build/tests pass and the installable artifact is verified. Record pending ports explicitly.
- Include LoRaWAN and unified profile selection in both targets. Trusstor stays excluded. Never replace an unknown setting with a default or claim firmware confirmation from a Bluetooth write alone.
