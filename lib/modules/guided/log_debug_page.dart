import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const supportInstructions = 'Use Copy diagnostics, then paste the report into an email to alessandro.paperi@lansitec.com. Describe what happened and the device model.';

String redactDiagnostic(String text) => text.split('\n').map((line) =>
  RegExp(r'password|passwd|psw|passkey|appkey|nwkskey|appskey', caseSensitive: false).hasMatch(line)
    ? '[Credential line omitted]' : line).join('\n');

class DeviceLogEntry {
  final DateTime time;
  final String text;
  DeviceLogEntry(List<int> bytes, {DateTime? time})
      : time = time ?? DateTime.now(),
        text = utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '');
  String get line => '${time.toIso8601String()}  $text';
}

/// Device output only: no configuration writes or polling.
class LogDebugPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;
  const LogDebugPage({super.key, required this.device, required this.characteristic});
  @override
  State<LogDebugPage> createState() => _LogDebugPageState();
}

class _LogDebugPageState extends State<LogDebugPage> {
  final entries = <DeviceLogEntry>[];
  StreamSubscription<List<int>>? values;
  StreamSubscription<BluetoothConnectionState>? connection;
  Timer? repaint;
  bool busy = false, listening = false, ownsNotify = false, dirty = false;
  bool closing = false;
  String error = '';
  bool get connected => widget.device.isConnected;
  BluetoothCharacteristic get c => widget.characteristic;

  @override
  void initState() {
    super.initState();
    // onValueReceived includes both notifications and explicit read responses.
    values = c.onValueReceived.listen((bytes) {
      if (bytes.isEmpty || closing) return;
      entries.add(DeviceLogEntry(bytes));
      if (entries.length > 500) entries.removeRange(0, entries.length - 500);
      dirty = true;
    }, onError: (Object e) {
      if (mounted) setState(() => error = 'Log reception failed: $e');
    });
    connection = widget.device.connectionState.listen((state) {
      if (!mounted || closing) return;
      if (state == BluetoothConnectionState.disconnected) {
        setState(() { listening = false; ownsNotify = false; error = 'Bluetooth disconnected.'; });
      }
    });
    repaint = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && dirty) setState(() => dirty = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && connected && (c.properties.notify || c.properties.indicate)) toggle();
    });
  }

  Future<void> operation(Future<void> Function() action) async {
    if (busy || !connected || closing) return;
    setState(() { busy = true; error = ''; });
    try { await action(); }
    catch (e) { if (mounted && !closing) setState(() => error = 'Bluetooth operation failed: $e'); }
    finally { if (mounted && !closing) setState(() => busy = false); }
  }

  Future<void> toggle() => operation(() async {
    if (listening) {
      if (ownsNotify) await c.setNotifyValue(false, timeout: 5);
      ownsNotify = false;
      await values?.cancel();
      values = null;
      listening = false;
    } else {
      // Restore the listener before enabling notifications to retain first output.
      values ??= c.onValueReceived.listen((bytes) {
        if (closing || bytes.isEmpty) return;
        entries.add(DeviceLogEntry(bytes));
        if (entries.length > 500) entries.removeRange(0, entries.length - 500);
        dirty = true;
      }, onError: (Object e) {
        if (mounted && !closing) setState(() => error = 'Log reception failed: $e');
      });
      if (!c.isNotifying) {
        await c.setNotifyValue(true, timeout: 5);
        ownsNotify = true;
        if (closing && connected) {
          await c.setNotifyValue(false, timeout: 5);
          ownsNotify = false;
          return;
        }
      }
      listening = true;
    }
  });

  Future<void> read() => operation(() async {
    final subscribed = values != null;
    final bytes = await c.read(timeout: 5);
    if (!subscribed && !closing) {
      entries.add(DeviceLogEntry(bytes));
      if (entries.length > 500) entries.removeAt(0);
    }
  });

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: redactDiagnostic([
      'Ls BLE Guided — Log & Debug',
      'Device: ${widget.device.platformName} (${widget.device.remoteId.str})',
      'Characteristic: ${c.uuid.str}',
      if (error.isNotEmpty) error,
      ...entries.map((e) => e.line),
    ].join('\n'))));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device log copied')));
  }

  Future<void> cleanup() async {
    if (ownsNotify && connected) {
      try { await c.setNotifyValue(false, timeout: 5); } catch (_) { /* Link may already be closed. */ }
    }
  }

  @override
  void dispose() {
    closing = true;
    repaint?.cancel();
    values?.cancel();
    connection?.cancel();
    unawaited(cleanup());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Log & Debug'), actions: [
      IconButton(tooltip: 'Copy diagnostics', onPressed: copy, icon: const Icon(Icons.copy)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.device.platformName} — ${c.uuid.str}'),
        const Text('Original device messages (UTF-8). Latest 500 messages, newest first.'),
        Wrap(spacing: 12, children: [
          OutlinedButton(onPressed: busy || !connected || !c.properties.read ? null : read, child: const Text('Read again')),
          if (c.properties.notify || c.properties.indicate)
            OutlinedButton(onPressed: busy || !connected ? null : toggle, child: Text(listening ? 'Stop listening' : 'Start listening')),
          TextButton(onPressed: () => setState(entries.clear), child: const Text('Clear')),
        ]),
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty) ...[SelectableText(error), const SelectableText(supportInstructions)],
      ])),
      Expanded(child: entries.isEmpty
        ? const Center(child: Text('No device messages received yet.'))
        : ListView.builder(itemCount: entries.length, itemBuilder: (_, index) {
            final entry = entries[entries.length - 1 - index];
            return ListTile(title: SelectableText(entry.text), subtitle: Text(entry.time.toIso8601String()));
          })),
    ]),
  );
}

Widget logDebugButton(BuildContext context, BluetoothDevice? device, BluetoothCharacteristic? characteristic, {required bool busy}) =>
  IconButton(tooltip: 'Log & Debug', icon: const Icon(Icons.receipt_long),
    onPressed: busy || device == null || characteristic == null ? null : () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => LogDebugPage(device: device, characteristic: characteristic))));
