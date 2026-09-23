import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/ble_scan_coordinator.dart';

class ConnectionReadiness extends StatefulWidget {
  final Widget child;
  const ConnectionReadiness({super.key, required this.child});
  @override
  State<ConnectionReadiness> createState() => _ConnectionReadinessState();
}

class _ConnectionReadinessState extends State<ConnectionReadiness>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('lansitec/connection');
  StreamSubscription<BluetoothAdapterState>? adapterSubscription;
  bool loading = true,
      working = false,
      allowed = false,
      location = false,
      bluetooth = false;
  int sdk = 0;
  bool autoScanStarted = false;
  String error = '';
  bool get ready => allowed && location && bluetooth;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => bluetooth = state == BluetoothAdapterState.on);
        if (!bluetooth) autoScanStarted = false;
        startWhenReady();
      }
    });
    check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !working) check();
  }

  void startWhenReady() {
    if (!mounted || !ready || autoScanStarted) return;
    autoScanStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !ready) {
        autoScanStarted = false;
        return;
      }
      try {
        await BleScanCoordinator.instance.start(
          BleScanCoordinator.devicesOwner,
        );
      } catch (_) {
        autoScanStarted = false;
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Scan could not start. Check permissions and tap Start Scan.',
              ),
            ),
          );
      }
    });
  }

  Future<void> check() async {
    try {
      bool permissions;
      bool enabled;
      if (Platform.isAndroid) {
        final info =
            await channel.invokeMapMethod<String, dynamic>('status') ?? {};
        sdk = info['sdk'] as int? ?? 0;
        enabled = info['location'] == true;
        permissions = await Permission.locationWhenInUse.isGranted;
        if (sdk >= 31) {
          permissions =
              permissions &&
              await Permission.bluetoothScan.isGranted &&
              await Permission.bluetoothConnect.isGranted;
        }
      } else if (Platform.isWindows) {
        enabled = true;
        permissions = true;
      } else {
        enabled = true;
        permissions = await Permission.bluetooth.isGranted;
      }
      if (mounted)
        setState(() {
          allowed = permissions;
          location = enabled;
          loading = false;
        });
      startWhenReady();
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Could not check settings: $e';
        });
    }
  }

  Future<void> enable() async {
    setState(() {
      working = true;
      error = '';
    });
    try {
      if (Platform.isWindows) {
        await openConnectionSettings();
        await check();
        return;
      }
      final required =
          Platform.isAndroid
              ? [
                Permission.locationWhenInUse,
                if (sdk >= 31) ...[
                  Permission.bluetoothScan,
                  Permission.bluetoothConnect,
                ],
              ]
              : [Permission.bluetooth];
      final results = await required.request();
      if (results.values.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
        await openAppSettings();
        return;
      }
      if (results.values.any((s) => !s.isGranted)) {
        if (mounted)
          setState(
            () =>
                error =
                    'Permission was not granted. Tap Enable and continue to try again, or use App settings.',
          );
        return;
      }
      await check();
      if (!bluetooth) {
        if (Platform.isAndroid) {
          // Android displays its own consent dialog; the user remains in control.
          await FlutterBluePlus.turnOn();
          await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 15));
        } else {
          await openAppSettings();
          return;
        }
      }
      if (Platform.isAndroid && !location) {
        await channel.invokeMethod('locationSettings');
        return;
      }
      await check();
      startWhenReady();
    } catch (e) {
      if (mounted)
        setState(
          () =>
              error =
                  'Setup was not completed. Enable Bluetooth and Location in Settings, then return here.',
        );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> openConnectionSettings() async {
    if (Platform.isWindows) {
      // Fixed system URI; no device/user data is interpolated into a shell.
      await Process.run('explorer.exe', ['ms-settings:bluetooth']);
    } else {
      await openAppSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    adapterSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (ready) return widget.child;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.bluetooth_searching, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Prepare your connection',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            Platform.isAndroid
                ? 'Enable Bluetooth and Location to find nearby devices. Android will ask for permission.'
                : Platform.isWindows
                ? 'Enable Bluetooth in Windows Settings. If a device requires a PIN, pair it there first.'
                : 'Enable Bluetooth and allow this app to use it. On iPhone: Settings → Bluetooth; then Settings → Privacy & Security → Bluetooth.',
          ),
          for (final entry
              in {
                if (!Platform.isWindows) 'Permissions': allowed,
                'Bluetooth': bluetooth,
                if (Platform.isAndroid) 'Location / GPS services': location,
              }.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.value ? Icons.check_circle : Icons.info_outline,
                color: entry.value ? Colors.green : Colors.orange,
              ),
              title: Text(entry.key),
              trailing: Text(entry.value ? 'Ready' : 'Required'),
            ),
          FilledButton(
            onPressed: working ? null : enable,
            child: Text(
              Platform.isWindows
                  ? 'Open Bluetooth settings'
                  : 'Enable and continue',
            ),
          ),
          if (!Platform.isWindows)
            TextButton(
              onPressed: working ? null : openConnectionSettings,
              child: const Text('App settings'),
            ),
          if (Platform.isAndroid)
            TextButton(
              onPressed:
                  working
                      ? null
                      : () async {
                        await channel.invokeMethod('locationSettings');
                      },
              child: const Text('Location settings'),
            ),
          TextButton(
            onPressed: working ? null : check,
            child: const Text('Check again'),
          ),
          if (working) const LinearProgressIndicator(),
          if (error.isNotEmpty) Text(error),
          const SizedBox(height: 16),
          if (Platform.isAndroid)
            const Text(
              'If needed on Android: Settings → Bluetooth → On; Settings → Location → On. In app permissions allow Nearby devices and Location while using the app. Names vary by phone.',
            ),
          const SizedBox(height: 8),
          if (!Platform.isWindows)
            const Text(
              'Pairing is separate from connecting. If your beacon requires a PIN, use Pair on its setup page and enter the PIN supplied with the device.',
            ),
        ],
      ),
    );
  }
}
