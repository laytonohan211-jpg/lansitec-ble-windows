import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/device_setup_page.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;

class Setting extends BluetoothCharacteristic {
  Setting(String id)
    : super(
        remoteId: const DeviceIdentifier('test-device'),
        serviceUuid: Guid('fff0'),
        characteristicUuid: Guid(id),
      );
  final values = StreamController<List<int>>.broadcast(sync: true);
  final sent = <List<int>>[], queries = <List<int>>[];
  @override
  CharacteristicProperties get properties =>
      const CharacteristicProperties(read: true, write: true);
  @override
  bool get isNotifying => false;
  @override
  Stream<List<int>> get onValueReceived => values.stream;
  @override
  Future<List<int>> read({int timeout = 15}) async =>
      sent.isEmpty ? [] : utf8.encode('Configuration success');
  @override
  Future<void> write(
    List<int> value, {
    bool withoutResponse = false,
    bool allowLongWrite = false,
    int timeout = 15,
  }) async {
    if (utf8.decode(value).startsWith('B0')) {
      queries.add(value);
      return;
    }
    sent.add(value);
  }
}

void main() {
  for (final section in ['Tracking', 'Connection']) {
    testWidgets('Cat-1 $section reboot uses dedicated FF15', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      final device = FakeDevice(),
          config = Setting('ff11'),
          reboot = Setting('ff15');
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSetupPage(
            device: device,
            services: [
              FakeService([config, reboot]),
            ],
            radioFamily: RadioFamily.cat1,
            initialModel: models[3],
            persist: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Restart device'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Restart device'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(reboot.sent.map(utf8.decode), ['00']);
      expect(config.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await device.changes.close();
      await config.values.close();
      await reboot.values.close();
    });
  }
  testWidgets('Cat-1 edit review apply confirms read response', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    final device = FakeDevice(), config = Setting('ff11');
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceSetupPage(
          device: device,
          services: [
            FakeService([config]),
          ],
          radioFamily: RadioFamily.cat1,
          initialModel: models[3],
          persist: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send heartbeat every'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3600');
    await tester.tap(find.text('Keep change'));
    await tester.pumpAndSettle();
    expect(config.sent, isEmpty);
    await tester.tap(find.textContaining('Review changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to device'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(config.sent.map(utf8.decode), ['A00100780001']);
    expect(find.textContaining('Confirmed by device'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await device.changes.close();
    await config.values.close();
  });
  testWidgets('disconnect keeps unsent changes', (tester) async {
    final device = FakeDevice(), config = Setting('ff11');
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceSetupPage(
          device: device,
          services: [
            FakeService([config]),
          ],
          radioFamily: RadioFamily.cat1,
          initialModel: models[3],
          persist: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send heartbeat every'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3600');
    await tester.tap(find.text('Keep change'));
    await tester.pumpAndSettle();
    device.connected = false;
    device.changes.add(BluetoothConnectionState.disconnected);
    await tester.pumpAndSettle();
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.textContaining('Review changes (1)'), findsOneWidget);
    expect(config.sent, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await device.changes.close();
    await config.values.close();
  });
}
