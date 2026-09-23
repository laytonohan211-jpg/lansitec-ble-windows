import 'dart:convert';

// B003 manual 4.0 §§3.4, 3.5, 5.1 (Major 0010 = 16), shared nRF52810 GATT.
const beaconPower = {1: -20, 2: -16, 3: -12, 4: -8, 5: -4, 6: 0, 7: 4};
const beaconSettingNames = {
  'fff8': 'Broadcast interval',
  'fff9': 'Transmit power',
  'fff6': 'Major',
  'fff7': 'Minor',
  'fff5': 'Beacon UUID',
  'fffb': 'Device name',
  'fffa': 'Calibrated signal at 1 m',
  'ff0d': 'Advertise battery level',
};
String? beaconValue(String id, List<int> b) {
  if (b.isEmpty) return null;
  switch (id) {
    case 'fff8':
      if (b.length != 4) return null;
      final ticks = b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24;
      return ticks >= 1 && ticks <= 100 ? '${ticks * 100}' : null;
    case 'fff9':
      return b.length == 1 && beaconPower.containsKey(b[0])
          ? '${beaconPower[b[0]]}'
          : null;
    case 'fff6':
    case 'fff7':
      return b.length == 2 ? '${b[0] * 256 + b[1]}' : null;
    case 'fff5':
      if (b.length != 16) return null;
      final h =
          b
              .map((v) => v.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase();
      return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    case 'fffb':
      try {
        return utf8.decode(b).replaceAll('\u0000', '').trim();
      } catch (_) {
        return null;
      }
    case 'fffa':
      return b.length == 1 ? '${b[0] > 127 ? b[0] - 256 : b[0]}' : null;
    case 'ff0d':
      return b.length == 1 && b[0] <= 1
          ? (b[0] == 1 ? 'Enabled' : 'Disabled')
          : null;
  }
  return null;
}

String beaconUnit(String id) =>
    id == 'fff8'
        ? 'ms'
        : ['fff9', 'fffa'].contains(id)
        ? 'dBm'
        : '';
List<int> encodeBeaconValue(String id, String input) {
  final s = input.trim(), n = int.tryParse(input.trim());
  switch (id) {
    case 'fff8':
      if (n == null || n < 100 || n > 10000 || n % 100 != 0)
        throw const FormatException('Use 100–10000 ms, in steps of 100.');
      return [n ~/ 100, 0, 0, 0];
    case 'fff9':
      for (final e in beaconPower.entries) {
        if (e.value == n) return [e.key];
      }
      throw const FormatException('Choose a supported transmit power.');
    case 'fff6':
    case 'fff7':
      if (n == null || n < 0 || n > 65535)
        throw const FormatException('Use a number from 0 to 65535.');
      return [n >> 8, n & 255];
    case 'fff5':
      final h = s.replaceAll('-', '');
      if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(h))
        throw const FormatException('Enter a valid beacon UUID.');
      return [
        for (var i = 0; i < 32; i += 2)
          int.parse(h.substring(i, i + 2), radix: 16),
      ];
    case 'fffb':
      if (s.isEmpty || s.contains('\u0000'))
        throw const FormatException('Enter a device name.');
      return utf8.encode(s);
    case 'ff0d':
      if (s == 'Enabled') return [1];
      if (s == 'Disabled') return [0];
      throw const FormatException('Choose Enabled or Disabled.');
  }
  throw const FormatException('This setting is available in advanced tools.');
}
