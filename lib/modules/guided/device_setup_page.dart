import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../utils/extra.dart';
import 'protocol.dart';
import 'device_profile.dart';
import 'feedback.dart';
import 'preferences.dart';
import 'help_page.dart';
import 'device_tools_page.dart';
import 'disconnect_guard.dart';
import 'snapshot.dart';

const friendlyNames = <int, String>{
  1: 'Send heartbeat every',
  2: 'Bluetooth position every',
  3: 'GPS position every',
  4: 'Report nearby assets every',
  5: 'Bluetooth scan duration',
  6: 'GPS search duration',
  7: 'Asset scan duration',
  32: 'Operating mode',
  41: 'Track nearby assets',
  42: 'Report unsuccessful GPS fixes',
  43: 'Sort assets by signal',
  46: 'Enable power button',
  47: 'Check mobile network',
  48: 'Use GPS positioning',
  49: 'Use Bluetooth positioning',
};
const networkNames = <String, String>{
  'LTE-RAT': 'Mobile network mode',
  'RATs ScanSeq': 'Preferred network',
  'eMTC Band': 'LTE-M bands',
  'NB-IoT Band': 'NB-IoT bands',
  'APN Name': 'APN',
  'APN UserName': 'APN username',
  'APN UserPsw': 'APN password',
  'APN AuthMethod': 'APN authentication',
  'HostName(URL/IP)': 'Server address',
  'HostPort': 'Port',
  'Client id': 'Client ID',
  'MQTT UserName': 'Username',
  'MQTT UserPsw': 'Password',
  'MQTT SubTopic': 'Subscribe topic',
  'MQTT PubTopic': 'Publish topic',
};
const networkGroups = <String, List<String>>{
  'SIM & network': [
    'LTE-RAT',
    'RATs ScanSeq',
    'eMTC Band',
    'NB-IoT Band',
    'APN Name',
    'APN UserName',
    'APN UserPsw',
    'APN AuthMethod',
  ],
  'MQTT server': [
    'HostName(URL/IP)',
    'HostPort',
    'Client id',
    'MQTT UserName',
    'MQTT UserPsw',
    'MQTT SubTopic',
    'MQTT PubTopic',
  ],
};
String settingName(Parameter p) => friendlyNames[p.id] ?? p.name;
String valueLabel(Parameter p, String raw) {
  if (p.kind != 'seconds') return p.display(raw);
  final n = int.parse(raw, radix: 16) * p.step;
  if (n == 0) return [5, 6, 7].contains(p.id) ? 'Continuous' : 'Off';
  return n % 3600 == 0
      ? '${n ~/ 3600} h'
      : n % 60 == 0
      ? '${n ~/ 60} min'
      : '$n s';
}

class DeviceSetupPage extends StatefulWidget {
  final BluetoothDevice device;
  final RadioFamily? radioFamily;
  final String? initialModel;
  final List<BluetoothService> services;
  final Map<String, String?> descriptions;
  final bool persist;
  const DeviceSetupPage({
    super.key,
    required this.device,
    this.radioFamily,
    this.initialModel,
    this.services = const [],
    this.descriptions = const {},
    this.persist = true,
  });
  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  late List<BluetoothService> services;
  RadioFamily? family;
  String? model;
  StreamSubscription<BluetoothConnectionState>? subscription;
  String page = 'Overview', status = '', nickname = '', netState = '';
  Color statusColor = Colors.blue;
  bool busy = false, readyForWrites = true;
  bool readingSettings = false;
  bool initialSnapshotRead = false;
  int connectionEpoch = 0, sequence = 1;
  final freshRead = <int>{};
  String snapshotStatus = 'Not read yet', trackingReadStatus = 'Not read yet';
  int nextSequence() {
    final n = sequence;
    sequence = n == 65535 ? 1 : n + 1;
    return n;
  }

  int? wizard;
  final drafts = <int, String>{}, current = <int, String>{};
  final networkDrafts = <String, String>{}, networkCurrent = <String, String>{};
  final trace = <String>[];
  final controllers = <TextEditingController>[];
  final lastSent = <int, String>{};
  TextEditingController dialogController({String? text}) {
    final c = TextEditingController(text: text);
    controllers.add(c);
    return c;
  }

