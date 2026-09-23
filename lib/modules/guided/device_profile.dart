// Source: Lansitec GATT For All Lansitec Devices, retrieved 2026-09-15.
import 'protocol.dart';

String shortUuid(String value) {
  final s = value.toLowerCase().replaceAll('0x', '');
  final m = RegExp(
    r'^0000([0-9a-f]{4})-0000-1000-8000-00805f9b34fb$',
  ).firstMatch(s);
  return m?.group(1) ?? s;
}

enum RadioFamily { nb, cat1 }

const commonGatt = {
  'ff05': 'HostName(URL/IP)',
  'ff06': 'HostPort',
  'ff08': 'Client id',
  'ff09': 'MQTT UserName',
  'ff0a': 'MQTT UserPsw',
  'ff0b': 'MQTT SubTopic',
  'ff0c': 'MQTT PubTopic',
  'ff0d': 'APN Name',
  'ff0e': 'APN UserName',
  'ff0f': 'APN UserPsw',
  'ff10': 'APN AuthMethod',
  'ff11': 'Configuration',
  'ff12': 'Device IMEI',
  'ff13': 'Device IMSI',
};
Map<String, String> gattFor(RadioFamily family) => {
  ...commonGatt,
  if (family == RadioFamily.nb) ...{
    'ff01': 'LTE-RAT',
    'ff02': 'RATs ScanSeq',
    'ff03': 'eMTC Band',
    'ff04': 'NB-IoT Band',
    'ff07': 'SSL',
    'ff14': 'Reboot',
    'ff15': 'Log',
    'ff16': 'NetState',
    'ff17': 'DeviceRunMode',
    'ff18': 'Device CCID',
  } else ...{
    'ff14': 'Device CCID',
    'ff15': 'Reboot',
    'ff16': 'Log',
    'ff17': 'NetState',
    'ff18': 'DeviceRunMode',
    'ff19': 'ModuleSwitch',
  },
};

RadioFamily? detectRadio(
  Iterable<String> services,
  Iterable<String> characteristics,
) {
  if (!services.map(shortUuid).contains('fff0')) return null;
  final ids = characteristics.map(shortUuid).toSet();
  if (!ids.containsAll(['ff05', 'ff11', 'ff12'])) return null;
  if (ids.contains('ff01') && ids.contains('ff04')) return RadioFamily.nb;
  if (ids.contains('ff19') && !ids.contains('ff01')) return RadioFamily.cat1;
  // Cat-1 firmware may omit ModuleSwitch. Require its entire published core.
  if (!ids.contains('ff01') &&
      !ids.contains('ff04') &&
      ids.containsAll([
        ...commonGatt.keys,
        'ff14',
        'ff15',
        'ff16',
        'ff17',
        'ff18',
      ])) {
    return RadioFamily.cat1;
  }
  return null;
}

bool beaconName(String name) {
  if (RegExp(r'tracker|gateway', caseSensitive: false).hasMatch(name)) {
    return false;
  }
  return RegExp(
    r'beacon|\bb00[2356]\b|\bb010\b|\bb014\b',
    caseSensitive: false,
  ).hasMatch(name.replaceAll('_', ' '));
}

String? detectModel(String name, RadioFamily? family) {
  if (family == null || beaconName(name)) return null;
  final n = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  if (family == RadioFamily.nb && (n.contains('cat1') || n.contains('4g'))) {
    return null;
  }
  if (family == RadioFamily.cat1 &&
      (n.contains('nbiot') || n.contains('ltem') || n.contains('emtc'))) {
    return null;
  }
  final candidates = <String>[];
  for (final entry
      in {
        'container': 'Container Tracker',
        'badge': 'Badge Tracker',
        'asset': 'Asset Tracker',
        'label': 'Tracking Label',
        'helmet': 'Helmet Sensor',
        'livestock': 'Livestock Tag',
        'gateway': 'Bluetooth Gateway',
      }.entries) {
    if (n.contains(entry.key)) {
      candidates.add(
        '${family == RadioFamily.nb ? 'NB-IoT / LTE-M' : 'LTE Cat-1'} ${entry.value}',
      );
    }
  }
  return candidates.length == 1 && models.contains(candidates.single)
      ? candidates.single
      : null;
}

// Only explicit device verdicts are accepted. A Bluetooth ACK or command echo
// does not prove that firmware applied the setting.
enum ConfigurationVerdict { success, failed }

ConfigurationVerdict? configurationVerdict(String response) {
  final s = response.replaceAll('\u0000', '').trim().toLowerCase();
  if (RegExp(r'^configuration\s*[:=]?\s*(failed|failure)[.!]?$').hasMatch(s)) {
    return ConfigurationVerdict.failed;
  }
  if (RegExp(
    r'^configuration\s*[:=]?\s*(success|successful)[.!]?$',
  ).hasMatch(s)) {
    return ConfigurationVerdict.success;
  }
  return null;
}

// Source: supplied Beacon_Service_ID_and_Characteristic_ID.xlsx, Sheet1.
// This is a shared nRF52810 profile, not a unique product/model identifier.
const beaconGatt = {
  'fff5': 'UUID',
  'fff6': 'MAJOR',
  'fff7': 'MINOR',
  'fff8': 'INTERVAL',
  'fff9': 'TX_POWER',
  'fffa': 'BEACON RSSI AT 1M',
  'fffb': 'Complete Local Name',
  'fffc': 'Accelerometer THLD',
  'ffe1': 'Fast advertising in range',
  'ffe2': 'SOS button enable',
  'ffe3': '3-axis Acc full scale',
  'ffe5': 'Namespace ID',
  'ffe6': 'Instance ID',
  'ffe7': 'Multi-type broadcast select',
  'ffe8': 'URL scheme prefix',
  'ffe9': 'URL',
  'ffeb': 'FreeFall high set',
  'ffec': 'Clear tamper data',
  'ffea': 'Passkey',
};

bool detectBeaconGatt(
  Iterable<String> services,
  Iterable<String> characteristics,
) {
  if (!services.map(shortUuid).contains('fff0')) return false;
  final ids = characteristics.map(shortUuid).toSet();
  // Require the five core beacon fields together; FFF0 alone is also used by LTE.
  // Cellular evidence takes precedence over a shared or mixed profile.
  return !ids.containsAll(['ff05', 'ff11', 'ff12']) &&
      ids.containsAll(['fff5', 'fff6', 'fff7', 'fff8', 'fff9']);
}

String? detectBeaconModel(String name) {
  if (RegExp(r'tracker|gateway', caseSensitive: false).hasMatch(name))
    return null;
  final matches =
      RegExp(
        r'(?:^|[^a-z0-9])(b002|b003|b005|b006|b010|b014|i5|i3\+)(?=$|[^a-z0-9])',
        caseSensitive: false,
      ).allMatches(name).map((m) => m.group(1)!.toLowerCase()).toSet();
  if (matches.length != 1) return null;
  final model = matches.single;
  return model.startsWith('b') ? model.toUpperCase() : model;
}
