import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/lorawan_setup_page.dart';
import 'package:flutter_blue/modules/guided/lorawan_protocol.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;

class LoRaField extends BluetoothCharacteristic {
  LoRaField(String id, {this.fail = false, this.readable = true})
      : super(remoteId: const DeviceIdentifier('test-device'),
          serviceUuid: Guid('fff0'), characteristicUuid: Guid(id));
  final bool fail, readable;
  int reads = 0;
  final sent = <List<int>>[];
  @override
  CharacteristicProperties get properties =>
      CharacteristicProperties(read: readable, write: true);
  @override
  Future<List<int>> read({int timeout = 15}) async {
    reads++;
    if (fail) throw Exception('Read denied');
    return utf8.encode('EU868');
  }
  @override
  Future<void> write(List<int> value, {
    bool withoutResponse = false, bool allowLongWrite = false, int timeout = 15,
  }) async { sent.add(List.of(value)); }
}

void main() {
  testWidgets('Selected LoRa model reads automatically without inventing current settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final device = FakeDevice();
    final fields = [LoRaField('ff81'), LoRaField('ff82'), LoRaField('ff84')];
    await tester.pumpWidget(MaterialApp(home: LoRaSetupPage(
      device: device, services: [FakeService(fields)], initialModel: LoRaModel.gateway,
    )));
    await tester.pumpAndSettle();
    expect(fields.every((c) => c.reads == 1 && c.sent.isEmpty), isTrue);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.widgetList<TextField>(find.byType(TextField)).every((f) => f.controller!.text.isEmpty), isTrue);
    await tester.pumpWidget(const SizedBox());
    await device.changes.close();
  });
  testWidgets('Initial LoRa read continues after failure and never writes commands', (tester) async {
    final device = FakeDevice();
    final fields = [
      LoRaField('ff81', fail: true), LoRaField('ff82'),
      LoRaField('ff84'), LoRaField('ff85'), LoRaField('ff86'),
      LoRaField('ff87', readable: false),
    ];
    await tester.pumpWidget(MaterialApp(home: LoRaSetupPage(
      device: device, services: [FakeService(fields)],
    )));
    await tester.pumpAndSettle();
    expect(fields.map((c) => c.reads), [1,1,1,0,0,0]);
    expect(fields.every((c) => c.sent.isEmpty), isTrue);
    expect(find.textContaining('Read 2 fields'), findsOneWidget);
    expect(find.textContaining('Read failed'), findsOneWidget);
    expect(find.textContaining('Sent '), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await device.changes.close();
  });
}
