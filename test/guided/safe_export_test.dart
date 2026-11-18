import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/utils/safe_export.dart';
import 'package:flutter_blue/modules/guided/log_debug_page.dart';

void main() {
  test('device text cannot create formulas or extra CSV columns', () {
    for (final input in ['=1+1', '+cmd', '-cmd', '@SUM(A1)', ' \t=1+1']) {
      expect(csvCell(input), startsWith('"\''));
    }
    expect(csvCell('sensor,"one"\r\ntwo'), '"sensor,""one""\r\ntwo"');
    expect(csvRow(['plain', 42]), '"plain","42"\n');
  });
  test('support JSON removes credentials without changing device settings', () {
    final original = {'MQTT UserPsw':'s3cr3t', 'APN UserName':'private', 'HostPort':'8883'};
    final exported = supportNetwork(original);
    expect(exported['MQTT UserPsw'], '[omitted]');
    expect(exported['APN UserName'], '[omitted]');
    expect(exported['HostPort'], '8883');
    expect(original['MQTT UserPsw'], 's3cr3t');
  });
  test('oversized and malformed device log bytes are bounded', () {
    final entry = DeviceLogEntry(List.filled(1000000, 255));
    expect(entry.text.length, lessThan(8300));
    expect(entry.text, contains('[truncated]'));
  });
  test('credential variants and identifiers are removed from support log', () {
    final report = redactDiagnostic('App Key: abcd\nAuthorization: Bearer abc\nIMSI: 123456789012345\nAA:BB:CC:DD:EE:FF\nOnline');
    expect(report, isNot(contains('abcd')));
    expect(report, isNot(contains('Bearer abc')));
    expect(report, isNot(contains('123456789012345')));
    expect(report, isNot(contains('AA:BB:CC:DD:EE:FF')));
    expect(report, contains('Online'));
  });
}
