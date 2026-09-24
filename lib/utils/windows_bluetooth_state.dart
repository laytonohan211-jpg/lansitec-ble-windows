import 'package:flutter/services.dart';

/// Query WinRT instead of FlutterBluePlus.adapterState's cached first value.
/// flutter_blue_plus_winrt 0.0.18 does not emit radio StateChanged events.
Future<bool> readWindowsBluetoothEnabled() async {
  final response = await const MethodChannel('flutter_blue_plus/methods')
      .invokeMapMethod<String, dynamic>('getAdapterState')
      .timeout(const Duration(seconds: 5));
  if (response == null || response['adapter_state'] is! int) {
    throw StateError('Windows did not return the Bluetooth adapter state.');
  }
  return response['adapter_state'] == 4;
}
