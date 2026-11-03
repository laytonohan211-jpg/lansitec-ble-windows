import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/utils/device_search.dart';
void main() {
 test('Printed Bluetooth number ignores separators and case but preserves digits', () {
  expect(matchesDeviceNumber('8f:3e-c7 81f928', ['Lck1_8F3EC781F928']), true);
  expect(matchesDeviceNumber('2768', ['Ls_LTE_Tracking_Tag_2768']), true);
  expect(matchesDeviceNumber('0012', ['Tracker_12']), false);
  expect(matchesDeviceNumber('9999', ['Tracker_2768']), false);
 });
}
