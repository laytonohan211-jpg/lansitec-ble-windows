class Parameter {
  final int id, width, min, max;
  final num step;
  final String name, kind;
  const Parameter(
    this.id,
    this.name,
    this.width, {
    this.min = 0,
    this.max = 255,
    this.step = 1,
    this.kind = 'seconds',
  });
  String encode(String value) {
    if (kind == 'uuid') {
      final h = cleanHex(value);
      if (h.length != 32) {
        throw FormatException('Enter a 16-byte UUID (32 hexadecimal digits).');
      }
      return h;
    }
    final v = double.tryParse(value);
    if (v == null ||
        !v.isFinite ||
        (v / step - (v / step).round()).abs() > 0.0000001) {
      throw FormatException(
        'Use a multiple of $step ${kind == 'seconds' ? 'seconds' : 'units'}.',
      );
    }
    final raw = (v / step).round();
    if (raw < min || raw > max) {
      throw FormatException('Allowed range: ${min * step}–${max * step}.');
    }
    return raw.toRadixString(16).padLeft(width * 2, '0').toUpperCase();
  }

  String display(String h) {
    if (kind == 'uuid') return h;
    if (kind == 'meters') return '${int.parse(h, radix: 16) * step} meters';
    final n = int.parse(h, radix: 16);
    if (kind == 'toggle') return n == 1 ? 'Enabled' : 'Disabled';
    if (kind == 'mode') return ['Periodic', 'Autonomous', 'On-demand'][n];
    return '${n * step} seconds${n == 0 ? ' (off / continuous: see parameter help)' : ''}';
  }
}

const catalog = [
  Parameter(1, 'Heartbeat interval', 2, min: 1, max: 65535, step: 30),
  Parameter(2, 'BLE positioning interval', 2, max: 65535, step: 5),
  Parameter(3, 'GNSS positioning interval', 2, max: 65535, step: 5),
  Parameter(4, 'Asset reporting interval', 2, max: 65535, step: 5),
  Parameter(5, 'BLE receive duration', 1, max: 10),
  Parameter(6, 'GNSS receive duration', 1, max: 255, step: 5),
  Parameter(7, 'Asset receive duration', 1, max: 10),
  Parameter(10, 'Positioning beacon UUID', 16, kind: 'uuid'),
  Parameter(11, 'Asset beacon UUID', 16, kind: 'uuid'),
  Parameter(28, 'Tamper alarm', 1, max: 1, kind: 'toggle'),
  Parameter(32, 'Working mode', 1, max: 2, kind: 'mode'),
  Parameter(41, 'Asset management', 1, max: 1, kind: 'toggle'),
  Parameter(42, 'GNSS failure reporting', 1, max: 1, kind: 'toggle'),
  Parameter(43, 'Sort assets by signal strength', 1, max: 1, kind: 'toggle'),
  Parameter(46, 'Power button', 1, max: 1, kind: 'toggle'),
  Parameter(47, 'Network checking', 1, max: 1, kind: 'toggle'),
  Parameter(48, 'GNSS positioning', 1, max: 1, kind: 'toggle'),
  Parameter(49, 'BLE positioning', 1, max: 1, kind: 'toggle'),
];
const models = [
  'NB-IoT / LTE-M Container Tracker',
  'NB-IoT / LTE-M Badge Tracker',
  'NB-IoT / LTE-M Asset Tracker',
  'LTE Cat-1 Container Tracker',
  'LTE Cat-1 Badge Tracker',
  'LTE Cat-1 Asset Tracker',
  'LTE Cat-1 Tracking Label',
  'LTE Cat-1 Helmet Sensor',
  'LTE Cat-1 Livestock Tag',
  'LTE Cat-1 Bluetooth Gateway',
];
const helmetExtras = [
  Parameter(
    8,
    'Fall detection threshold',
    1,
    max: 10,
    step: 0.5,
    kind: 'meters',
  ),
  Parameter(12, 'Special area beacon UUID', 16, kind: 'uuid'),
  Parameter(13, 'Search beacon UUID', 16, kind: 'uuid'),
  Parameter(27, 'Search alarm', 1, max: 1, kind: 'toggle'),
  Parameter(29, 'Special area alarm', 1, max: 1, kind: 'toggle'),
  Parameter(30, 'Fall detection alarm', 1, max: 1, kind: 'toggle'),
  Parameter(31, 'SOS alarm', 1, max: 1, kind: 'toggle'),
  Parameter(44, 'Wearing detection', 1, max: 1, kind: 'toggle'),
];
List<Parameter> parameters(String model) {
  if (model.contains('Gateway')) {
    return const [
      Parameter(1, 'Heartbeat interval', 2, min: 1, max: 65535, step: 30),
      Parameter(3, 'GNSS positioning interval', 2, max: 65535, step: 5),
      Parameter(4, 'Device reporting interval', 2, max: 65535, step: 5),
      Parameter(7, 'Bluetooth receive duration', 1, max: 10),
      Parameter(41, 'BLE receiving', 1, max: 1, kind: 'toggle'),
      Parameter(
        43,
        'Sort devices by signal strength',
        1,
        max: 1,
        kind: 'toggle',
      ),
    ];
  }
  if (model.contains('Helmet')) {
    return [...catalog.where((p) => p.id != 28), ...helmetExtras];
  }
  if (model.contains('Badge') ||
      model.contains('Label') ||
      model.contains('Livestock')) {
    return catalog
        .where((p) => ![4, 7, 11, 28, 41, 43].contains(p.id))
        .toList();
  }
  return catalog;
}