  bool get connected => widget.device.isConnected;
  bool get canWrite =>
      connected && readyForWrites && family != null && model != null;
  int get changeCount => drafts.length + networkDrafts.length;
  String get deviceTitle =>
      nickname.isNotEmpty
          ? nickname
          : widget.device.platformName.isEmpty
          ? 'Device'
          : widget.device.platformName;
  String norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  Map<String, BluetoothCharacteristic> get fields {
    if (family == null) return {};
    final out = <String, BluetoothCharacteristic>{},
        duplicates = <String>{},
        mapping = gattFor(family!);
    for (final s in services.where((s) => shortUuid(s.uuid.str) == 'fff0')) {
      for (final c in s.characteristics) {
        final name = mapping[shortUuid(c.uuid.str)];
        if (name == null) continue;
        final key = norm(name);
        if (out.containsKey(key)) duplicates.add(key);
        out[key] = c;
      }
    }
    for (final key in duplicates) {
      out.remove(key);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    services = widget.services;
    family = widget.radioFamily;
    model = widget.initialModel;
    subscription = widget.device.connectionState.listen((s) {
      if (!mounted) return;
      if (s == BluetoothConnectionState.disconnected) {
        connectionEpoch++;
        initialSnapshotRead = false;
        freshRead.clear();
        current.clear();
        networkCurrent.clear();
        netState = '';
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) initialize();
    });
  }

  Future<void> initialize() async {
    if (widget.persist) {
      try {
        final b = await GuidedPreferences.box();
        if (mounted)
          setState(
            () =>
                nickname = b.get(
                  'name:${widget.device.remoteId.str}',
                  defaultValue: '',
                ),
          );
      } catch (_) {}
    }
    if (connected && family != null && !initialSnapshotRead) {
      initialSnapshotRead = true;
      await run(() => readCurrentSettings(quiet: true));
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void record(String line) {
    trace.add('${DateTime.now().toIso8601String()} $line');
    if (trace.length > 40) trace.removeAt(0);
  }

  void message(String text, {Color color = Colors.blue}) {
    if (mounted)
      setState(() {
        status = text;
        statusColor = color;
      });
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      status = '';
    });
    try {
      await action();
    } catch (e) {
      message(
        e
            .toString()
            .replaceFirst('FormatException: ', '')
            .replaceFirst('Bad state: ', ''),
        color: Colors.deepOrange,
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: Text(text)),
              actions: [
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
    if (!canWrite) throw StateError('Reconnect and check the device model.');
    if (bytes.length > widget.device.mtuNow - 3)
      throw const FormatException('Value exceeds the Bluetooth packet size.');
    if (!c.properties.write && !c.properties.writeWithoutResponse)
      throw StateError('This setting is read-only.');
    await c.write(bytes, withoutResponse: !c.properties.write);
  }

  Future<void> readCurrentSettings({bool quiet = false}) async {
    if (!mounted || readingSettings) return;
    setState(() => readingSettings = true);
    try {
      await _readCurrentSettings(quiet: quiet);
    } finally {
      if (mounted) setState(() => readingSettings = false);
    }
  }

  Future<void> _readCurrentSettings({bool quiet = false}) async {
    if (!connected) throw StateError('Reconnect to read settings.');
    final epoch = connectionEpoch;
    final readers = <String, Future<List<int>> Function()>{};
    final config = fields['configuration'];
    if (config != null && config.properties.read)
      readers['configuration'] = () => config.read(timeout: 2);
    for (final name in networkGroups.values.expand((n) => n)) {
      final c = fields[norm(name)];
      if (c != null && c.properties.read)
        readers[name] = () => c.read(timeout: 2);
    }
    setState(() {
      current.clear();
      freshRead.clear();
      networkCurrent.clear();
      snapshotStatus = 'Reading settings…';
    });
    bool active() => mounted && connected && epoch == connectionEpoch;
    final result = await readSnapshotOnce(readers, active: active);
    if (!active()) return;
    var tracking = const TrackingSnapshot({}, {});
    if (!result.incomplete &&
        model != null &&
        config != null &&
        (config.properties.write || config.properties.writeWithoutResponse)) {
      tracking = await queryTrackingOnce(
        model: model!,
        maxBytes: widget.device.mtuNow - 3,
        nextId: nextSequence,
        progress: (index, total) {
          if (active())
            setState(
              () =>
                  trackingReadStatus =
                      'Reading tracking settings $index/$total…',
            );
        },
        write:
            (command) => config.write(
              utf8.encode(command),
              withoutResponse: !config.properties.write,
              timeout: 2,
            ),
        read: config.properties.read ? () => config.read(timeout: 2) : null,
        notifications: config.onValueReceived,
        notify: (enable) => config.setNotifyValue(enable),
        canNotify: config.properties.notify || config.properties.indicate,
        alreadyNotifying: config.isNotifying,
        active: active,
        baseline: result.values['configuration'] ?? [],
        trace: record,
      );
    }
    if (!active()) return;
    setState(() {
      current.addAll(tracking.values);
      freshRead.addAll(tracking.fresh);
      for (final e in result.values.entries) {
        if (e.key != 'configuration')
          networkCurrent[e.key] =
              utf8
                  .decode(e.value, allowMalformed: true)
                  .replaceAll('\u0000', '')
                  .trim();
      }
      snapshotStatus =
          'Read ${networkCurrent.length} network fields${result.incomplete ? ' · partial result' : ''}';
      trackingReadStatus =
          tracking.values.isEmpty
              ? 'No tracking values returned. Refresh to try again.'
              : 'Read ${tracking.values.length} tracking parameters${tracking.fresh.length < tracking.values.length ? ' · some responses may be cached' : ''}';
    });
    record(
      'SNAPSHOT ${networkCurrent.length} network fields; ${tracking.values.length} tracking parameters',
    );
    if (!quiet) message('$snapshotStatus. $trackingReadStatus');
  }

  Future<List<int>> readDeviceResponse() async {
    final c = fields['configuration'];
    if (c == null || !c.properties.read || !connected)
      throw StateError('Reconnect to read the configuration response.');
    final bytes = await c.read(timeout: 5);
    record('MANUAL READ ${wireHex(bytes)}');
    if (model != null) {
      final values = parameterResponse(bytes, model!);
      if (mounted && values.isNotEmpty)
        setState(() {
          current.addAll(values);
          freshRead.removeAll(values.keys);
        });
    }
    return bytes;
  }

  Future<void> readSettings({bool quiet = true}) async {
    try {
      final bytes = await readDeviceResponse();
      if (!quiet) {
        final values =
            model == null ? <int, String>{} : parameterResponse(bytes, model!);
        final text =
            utf8
                .decode(bytes, allowMalformed: true)
                .replaceAll('\u0000', '')
                .trim();
        if (values.isNotEmpty)
          message('Read ${values.length} saved parameters.');
        else if (explicitVerdict(text) != null)
          message(
            'Device response: $text. Saved parameter values were not returned.',
          );
        else
          message(
            text.isEmpty
                ? 'The device returned an empty response.'
                : 'Device response: $text',
          );
      }
    } catch (e) {
      if (!quiet) rethrow;
    }
  }

  Future<ApplyResult> sendWithFeedback(
    BluetoothCharacteristic c,
    List<int> bytes,
  ) async {
    final command = utf8.decode(bytes);
    message('Applying setting…');
    final result = await exchangeConfiguration(
      command: command,
      model: model!,
      write: () => write(c, bytes),
      read: c.properties.read ? () => c.read(timeout: 2) : null,
      notifications: c.onValueReceived,
      connections: widget.device.connectionState.map(
        (s) => s == BluetoothConnectionState.connected,
      ),
      notify: (v) async {
        if (connected) await c.setNotifyValue(v, timeout: 3);
      },
      canNotify: c.properties.notify || c.properties.indicate,
      alreadyNotifying: c.isNotifying,
      trace: record,
    );
    if (mounted)
      setState(() {
        lastSent.addAll(commandValues(command, model!));
        freshRead.removeAll(commandValues(command, model!).keys);
        if (result.outcome == ApplyOutcome.verified)
          current.addAll(result.values);
        else
          for (final id in commandValues(command, model!).keys) {
            current.remove(id);
          }
      });
    message(
      result.label,
      color: result.verified ? Colors.green.shade700 : Colors.deepOrange,
    );
    return result;
  }

  Future<void> reconnect() async {
    message('Reconnecting…');
    await FlutterBluePlus.stopScan();
    await widget.device.connectAndUpdateStream();
    try {
      if (Platform.isAndroid) await widget.device.requestMtu(223);
    } catch (_) {}
    final found = await widget.device.discoverServices();
    final detected = detectRadio(
      found.map((s) => s.uuid.str),
      found
          .where((s) => shortUuid(s.uuid.str) == 'fff0')
          .expand((s) => s.characteristics.map((c) => c.uuid.str)),
    );
    if (!mounted) return;
    setState(() {
      services = found;
      readyForWrites = detected == family && detected != null;
    });
    if (!readyForWrites) {
      message(
        'Device services changed. Reconnect from Devices.',
        color: Colors.deepOrange,
      );
      return;
    }
    initialSnapshotRead = true;
    await readCurrentSettings(quiet: true);
    message('Reconnected. Unsent changes retained.');
  }

  Future<void> reboot() async {
    final c = fields['reboot'];
    if (c == null || !canWrite)
      throw StateError('Reboot is unavailable on this connection.');
    if (!await confirm(
      'Restart device?',
      'The Bluetooth connection will close.',
    ))
      return;
    await write(c, utf8.encode('00'));
    current.clear();
    networkCurrent.clear();
    netState = '';
    message('Restart requested. Reconnect when available.');
  }

  Future<void> changeModel() async {
    final allowed =
        family == null
            ? models
            : models
                .where(
                  (m) =>
                      family == RadioFamily.nb
                          ? m.startsWith('NB-IoT')
                          : m.startsWith('LTE Cat-1'),
                )
                .toList();
    final next = await showDialog<String>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Device model'),
            children:
                allowed
                    .map(
                      (m) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, m),
                        child: Text(m),
                      ),
                    )
                    .toList(),
          ),
    );
    if (next == null || next == model || !mounted) return;
    if (changeCount > 0 &&
        !await confirm(
          'Change model?',
          'Discard the unsent changes for the previous model?',
        ))
      return;
    if (!mounted) return;
    setState(() {
      model = next;
      lastSent.clear();
      current.clear();
      drafts.clear();
      networkDrafts.clear();
      networkCurrent.clear();
    });
    await run(readSettings);
  }

  Future<String?> askName(String title, {String initial = ''}) async {
    final c = dialogController(text: initial);
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(controller: c, maxLength: 48),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> rename() async {
    final name = await askName('Device name', initial: nickname);
    if (name == null || !mounted) return;
    setState(() => nickname = name);
    if (widget.persist)
      await (await GuidedPreferences.box()).put(
        'name:${widget.device.remoteId.str}',
        name,
      );
  }

  Widget tile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? action,
  ) => Card(
    child: ListTile(
      minVerticalPadding: 14,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: action == null ? null : const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
  void navigate(String section) => setState(() => page = section);
  @override
  Widget build(BuildContext context) => DisconnectGuard(
    connected: connected,
    busy: busy,
    pending: changeCount,
    child: Scaffold(
      appBar: AppBar(
        title: Text(page == 'Overview' ? 'Device setup' : page),
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
          PopupMenuButton<String>(
            enabled: !busy,
            onSelected: (s) {
              if (s == 'model') changeModel();
              if (s == 'name') run(rename);
              if (s == 'pair')
                run(() async {
                  await widget.device.createBond();
                  message('Paired.');
                });
              if (s == 'tools')
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => DeviceToolsPage(
                          device: widget.device,
                          model: model,
                          canRead:
                              fields['configuration']?.properties.read ?? false,
                          read: readDeviceResponse,
                        ),
                  ),
                );
              if (s == 'read') run(() => readCurrentSettings());
              if (s == 'diagnostics') diagnostics();
              if (s == 'disconnect') Navigator.of(context).maybePop();
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'model',
                    child: Text('Change model'),
                  ),
                  const PopupMenuItem(
                    value: 'name',
                    child: Text('Device name'),
                  ),
                  if (Platform.isAndroid && connected)
                    const PopupMenuItem(
                      value: 'pair',
                      child: Text('Pair device'),
                    ),
                  const PopupMenuItem(
                    value: 'read',
                    child: Text('Read current settings'),
                  ),
                  const PopupMenuItem(
                    value: 'tools',
                    child: Text('Advanced tools'),
                  ),
                  const PopupMenuItem(
                    value: 'disconnect',
                    child: Text('Disconnect device'),
                  ),
                  const PopupMenuItem(
                    value: 'diagnostics',
                    child: Text('Copy diagnostics'),
                  ),
                ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (page != 'Overview')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed:
                      busy
                          ? null
                          : () => setState(() {
                            page = 'Overview';
                            wizard = null;
                          }),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Device overview'),
                ),
              ),
            if (!connected || !readyForWrites)
              Material(
                color: Colors.orange.shade50,
                child: ListTile(
                  title: Text(
                    !connected
                        ? 'Bluetooth disconnected'
                        : 'Check device services',
                  ),
                  trailing: TextButton(
                    onPressed: busy ? null : () => run(reconnect),
                    child: const Text('Reconnect'),
                  ),
                ),
              ),
            if (wizard != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: i <= wizard! ? 1 : 0,
                                minHeight: 3,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ['SIM', 'Server', 'Tracking', 'Verify'][i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      i == wizard
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (busy) const LinearProgressIndicator(minHeight: 2),
            if (readingSettings && connected)
              Semantics(
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Reading device settings. Please wait a few seconds…',
                  ),
                ),
              ),
            if (status.isNotEmpty)
              Container(
                color: statusColor.withValues(alpha: 0.08),
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Icon(
                      statusColor == Colors.deepOrange
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status, maxLines: 4)),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => setState(() => status = ''),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            Expanded(
              child:
                  page == 'Overview'
                      ? overview()
                      : page == 'Tracking'
                      ? tracking()
                      : page == 'Connection'
                      ? connection()
                      : network(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (changeCount > 0)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : reviewChanges,
                    child: Text('Review changes ($changeCount)'),
                  ),
                ),
              if (wizard != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed:
                        busy
                            ? null
                            : () => setState(() {
                              if (wizard == 3) {
                                wizard = null;
                                page = 'Overview';
                              } else {
                                wizard = wizard! + 1;
                                page =
                                    [
                                      'SIM & network',
                                      'MQTT server',
                                      'Tracking',
                                      'Connection',
                                    ][wizard!];
                              }
                            }),
                    child: Text(wizard == 3 ? 'Done' : 'Continue'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget overview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sensors, size: 36),
              const SizedBox(height: 12),
              Text(
                model ?? 'Choose device model',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(deviceTitle),
              Text(
                widget.device.remoteId.str,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                connected ? 'Bluetooth connected' : 'Bluetooth disconnected',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed:
            busy
                ? null
                : () =>
                    model == null
                        ? changeModel()
                        : setState(() {
                          wizard = 0;
                          page = 'SIM & network';
                        }),
        child: const Text('Set up device'),
      ),
      const SizedBox(height: 12),
      tile(
        'Tracking',
        'Reporting, positioning and alarms',
        Icons.route,
        busy ? null : () => navigate('Tracking'),
      ),
      tile(
        'SIM & network',
        'APN and mobile network',
        Icons.sim_card_outlined,
        busy ? null : () => navigate('SIM & network'),
      ),
      tile(
        'MQTT server',
        'Server address and credentials',
        Icons.cloud_outlined,
        busy ? null : () => navigate('MQTT server'),
      ),
      tile(
        'Connection',
        'Network status and device identifiers',
        Icons.network_check,
        busy ? null : () => navigate('Connection'),
      ),
      tile(
        'Configuration profiles',
        'Reuse settings for the same model',
        Icons.bookmarks_outlined,
        busy || model == null ? null : () => run(profiles),
      ),
      const SizedBox(height: 12),
      restartButton(),
    ],
  );
  Widget restartButton() => OutlinedButton.icon(
    onPressed:
        busy || !canWrite || !fields.containsKey('reboot')
            ? null
            : () => run(reboot),
    icon: const Icon(Icons.restart_alt),
    label: const Text('Restart device'),
  );
  Widget tracking() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (model == null)
        FilledButton(
          onPressed: changeModel,
          child: const Text('Choose device model'),
        )
      else ...[
        Row(
          children: [
            Expanded(child: heading('Tracking parameters')),
            IconButton(
              tooltip: 'Read current settings',
              onPressed:
                  busy || !connected
                      ? null
                      : () => run(() => readCurrentSettings()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(trackingReadStatus),
        ),
        for (final p in parameters(model!))
          Card(
            child: ListTile(
              title: Text(settingName(p)),
              subtitle: Text(
                '${current.containsKey(p.id) ? valueLabel(p, current[p.id]!) : 'Current: no valid reply received'}${lastSent.containsKey(p.id) ? '\nLast sent: ${valueLabel(p, lastSent[p.id]!)}${current.containsKey(p.id)
                        ? freshRead.contains(p.id)
                            ? current[p.id] == lastSent[p.id]
                                ? ' · verified'
                                : ' · DOES NOT MATCH'
                            : ' · readback freshness unconfirmed'
                        : ''}' : ''}${drafts.containsKey(p.id) ? ' → ${valueLabel(p, drafts[p.id]!)}' : ''}',
              ),
              trailing: Icon(
                drafts.containsKey(p.id) ? Icons.edit : Icons.chevron_right,
              ),
              onTap: busy ? null : () => editParameter(p),
            ),
          ),
        const SizedBox(height: 12),
        restartButton(),
      ],
    ],
  );
  Future<void> editParameter(Parameter p) async {
    final raw = drafts[p.id] ?? current[p.id];
    var unit = 1;
    int? option = raw == null ? null : int.tryParse(raw, radix: 16);
    String? error;
    final c = dialogController(
      text:
          raw == null
              ? ''
              : p.kind == 'uuid'
              ? raw
              : '${int.parse(raw, radix: 16) * p.step}',
    );
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, update) => AlertDialog(
                  title: Text(settingName(p)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: ${current.containsKey(p.id) ? valueLabel(p, current[p.id]!) : 'Not available'}',
                        ),
                        const SizedBox(height: 16),
                        if (['toggle', 'mode'].contains(p.kind))
                          DropdownButtonFormField<int>(
                            value: option,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'New value',
                            ),
                            items:
                                (p.kind == 'toggle' ? [0, 1] : [0, 1, 2])
                                    .map(
                                      (n) => DropdownMenuItem(
                                        value: n,
                                        child: Text(
                                          p.kind == 'toggle'
                                              ? ['Disabled', 'Enabled'][n]
                                              : [
                                                'Periodic',
                                                'Autonomous',
                                                'On demand',
                                              ][n],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => update(() => option = v),
                          )
                        else ...[
                          TextField(
                            controller: c,
                            keyboardType:
                                p.kind == 'uuid'
                                    ? TextInputType.text
                                    : const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                            decoration: InputDecoration(
                              labelText:
                                  p.kind == 'uuid' ? 'New UUID' : 'New value',
                            ),
                          ),
                          if (p.kind == 'seconds')
                            DropdownButtonFormField<int>(
                              value: unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                              items:
                                  [1, 60, 3600]
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(
                                            {
                                              1: 'Seconds',
                                              60: 'Minutes',
                                              3600: 'Hours',
                                            }[u]!,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (u) => update(() {
                                    final old = double.tryParse(c.text);
                                    if (old != null)
                                      c.text = '${old * unit / u!}';
                                    unit = u!;
                                  }),
                            ),
                          if (p.kind != 'uuid')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${p.min * p.step}–${p.max * p.step} ${p.kind == 'seconds' ? 's' : 'm'} · step ${p.step}${p.min == 0 ? ' · 0 = ${[5, 6, 7].contains(p.id) ? 'continuous' : 'off'}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.deepOrange),
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
                          final entered =
                              ['toggle', 'mode'].contains(p.kind)
                                  ? option?.toString()
                                  : p.kind == 'seconds'
                                  ? '${(double.tryParse(c.text) ?? double.nan) * unit}'
                                  : c.text;
                          if (entered == null)
                            throw const FormatException('Choose a value.');
                          Navigator.pop(ctx, p.encode(entered));
                        } catch (e) {
                          update(
                            () =>
                                error = e.toString().replaceFirst(
                                  'FormatException: ',
                                  '',
                                ),
                          );
                        }
                      },
                      child: const Text('Keep change'),
                    ),
                  ],
                ),
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (current[p.id] == result) {
        drafts.remove(p.id);
      } else {
        drafts[p.id] = result;
      }
    });
  }

  String displayNetwork(String name, String v) =>
      name.contains('Psw')
          ? (v.isEmpty ? 'Empty' : '••••••••')
          : v.isEmpty
          ? 'Empty'
          : v;
  Widget network() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ListTile(
        title: Text(snapshotStatus),
        trailing: IconButton(
          tooltip: 'Read current settings',
          icon: const Icon(Icons.refresh),
          onPressed:
              busy || !connected
                  ? null
                  : () => run(() => readCurrentSettings()),
        ),
      ),
      for (final name in networkGroups[page]!)
        if (fields.containsKey(norm(name)))
          Card(
            child: ListTile(
              title: Text(networkNames[name] ?? name),
              subtitle: Text(
                networkDrafts.containsKey(name)
                    ? 'Change ready'
                    : networkCurrent.containsKey(name)
                    ? displayNetwork(name, networkCurrent[name]!)
                    : 'Tap to read and edit',
              ),
              trailing: Icon(
                networkDrafts.containsKey(name)
                    ? Icons.edit
                    : Icons.chevron_right,
              ),
              onTap:
                  busy || !connected
                      ? null
                      : () => run(() => editField(name, fields[norm(name)]!)),
            ),
          ),
      if (!connected) const Text('Reconnect to read network settings.'),
      if (fields.isEmpty) const Text('Supported device services not found.'),
    ],
  );
  Future<void> checkConnection() async {
    final c = fields['netstate'];
    if (c == null || !c.properties.read)
      throw StateError('Network status is unavailable.');
    final data =
        utf8
            .decode(await c.read(timeout: 5), allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
    if (mounted) setState(() => netState = data);
  }

  Widget connection() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      tile(
        'Bluetooth',
        connected ? 'Connected' : 'Disconnected',
        Icons.bluetooth,
        null,
      ),
      tile(
        'Mobile network',
        netState.isEmpty ? 'Not checked' : 'Device response available below',
        Icons.cell_tower,
        null,
      ),
      tile(
        'MQTT server',
        'Not independently verified',
        Icons.cloud_outlined,
        null,
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: busy || !connected ? null : () => run(checkConnection),
        child: const Text('Read network status'),
      ),
      if (netState.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(netState),
          ),
        ),
      heading('Device information'),
      for (final name in ['Device IMEI', 'Device IMSI', 'Device CCID'])
        if (fields.containsKey(norm(name)))
          tile(
            name.replaceFirst('Device ', ''),
            'Tap to read',
            Icons.info_outline,
            busy || !connected
                ? null
                : () => run(() => editField(name, fields[norm(name)]!)),
          ),
      const SizedBox(height: 12),
      restartButton(),
    ],
  );
  Future<void> reviewChanges() async {
    if (model == null || changeCount == 0) return;
    final generated =
        drafts.isEmpty
            ? ''
            : 'A0${drafts.entries.map((e) => '${e.key.toRadixString(16).padLeft(2, '0')}${e.value}').join()}${messageId('$sequence')}'
                .toUpperCase();
    final c = dialogController(text: generated);
    String? error;
    final edited = await showDialog<String>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, update) => AlertDialog(
                  title: const Text('Review changes'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(model!),
                        const SizedBox(height: 12),
                        for (final e in networkDrafts.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${networkNames[e.key] ?? e.key}\n${networkCurrent.containsKey(e.key) ? displayNetwork(e.key, networkCurrent[e.key]!) : 'Not read'} → ${displayNetwork(e.key, e.value)}',
                            ),
                          ),
                        for (final e in drafts.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${settingName(parameters(model!).firstWhere((p) => p.id == e.key))}: ${current.containsKey(e.key) ? valueLabel(parameters(model!).firstWhere((p) => p.id == e.key), current[e.key]!) : 'Not read'} → ${valueLabel(parameters(model!).firstWhere((p) => p.id == e.key), e.value)}',
                            ),
                          ),
                        if (generated.isNotEmpty)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Advanced · command'),
                            children: [
                              TextField(
                                controller: c,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Generated hex',
                                ),
                                onChanged: (_) => update(() => error = null),
                              ),
                              const Text(
                                'Changes are sent and verified one at a time.',
                              ),
                            ],
                          ),
                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Back'),
                    ),
                    FilledButton(
                      onPressed:
                          !canWrite
                              ? null
                              : () {
                                try {
                                  if (generated.isNotEmpty)
                                    commandValues(c.text, model!);
                                  Navigator.pop(ctx, c.text);
                                } catch (e) {
                                  update(
                                    () =>
                                        error = e.toString().replaceFirst(
                                          'FormatException: ',
                                          '',
                                        ),
                                  );
                                }
                              },
                      child: const Text('Apply to device'),
                    ),
                  ],
                ),
          ),
    );
    if (edited == null || !mounted) return;
    if (edited.isNotEmpty) {
      final accepted = commandValues(edited, model!);
      if (cleanHex(edited) != generated &&
          !await confirm('Apply edited command?', describe(edited, model!)))
        return;
      if (!mounted) return;
      setState(() {
        drafts.clear();
        drafts.addAll(accepted);
      });
    }
    await run(
      () => applyDrafts(
        edited.isEmpty
            ? '0001'
            : cleanHex(edited).substring(cleanHex(edited).length - 4),
      ),
    );
  }

  Future<void> applyDrafts(String idHex) async {
    if (drafts.isNotEmpty) sequence = int.parse(idHex, radix: 16);
    final total = changeCount;
    var done = 0;
    var reported = 0;
    var confirmed = 0;
    for (final e in Map<String, String>.from(networkDrafts).entries) {
      final c = fields[norm(e.key)];
      if (c == null)
        throw StateError(
          'Setting unavailable: ${e.key}. Remaining changes were not sent.',
        );
      message('Applying ${++done}/$total…');
      await write(c, e.value.isEmpty ? [0] : utf8.encode(e.value));
      if (!c.properties.read) {
        message(
          'Readback unavailable. Remaining changes were not sent.',
          color: Colors.deepOrange,
        );
        return;
      }
      final back = utf8
          .decode(await c.read(timeout: 3), allowMalformed: true)
          .replaceAll('\u0000', '');
      if (back != e.value) {
        message(
          'Could not verify ${networkNames[e.key] ?? e.key}. Remaining changes were not sent.',
          color: Colors.deepOrange,
        );
        return;
      }
      if (mounted)
        setState(() {
          networkCurrent[e.key] = back;
          networkDrafts.remove(e.key);
        });
    }
    for (final e in Map<int, String>.from(drafts).entries) {
      final c = fields['configuration'];
      if (c == null) throw StateError('Configuration service is unavailable.');
      message('Applying ${++done}/$total…');
      final command =
          'A0${e.key.toRadixString(16).padLeft(2, '0')}${e.value}${messageId('${nextSequence()}')}'
              .toUpperCase();
      final result = await sendWithFeedback(c, utf8.encode(command));
      if (!result.acknowledged) {
        message(
          '${result.label}. Remaining changes were not sent.',
          color: Colors.deepOrange,
        );
        return;
      }
      if (result.outcome == ApplyOutcome.reported) reported++;
      if (result.outcome == ApplyOutcome.confirmed) confirmed++;
      if (mounted) setState(() => drafts.remove(e.key));
    }
    message(
      reported > 0
          ? 'Sent $total changes. Success response received; saved values not verified.'
          : confirmed > 0
          ? 'Sent $total changes. Confirmed by device; saved values not read back.'
          : '$total ${total == 1 ? 'change' : 'changes'} verified.',
      color: reported > 0 ? Colors.blue : Colors.green.shade700,
    );
  }

  Future<void> diagnostics() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            'Ls BLE Guided 1.3.4\nModel: $model\nRadio: ${family?.name}\nGATT: ${services.where((s) => shortUuid(s.uuid.str) == 'fff0').expand((s) => s.characteristics.map((c) => shortUuid(c.uuid.str))).join(',')}\n${trace.join('\n')}',
      ),
    );
    message('Diagnostics copied.');
  }

  Future<void> profiles() async {
    if (model == null) return;
    final saved = await GuidedPreferences.profiles(model!);
    if (!mounted) return;
    final selected = await showDialog<Object>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Configuration profiles'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const ListTile(
                  leading: Icon(Icons.bookmark_add_outlined),
                  title: Text('Save this configuration'),
                  subtitle: Text('Excludes credentials, client ID and topics.'),
                ),
              ),
              for (final p in saved)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, p),
                  child: Text(p.name),
                ),
              if (saved.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No profiles for this model.'),
                ),
            ],
          ),
    );
    if (!mounted) return;
    if (selected is SetupProfile) {
      if (selected.model != model)
        throw const FormatException('Incompatible profile.');
      for (final e in selected.network.entries) {
        validateField(e.key, e.value, e.value.isEmpty);
      }
      setState(() {
        drafts.addAll(selected.tracking);
        networkDrafts.addAll(selected.network);
      });
      message('Profile loaded. Review before applying.');
    } else if (selected == 'save') {
      final name = await askName('Profile name');
      if (name == null || name.isEmpty || !mounted) return;
      final ids = parameters(model!).map((p) => p.id).toSet();
      final values = Map<int, String>.fromEntries(
        {...current, ...drafts}.entries.where((e) => ids.contains(e.key)),
      );
      await GuidedPreferences.saveProfile(
        SetupProfile(
          name: name,
          model: model!,
          tracking: values,
          network: {...networkCurrent, ...networkDrafts},
        ),
      );
      message('Profile saved.');
    }
  }

  Future<void> editField(String name, BluetoothCharacteristic c) async {
    final bytes = await c.read(timeout: 5);
    final current = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\u0000', '');
    if (!mounted) return;
    final readonly = !c.properties.write && !c.properties.writeWithoutResponse;
    networkCurrent[name] = current;
    final controller = dialogController(text: networkDrafts[name] ?? current);
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
                  title: Text(networkNames[name] ?? name),
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
                        child: const Text('Keep change'),
                      ),
                  ],
                ),
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result == current) {
        networkDrafts.remove(name);
      } else {
        networkDrafts[name] = result;
      }
    });
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
}
