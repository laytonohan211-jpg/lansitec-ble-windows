import 'package:hive/hive.dart';
import 'protocol.dart';

const reusableNetworkFields = {
  'LTE-RAT',
  'RATs ScanSeq',
  'eMTC Band',
  'NB-IoT Band',
  'APN Name',
  'APN AuthMethod',
  'HostName(URL/IP)',
  'HostPort',
};

class SetupProfile {
  final String name, model;
  final Map<int, String> tracking;
  final Map<String, String> network;
  SetupProfile({
    required this.name,
    required this.model,
    required Map<int, String> tracking,
    required Map<String, String> network,
  }) : tracking = Map.unmodifiable(tracking),
       network = Map.unmodifiable(
         Map.fromEntries(
           network.entries.where((e) => reusableNetworkFields.contains(e.key)),
         ),
       ) {
    if (name.trim().isEmpty || !models.contains(model))
      throw const FormatException('Invalid profile.');
    for (final e in tracking.entries) {
      final p = parameters(model).firstWhere(
        (p) => p.id == e.key,
        orElse: () => throw const FormatException('Incompatible profile.'),
      );
      if (cleanHex(e.value).length != p.width * 2)
        throw const FormatException('Invalid profile value.');
      p.encode(
        p.kind == 'uuid'
            ? e.value
            : '${int.parse(e.value, radix: 16) * p.step}',
      );
    }
  }
  Map<String, dynamic> toMap() => {
    'name': name,
    'model': model,
    'tracking': {for (final e in tracking.entries) '${e.key}': e.value},
    'network': network,
  };
  factory SetupProfile.fromMap(Map m) => SetupProfile(
    name: m['name'],
    model: m['model'],
    tracking: {
      for (final e in (m['tracking'] as Map).entries)
        int.parse('${e.key}'): '${e.value}',
    },
    network: Map<String, String>.from(m['network']),
  );
}

class GuidedPreferences {
  static Future<Box<dynamic>> box() =>
      Hive.openBox<dynamic>('guided_preferences_v1');
  static Future<List<SetupProfile>> profiles(String model) async {
    final b = await box(), out = <SetupProfile>[];
    for (final v in b.get('profiles', defaultValue: []) as List) {
      try {
        final p = SetupProfile.fromMap(Map.from(v));
        if (p.model == model) out.add(p);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> saveProfile(SetupProfile p) async {
    final b = await box(),
        values = List<dynamic>.from(
          (await box()).get('profiles', defaultValue: []) as List,
        );
    values.removeWhere(
      (v) => v is Map && v['name'] == p.name && v['model'] == p.model,
    );
    values.add(p.toMap());
    await b.put('profiles', values);
  }
}
