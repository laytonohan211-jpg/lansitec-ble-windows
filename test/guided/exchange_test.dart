import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/feedback.dart';
import 'package:flutter_blue/modules/guided/preferences.dart';
import 'package:flutter_blue/modules/guided/protocol.dart';

void main() {
  test(
    'parameter response accepts bytes and ASCII, rejects malformed state',
    () {
      expect(parameterResponse([0x60, 1, 0, 120], models.last), {1: '0078'});
      expect(parameterResponse(utf8.encode('60010078'), models.last), {
        1: '0078',
      });
      for (final b in [
        [0x60, 1, 0],
        [0x60, 32, 9],
        [0x60, 99, 0],
        [0xA0, 1, 0, 120],
        [0x60, 1, 0, 0],
      ]) {
        expect(parameterResponse(b, models.last), isEmpty);
      }
    },
  );
  for (final mode in [
    'notify',
    'fragment',
    'read',
    'state',
    'stale',
    'echo',
    'reject',
    'disconnect',
  ]) {
    test('exchange $mode', () async {
      final notifications = StreamController<List<int>>.broadcast(sync: true),
          links = StreamController<bool>.broadcast(sync: true);
      var written = false, enabled = false;
      final result = await exchangeConfiguration(
        command: 'A00100780001',
        model: models.last,
        write: () async {
          expect(enabled, isTrue);
          written = true;
          if (mode == 'notify') notifications.add(utf8.encode('Config: OK'));
          if (mode == 'fragment') {
            notifications.add(utf8.encode('Configuration suc'));
            notifications.add(utf8.encode('cess'));
          }
          if (mode == 'reject')
            notifications.add(utf8.encode('Configuration failed'));
          if (mode == 'disconnect') links.add(false);
        },
        read:
            () async => utf8.encode(
              mode == 'stale'
                  ? 'Configuration success'
                  : !written
                  ? ''
                  : mode == 'read'
                  ? 'Configuration success'
                  : mode == 'state'
                  ? '60010078'
                  : mode == 'echo'
                  ? 'A00100780001'
                  : '',
            ),
        notifications: notifications.stream,
        connections: links.stream,
        notify: (v) async {
          enabled = v;
          if (v) notifications.add(utf8.encode('Configuration success'));
        },
        canNotify: true,
        timeout: const Duration(milliseconds: 30),
        pollEvery: const Duration(milliseconds: 5),
      );
      expect(result.outcome, switch (mode) {
        'notify' || 'fragment' || 'read' => ApplyOutcome.confirmed,
        'state' => ApplyOutcome.verified,
        'stale' => ApplyOutcome.reported,
        'reject' => ApplyOutcome.rejected,
        'disconnect' => ApplyOutcome.disconnected,
        _ => ApplyOutcome.unknown,
      });
      expect(enabled, isFalse);
      expect(notifications.hasListener, isFalse);
      expect(links.hasListener, isFalse);
      await notifications.close();
      await links.close();
    });
  }
  test('profiles exclude device identity and passwords', () {
    final p = SetupProfile(
      name: 'Warehouse',
      model: models.last,
      tracking: {1: '0078'},
      network: {
        'HostPort': '1883',
        'APN Name': 'iot',
        'APN UserPsw': 'secret',
        'MQTT UserPsw': 'secret',
        'Client id': 'unit1',
        'MQTT PubTopic': 'unit1/up',
      },
    );
    expect(p.network, {'HostPort': '1883', 'APN Name': 'iot'});
    expect(SetupProfile.fromMap(p.toMap()).tracking, {1: '0078'});
    expect(
      () => SetupProfile(
        name: 'Invalid',
        model: models.last,
        tracking: {32: 'FF'},
        network: {},
      ),
      throwsFormatException,
    );
  });
}
