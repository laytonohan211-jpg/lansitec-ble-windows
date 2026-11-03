import 'livestock_setup_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_profile.dart' show shortUuid;
import 'disconnect_guard.dart';
import 'lorawan_protocol.dart';

class LoRaSetupPage extends StatefulWidget {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  final LoRaModel? initialModel;
  const LoRaSetupPage({super.key, required this.device, required this.services, this.initialModel});
  @override
  State<LoRaSetupPage> createState() => _LoRaSetupPageState();
}

class _LoRaSetupPageState extends State<LoRaSetupPage> {
  final values = <String, String>{};
  final editors = <String, TextEditingController>{};
  StreamSubscription<BluetoothConnectionState>? connection;
  LoRaModel? model;
  bool busy = false, linked = false, confirming = false;
  String status = 'Reading available settings…';
  int generation = 0;
  Map<String, BluetoothCharacteristic> get characteristics => {
    for (final s in widget.services)
      for (final c in s.characteristics)
        if (loRaFields.containsKey(shortUuid(c.uuid.str))) shortUuid(c.uuid.str): c,
  };

  @override
  void initState() {
    super.initState();
    linked = widget.device.isConnected;
    if (widget.initialModel != null) choose(widget.initialModel);
    connection = widget.device.connectionState.listen((s) {
      if (!mounted) return;
      setState(() {
        linked = s == BluetoothConnectionState.connected;
        if (!linked) {
          generation++;
          values.clear();
          status = 'Disconnected. Reconnect to read current settings.';
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => read());
  }

  @override
  void dispose() {
    generation++;
    connection?.cancel();
    for (final c in editors.values) { c.dispose(); }
    super.dispose();
  }

  void choose(LoRaModel? next) {
    for (final c in editors.values) { c.dispose(); }
    editors.clear();
    if (next != null) {
      for (final p in loRaParameters(next)) {
        editors[p.key] = TextEditingController();
      }
      if (next == LoRaModel.container) {
        editors['uuid'] = TextEditingController();
      }
    }
    setState(() => model = next);
  }

  Future<void> read() async {
    if (!mounted || busy || !linked) return;
    final epoch = generation;
    setState(() { busy = true; values.clear(); status = 'Reading available settings…'; });
    var count = 0;
    for (final entry in characteristics.entries) {
      if (!mounted || epoch != generation) break;
      final c = entry.value;
      if (!c.properties.read || entry.key == 'ff85' || entry.key == 'ff86') {
        values[entry.key] = '—';
        continue;
      }
      String text;
      try {
        text = loRaReadValue(await c.read(timeout: 5));
        count++;
      } catch (e) {
        text = 'Read failed';
      }
      if (!mounted || epoch != generation) break;
      setState(() => values[entry.key] = text);
    }
    if (mounted) setState(() {
      busy = false;
      if (epoch == generation) status = 'Read $count fields.';
    });
  }

  Future<void> send({bool reboot = false}) async {
    if (model == null || busy || confirming || !linked) return;
    final c = characteristics['ff84'];
    if (c == null || (!c.properties.write && !c.properties.writeWithoutResponse)) return;
    String command;
    try {
      command = reboot ? loRaReboot(model!) : loRaSettings(model!, {
        for (final e in editors.entries) e.key: e.value.text,
      });
    } on FormatException catch (e) {
      setState(() => status = e.message);
      return;
    }
    confirming = true;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(reboot ? 'Reboot device?' : 'Send complete configuration?'),
      content: SingleChildScrollView(child: Text(
        '${loRaModelLabel(model!)}\n\n${reboot ? 'Bluetooth will disconnect.' : 'Apply all the settings below?\n\n${loRaParameters(model!).map((p) => '${p.label}: ${editors[p.key]!.text}').join('\n')}${editors.containsKey('uuid') ? '\nUUID: ${editors['uuid']!.text}' : ''}'}\n\nCommand: $command\n\n')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
      ],
    ));
    confirming = false;
    if (!mounted || ok != true || !linked || busy) return;
    final epoch = generation;
    setState(() { busy = true; status = 'Sending…'; });
    try {
      await c.write(loRaWire(command), withoutResponse: !c.properties.write, timeout: 8);
      if (mounted && epoch == generation) setState(() => status =
        reboot ? 'Restart requested' : c.properties.write
          ? 'Received via Bluetooth. Settings not yet verified.'
          : 'Sent. Device confirmation not received.');
    } catch (e) {
      if (mounted) setState(() => status = 'Could not confirm delivery: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if(model==LoRaModel.livestock) return LivestockSetupPage(device:widget.device,services:widget.services);
    final config = characteristics['ff84'];
    final canWrite = linked && !busy && config != null &&
        (config.properties.write || config.properties.writeWithoutResponse);
    return DisconnectGuard(connected: linked, busy: busy, child: Scaffold(
      appBar: AppBar(title: const Text('LoRaWAN setup'), actions: [
        IconButton(tooltip: 'Read current fields', onPressed: busy || !linked ? null : read, icon: const Icon(Icons.refresh)),
        IconButton(tooltip: 'Copy diagnostics', onPressed: () async {
          await Clipboard.setData(ClipboardData(text: [
            'Ls BLE Guided 1.5.5 — LoRaWAN', widget.device.platformName,
            'Selected model: ${model?.name ?? 'none'}', status,
            for (final e in characteristics.entries)
              '${e.key} ${loRaFields[e.key]} read=${e.value.properties.read} write=${e.value.properties.write} withoutResponse=${e.value.properties.writeWithoutResponse}: ${values[e.key] ?? 'not read'}',
          ].join('\n')));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Diagnostics copied')));
        }, icon: const Icon(Icons.copy)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.device.platformName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(),
        SelectableText(status),
        const SizedBox(height: 16),
        const Text('Read from device', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        for (final e in characteristics.entries)
          Card(child: ListTile(title: Text(loRaFields[e.key]!), subtitle: SelectableText(values[e.key] ?? 'Not read yet'))),
        const SizedBox(height: 16),
        const Text('Guided configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text('Select your device.'),
        const SizedBox(height: 12),
        DropdownButtonFormField<LoRaModel>(
          value: model, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Device family'),
          items: [for (final m in LoRaModel.values) DropdownMenuItem(value: m,
            child: Text(loRaModelLabel(m), overflow: TextOverflow.ellipsis))],
          onChanged: busy ? null : choose,
        ),
        if (model != null) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text(
            'New configuration — review all values before applying.')),
          for (final p in loRaParameters(model!))
            Padding(padding: const EdgeInsets.only(bottom: 14), child: TextField(
              controller: editors[p.key], enabled: !busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: p.label, helperText: '${p.min}–${p.max}; step ${p.step}'),
            )),
          if (model == LoRaModel.container) TextField(
            controller: editors['uuid'], enabled: !busy,
            decoration: const InputDecoration(labelText: 'Positioning beacon UUID'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: canWrite ? () => send() : null, child: const Text('Review and send settings')),
          OutlinedButton(onPressed: canWrite ? () => send(reboot: true) : null, child: const Text('Reboot device')),
        ],
      ]),
    ));
  }
}
