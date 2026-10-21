import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/lorawan_protocol.dart';
import 'package:flutter_blue/modules/guided/feedback.dart';

Map<String, String> defaults(LoRaModel m) => {
  for (final p in loRaParameters(m)) p.key: p.preset,
  'uuid': 'F2A52D43E0AB489CB64C4A8300146720',
};

void main() {
  test('Gateway documented vector: 60 s reporting, 30 min heartbeat', () {
    expect(loRaSettings(LoRaModel.gateway, {
      'heartbeat': '1800', 'ble': '60',
    }), '90000C3C');
    expect(loRaWire('90000C3C'), utf8.encode('90000C3C'));
  });
  test('Container documented vector preserves byte order and flags', () {
    final fields = defaults(LoRaModel.container)
      ..addAll({'heartbeat': '1800', 'ble': '60', 'motion': '5'});
    expect(loRaSettings(LoRaModel.container, fields),
      '9B003C000C0001F2A52D43E0AB489CB64C4A8300146720050168');
  });
  test('Badge v5.35 packet uses one-byte heartbeat and distinct ordering', () {
    expect(loRaSettings(LoRaModel.badge, defaults(LoRaModel.badge)), '9B003C016878020504');
    expect(loRaReboot(LoRaModel.badge), 'A300');
    expect(loRaReboot(LoRaModel.container), 'A300');
    expect(loRaReboot(LoRaModel.gateway), 'A30000');
  });
  test('Reject incomplete, out-of-range, fractional-unit and disabled positioning settings', () {
    for (final m in LoRaModel.values) {
      for (final p in loRaParameters(m)) {
        for (final bad in ['', '-1', '${p.max + 1}', 'abc']) {
          expect(() => loRaSettings(m, defaults(m)..[p.key] = bad), throwsFormatException);
        }
      }
      expect(() => loRaSettings(m, defaults(m)..['heartbeat'] = '31'), throwsFormatException);
    }
    expect(() => loRaSettings(LoRaModel.badge, defaults(LoRaModel.badge)
      ..addAll({'gnssOn': '0', 'bleOn': '0'})), throwsFormatException);
    expect(() => loRaSettings(LoRaModel.container, defaults(LoRaModel.container)
      ..['uuid'] = 'bad'), throwsFormatException);
  });
  test('LoRa detection accepts full UUIDs but not cellular or beacon profiles', () {
    expect(isLoRaGatt(['ff81','ff82','ff84']), isTrue);
    expect(isLoRaGatt(['0000ff81-0000-1000-8000-00805f9b34fb','ff82','ff84']), isTrue);
    expect(isLoRaGatt(['ff05','ff11','ff12']), isFalse);
    expect(isLoRaGatt(['fff5','fff6','fff7']), isFalse);
    expect(isLoRaGatt(['ff81','ff82']), isFalse);
  });
  test('Read display preserves unknown binary and does not invent units', () {
    expect(loRaReadValue([0xff,0x00]), 'Raw: FF 00');
    expect(loRaReadValue(utf8.encode('EU868\u0000')), contains('EU868'));
  });
  test('Cellular ASCII hex feedback remains supported', () {
    expect(payloadBytes(utf8.encode('600509')), [0x60, 0x05, 0x09]);
  });
}
