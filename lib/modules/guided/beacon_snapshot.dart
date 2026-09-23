import 'dart:async';
import 'package:flutter/foundation.dart';
import 'beacon_values.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_profile.dart';
import 'snapshot.dart';

class BeaconSnapshot extends StatefulWidget {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  const BeaconSnapshot({
    super.key,
    required this.device,
    required this.services,
  });
  @override
  State<BeaconSnapshot> createState() => _BeaconSnapshotState();
}

class _BeaconSnapshotState extends State<BeaconSnapshot> {
  Map<String, List<int>> values = {};
  bool busy = false, attempted = false;
  int epoch = 0;
  final editors = <TextEditingController>[];
  String status = 'Not read yet';
  StreamSubscription<BluetoothConnectionState>? link;
  @override
  void initState() {
    super.initState();
    link = widget.device.connectionState.listen((s) {
      if (!mounted) return;
      if (s == BluetoothConnectionState.disconnected) {
        epoch++;
        setState(() {
          values.clear();
          attempted = false;
          status = 'Disconnected';
        });
      } else if (s == BluetoothConnectionState.connected &&
          !attempted &&
          !busy) {
        unawaited(read());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.device.isConnected && !attempted && !busy)
        unawaited(read());
    });
  }

  @override
  void dispose() {
    epoch++;
    link?.cancel();
    for (final editor in editors) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> read() async {
    if (busy || !widget.device.isConnected) return;
    final generation = epoch;
    setState(() {
      busy = true;
      attempted = true;
      values.clear();
      status = 'Reading…';
    });
    final readers = <String, Future<List<int>> Function()>{},
        duplicates = <String>{};
    for (final s in widget.services.where(
      (s) => shortUuid(s.uuid.str) == 'fff0',
    )) {
      for (final c in s.characteristics) {
        final id = shortUuid(c.uuid.str);
        if (!beaconSettingNames.containsKey(id) ||
            id == 'ffea' ||
            id == 'ffec' ||
            !c.properties.read)
          continue;
        if (readers.containsKey(id)) duplicates.add(id);
        readers[id] = () => c.read(timeout: 2);
      }
    }
    for (final id in duplicates) {
      readers.remove(id);
    }
    final result = await readSnapshotOnce(
      readers,
      active: () => mounted && epoch == generation && widget.device.isConnected,
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      if (epoch != generation || !widget.device.isConnected) return;
      values = result.values;
      status =
          'Read ${values.length} parameters${result.incomplete ? ' · partial result' : ''}';
    });
  }

  BluetoothCharacteristic? field(String id) {
    final matches =
        widget.services
            .where((s) => shortUuid(s.uuid.str) == 'fff0')
            .expand((s) => s.characteristics)
            .where((c) => shortUuid(c.uuid.str) == id)
            .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> edit(String id) async {
    final c = field(id), old = values[id];
    if (busy || c == null || old == null || !widget.device.isConnected) return;
    final value = beaconValue(id, old);
    if (value == null) return;
    final controller = TextEditingController(text: value);
    editors.add(controller);
    String? error;
    String selection = value;
    final result = await showDialog<List<int>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, update) => AlertDialog(
                  title: Text(beaconSettingNames[id]!),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (id == 'fff9' || id == 'ff0d')
                          DropdownButtonFormField<String>(
                            value: selection,
                            items:
                                (id == 'fff9'
                                        ? beaconPower.values
                                            .map((v) => '$v')
                                            .toList()
                                        : ['Disabled', 'Enabled'])
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                          '$v ${beaconUnit(id)}'.trim(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => update(() => selection = v!),
                          )
                        else
                          TextField(
                            controller: controller,
                            autofocus: true,
                            keyboardType:
                                ['fff8', 'fff6', 'fff7'].contains(id)
                                    ? TextInputType.number
                                    : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Value',
                              suffixText: beaconUnit(id),
                              helperText:
                                  id == 'fff8'
                                      ? '100–10000 ms · steps of 100'
                                      : null,
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        try {
                          final bytes = encodeBeaconValue(
                            id,
                            ['fff9', 'ff0d'].contains(id)
                                ? selection
                                : controller.text,
                          );
                          if (bytes.length > widget.device.mtuNow - 3)
                            throw const FormatException(
                              'Value is too long for this connection.',
                            );
                          Navigator.pop(ctx, bytes);
                        } on FormatException catch (e) {
                          update(() => error = e.message);
                        }
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
          ),
    );
    // The dialog may still animate after its Future completes.
    if (result == null || !mounted || !widget.device.isConnected) return;
    final generation = epoch;
    setState(() {
      busy = true;
      status = 'Applying ${beaconSettingNames[id]}…';
    });
    var sent = false;
    try {
      await c.write(result, withoutResponse: !c.properties.write, timeout: 3);
      sent = true;
      if (!mounted || generation != epoch || !widget.device.isConnected) return;
      final back = await c.read(timeout: 3);
      if (!mounted || generation != epoch || !widget.device.isConnected) return;
      setState(() {
        values[id] = back;
        status =
            listEquals(result, back)
                ? 'Value verified. Disconnect when finished to save.'
                : 'Read value differs. Change not verified.';
      });
    } catch (_) {
      if (mounted && generation == epoch)
        setState(
          () =>
              status =
                  sent
                      ? 'Sent; verification unavailable. Refresh before retrying.'
                      : 'Write not confirmed. Check pairing and connection.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Beacon settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Read current settings',
              onPressed: busy || !widget.device.isConnected ? null : read,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(status),
        if (busy) const LinearProgressIndicator(),
        if (busy && status == 'Reading…' && widget.device.isConnected)
          Semantics(
            liveRegion: true,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Reading device settings. Please wait a few seconds…',
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final id in beaconSettingNames.keys.where(
          (id) => field(id) != null,
        ))
          Card(
            child: ListTile(
              title: Text(beaconSettingNames[id]!),
              subtitle: Text(
                values[id] == null
                    ? (busy ? 'Reading…' : 'Not read')
                    : beaconValue(id, values[id]!) == null
                    ? 'Format not supported · see advanced tools'
                    : '${beaconValue(id, values[id]!)} ${beaconUnit(id)}'
                        .trim(),
              ),
              trailing: id == 'fffa' ? null : const Icon(Icons.chevron_right),
              onTap:
                  busy ||
                          !widget.device.isConnected ||
                          values[id] == null ||
                          beaconValue(id, values[id]!) == null ||
                          id == 'fffa' ||
                          !(field(id)!.properties.write ||
                              field(id)!.properties.writeWithoutResponse)
                      ? null
                      : () => edit(id),
            ),
          ),
      ],
    ),
  );
}
