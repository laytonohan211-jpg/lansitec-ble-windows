import '../../lib/modules/guided/protocol.dart';

void main() {
  if (config(catalog[0], '86400', '1') != 'A0010B400001')
    throw StateError('heartbeat example');
  if (config(catalog[2], '1800', '1') != 'A00301680001')
    throw StateError('GNSS example');
  for (final model in models) {
    for (final p in parameters(model)) {
      for (final v
          in p.kind == 'uuid'
              ? ['F2A52D43E0AB489CB64C4A8300146720']
              : ['${p.min * p.step}', '${p.max * p.step}']) {
        describe(config(p, v, '65535'), model);
      }
    }
  }
  for (final v in ['0', '31', '1966080', 'NaN']) {
    var rejected = false;
    try {
      config(catalog[0], v, '1');
    } catch (e) {
      rejected = true;
    }
    if (!rejected) throw StateError('Accepted invalid value: $v');
  }
  print('Command examples and all ${models.length} model bounds passed');
}
