import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';

void main() {
  test('documented heartbeat and GNSS command examples', () {
    expect(config(catalog[0], '86400', '1'), 'A0010B400001');
    expect(config(catalog[2], '1800', '1'), 'A00301680001');
    expect(config(catalog[5], '300', '1'), 'A0063C0001');
  });
  test('reject invalid duration, model, edited bytes and message ID', () {
    for (final v in ['0', '31', '1966080', 'NaN']) {
      expect(() => config(catalog[0], v, '1'), throwsFormatException);
    }
    for (final h in [
      'A10100780001',
      'A00100000001',
      'A00100780000',
      'A00100780100780001',
      'A0GG0001',
      'A0010001',
    ]) {
      expect(() => describe(h, models.first), throwsFormatException);
    }
    expect(() => describe('A029010001', models[1]), throwsFormatException);
  });
  test('all model parameter bounds round trip', () {
    for (final model in models) {
      for (final p in parameters(model)) {
        for (final v
            in p.kind == 'uuid'
                ? ['F2A52D43E0AB489CB64C4A8300146720']
                : ['${p.min * p.step}', '${p.max * p.step}']) {
          expect(describe(config(p, v, '65535'), model), contains(p.name));
        }
      }
    }
  });
}
