import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/lorawan_setup_page.dart';
import 'package:flutter_blue/modules/guided/lorawan_protocol.dart';
import 'package:flutter_blue/modules/guided/livestock_gatt.dart';
import 'feedback_test.dart' show FakeDevice, FakeService;
import 'lorawan_setup_test.dart' show LoRaField;

void main() {
  test('Livestock GATT and regional bands match latest workbook', () {
    expect(livestockInfoLabels['ff89'], 'LoRaWAN region');
    expect(livestockInfoLabels['ff8b'], 'Firmware version');
    expect(livestockInfoLabels.containsKey('ff81'), isFalse);
    expect(isLoRaGatt(['ff84','ff87','ff89','ff8a','ff8b','ff8c']), isTrue);
    expect(livestockBandMaximum('CN470'), 12);
    expect(livestockBandMaximum('US915'), 8);
    expect(livestockBandMaximum('EU868'), 0);
    expect(livestockBandInput('auto', 8), 'AUTO');
    for (final invalid in ['0','9','-1','']) {
      expect(() => livestockBandInput(invalid, 8), throwsFormatException);
    }
    expect(() => livestockBandInput('AUTO', 0), throwsFormatException);
  });
  testWidgets('Send gives visible validation, then review, then a real write', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final device = FakeDevice(), config = LoRaField('ff84');
    await tester.pumpWidget(MaterialApp(home: LoRaSetupPage(
      device: device, services: [FakeService([config])], initialModel: LoRaModel.gateway,
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review and send settings'));
    await tester.tap(find.text('Review and send settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Heartbeat (seconds): enter'), findsWidgets);
    expect(config.sent, isEmpty);
    await tester.enterText(find.byType(TextField).at(0), '1800');
    await tester.enterText(find.byType(TextField).at(1), '60');
    await tester.tap(find.text('Review and send settings'));
    await tester.pumpAndSettle();
    expect(find.text('Send complete configuration?'), findsOneWidget);
    expect(config.sent, isEmpty);
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(config.sent.map(utf8.decode), ['90000C3C']);
    expect(find.textContaining('Settings not yet verified.'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await device.changes.close();
  });
}
