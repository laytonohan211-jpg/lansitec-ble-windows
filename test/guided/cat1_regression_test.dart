import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/device_setup_page.dart';
import 'package:flutter_blue/modules/guided/device_tools_page.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/feedback.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;
import 'device_setup_test.dart' show Setting;

final realReply = [
  ...utf8.encode('Configurate Success'),
  ...List.filled(141, 0),
];

class BadgeSetting extends Setting {
  BadgeSetting() : super('ff11');
  int reads = 0;
  @override
  Future<List<int>> read({int timeout = 15}) async {
    reads++;
    return realReply;
  }
}

void main() {
  test('actual Badge firmware spelling and padding', () {
    expect(explicitVerdict(utf8.decode(realReply)), true);
    expect(explicitVerdict('Configurate Failed\u0000'), false);
    expect(explicitVerdict('Configuration success'), true);
    expect(explicitVerdict('unexpected success text'), isNull);
  });
  for (final stale in [false, true]) {
    test('Badge read response stops polling, stale=$stale', () async {
      final stream = StreamController<List<int>>.broadcast(),
          links = StreamController<bool>.broadcast();
      var written = false, reads = 0;
      final r = await exchangeConfiguration(
        command: 'A00316800001',
        model: models[4],
        write: () async {
          written = true;
        },
        read: () async {
          reads++;
          return !written && !stale ? [] : realReply;
        },
        notifications: stream.stream,
        connections: links.stream,
        notify: (_) async {},
        canNotify: false,
      );
      expect(r.outcome, stale ? ApplyOutcome.reported : ApplyOutcome.confirmed);
      expect(r.acknowledged, isTrue);
      if (stale) expect(r.verified, isFalse);
      expect(reads, 2);
      await stream.close();
      await links.close();
    });
  }
  testWidgets(
    'real reply: sent, no false timeout, not cached as measured value',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1000));
      final d = FakeDevice(), c = BadgeSetting();
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceSetupPage(
            device: d,
            services: [
              FakeService([c]),
            ],
            radioFamily: RadioFamily.cat1,
            initialModel: models[4],
            persist: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPS position every'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '28800');
      await tester.tap(find.text('Keep change'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Review changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to device'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(c.sent.map(utf8.decode), ['A00316800001']);
      expect(find.textContaining('Success response received'), findsOneWidget);
      expect(find.textContaining('Review changes ('), findsNothing);
      expect(find.textContaining('No confirmation'), findsNothing);
      expect(find.textContaining('Last sent: 8 h'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await d.changes.close();
      await c.values.close();
    },
  );
  testWidgets('device tools preserves BLE target and Read works', (
    tester,
  ) async {
    final d = FakeDevice();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceToolsPage(
          device: d,
          model: models[4],
          canRead: true,
          read: () async {
            reads++;
            return realReply;
          },
        ),
      ),
    );
    await tester.tap(find.text('Read configuration response'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('Device response: Success'), findsOneWidget);
    expect(find.textContaining('not saved parameter values'), findsOneWidget);
    expect(find.textContaining('Offline calculator'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await d.changes.close();
  });
  testWidgets('Advanced tools menu keeps the connected device', (tester) async {
    final d = FakeDevice(), c = BadgeSetting();
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceSetupPage(
          device: d,
          services: [
            FakeService([c]),
          ],
          radioFamily: RadioFamily.cat1,
          initialModel: models[4],
          persist: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced tools'));
    await tester.pumpAndSettle();
    expect(find.text('Bluetooth connected'), findsOneWidget);
    final before = c.reads;
    await tester.tap(find.text('Read configuration response'));
    await tester.pumpAndSettle();
    expect(c.reads, before + 1);
    expect(find.text('Device response: Success'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Device setup'), findsOneWidget);
    expect(find.text('Disconnect device?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await d.changes.close();
    await c.values.close();
  });
}