String cleanHex(String value) {
  var h =
      value
          .trim()
          .replaceFirst(RegExp(r'^0x', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\s:-]'), '')
          .toUpperCase();
  if (h.isEmpty ||
      h.length.isOdd ||
      h.length > 8192 ||
      !RegExp(r'^[0-9A-F]+$').hasMatch(h)) {
    throw FormatException(
      'Enter complete hexadecimal bytes only (maximum 4096 bytes).',
    );
  }
  return h;
}

String messageId(String s) {
  final n = int.tryParse(s);
  if (n == null || n < 1 || n > 65535) {
    throw FormatException('Message ID must be 1–65535.');
  }
  return n.toRadixString(16).padLeft(4, '0').toUpperCase();
}

String config(Parameter p, String value, String id) =>
    'A0${p.id.toRadixString(16).padLeft(2, '0')}${p.encode(value)}${messageId(id)}'
        .toUpperCase();
String describe(String input, String model) {
  final h = cleanHex(input);
  if (h.length < 8) throw FormatException('Incomplete command.');
  if (!h.startsWith('B0') && int.parse(h.substring(h.length - 4), radix: 16) == 0) {
    throw FormatException('Message ID cannot be zero.');
  }
  final type = h.substring(0, 2), end = h.length - 4;
  var i = 2;
  final rows = <String>[], seen = <int>{};
  while (i < end) {
    final id = int.parse(h.substring(i, i + 2), radix: 16);
    i += 2;
    if (!seen.add(id)) throw FormatException('Duplicate parameter.');
    if (type == 'C0') {
      const names = {
        1: 'Request position',
        2: 'Request registration',
        3: 'Reboot',
        4: 'Factory reset',
      };
      if (model.contains('Gateway') && id == 1) {
        throw FormatException('Position request is not supported for gateway.');
      }
      if (!names.containsKey(id)) throw FormatException('Unknown action.');
      rows.add(names[id]!);
      continue;
    }
    if (type == 'B0' && [0, 14].contains(id)) {
      rows.add(id == 0 ? 'Query software version' : 'Query IMSI');
      continue;
    }
    final ps = parameters(model).where((p) => p.id == id);
    if (ps.isEmpty) {
      throw FormatException('Parameter not supported for this model.');
    }
    final p = ps.first;
    if (type == 'B0') {
      rows.add('Query ${p.name}');
      continue;
    }
    if (type != 'A0' || i + p.width * 2 > end) {
      throw FormatException('Invalid header or parameter length.');
    }
    final v = h.substring(i, i + p.width * 2);
    i += p.width * 2;
    p.encode(p.kind == 'uuid' ? v : '${int.parse(v, radix: 16) * p.step}');
    rows.add('${p.name}: ${p.display(v)}');
  }
  if (rows.isEmpty) throw FormatException('No parameters.');
  return '${rows.join('\n')}\nMessage ID: ${int.parse(h.substring(end), radix: 16)}';
}
