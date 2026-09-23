import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'feedback.dart';
import 'protocol.dart';
import 'guided_page.dart';

class DeviceToolsPage extends StatefulWidget {
  final BluetoothDevice device;
  final String? model;
  final bool canRead;
  final Future<List<int>> Function() read;
  const DeviceToolsPage({
    super.key,
    required this.device,
    required this.model,
    required this.canRead,
    required this.read,
  });
  @override
  State<DeviceToolsPage> createState() => _DeviceToolsPageState();
}

class _DeviceToolsPageState extends State<DeviceToolsPage> {
  StreamSubscription<BluetoothConnectionState>? subscription;
  bool busy = false;
  String response = '', error = '';
  Map<int, String> values = {};
  @override
  void initState() {
    super.initState();
    subscription = widget.device.connectionState.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> read() async {
    setState(() {
      busy = true;
      error = '';
      response = '';
      values = {};
    });
    try {
      final bytes = await widget.read();
      if (!mounted) return;
      setState(() {
        response =
            utf8
                .decode(bytes, allowMalformed: true)
                .replaceAll('\u0000', '')
                .trim();
        values =
            widget.model == null ? {} : parameterResponse(bytes, widget.model!);
        if (response.isEmpty) response = 'Empty response';
      });
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Device tools')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.model ?? widget.device.platformName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          widget.device.isConnected
              ? 'Bluetooth connected'
              : 'Bluetooth disconnected',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed:
              busy || !widget.device.isConnected || !widget.canRead
                  ? null
                  : read,
          icon: const Icon(Icons.download),
          label: const Text('Read configuration response'),
        ),
        if (!widget.canRead)
          const Text(
            'This firmware does not expose a readable Configuration characteristic.',
          ),
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Colors.deepOrange)),
        if (response.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    values.isNotEmpty
                        ? 'Saved parameter values'
                        : explicitVerdict(response) == true
                        ? 'Device response: Success'
                        : explicitVerdict(response) == false
                        ? 'Device response: Failed'
                        : 'Device response',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (values.isEmpty && explicitVerdict(response) != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'The device returned an acknowledgement, not saved parameter values.',
                      ),
                    ),
                  for (final e in values.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${parameters(widget.model!).where((p) => p.id == e.key).isEmpty ? 'Parameter ${e.key}' : parameters(widget.model!).firstWhere((p) => p.id == e.key).name}: ${parameters(widget.model!).where((p) => p.id == e.key).isEmpty ? e.value : parameters(widget.model!).firstWhere((p) => p.id == e.key).display(e.value)}',
                      ),
                    ),
                  ExpansionTile(
                    title: const Text('Raw response'),
                    children: [SelectableText(response)],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        ListTile(
          title: const Text('MQTT queries & decoder'),
          subtitle: const Text(
            'Generate payloads to send through your MQTT server.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap:
              busy
                  ? null
                  : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuidedPage(initialModel: widget.model),
                    ),
                  ),
        ),
      ],
    ),
  );
}
