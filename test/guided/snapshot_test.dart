import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/snapshot.dart';
import 'package:flutter_blue/modules/guided/device_setup_page.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;
import 'device_setup_test.dart' show Setting;

class NetworkField extends Setting {
  NetworkField(super.id);
  int count = 0;
  @override
  Future<List<int>> read({int timeout = 15}) async {
    count++;
    return utf8.encode('internet');
  }
}

void main() {
  test(
    'timeout stops reads, without retries or overlapping requests',
    () async {
      var calls = 0;
      final r = await readSnapshotOnce(
        {
          'a': () {
            calls++;
            return Completer<List<int>>().future;
          },
          'b': () async {
            calls++;
            return [1];
          },
        },
        active: () => true,
        perRead: const Duration(milliseconds: 5),
      );
      expect(calls, 1);
      expect(r.incomplete, isTrue);
    },
  );
  test('late result after disconnect is discarded', () async {
    var active = true;
    final r = await readSnapshotOnce({
      'a': () async {
        active = false;
        return [1];
      },
    }, active: () => active);
    expect(r.values, isEmpty);
  });
  for (final variant in ['ack', 'changed', 'cached']) {
    test('tracking query only accepts typed values; $variant', () async {
      final stream = StreamController<List<int>>.broadcast();
      final sent = <String>[];
      final value = [0x60, 3, 0x16, 0x80];
      final r = await queryTrackingOnce(
        model: models[4],
        maxBytes: 220,
        requestedIds: [3],
        settle: Duration.zero,
        nextId: () => 1,
        write: (cmd) async {
          sent.add(cmd);
        },
        read:
            () async =>
                variant == 'ack'
                    ? [...utf8.encode('Configurate Success'), 0]
                    : value,
        notifications: stream.stream,
        notify: (_) async {},
        canNotify: false,
        alreadyNotifying: false,
        active: () => true,
        baseline: variant == 'cached' ? value : [],
      );
      expect(sent.length, 1);
      expect(sent.single.startsWith('B0'), isTrue);
      if (variant == 'ack') {
        expect(r.values, isEmpty);
      } else {
        expect(r.values[3], '1680');
        expect(r.fresh.contains(3), variant == 'changed');
      }
      await stream.close();
    });
  }
  test(
    'customer FF11 capture: separate queries, ASCII reply and scaled heartbeat',
    () async {
      final sent = <String>[];
      var response = '';
      final r = await queryTrackingOnce(
        model: models[4],
        maxBytes: 20,
        nextId: () => 99,
        requestedIds: [1, 3],
        settle: Duration.zero,
        write: (cmd) async {
          sent.add(cmd);
          response = cmd == 'B0010000' ? '60010B40' : '600321C0';
        },
        read: () async => utf8.encode(response),
        notifications: const Stream.empty(),
        notify: (_) async {},
        canNotify: false,
        alreadyNotifying: false,
        active: () => true,
      );
      expect(sent, ['B0010000', 'B0030000']);
      expect(r.values, {1: '0B40', 3: '21C0'});
      expect(
        parameters(models[4]).firstWhere((p) => p.id == 1).display('0B40'),
        contains('86400'),
      );
    },
  );
  testWidgets(
    'initial network read once; navigation cached; manual refresh rereads',
    (tester) async {
      final d = FakeDevice(), c = NetworkField('ff0d');
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
      expect(c.count, 1);
      await tester.tap(find.text('SIM & network'));
      await tester.pumpAndSettle();
      expect(find.text('internet'), findsOneWidget);
      expect(c.count, 1);
      await tester.tap(find.byTooltip('Read current settings'));
      await tester.pumpAndSettle();
      expect(c.count, 2);
      await tester.pumpWidget(const SizedBox());
      await d.changes.close();
      await c.values.close();
    },
  );
}
