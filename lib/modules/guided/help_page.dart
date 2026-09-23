import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const beaconModels = [
  'B002',
  'B003',
  'B006',
  'B010',
  'B014',
  'i5',
  'i3+',
  'B005',
  'Legacy beacon (guide 1.04)',
];
const beaconInstructions = {
  'B002':
      'Hold the button for 3 seconds to switch on. Look for LS_Beacon_Vx.x. The manual requires a connection PIN; factory PIN: 116321. Connect promptly after switching on.',
  'B003':
      'Long-press the button to switch on; the red LED flashes 10 times. The documented name is LS_Beacon_V96. Factory connection PIN: 116321.',
  'B006':
      'Hold the button for 3 seconds to switch on; the LED flashes 10 times. The documented name is LS_Beacon_V96. Factory connection PIN: 116321.',
  'B010':
      'Connect the beacon to its power source. It switches on automatically. The documented name is B010_V10. Factory connection PIN: 116321.',
  'B014':
      'Hold the magnet against the switch area for 3 seconds; the LED flashes 10 times (manual section 3.1). The documented name is LS_Beacon_V96. Factory connection PIN: 116321.',
  'i5':
      'Long-press the button to switch on. Connect within 1 minute of power-on; otherwise restart the beacon and scan again. The manual shows the LS_Beacon_V8.3 name.',
  'i3+':
      'Remove the plastic battery isolation tab to switch on. A green light flashes in the first minute. Connect to LS_Beacon_V8.3 within that minute; otherwise restart the beacon.',
  'B005':
      'Press the switch to switch on. A green light flashes in the first minute. Connect to LS_Beacon_V8.3 within that minute; otherwise restart the beacon.',
  'Legacy beacon (guide 1.04)':
      'For part numbers 100-02195, 100-02386 and 100-02395: open the enclosure as documented and turn on the switch. A white light flashes. Connect to iBeacon_xxxxxx within 1 minute; otherwise restart it.',
};
const beaconSources = {
  'B002': 'B002 Beacon Label User Manual v1.5, sections 3 and 5',
  'B003': 'B003 Beacon User Manual v4.0, sections 3 and 5',
  'B006': 'B006 Badge Beacon User Manual v1.3, sections 3 and 5',
  'B010': 'B010 Beacon User Manual v1.1, configuration section',
  'B014': 'B014 Flex Tag User Manual v2.0, sections 3 and 5',
  'i5': 'i5 Beacon User Manual v1.2, sections 3 and 5',
  'i3+': 'Bluetooth Beacon User Manual v1.4, sections 3 and 5',
  'B005': 'Bluetooth Beacon User Manual v1.4, sections 3 and 5',
  'Legacy beacon (guide 1.04)': 'How to configure a Bluetooth beacon v1.04',
};

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('User guide'),
        bottom: const TabBar(
          tabs: [Tab(text: 'Trackers & gateways'), Tab(text: 'Beacons')],
        ),
      ),
      body: const TabBarView(
        children: [
          TrackerGuide(),
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: BeaconGuide(),
          ),
        ],
      ),
    ),
  );
}

