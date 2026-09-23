import 'uplink_decoder.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'protocol.dart';
import 'device_profile.dart';
import 'help_page.dart';

class GuidedPage extends StatefulWidget {
  final BluetoothDevice? device;
  final RadioFamily? radioFamily;
  final String? initialModel;
  final List<BluetoothService> services;
  final Map<String, String?> descriptions;
  const GuidedPage({
    super.key,
    this.device,
    this.radioFamily,
    this.initialModel,
    this.services = const [],
    this.descriptions = const {},
  });
  @override
  State<GuidedPage> createState() => _GuidedPageState();
}

class _GuidedPageState extends State<GuidedPage> {
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  @override
  void initState() {
    super.initState();
    model = widget.initialModel;
    if (widget.device == null) mqtt = true;
    if (model != null) p = parameters(model!).first;
    connectionSubscription = widget.device?.connectionState.listen((_) {
      if (mounted) setState(() {});
    });
  }

  String? model;
  Parameter p = catalog.first;
  final value = TextEditingController(text: '60'),
      hex = TextEditingController(),
      mid = TextEditingController(text: '1'),
      uplink = TextEditingController();
  int unit = 60;
  String operation = 'Configure', status = '', decoded = '';
  bool busy = false, advanced = false, mqtt = false;
  bool get connected => widget.device?.isConnected ?? false;
  String norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  Map<String, BluetoothCharacteristic> get fields {
    final result = <String, BluetoothCharacteristic>{}, duplicates = <String>{};
    final family = widget.radioFamily;
    if (family == null) return result;
    final mapping = gattFor(family);
    for (final s in widget.services.where(
      (s) => shortUuid(s.uuid.str) == 'fff0',
    )) {
      for (final c in s.characteristics) {
        final name = mapping[shortUuid(c.uuid.str)];
        if (name == null) continue;
        final key = norm(name);
        if (result.containsKey(key)) duplicates.add(key);
        result[key] = c;
      }
    }
    for (final key in duplicates) {
      result.remove(key);
    }
    return result;
  }

