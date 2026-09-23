import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';

void main() {
  test('GATT UUID collisions are resolved by radio family', () {
    expect(gattFor(RadioFamily.nb)['ff14'], 'Reboot');
    expect(gattFor(RadioFamily.cat1)['ff14'], 'Device CCID');
    expect(gattFor(RadioFamily.nb)['ff16'], 'NetState');
    expect(gattFor(RadioFamily.cat1)['ff16'], 'Log');
    expect(gattFor(RadioFamily.cat1)['ff17'], 'NetState');
    for (final family in RadioFamily.values) {
      final uuids = gattFor(
        family,
      ).keys.map((u) => '0000$u-0000-1000-8000-00805f9b34fb');
      expect(
        detectRadio(['0000fff0-0000-1000-8000-00805f9b34fb'], uuids),
        family,
      );
    }
  });
  test('incomplete, beacon and foreign GATT cannot enable cellular writes', () {
    expect(detectRadio(['fff0'], ['fff1', 'fff2', 'fff6']), isNull);
    expect(detectRadio(['fff0'], commonGatt.keys), isNull);
    expect(detectRadio(['fe59'], gattFor(RadioFamily.nb).keys), isNull);
  });
  test('name and GATT select exact model; conflicts remain unresolved', () {
    expect(
      detectModel('Ls_NBIoT_Container_Tracker_13', RadioFamily.nb),
      'NB-IoT / LTE-M Container Tracker',
    );
    expect(
      detectModel('LS_Cat1_Badge_Tracker', RadioFamily.cat1),
      'LTE Cat-1 Badge Tracker',
    );
    expect(
      detectModel('LS_Container_Tracker', RadioFamily.cat1),
      'LTE Cat-1 Container Tracker',
    );
    expect(
      detectModel('LS_Bluetooth_Gateway', RadioFamily.cat1),
      'LTE Cat-1 Bluetooth Gateway',
    );
    expect(detectModel('LS_NBIoT_Container', RadioFamily.cat1), isNull);
    expect(detectModel('LS_Cat1_Container', RadioFamily.nb), isNull);
    expect(detectModel('LS_Beacon_V96', RadioFamily.nb), isNull);
    expect(detectModel('LS_Badge_Asset', RadioFamily.nb), isNull);
    expect(detectModel('Unknown', RadioFamily.nb), isNull);
    expect(detectModel('LS_Container', null), isNull);
    expect(beaconName('B010_V10'), isTrue);
    expect(beaconName('LS_Beacon_Gateway'), isFalse);
  });
  test('only explicit device confirmation is accepted', () {
    expect(
      configurationVerdict('Configuration success\r\n'),
      ConfigurationVerdict.success,
    );
    expect(
      configurationVerdict('configuration: FAILED\x00'),
      ConfigurationVerdict.failed,
    );
    for (final response in [
      'OK',
      'Write success',
      'A00100780001',
      '',
      'configuration success failed',
      'error: configuration success',
      'configuration suc',
    ]) {
      expect(configurationVerdict(response), isNull, reason: response);
    }
  });
}
