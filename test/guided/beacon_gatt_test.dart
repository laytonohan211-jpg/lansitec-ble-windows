import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/help_page.dart';

void main() {
  test('recognizes shared beacon profile, including full UUIDs', () {
    expect(detectBeaconGatt(['fff0'], beaconGatt.keys), isTrue);
    expect(
      detectBeaconGatt(
        ['0000fff0-0000-1000-8000-00805f9b34fb'],
        [
          'FFF5',
          'FFF6',
          'FFF7',
          'FFF8',
          'FFF9',
        ].map((s) => '0000$s-0000-1000-8000-00805f9b34fb'),
      ),
      isTrue,
    );
    expect(detectBeaconGatt(['fff0'], ['fff5']), isFalse);
    expect(detectBeaconGatt(['1800'], beaconGatt.keys), isFalse);
    expect(
      detectBeaconGatt(['fff0'], [...beaconGatt.keys, 'ff05', 'ff11', 'ff12']),
      isFalse,
    );
    expect(detectRadio(['fff0'], beaconGatt.keys), isNull);
  });
  test('shared names never identify a unique model', () {
    expect(detectBeaconModel('LS_Beacon_V96'), isNull);
    expect(detectBeaconModel('LS_Beacon_V8.3'), isNull);
    expect(detectBeaconModel('B010_V10'), 'B010');
    expect(detectBeaconModel('LS_B006_Beacon'), 'B006');
    expect(detectBeaconModel('B003 B006'), isNull);
    expect(detectBeaconModel('B006 Tracker'), isNull);
    expect(detectBeaconModel('i3+ Beacon'), 'i3+');
  });
  testWidgets('detected model stays editable in beacon guide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BeaconGuide(initialModel: 'B010')),
        ),
      ),
    );
    expect(find.textContaining('B010_V10'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B003').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('LS_Beacon_V96'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