class TrackerGuide extends StatelessWidget {
  const TrackerGuide({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      for (final entry
          in const {
            '1. Prepare your phone':
                'Open Devices. Tap Enable and continue if shown. Allow the requested permissions and enable Bluetooth and Location services. If Android opens Settings, enable the requested setting and return to the app.',
            '2. Connect':
                'Power on the tracker and keep it nearby. Tap Start Scan if needed, then select its name. Check the identifier to avoid connecting to a neighbouring unit. Complete any pairing request using the device PIN.',
            '3. Check the model':
                'The app opens Device setup and uses the device name and published GATT profile to select the model. Use ⋮ → Change model if necessary. If identification is ambiguous, choose the exact model printed on the device.',
            '4. Configure the network':
                'Open SIM & network. Tap a field to read it before editing. For NB-IoT/LTE-M, select LTE-RAT, scan order and the bands supplied by your operator. Cat-1 does not expose those radio fields. Enter the APN and any username, password and authentication method supplied with the SIM.',
            '5. Configure MQTT':
                'Open MQTT server. Enter the broker hostname or IP, port, unique client ID, credentials and publish/subscribe topics supplied by your platform. The broker address is a hostname or IP, not a web-page URL. Tap Keep change, then Review changes → Apply to device. Do not enable a TLS-only broker unless the device firmware has already been provisioned appropriately; SSL is not configured by this screen.',
            '6. Change tracking parameters':
                'Open Tracking, choose a parameter and enter an ordinary value or select a switch. Choose seconds, minutes or hours where offered. Tap Keep change, then Review changes → Apply to device. Advanced editing lets you change the generated hex before sending; invalid commands are blocked.',
            '7. Verify the result':
                'Success response received means the device returned a success message; it does not verify the saved value. Confirmed by device means a fresh acknowledgement was received. Value verified means the returned parameter matches. Rejected means failure; no confirmation leaves the outcome unknown. Network fields are read back and compared where supported; this does not prove the mobile network or MQTT connection is working.',
            '8. Check connectivity':
                'Open Connection → Read network status after applying settings. Use Restart device if required by your firmware. Read IMEI, IMSI or CCID to identify the device and SIM. Reconnect after reboot. Verify that the server receives a new uplink; if it does not, check SIM service, coverage, APN and MQTT credentials.',
            '9. Read device response':
                'Open ⋮ → Advanced tools → Read configuration response. Saved parameters appear only if returned by the firmware; a generic success response does not contain them.',
            '10. Decode or use MQTT':
                'Open ⋮ → Advanced tools → MQTT queries & decoder to decode offline. Paste an uplink for the selected model. Queries and actions labelled for MQTT must be copied to your existing MQTT server; they are not sent over Bluetooth by this app.',
            '11. Disconnect':
                'Use ⋮ → Disconnect device or go Back. Choose Disconnect to leave, or Stay connected to cancel. Unsent changes are discarded only after confirmation.',
            'Troubleshooting':
                'If the device is missing, move closer, check power and restart scanning. If disconnected, tap Reconnect; unsent changes stay in the form. A disabled field was not found in the connected device profile. If the model cannot be identified, confirm the label and firmware with Lansitec; do not select a different model just to unlock a command.',
          }.entries) ...[
        Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(entry.value),
        const SizedBox(height: 18),
      ],
      const Text(
        'This APK is for Android. On iPhone, use a compatible BLE app such as LightBlue and the relevant Lansitec manual. Enable Bluetooth in Settings and permit Bluetooth access for that app. This APK cannot be installed on iPhone.',
      ),
    ],
  );
}

class BeaconGuide extends StatefulWidget {
  final String? initialModel;
  const BeaconGuide({super.key, this.initialModel});
  @override
  State<BeaconGuide> createState() => _BeaconGuideState();
}

