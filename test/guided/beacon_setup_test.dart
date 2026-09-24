import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/beacon_snapshot.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;

class BeaconInterval extends BluetoothCharacteristic {
  BeaconInterval(this.accept)
    : super(
        remoteId: const DeviceIdentifier('test-device'),
        serviceUuid: Guid('fff0'),
        characteristicUuid: Guid('fff8'),
      );
  final bool accept;
  List<int> stored = [5, 0, 0, 0];
  final sent = <List<int>>[];
  int reads = 0;
  @override
  CharacteristicProperties get properties =>
      const CharacteristicProperties(read: true, write: true);
  @override
  Future<List<int>> read({int timeout = 15}) async {
    reads++;
    return List.of(stored);
  }

  @override
  Future<void> write(
    List<int> value, {
    bool withoutResponse = false,
    bool allowLongWrite = false,
    int timeout = 15,
  }) async {
    sent.add(List.of(value));
    if (accept) stored = List.of(value);
  }
}

class UnreadableBeaconField extends BluetoothCharacteristic {
  UnreadableBeaconField(String id) : super(
    remoteId: const DeviceIdentifier('test-device'),
    serviceUuid: Guid('fff0'), characteristicUuid: Guid(id));
  @override
  CharacteristicProperties get properties => const CharacteristicProperties(read: true);
  @override
  Future<List<int>> read({int timeout = 15}) async => throw StateError('Access denied');
}

void main() {
  testWidgets('unreadable fields do not stop automatic beacon snapshot', (tester) async {
    final d = FakeDevice(), interval = BeaconInterval(true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: BeaconSnapshot(device: d, services: [FakeService([
        UnreadableBeaconField('fff5'), UnreadableBeaconField('fff6'), interval,
      ])]),
    ))));
    await tester.pumpAndSettle();
    expect(interval.reads, 1);
    expect(interval.sent, isEmpty);
    expect(find.text('500 ms'), findsOneWidget);
    expect(find.textContaining('2 unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await d.changes.close();
  });
  for (final accept in [true, false]) {
    testWidgets('beacon numeric Apply and readback; accept=$accept', (
      tester,
    ) async {
      final d = FakeDevice(), c = BeaconInterval(accept);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeaconSnapshot(
                device: d,
                services: [
                  FakeService([c]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('500 ms'), findsOneWidget);
      expect(c.reads, 1);
      expect(find.textContaining('(hex)'), findsNothing);
      await tester.tap(find.text('Broadcast interval'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(c.sent, [
        [10, 0, 0, 0],
      ]);
      expect(c.reads, 2);
      expect(find.text(accept ? '1000 ms' : '500 ms'), findsOneWidget);
      expect(
        find.text(
          accept
              ? 'Value verified. Disconnect when finished to save.'
              : 'Read value differs. Change not verified.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await d.changes.close();
    });
  }
}
