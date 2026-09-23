import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/beacon_values.dart';

void main() {
  test('documented interval and power vectors use human units', () {
    expect(beaconValue('fff8', [5, 0, 0, 0]), '500');
    expect(encodeBeaconValue('fff8', '10000'), [100, 0, 0, 0]);
    expect(beaconValue('fff9', [6]), '0');
    expect(encodeBeaconValue('fff9', '4'), [7]);
    expect(() => encodeBeaconValue('fff8', '550'), throwsFormatException);
    expect(() => encodeBeaconValue('fff9', '5'), throwsFormatException);
    expect(beaconValue('fff8', [5]), isNull);
  });
  test(
    'major example is 16, UUID round trip and unknown formats are rejected',
    () {
      expect(beaconValue('fff6', [0, 16]), '16');
      expect(encodeBeaconValue('fff7', '4660'), [0x12, 0x34]);
      const uuid = 'F2A52D43-E0AB-489C-B64C-4A8300146720';
      expect(beaconValue('fff5', encodeBeaconValue('fff5', uuid)), uuid);
      expect(() => encodeBeaconValue('fff6', '65536'), throwsFormatException);
      expect(beaconValue('fff9', [255]), isNull);
    },
  );
}
