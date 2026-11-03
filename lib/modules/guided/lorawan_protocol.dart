import 'dart:convert';
import 'device_profile.dart' show shortUuid;

// Sources: user-supplied GATT ID for LoRaWAN Trackers.jpg; Container
// Payload Specification 990-00121; Badge/Asset datasheet v5.35;
// LoRaWAN Bluetooth Gateway Payload Specification, sections 4.2/4.3.
enum LoRaModel { gateway, badge, asset, container, flex, label, helmet, livestock }
LoRaModel loRaLayout(LoRaModel m) => [LoRaModel.asset, LoRaModel.flex, LoRaModel.label].contains(m) ? LoRaModel.badge : m;

const loRaFields = {
  'ff81': 'Region', 'ff82': 'Band', 'ff83': 'Frequency (Hz)',
  'ff84': 'Configuration', 'ff85': 'Reboot', 'ff86': 'Message log',
  'ff87': 'Network state', 'ff88': 'Run mode', 'ff89': 'Advertising UUID',
  'ff8a': 'Advertising major', 'ff8b': 'Advertising minor',
  'ff8c': 'Advertising interval', 'ff8d': 'Advertising TX power',
};

bool isLoRaGatt(Iterable<String> ids) =>
    ids.map(shortUuid).toSet().containsAll(['ff81', 'ff82', 'ff84']);

String loRaModelLabel(LoRaModel model) => switch (model) {
  LoRaModel.gateway => 'LoRaWAN Bluetooth Gateway',
  LoRaModel.badge => 'LoRaWAN Badge Tracker',
  LoRaModel.asset => 'LoRaWAN Asset Management Tracker',
  LoRaModel.flex => 'LoRaWAN Flex Tracker',
  LoRaModel.label => 'LoRaWAN Tracking Label',
  LoRaModel.helmet => 'LoRaWAN Helmet Sensor',
  LoRaModel.livestock => 'LoRaWAN Livestock Tracker',
  LoRaModel.container => 'LoRaWAN Container Tracker',
};

class LoRaParameter {
  final String key, label, preset;
  final int max, step, min;
  const LoRaParameter(this.key, this.label, this.preset, this.max,
      {this.step = 1, this.min = 0});
}

List<LoRaParameter> loRaParameters(LoRaModel input) {
 final model=loRaLayout(input);
 if(model==LoRaModel.livestock) return [];
 return [
  LoRaParameter('heartbeat', 'Heartbeat (seconds)', '3600',
      model == LoRaModel.container ? 1966050 : 7650, step: 30, min: 30),
  LoRaParameter('ble', model == LoRaModel.gateway
      ? 'Report interval (seconds; 0 = off)'
      : 'Bluetooth position interval (seconds; 0 = off)', '300', 327675, step: 5),
  if (model != LoRaModel.gateway) ...[
    const LoRaParameter('gnss', 'GNSS interval (seconds; 0 = off)', '1800', 327675, step: 5),
    const LoRaParameter('mode', 'Position mode: 0 periodic, 1 autonomous, 2 on-demand', '1', 2),
    const LoRaParameter('gnssOn', 'GNSS enabled: 0 no, 1 yes', '1', 1),
    const LoRaParameter('bleOn', 'Bluetooth positioning enabled: 0 no, 1 yes', '1', 1),
  ],
  if (model == LoRaModel.badge || model == LoRaModel.helmet) ...[
    const LoRaParameter('cfm', 'Confirm every N heartbeat messages', '2', 255),
    const LoRaParameter('missed', 'Missed acknowledgements before rejoin', '5', 255),
    const LoRaParameter('fall', 'Fall threshold (units of 0.5 m; 0 = off)', '4', 10),
  ],
  if (model == LoRaModel.helmet) ...[
    const LoRaParameter('beacons', 'Maximum positioning beacons', '3', 15, min: 1),
    const LoRaParameter('switch', 'Power switch enabled: 0 no, 1 yes', '1', 1),
    const LoRaParameter('areaRssi', 'Special area signal threshold (magnitude)', '50', 255),
  ],
  if (model == LoRaModel.container) ...[
    const LoRaParameter('switch', 'Power switch enabled: 0 no, 1 yes', '1', 1),
    const LoRaParameter('div', 'Bluetooth report division', '0', 255),
    const LoRaParameter('motion', 'Motion threshold: (50 + value × 5) mg', '10', 255),
  ],
];
}

String loRaSettings(LoRaModel input, Map<String, String> fields) {
  final model=loRaLayout(input);
  if(model==LoRaModel.livestock) throw const FormatException('Select an individual Livestock setting.');
  final n = <String, int>{};
  for (final p in loRaParameters(model)) {
    final v = int.tryParse(fields[p.key]?.trim() ?? '');
    if (v == null || v < p.min || v > p.max || v % p.step != 0) {
      throw FormatException('${p.label}: enter ${p.min}–${p.max}, in steps of ${p.step}.');
    }
    n[p.key] = v;
  }
  String byte(int v) => v.toRadixString(16).padLeft(2, '0');
  String word(int v) => v.toRadixString(16).padLeft(4, '0');
  final ble = word(n['ble']! ~/ 5), hb = n['heartbeat']! ~/ 30;
  if (model == LoRaModel.gateway) return '90$ble${byte(hb)}'.toUpperCase();
  if (n['gnssOn'] == 0 && n['bleOn'] == 0) {
    throw const FormatException('Enable at least one positioning method.');
  }
  final header = 0x90 | (n['gnssOn']! << 3) | (n['mode']! << 1) |
      n[model == LoRaModel.container ? 'switch' : 'bleOn']!;
  final gnss = word(n['gnss']! ~/ 5);
  if (model == LoRaModel.helmet) {
    return '${byte(header)}${byte((n['beacons']! << 4) | (n['switch']! << 3))}${byte(n['areaRssi']!)}$ble$gnss${byte(hb)}${byte(n['cfm']!)}${byte(n['missed']!)}${byte(n['fall']!)}'.toUpperCase();
  }
  if (model == LoRaModel.badge) {
    return '${byte(header)}$ble$gnss${byte(hb)}${byte(n['cfm']!)}${byte(n['missed']!)}${byte(n['fall']!)}'.toUpperCase();
  }
  final uuid = (fields['uuid'] ?? '').replaceAll('-', '').trim();
  if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(uuid)) {
    throw const FormatException('Positioning UUID must contain 32 hexadecimal digits.');
  }
  return '${byte(header)}${word(hb)}$ble${byte(n['div']!)}${byte(n['bleOn']!)}$uuid${byte(n['motion']!)}$gnss'.toUpperCase();
}

String loRaReboot(LoRaModel model) => model == LoRaModel.livestock ? 'C003' : model == LoRaModel.gateway ? 'A30000' : 'A300';

// Configuration is an ASCII hexadecimal string carried as UTF-8, not binary.
List<int> loRaWire(String command) => utf8.encode(command);

String loRaReadValue(List<int> bytes) {
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
  try {
    final value = utf8.decode(bytes).replaceAll(RegExp(r'\x00+$'), '');
    if (value.isNotEmpty && !value.runes.any((c) => c < 32 || c == 127)) {
      return '$value\nRaw: $hex';
    }
  } catch (_) {}
  return bytes.isEmpty ? 'Empty response' : 'Raw: $hex';
}
