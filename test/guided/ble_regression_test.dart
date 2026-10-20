import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/feedback.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/snapshot.dart';
import 'package:flutter_blue/utils/stable_scan_stream.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const model = 'LTE Cat-1 Badge Tracker';
  test('2026-09-24 capture: double ASCII hex yields scan duration 9', () {
    final wire = [...utf8.encode('363030353039'), ...List.filled(120, 0)];
    expect(parameterResponse(wire, model), {5: '09'});
    expect(parameterResponse([...utf8.encode('600509'), 0, 0], model), {5: '09'});
    expect(parameterResponse([0x60, 5, 0], model), {5: '00'});
    expect(parameterResponse(utf8.encode('600509\u0000BAD'), model), isEmpty);
    expect(parameterResponse(utf8.encode('6005'), model), isEmpty);
    expect(parameterResponse(utf8.encode('363030354646'), model), isEmpty);
  });
  test('tracking read accepts the captured double encoded reply', () async {
    final result = await queryTrackingOnce(
      model: model, maxBytes: 20, nextId: () => 1, requestedIds: [5],
      settle: Duration.zero,
      write: (cmd) async { expect(cmd, 'B0050000'); },
      read: () async => [...utf8.encode('363030353039'), 0, 0],
      notifications: const Stream.empty(), notify: (_) async {},
      canNotify: false, alreadyNotifying: false, active: () => true,
    );
    expect(result.values, {5: '09'});
  });
  test('partial documented beacon profile is automatic; cellular is excluded', () {
    expect(detectBeaconGatt(['fff0'], ['fff5', 'fff6', 'fff7']), isTrue);
    expect(detectBeaconGatt(['fff0'], ['fff8', 'fff9', 'fff5']), isTrue);
    expect(detectBeaconGatt(['fff0'], ['fff8']), isFalse);
    expect(detectBeaconGatt(['fff0'], ['fff5', 'fff6', 'fff7', 'ff05', 'ff11', 'ff12']), isFalse);
  });
  test('scan publishes once per second without moving existing rows', () async {
    final source = StreamController<List<(String, int)>>();
    final events = <List<(String, int)>>[];
    final first = Completer<void>(), second = Completer<void>();
    final elapsed = Stopwatch()..start();
    final sub = stableScanStream<(String, int)>(source.stream,
      id: (v) => v.$1, compareNew: (a, b) => b.$2.compareTo(a.$2),
    ).listen((items) {
      events.add(items);
      if (events.length == 1) first.complete();
      if (events.length == 2) second.complete();
    });
    addTearDown(() async { await sub.cancel(); await source.close(); });
    source.add([('A', -40), ('B', -70)]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events, isEmpty);
    await first.future.timeout(const Duration(seconds: 5));
    expect(elapsed.elapsedMilliseconds, greaterThanOrEqualTo(1000));
    expect(events.single.map((x) => x.$1), ['A', 'B']);
    source.add([('B', -30), ('A', -90), ('C', -20)]);
    await second.future.timeout(const Duration(seconds: 5));
    expect(events.last.map((x) => x.$1), ['A', 'B', 'C']);
    expect(events.last.first.$2, -90);
    source.add([('A', -50)]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(events.length, 2);
    await source.close();
  }, timeout: const Timeout(Duration(seconds: 20)));
}