class _BeaconGuideState extends State<BeaconGuide> {
  late String? model =
      beaconModels.contains(widget.initialModel) ? widget.initialModel : null;
  String interval = '500', generated = '', error = '';
  int power = 0;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        value: model,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Select beacon model',
          border: OutlineInputBorder(),
        ),
        items:
            beaconModels
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
        onChanged: (m) => setState(() => model = m),
      ),
      const SizedBox(height: 12),
      const Text(
        'The nRF52810 GATT profile identifies beacon parameters automatically. An explicit model in the device name is preselected; you can change it. For a shared LS_Beacon name, select the model from its label.',
      ),
      if (model != null) ...[
        const SizedBox(height: 16),
        Text(
          '1. Power on and connect',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(beaconInstructions[model]!),
        const SizedBox(height: 8),
        const Text(
          'In Devices, scan and tap the beacon. On its Beacon setup page, use Pair if a PIN is required, and complete the Android pairing dialog. Use your assigned PIN if it differs from the factory value. If pairing fails, check the PIN and restart the beacon before retrying.',
        ),
        const SizedBox(height: 16),
        Text(
          '2. Read before changing',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Open Manual beacon parameters, select the characteristic identified in your model documentation (for example Major, Minor, UUID, TX_power or Interval). If only UUIDs are shown and you cannot identify the field, stop and ask Lansitec for its mapping. Do not try arbitrary characteristics. Choose Hex in the encoding menu and read the current value; keep a copy.',
        ),
        const SizedBox(height: 16),
        Text(
          '3. Write and verify',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Tap Write new value, enter or paste the documented hex and confirm. Read the field again and compare. Return with Back after editing, then leave the device page to disconnect. Reconnect and read again to verify persistence: the manuals require exiting configuration to save. A Bluetooth write acknowledgment alone is not proof that the setting was saved.',
        ),
        const SizedBox(height: 16),
        Text(
          '4. Prepare common values',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'These helpers prepare values only. You still choose the correct characteristic and write manually. UUID uses 16 bytes; preserve the format and byte order in your model manual. Major/Minor must also follow the documented byte order.',
        ),
        TextFormField(
          initialValue: interval,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Advertisement interval (100–10000 ms, step 100)',
          ),
          onChanged:
              (s) => setState(() {
                interval = s;
                generated = '';
              }),
        ),
        OutlinedButton(
          onPressed: () {
            final ms = int.tryParse(interval);
            setState(() {
              if (ms == null || ms < 100 || ms > 10000 || ms % 100 != 0) {
                error = 'Use 100–10000 milliseconds in steps of 100.';
                generated = '';
              } else {
                error = '';
                generated =
                    '${(ms ~/ 100).toRadixString(16).padLeft(2, '0')}000000'
                        .toUpperCase();
              }
            });
          },
          child: const Text('Create interval value'),
        ),
        DropdownButtonFormField<int>(
          value: power,
          decoration: const InputDecoration(labelText: 'TX power (dBm)'),
          items:
              [-20, -16, -12, -8, -4, 0, 4]
                  .map((p) => DropdownMenuItem(value: p, child: Text('$p dBm')))
                  .toList(),
          onChanged:
              (p) => setState(() {
                power = p!;
                generated = '';
              }),
        ),
        OutlinedButton(
          onPressed:
              () => setState(() {
                error = '';
                generated =
                    ((power + 20) ~/ 4 + 1)
                        .toRadixString(16)
                        .padLeft(2, '0')
                        .toUpperCase();
              }),
          child: const Text('Create TX power value'),
        ),
        if (generated.isNotEmpty)
          Row(
            children: [
              Expanded(child: SelectableText(generated)),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: generated));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Copied. Select the matching beacon characteristic before writing.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Copy'),
              ),
            ],
          ),
        if (error.isNotEmpty) Text(error),
        if (model != 'B010' && model != 'Legacy beacon (guide 1.04)')
          const Text(
            'Battery Level Advert: 00 = off, 01 = on. Use only if the corresponding characteristic is present.',
          ),
        if (['B002', 'B006', 'i5'].contains(model))
          const Text(
            'No Movement 24h Advert: 00 = off, 01 = on; applies only in autonomous mode.',
          ),
        if (model == 'i5')
          const Text(
            'i5 motion settings: G-sensor thld 00 = periodic. Values 10–7F select autonomous mode (16 mg per unit; 01–0F reserved). Advert time: 0000 = continuous, 001E–FFFF = 30–65535 seconds; 0001–001D reserved. These apply only to versions with a motion sensor.',
          ),
        const SizedBox(height: 16),
        Text('Reference: ${beaconSources[model]}.'),
        const Text(
          'On iPhone: enable Bluetooth and allow LightBlue Bluetooth access, then follow the same model-specific power-on, pairing, write and exit steps using the manual. This Android APK is not an iPhone app.',
        ),
      ],
    ],
  );
}
