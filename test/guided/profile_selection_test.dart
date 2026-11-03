import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue/modules/guided/profile_selection.dart';
import 'package:flutter_blue/modules/guided/lorawan_protocol.dart';
import 'package:flutter_blue/modules/guided/lora_catalog_page.dart';

void main() {
  test('Models stay within their connectivity and exclude custom devices', () {
    expect(profileModels(DeviceConnectivity.beacon), contains('B003'));
    expect(profileModels(DeviceConnectivity.cat1), isNot(contains('B003')));
    expect(profileModels(DeviceConnectivity.lora), contains('LoRaWAN Livestock Tracker'));
    expect(extraLoRaModels.any((m) => m.toLowerCase().contains('trusstor')), false);
    expect(() => extraCommand('Trusstor Asset Tracker', 'Restart', {}, 1), throwsFormatException);
    expect(detectLoRaModel('LS_LoRa_Livestock_2768'), LoRaModel.livestock);
    expect(detectLoRaModel('LS_LoRa_Tracker_2768'), isNull);
    expect(detectLoRaModel('Badge_Asset'), isNull);
  });
  testWidgets('Detected profile can be overridden before any parameter read', (tester) async {
    DeviceConnectivity? selected;
    String? selectedModel;
    await tester.pumpWidget(MaterialApp(home: ProfileSelection(
      deviceName: 'Tracker', connected: true,
      initialType: DeviceConnectivity.lora,
      initialModel: 'LoRaWAN Livestock Tracker',
      onSelected: (t, m) { selected = t; selectedModel = m; },
    )));
    expect(selected, isNull);
    await tester.tap(find.text('LoRaWAN').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BLE beacon').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B003').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read current settings'));
    expect(selected, DeviceConnectivity.beacon);
    expect(selectedModel, 'B003');
  });
  testWidgets('Disconnected device cannot start reading', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileSelection(
      deviceName: 'B003', connected: false,
      initialType: DeviceConnectivity.beacon, initialModel: 'B003',
      onSelected: (_, __) => fail('Disconnected read'),
    )));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