  @override
  void dispose() {
    connectionSubscription?.cancel();
    value.dispose();
    hex.dispose();
    mid.dispose();
    uplink.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      status = '';
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => status = e.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void selectParameter(Parameter next) {
    setState(() {
      p = next;
      unit = 1;
      value.text =
          p.kind == 'uuid'
              ? 'F2A52D43E0AB489CB64C4A83001467${(p.id + 22).toRadixString(16).toUpperCase()}'
              : p.kind == 'toggle'
              ? '1'
              : p.kind == 'mode'
              ? '1'
              : p.id == 1
              ? '3600'
              : p.id == 6
              ? '180'
              : p.id >= 5
              ? '3'
              : '300';
      hex.clear();
    });
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: Text(body)),
              actions: [
                if (connected && Platform.isAndroid)
                  IconButton(
                    tooltip: 'Pair if required',
                    icon: const Icon(Icons.link),
                    onPressed:
                        busy
                            ? null
                            : () => run(() async {
                              if (!await confirm(
                                'Pair this device?',
                                'Pair only if this device requires it. Android will request its PIN if needed.',
                              )) {
                                return;
                              }
                              await widget.device!.createBond();
                              if (mounted) {
                                setState(() => status = 'Pairing completed.');
                              }
                            }),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
      ) ??
      false;
  Future<void> write(BluetoothCharacteristic c, List<int> bytes) async {
    if (!connected) throw StateError('Device disconnected. Reconnect first.');
    if (bytes.length > (widget.device!.mtuNow - 3)) {
      throw StateError(
        'Value exceeds the Bluetooth MTU. Reconnect and try again.',
      );
    }
    if (!c.properties.write && !c.properties.writeWithoutResponse) {
      throw StateError('This field is read-only.');
    }
    await c.write(bytes, withoutResponse: !c.properties.write);
    if (mounted) {
      setState(
        () =>
            status =
                c.properties.write
                    ? 'Bluetooth write acknowledged. Verify the device settings or next report.'
                    : 'Sent without acknowledgment. Verify the device settings or next report.',
      );
    }
  }

  String get commandSummary {
    if (hex.text.isEmpty || model == null) return '';
    try {
      return describe(hex.text, model!);
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> send() async {
    final h = cleanHex(hex.text), summary = describe(hex.text, model!);
    if (mqtt || !h.startsWith('A0')) {
      throw StateError(
        'This command is prepared for MQTT. Copy it to your server.',
      );
    }
    final c = fields['configuration'];
    if (c == null) {
      throw StateError('Configuration field not found in service FFF0.');
    }
    if (!await confirm(
      'Send configuration?',
      '${widget.device!.platformName}\n$model\n\n$summary\n\n$h',
    )) {
      return;
    }
    describe(h, model!);
    await sendWithFeedback(c, utf8.encode(h));
  }

  Future<void> sendWithFeedback(
    BluetoothCharacteristic c,
    List<int> bytes,
  ) async {
    final reply = Completer<ConfigurationVerdict?>();
    StreamSubscription<List<int>>? subscription;
    StreamSubscription<BluetoothConnectionState>? disconnect;
    final wasNotifying = c.isNotifying;
    var armed = false;
    String lastResponse = '';
    String buffer = '';
    void consume(List<int> data) {
      if (!armed || reply.isCompleted || data.isEmpty) return;
      final text = utf8.decode(data, allowMalformed: true);
      lastResponse = text.length > 160 ? '${text.substring(0, 160)}…' : text;
      buffer += text;
      if (buffer.length > 2048) buffer = buffer.substring(buffer.length - 2048);
      // A response can arrive in one notification or be split over several.
      for (final line in [text, ...buffer.split(RegExp(r'[\r\n]+'))]) {
        final verdict = configurationVerdict(line);
        if (verdict != null) {
          reply.complete(verdict);
          return;
        }
      }
    }

    try {
      if (c.properties.notify || c.properties.indicate) {
        subscription = c.onValueReceived.listen(consume);
        await c.setNotifyValue(true);
      }
      disconnect = widget.device!.connectionState.listen((state) {
        if (armed &&
            state == BluetoothConnectionState.disconnected &&
            !reply.isCompleted) {
          reply.complete(null);
        }
      });
      armed = true;
      await write(c, bytes);
      if (mounted) {
        setState(
          () => status = 'Command sent. Waiting for device confirmation…',
        );
      }
      // Read-only feedback is not accepted: a stored success string may be stale.
      final verdict = await reply.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      if (!mounted) return;
      setState(
        () =>
            status = switch (verdict) {
              ConfigurationVerdict.success =>
                'Configuration success — confirmed by the device.',
              ConfigurationVerdict.failed =>
                'Configuration failed — rejected by the device.',
              null =>
                connected
                    ? 'No confirmation received. The change is unverified. Check the setting before retrying.${lastResponse.isEmpty ? '' : ' Device response: $lastResponse'}'
                    : 'Device disconnected before confirmation. The change is unverified.',
            },
      );
    } finally {
      armed = false;
      await subscription?.cancel();
      await disconnect?.cancel();
      if (!wasNotifying && c.isNotifying && connected) {
        try {
          await c.setNotifyValue(false);
        } catch (_) {}
      }
    }
  }

  Widget dropdown<T>(
    String label,
    T? selected,
    List<T> options,
    String Function(T) title,
    void Function(T) change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      isExpanded: true,
      value: selected,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items:
          options
              .map(
                (x) => DropdownMenuItem(
                  value: x,
                  child: Text(title(x), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged:
          busy
              ? null
              : (v) {
                if (v != null) change(v);
              },
    ),
  );
  Widget input(
    String label,
    TextEditingController c, {
    bool number = false,
    void Function(String)? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType:
          number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: widget.device == null ? 2 : 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'MQTT tools' : 'Device setup'),
        actions: [
          IconButton(
            tooltip: 'User guide',
            icon: const Icon(Icons.help_outline),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpPage()),
                ),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: widget.device == null ? 'Payloads' : 'Tracking'),
            if (widget.device != null) const Tab(text: 'Network & MQTT'),
            const Tab(text: 'Decoder'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  connected
                      ? 'Connected: ${widget.device!.platformName}'
                      : widget.device != null
                      ? 'Disconnected — return to Devices and reconnect'
                      : 'MQTT payload generator • copy to your server',
                ),
                const SizedBox(height: 8),
                dropdown(
                  model == null
                      ? '1. Select your exact device'
                      : 'Device model (change if needed)',
                  model,
                  widget.radioFamily == null
                      ? models
                      : models
                          .where(
                            (m) =>
                                widget.radioFamily == RadioFamily.nb
                                    ? m.startsWith('NB-IoT')
                                    : m.startsWith('LTE Cat-1'),
                          )
                          .toList(),
                  (s) => s,
                  (s) {
                    setState(() {
                      model = s;
                      hex.clear();
                      decoded = '';
                    });
                    selectParameter(parameters(s).first);
                  },
                ),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              children: [
                tracking(),
                if (widget.device != null) network(),
                decoder(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget tracking() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        widget.device == null
            ? 'Generate a payload for your MQTT server. These values are not read from the device.'
            : 'Choose a setting and review the command.',
      ),
      const SizedBox(height: 16),
      dropdown(
        '2. Operation',
        operation,
        ['Configure', 'Query for MQTT', 'Action for MQTT'],
        (s) => s,
        (s) {
          setState(() {
            operation = s;
            if (s == 'Action for MQTT') value.text = '3';
            if (s == 'Configure') selectParameter(p);
            mqtt = widget.device == null || s != 'Configure';
            hex.clear();
          });
        },
      ),
      if (operation != 'Action for MQTT')
        dropdown(
          'Parameter',
          p,
          parameters(model ?? models.first),
          (p) => p.name,
          selectParameter,
        ),
      if (operation == 'Configure') ...[
        if (p.kind == 'seconds') ...[
          input(
            'Value',
            value,
            number: true,
            onChanged: (_) => setState(() => hex.clear()),
          ),
          dropdown(
            'Time unit',
            unit,
            [1, 60, 3600],
            (n) => {1: 'Seconds', 60: 'Minutes', 3600: 'Hours'}[n]!,
            (n) {
              setState(() {
                final old = double.tryParse(value.text);
                if (old != null) value.text = '${old * unit / n}';
                unit = n;
                hex.clear();
              });
            },
          ),
          Text(
            'Range: ${p.min * p.step}–${p.max * p.step} seconds, in steps of ${p.step}. ${p.min == 0 ? (p.id >= 5 ? 'Zero = continuous reception.' : 'Zero = disabled.') : 'Heartbeat cannot be disabled.'}',
          ),
          if (p.id == 5)
            const Text(
              'BLE receive duration can be firmware-dependent; verify support for your device.',
            ),
        ] else if (p.kind == 'toggle')
          SwitchListTile(
            title: Text(p.name),
            value: value.text == '1',
            onChanged:
                (v) => setState(() {
                  value.text = v ? '1' : '0';
                  hex.clear();
                }),
          )
        else if (p.kind == 'mode')
          dropdown(
            'Working mode',
            int.tryParse(value.text) ?? 1,
            [0, 1, 2],
            (n) => ['Periodic', 'Autonomous', 'On-demand'][n],
            (n) => setState(() {
              value.text = '$n';
              hex.clear();
            }),
          )
        else
          input(
            p.kind == 'meters'
                ? 'Fall threshold (0–5 meters, step 0.5)'
                : 'Beacon UUID',
            value,
            onChanged: (_) => setState(() => hex.clear()),
          ),
        if (widget.device != null)
          SwitchListTile(
            title: const Text('Prepare for MQTT server'),
            subtitle: const Text(
              'Copy the payload to your existing server. This app sends directly using Bluetooth.',
            ),
            value: mqtt,
            onChanged:
                (v) => setState(() {
                  mqtt = v;
                  hex.clear();
                }),
          ),
      ],
      if (operation == 'Action for MQTT')
        dropdown(
          'Action',
          int.tryParse(value.text) != null &&
                  [1, 2, 3, 4].contains(int.parse(value.text))
              ? int.parse(value.text)
              : 3,
          [1, 2, 3, 4],
          (n) =>
              [
                'Request position',
                'Request registration',
                'Reboot',
                'Factory reset',
              ][n - 1],
          (n) => setState(() {
            value.text = '$n';
            hex.clear();
          }),
        ),
      if (mqtt)
        input(
          'Server message ID (1–65535)',
          mid,
          number: true,
          onChanged: (_) => setState(() => hex.clear()),
        ),
      if (mqtt)
        const Text(
          'For MQTT, increase the message ID by 1 for each downlink, following your server/device sequence. Factory reset deletes configuration.',
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed:
            model == null || busy
                ? null
                : () => run(() async {
                  String h;
                  if (operation == 'Configure') {
                    final v =
                        p.kind == 'seconds'
                            ? '${(double.tryParse(value.text) ?? double.nan) * unit}'
                            : value.text;
                    h = config(p, v, mqtt ? mid.text : '1');
                  } else if (operation == 'Query for MQTT') {
                    h = 'B0${p.id.toRadixString(16).padLeft(2, '0')}${messageId(mid.text)}';
                  } else {
                    final n = int.tryParse(value.text);
                    if (n == null || n < 1 || n > 4) {
                      throw FormatException('Select an action.');
                    }
                    h = 'C0${n.toRadixString(16).padLeft(2, '0')}${messageId(mid.text)}';
                  }
                  describe(h, model!);
                  setState(() => hex.text = h.toUpperCase());
                }),
        child: const Text('3. Create command'),
      ),
      if (hex.text.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(commandSummary),
        SwitchListTile(
          title: const Text('Advanced: edit hexadecimal command'),
          value: advanced,
          onChanged: (v) => setState(() => advanced = v),
        ),
        if (advanced)
          input('Command', hex, onChanged: (_) => setState(() {}))
        else
          SelectableText(hex.text),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed:
                  busy
                      ? null
                      : () => run(() async {
                        describe(hex.text, model!);
                        await Clipboard.setData(
                          ClipboardData(text: cleanHex(hex.text)),
                        );
                        setState(() => status = 'Command copied.');
                      }),
              child: const Text('Copy'),
            ),
            if (widget.device != null)
              FilledButton(
                onPressed:
                    busy ||
                            !connected ||
                            mqtt ||
                            !fields.containsKey('configuration')
                        ? null
                        : () => run(send),
                child: const Text('4. Send by Bluetooth'),
              ),
          ],
        ),
      ],
    ],
  );
  static const groups = {
    'Network': ['LTE-RAT', 'RATs ScanSeq', 'eMTC Band', 'NB-IoT Band'],
    'SIM / APN': ['APN Name', 'APN UserName', 'APN UserPsw', 'APN AuthMethod'],
    'MQTT': [
      'HostName(URL/IP)',
      'HostPort',
      'Client id',
      'MQTT UserName',
      'MQTT UserPsw',
      'MQTT SubTopic',
      'MQTT PubTopic',
    ],
    'Device information': [
      'NetState',
      'Device IMEI',
      'Device IMSI',
      'Device CCID',
    ],
  };
  Widget network() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Connect the device from Devices first. Tap a setting to read its current value and change it. Use SIM/operator and broker settings supplied by your provider.',
      ),
      if (!connected)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Connect a device to unlock these settings.'),
        ),
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(g.key, style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final name in g.value)
          ListTile(
            title: Text(name),
            subtitle: Text(
              fields.containsKey(norm(name))
                  ? 'Read current value'
                  : 'Not discovered on this device',
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: connected && !busy && fields.containsKey(norm(name)),
            onTap: () => run(() => editField(name, fields[norm(name)]!)),
          ),
      ],
      const SizedBox(height: 16),
      const Text(
        'Only settings supported by this connected device are enabled. SSL and device operating controls require a firmware-specific mapping and are not exposed here.',
      ),
      OutlinedButton(
        onPressed:
            !connected || busy || !fields.containsKey('reboot')
                ? null
                : () => run(() async {
                  if (await confirm(
                    'Reboot device?',
                    'The Bluetooth connection will disconnect. Reconnect after the device restarts.',
                  )) {
                    await write(fields['reboot']!, utf8.encode('00'));
                  }
                }),
        child: const Text('Reboot device'),
      ),
    ],
  );
  Future<void> editField(String name, BluetoothCharacteristic c) async {
    final bytes = await c.read();
    final current = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\u0000', '');
    if (!mounted) return;
    final readonly = !c.properties.write && !c.properties.writeWithoutResponse;
    final controller = TextEditingController(text: current);
    final secret = name.toLowerCase().contains('psw');
    const options = {
      'LTE-RAT': {'1': 'NB-IoT', '0': 'LTE-M', '2': 'NB-IoT and LTE-M'},
      'RATs ScanSeq': {'0302': 'NB-IoT first', '0203': 'LTE-M first'},
      'APN AuthMethod': {
        '0': 'None',
        '1': 'PAP',
        '2': 'CHAP',
        '3': 'PAP or CHAP',
      },
    };
    final choices = options[name];
    bool clear = false;
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, update) => AlertDialog(
                  title: Text(name),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (readonly)
                          SelectableText(
                            current.isEmpty ? 'Empty response' : current,
                          )
                        else if (choices != null)
                          DropdownButtonFormField<String>(
                            value:
                                choices.containsKey(controller.text)
                                    ? controller.text
                                    : null,
                            isExpanded: true,
                            hint: const Text('Choose value'),
                            items:
                                choices.entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              controller.text = v ?? '';
                            },
                          )
                        else if (name.contains('Band'))
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SwitchListTile(
                                title: const Text('Scan all supported bands'),
                                value: controller.text == '0',
                                onChanged:
                                    (v) => update(
                                      () => controller.text = v ? '0' : '',
                                    ),
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final band in [
                                    1,
                                    2,
                                    3,
                                    4,
                                    5,
                                    8,
                                    12,
                                    13,
                                    18,
                                    19,
                                    20,
                                    25,
                                    26,
                                    28,
                                    39,
                                    66,
                                    71,
                                    85,
                                  ])
                                    FilterChip(
                                      label: Text('B$band'),
                                      selected: controller.text
                                          .split(',')
                                          .map((s) => s.trim())
                                          .contains('$band'),
                                      onSelected:
                                          (enabled) => update(() {
                                            final selected =
                                                controller.text
                                                    .split(',')
                                                    .map(
                                                      (s) => int.tryParse(
                                                        s.trim(),
                                                      ),
                                                    )
                                                    .whereType<int>()
                                                    .where((n) => n > 0)
                                                    .toSet();
                                            if (enabled) {
                                              selected.add(band);
                                            } else {
                                              selected.remove(band);
                                            }
                                            final ordered =
                                                selected.toList()..sort();
                                            controller.text = ordered.join(',');
                                          }),
                                    ),
                                ],
                              ),
                              Text('Selected: ${controller.text}'),
                            ],
                          )
                        else
                          TextField(
                            controller: controller,
                            obscureText: secret,
                            decoration: const InputDecoration(
                              labelText: 'Value',
                            ),
                          ),
                        if (!readonly &&
                            (name.contains('User') || name == 'APN Name'))
                          CheckboxListTile(
                            title: const Text('Clear this optional field'),
                            value: clear,
                            onChanged: (v) => update(() => clear = v ?? false),
                          ),
                        if (name.contains('Band'))
                          const Text(
                            'Select only bands supported by your device module and operator. All bands may take longer to register.',
                          ),
                        if (error != null) Text(error!),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(readonly ? 'Close' : 'Cancel'),
                    ),
                    if (!readonly)
                      FilledButton(
                        onPressed: () {
                          try {
                            final exact =
                                name.contains('User') ||
                                name == 'Client id' ||
                                name.contains('Topic');
                            final v =
                                clear
                                    ? ''
                                    : exact
                                    ? controller.text
                                    : controller.text.trim();
                            validateField(name, v, clear);
                            Navigator.pop(ctx, v);
                          } catch (e) {
                            update(() => error = e.toString());
                          }
                        },
                        child: const Text('Review'),
                      ),
                  ],
                ),
          ),
    );
    controller.dispose();
    if (result == null) return;
    if (!await confirm(
      'Write $name?',
      secret
          ? 'Update this credential?'
          : 'New value: ${result.isEmpty ? '(clear)' : result}',
    )) {
      return;
    }
    await write(c, result.isEmpty ? [0] : utf8.encode(result));
    if (c.properties.read) {
      final back = utf8
          .decode(await c.read(), allowMalformed: true)
          .replaceAll('\u0000', '');
      if (mounted) {
        setState(
          () =>
              status =
                  back == result
                      ? 'Saved and read back: $name.'
                      : 'Write sent, but readback differs. Check $name in the original editor.',
        );
      }
    }
  }

  void validateField(String name, String v, bool clear) {
    if (clear) return;
    const choices = {
      'LTE-RAT': ['0', '1', '2'],
      'RATs ScanSeq': ['0302', '0203'],
      'APN AuthMethod': ['0', '1', '2', '3'],
    };
    if (choices.containsKey(name) && !choices[name]!.contains(v)) {
      throw FormatException('Select a supported value.');
    }
    if (v.isEmpty) throw FormatException('Enter a value or choose Clear.');
    if (name == 'HostPort') {
      final n = int.tryParse(v);
      if (n == null || n < 1 || n > 65535) {
        throw FormatException('Port must be 1–65535.');
      }
    }
    if (name == 'HostName(URL/IP)' &&
        (v.contains('/') || RegExp(r'\s').hasMatch(v))) {
      throw FormatException(
        'Use a hostname or IP address, without URL scheme/path.',
      );
    }
    if (name == 'MQTT PubTopic' && (v.contains('#') || v.contains('+'))) {
      throw FormatException('Publish topics cannot contain wildcards.');
    }
    if (name.contains('Band')) {
      if (v == '0') return;
      const bands = {
        1,
        2,
        3,
        4,
        5,
        8,
        12,
        13,
        18,
        19,
        20,
        25,
        26,
        28,
        39,
        66,
        71,
        85,
      };
      final entries = v.split(',');
      if (entries.any((s) => !bands.contains(int.tryParse(s.trim())))) {
        throw FormatException(
          'Enter supported band numbers separated by commas. Check module and operator support.',
        );
      }
    }
  }

  Widget decoder() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Paste an uplink application payload from your MQTT server. Select the exact device above. Decoding works offline.',
      ),
      const SizedBox(height: 16),
      input('Uplink hexadecimal payload', uplink),
      FilledButton(
        onPressed:
            model == null || busy
                ? null
                : () => run(() async {
                  final h = cleanHex(uplink.text);
                  final result = await decodeUplink(
                    model!.contains('Gateway')
                        ? 'gateway'
                        : model!.contains('Container')
                        ? 'container'
                        : 'badge',
                    h,
                  );
                  final data = jsonDecode(result);
                  if (data is Map && data['error'] != null) {
                    throw FormatException('${data['error']}');
                  }
                  setState(
                    () =>
                        decoded = const JsonEncoder.withIndent(
                          '  ',
                        ).convert(data),
                  );
                }),
        child: const Text('Decode'),
      ),
      const SizedBox(height: 16),
      SelectableText(decoded),
    ],
  );
}
