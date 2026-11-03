import 'dart:convert';
import 'dart:typed_data';

String lsHex(Iterable<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
List<int> lsBytes(String text) {
  final h = text.replaceAll(RegExp(r'\s+|-'), '');
  if (h.isEmpty || h.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) {
    throw const FormatException('Enter valid hexadecimal data.');
  }
  return [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
}

class LivestockParameter {
  final int id, width, min, max, step;
  final String name, unit, group;
  final List<String>? choices;
  const LivestockParameter(this.id, this.name, this.width, this.max,
      {this.min = 0, this.step = 1, this.unit = '', this.group = 'Tracking', this.choices});
  List<int> encode(String text) {
    if (width == 16) {
      final b = lsBytes(text);
      if (b.length != 16) throw const FormatException('Enter a complete beacon UUID.');
      return b;
    }
    final value = int.tryParse(text.trim());
    if (value == null || value % step != 0 || value < min * step || value > max * step) {
      throw FormatException('$name: enter ${min * step}–${max * step} $unit, step $step.');
    }
    return [for (var i = width - 1; i >= 0; i--) ((value ~/ step) >> (i * 8)) & 255];
  }
  String decode(List<int> bytes) {
    if (bytes.length != width) throw const FormatException('Incomplete response');
    if (width == 16) return lsHex(bytes);
    final value = bytes.fold<int>(0, (v, b) => (v << 8) | b);
    if (value < min || value > max) throw const FormatException('Invalid response');
    return '${value * step}';
  }
  String display(String value) {
    if (choices != null) {
      final n = int.tryParse(value);
      if (n != null && n >= 0 && n < choices!.length) return choices![n];
    }
    return '$value${unit.isEmpty ? '' : ' $unit'}';
  }
}

// 990-01211 v1.2 section 5.1. Raw bounds; UI durations use real seconds.
const livestockParameters = [
  LivestockParameter(1, 'Positioning mode', 1, 2, choices: ['Periodic', 'Autonomous', 'On demand']),
  LivestockParameter(2, 'Bluetooth positioning', 1, 1, choices: ['Off', 'On']),
  LivestockParameter(3, 'GNSS positioning', 1, 1, choices: ['Off', 'On']),
  LivestockParameter(4, 'Bluetooth position interval', 2, 25920, step: 5, unit: 's'),
  LivestockParameter(5, 'GNSS position interval', 2, 25920, step: 5, unit: 's'),
  LivestockParameter(6, 'Heartbeat interval', 1, 255, min: 1, step: 30, unit: 's'),
  LivestockParameter(7, 'Confirm every N heartbeats', 1, 255, min: 1, group: 'Connection'),
  LivestockParameter(8, 'Missed acknowledgements before rejoin', 1, 255, group: 'Connection'),
  LivestockParameter(9, 'Positioning beacon UUID', 16, 0),
  LivestockParameter(10, 'Asset scanning', 1, 1, group: 'Assets', choices: ['Off', 'On']),
  LivestockParameter(11, 'Asset report interval', 2, 25920, step: 5, unit: 's', group: 'Assets'),
  LivestockParameter(13, 'Bluetooth scan duration', 1, 60, min: 1, unit: 's'),
  LivestockParameter(14, 'BLE / GNSS operation', 1, 1, choices: ['Bluetooth priority', 'Independent']),
  LivestockParameter(16, 'Motion enter threshold', 2, 4095, min: 1, unit: 'mg', group: 'Motion alarms'),
  LivestockParameter(17, 'Motion reset threshold', 2, 4094, unit: 'mg', group: 'Motion alarms'),
  LivestockParameter(18, 'Inactivity alarm delay', 2, 65535, unit: 'min', group: 'Motion alarms'),
  LivestockParameter(19, 'High-intensity enter threshold', 2, 4095, min: 1, unit: 'mg', group: 'Motion alarms'),
  LivestockParameter(20, 'High-intensity reset threshold', 2, 4094, unit: 'mg', group: 'Motion alarms'),
  LivestockParameter(21, 'High-intensity seconds', 1, 32, unit: 's', group: 'Motion alarms'),
  LivestockParameter(22, 'High-intensity time window', 1, 60, min: 1, unit: 's', group: 'Motion alarms'),
  LivestockParameter(23, 'Geofence alarm', 1, 1, group: 'Geofence', choices: ['Off', 'On']),
  LivestockParameter(32, 'Adaptive data rate', 1, 1, group: 'Radio', choices: ['Off', 'On']),
  LivestockParameter(33, 'Data rate', 1, 15, group: 'Radio'),
  LivestockParameter(34, 'Transmit power', 1, 22, unit: 'dBm', group: 'Radio'),
];

void validateLivestockRelations(int id, String value, Map<int, String> current, {bool polygon = false}) {
  final next = {...current, id: value};
  int? n(int key) => int.tryParse(next[key] ?? '');
  for (final pair in [(16,17), (19,20)]) {
    if (id == pair.$1 || id == pair.$2) {
      if (n(pair.$1) == null || n(pair.$2) == null) throw const FormatException('Read both thresholds before changing them.');
      if (n(pair.$1)! <= n(pair.$2)!) throw const FormatException('Enter threshold must exceed reset threshold.');
    }
  }
  if (id == 21 || id == 22) {
    if (n(21) == null || n(22) == null) throw const FormatException('Read the alarm duration and window first.');
    if (n(21)! > n(22)!) throw const FormatException('Alarm seconds cannot exceed the time window.');
  }
  if (id == 23 && value == '1' && !polygon) throw const FormatException('Save or read a geofence before enabling it.');
}

List<int> livestockResponse(List<int> wire) {
  if (wire.isNotEmpty && [0x6a,0x6b,0x6c,0x6d].contains(wire.first)) return wire;
  try { return lsBytes(utf8.decode(wire).replaceAll(RegExp(r'\x00+$'), '')); } catch (_) { return []; }
}

void validateAssetRule(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > 69 || bytes.first >> 4 != 1 || bytes.first & 15 == 0) {
    throw const FormatException('Invalid asset filter.');
  }
  var offset = 1, reports = false;
  final occupied = <int, Set<int>>{};
  for (var i = 0; i < (bytes.first & 15); i++) {
    if (offset + 3 > bytes.length) throw const FormatException('Incomplete asset filter.');
    final type = bytes[offset++], start = bytes[offset++], end = bytes[offset++];
    if (type < 1 || type > 4 || start > end || end > (type >= 3 ? 5 : 30)) throw const FormatException('Invalid asset range.');
    final used = occupied.putIfAbsent(type, () => {});
    for (var j = start; j <= end; j++) { if (!used.add(j)) throw const FormatException('Overlapping asset ranges.'); }
    if (type == 1 || type == 4) { offset += end - start + 1; } else { reports = true; }
    if (offset > bytes.length) throw const FormatException('Incomplete asset filter.');
  }
  if (offset != bytes.length || !reports) throw const FormatException('Select at least one report field.');
}

List<int> livestockPolygon(String text) {
  final points = <(int,int)>[];
  for (final line in text.trim().split(RegExp(r'\r?\n'))) {
    final parts = line.trim().split(RegExp(r'[,;\s]+'));
    if (parts.length != 2) throw const FormatException('Enter longitude, latitude on each line.');
    final lon = double.tryParse(parts[0]), lat = double.tryParse(parts[1]);
    if (lon == null || lat == null || !lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 90) throw const FormatException('Invalid coordinates.');
    points.add(((lon * 1e7).round(), (lat * 1e7).round()));
  }
  if (points.length < 3 || points.length > 8 || points.toSet().length != points.length) throw const FormatException('Use 3–8 different points.');
  BigInt cross((int,int) a, (int,int) b, (int,int) c) => BigInt.from(b.$1-a.$1)*BigInt.from(c.$2-a.$2)-BigInt.from(b.$2-a.$2)*BigInt.from(c.$1-a.$1);
  bool on((int,int) a, (int,int) b, (int,int) p) => cross(a,b,p)==BigInt.zero && p.$1>= (a.$1<b.$1?a.$1:b.$1) && p.$1<= (a.$1>b.$1?a.$1:b.$1) && p.$2>= (a.$2<b.$2?a.$2:b.$2) && p.$2<= (a.$2>b.$2?a.$2:b.$2);
  for (var i=0;i<points.length;i++) {
    for (var j=i+1;j<points.length;j++) {
      if(j==i+1 || (i==0 && j==points.length-1)) continue;
      final a=points[i],b=points[(i+1)%points.length],c=points[j],d=points[(j+1)%points.length];
      if ((cross(a,b,c).sign*cross(a,b,d).sign<0 && cross(c,d,a).sign*cross(c,d,b).sign<0) || on(a,b,c)||on(a,b,d)||on(c,d,a)||on(c,d,b)) throw const FormatException('Geofence edges cannot cross or touch.');
    }
  }
  var area=BigInt.zero;
  for(var i=0;i<points.length;i++){final a=points[i],b=points[(i+1)%points.length];area+=BigInt.from(a.$1)*BigInt.from(b.$2)-BigInt.from(b.$1)*BigInt.from(a.$2);}
  if(area<=BigInt.zero) throw const FormatException('List points counter-clockwise around a nonzero area.');
  final data=ByteData(points.length*8);
  for(var i=0;i<points.length;i++){data.setInt32(i*8,points[i].$1);data.setInt32(i*8+4,points[i].$2);}
  return [0xd0,points.length,...data.buffer.asUint8List()];
}

String polygonText(List<int> value) {
  if(value.isEmpty || value.length != 1+8*value.first || value.first>8) throw const FormatException('Incomplete geofence');
  if(value.first==0)return '';
  if(value.first<3)throw const FormatException('Invalid geofence');
  final d=ByteData.sublistView(Uint8List.fromList(value.sublist(1)));
  final text=[for(var i=0;i<value.first;i++) '${(d.getInt32(i*8)/1e7).toStringAsFixed(7)}, ${(d.getInt32(i*8+4)/1e7).toStringAsFixed(7)}'].join('\n');
  livestockPolygon(text);
  return text;
}
