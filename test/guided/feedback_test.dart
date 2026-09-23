import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/guided_page.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';

class FakeDevice extends BluetoothDevice {
  FakeDevice() : super(remoteId: const DeviceIdentifier('test-device'));
  final changes = StreamController<BluetoothConnectionState>.broadcast(
    sync: true,
  );
  bool connected = true;
  @override
  bool get isConnected => connected;
  @override
  int get mtuNow => 223;
  @override
  String get platformName => 'Ls_NBIoT_Container_Tracker_13';
  @override
  Stream<BluetoothConnectionState> get connectionState => changes.stream;
}

class FakeCharacteristic extends BluetoothCharacteristic {
  FakeCharacteristic()
    : super(
        remoteId: const DeviceIdentifier('test-device'),
        serviceUuid: Guid('fff0'),
        characteristicUuid: Guid('ff11'),
      );
  final values = StreamController<List<int>>.broadcast(sync: true);
  bool notifying = false;
  List<int>? sent;
  @override
  CharacteristicProperties get properties =>
      const CharacteristicProperties(write: true, notify: true);
  @override
  bool get isNotifying => notifying;
  @override
  Stream<List<int>> get onValueReceived => values.stream;
  @override
  Future<bool> setNotifyValue(
    bool notify, {
    int timeout = 15,
    bool forceIndications = false,
  }) async {
    notifying = notify;
    if (notify)
      values.add(utf8.encode('Configuration success')); // stale, before write
    return true;
  }

  @override
  Future<void> write(
    List<int> value, {
    bool withoutResponse = false,
    bool allowLongWrite = false,
    int timeout = 15,
  }) async {
    expect(notifying, isTrue, reason: 'Subscribe before writing');
    sent = value;
  }
}

class FakeService implements BluetoothService {
  FakeService(this.characteristics);
  @override
  final List<BluetoothCharacteristic> characteristics;
  @override
  Guid get uuid => Guid('fff0');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final outcome in ['success', 'failed', 'timeout', 'disconnect']) {
    testWidgets('device feedback: $outcome, ignoring stale success', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(480, 1500));
      final device = FakeDevice(), c = FakeCharacteristic();
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedPage(
            device: device,
            services: [
              FakeService([c]),
            ],
            radioFamily: RadioFamily.nb,
            initialModel: models.first,
          ),
        ),
      );
      final dynamic state = tester.state(find.byType(GuidedPage));
      await tester.ensureVisible(find.text('3. Create command'));
      await tester.tap(find.text('3. Create command'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('4. Send by Bluetooth'));
      await tester.tap(find.text('4. Send by Bluetooth'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        c.sent,
        isNotNull,
        reason:
            'status=${state.status}, busy=${state.busy}, notifying=${c.notifying}',
      );
      expect(utf8.decode(c.sent!), 'A00100780001');
      expect(
        find.textContaining('Waiting for device confirmation'),
        findsOneWidget,
      );
      expect(find.textContaining('confirmed by the device'), findsNothing);
      if (outcome == 'success') {
        c.values.add(utf8.encode('Configuration suc'));
        c.values.add(utf8.encode('cess\r\n'));
      } else if (outcome == 'failed') {
        c.values.add(utf8.encode('Configuration failed'));
      } else if (outcome == 'disconnect') {
        device.connected = false;
        device.changes.add(BluetoothConnectionState.disconnected);
      } else {
        c.values.add(utf8.encode('A00100780001')); // echo is not confirmation
        await tester.pump(const Duration(seconds: 11));
      }
      await tester.pump();

      await tester.pump();
      expect(
        find.textContaining(switch (outcome) {
          'success' => 'confirmed by the device',
          'failed' => 'rejected by the device',
          'disconnect' => 'disconnected before confirmation',
          _ => 'No confirmation received',
        }),
        findsOneWidget,
      );
      expect(c.values.hasListener, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.values.close();
      await device.changes.close();
    });
  }
}
