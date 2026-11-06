import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_profile.dart' show shortUuid;

String? batteryPercent(List<int> bytes, {bool standard = false}) {
  if (standard) return bytes.length == 1 && bytes.first <= 100 ? '${bytes.first}%' : null;
  try {
    final text = utf8.decode(bytes).replaceAll(RegExp(r'\x00+$'), '').trim();
    final match = RegExp(r'^(\d{1,3})\s*%$').firstMatch(text);
    if (match == null) return null;
    final value = int.parse(match.group(1)!);
    return value <= 100 ? '$value%' : null;
  } catch (_) { return null; }
}

/// Read only, serialized with the caller's initial snapshot. No writes or polling.
Future<String?> readBattery(List<BluetoothService> services, {
  required bool Function() active, bool livestock = false,
}) async {
  final standard = <BluetoothCharacteristic>[];
  final custom = <BluetoothCharacteristic>[];
  for (final service in services) {
    for (final c in service.characteristics) {
      if (!c.properties.read) continue;
      if (shortUuid(service.uuid.str) == '180f' && shortUuid(c.uuid.str) == '2a19') standard.add(c);
      // User capture 2026-11-06: Livestock FFF0/FF8C returns UTF-8 "85%".
      // FF8C means advertising interval on other legacy LoRa profiles.
      if (livestock && shortUuid(service.uuid.str) == 'fff0' && shortUuid(c.uuid.str) == 'ff8c' &&
          !c.properties.write && !c.properties.writeWithoutResponse) custom.add(c);
    }
  }
  Future<String?> read(BluetoothCharacteristic c, bool binary) async {
    if (!active()) return null;
    try {
      final bytes = await c.read(timeout: 2);
      return active() ? batteryPercent(bytes, standard: binary) : null;
    } catch (_) { return null; }
  }
  if (custom.length == 1) {
    final value = await read(custom.single, false);
    if (value != null || !active()) return value;
  }
  if (standard.length == 1) {
    final value = await read(standard.single, true);
    if (value != null || !active()) return value;
  }
  // Other firmware can name its own battery characteristic through descriptor
  // 2901, as in LightBlue. Never infer a percentage from an arbitrary byte.
  // Only read-only characteristics; at most four metadata requests, no retries.
  var attempts = 0;
  for (final service in services) {
    for (final c in service.characteristics) {
      if (!c.properties.read || c.properties.write || c.properties.writeWithoutResponse) continue;
      for (final d in c.descriptors) {
        if (shortUuid(d.uuid.str) != '2901') continue;
        if (!active() || attempts++ >= 4) return null;
        try {
          final label = utf8.decode(await d.read(timeout: 1)).trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
          if (!active()) return null;
          if (label == 'batterylevel' || label == 'batterypercentage') return await read(c, false);
        } catch (_) { /* Optional descriptor absent or unreadable. */ }
      }
    }
  }
  return null;
}
