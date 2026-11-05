import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue/modules/guided/log_debug_page.dart';
import 'package:flutter_blue/modules/guided/device_profile.dart';
import 'package:flutter_blue/modules/guided/disconnect_guard.dart';
import 'feedback_test.dart' show FakeDevice;

class LogCharacteristic extends BluetoothCharacteristic {
  LogCharacteristic() : super(remoteId: const DeviceIdentifier('test-device'), serviceUuid: Guid('fff0'), characteristicUuid: Guid('ff16'));
  final events = StreamController<List<int>>.broadcast(sync: true);
  final toggles = <bool>[];
  bool notifying = false;
  @override CharacteristicProperties get properties => const CharacteristicProperties(read: true, notify: true);
  @override bool get isNotifying => notifying;
  @override Stream<List<int>> get onValueReceived => events.stream;
  @override Future<bool> setNotifyValue(bool value, {int timeout = 15, bool forceIndications = false}) async {
    toggles.add(value); notifying = value; return true;
  }
  @override Future<List<int>> read({int timeout = 15}) async {
    final bytes = utf8.encode('Version(V0215),Online,3.57V(100%)');
    events.add(bytes); return bytes;
  }
}

void main() {
  test('log addresses are family-specific, never reboot', () {
    expect(gattFor(RadioFamily.cat1)['ff16'], 'Log');
    expect(gattFor(RadioFamily.nb)['ff15'], 'Log');
    expect(gattFor(RadioFamily.cat1)['ff15'], 'Reboot');
  });
  test('support export removes credential lines', () {
    expect(redactDiagnostic('Online\nMQTT UserPsw=secret\nAPN password: secret\nVersion(V0215)'),
      'Online\n[Credential line omitted]\n[Credential line omitted]\nVersion(V0215)');
  });
  testWidgets('read/notify once, copy after disconnect and stop owned subscription', (tester) async {
    final device = FakeDevice(), c = LogCharacteristic();
    String copied = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.pumpWidget(MaterialApp(home: LogDebugPage(device: device, characteristic: c)));
    await tester.pump();
    expect(c.toggles, [true]);
    await tester.tap(find.text('Read again'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Version(V0215),Online,3.57V(100%)'), findsOneWidget);
    c.events.add(utf8.encode('Device(Container_Tracker),Network(LTE)'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Stop listening')); await tester.pump();
    expect(c.toggles, [true,false]);
    device.connected = false;
    device.changes.add(BluetoothConnectionState.disconnected);
    await tester.pump();
    expect(find.text(supportInstructions), findsOneWidget);
    await tester.tap(find.byTooltip('Copy diagnostics')); await tester.pump();
    expect(copied, contains('Network(LTE)'));
    await tester.pumpWidget(const SizedBox());
    await c.events.close(); await device.changes.close();
  });
  testWidgets('closing releases owned notify but preserves an existing subscription', (tester) async {
    for (final alreadyActive in [false,true]) {
      final device=FakeDevice(), c=LogCharacteristic()..notifying=alreadyActive;
      await tester.pumpWidget(MaterialApp(home: LogDebugPage(device:device,characteristic:c)));
      await tester.pump();
      await tester.pumpWidget(const SizedBox()); await tester.pump();
      expect(c.toggles, alreadyActive ? isEmpty : [true,false]);
      await c.events.close(); await device.changes.close();
    }
  });
  testWidgets('support hint only on unexpected link loss', (tester) async {
    Widget page(bool connected, bool expected) => MaterialApp(home: DisconnectGuard(connected:connected,expectedDisconnect:expected,child:const Scaffold(body:Text('Settings'))));
    await tester.pumpWidget(page(true,false));
    await tester.pumpWidget(page(false,true));
    expect(find.textContaining(supportInstructions), findsNothing);
    await tester.pumpWidget(page(true,false));
    await tester.pumpWidget(page(false,false));
    expect(find.textContaining(supportInstructions), findsOneWidget);
  });
}
