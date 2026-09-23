import '../guided/disconnect_guard.dart';
import '../guided/beacon_snapshot.dart';
import 'dart:async';
import 'dart:io';
import '../guided/device_profile.dart';
import '../guided/help_page.dart';
import '../guided/device_setup_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc_characteristic/characteristic_bloc.dart';
import 'package:flutter_blue/modules/peripherals/peripheral_characteristic_detail_page.dart';
import 'package:flutter_blue/modules/peripherals/widgets/peripheral_characteristic_list_tile.dart';
import 'package:flutter_blue/modules/peripherals/widgets/peripheral_service_tile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '/utils/extra.dart';

class PeripheralCharacteristicsPage extends StatefulWidget {
  final BluetoothDevice device;
  final List<BluetoothService>? services; // 新增，可选
  final Map<String, String?>? descCache; // 新增，可选

  const PeripheralCharacteristicsPage({
    super.key,
    required this.device,
    this.services,
    this.descCache,
  });

  @override
  State<PeripheralCharacteristicsPage> createState() =>
      _PeripheralCharacteristicsPageState();
}

class _PeripheralCharacteristicsPageState
    extends State<PeripheralCharacteristicsPage> {
  late final CharacteristicBloc _characteristicBloc;
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isLoadingDescriptions = false;

  late StreamSubscription<BluetoothConnectionState>
  _connectionStateSubscription;
  late StreamSubscription<int> _mtuSubscription;
  // 缓存 characteristic 的值
  Map<String, String?> _descCache = {};
  bool _disconnectTriggeredOnExit = false;
  bool _hasRequestedMtu = false;
  bool? _manualBeacon;
  bool _pairing = false;
  String _pairingStatus = '';
  RadioFamily? get _radio => detectRadio(
    _services.map((s) => s.uuid.str),
    _services
        .where((s) => shortUuid(s.uuid.str) == 'fff0')
        .expand((s) => s.characteristics.map((c) => c.uuid.str)),
  );
  bool get _beaconGatt => detectBeaconGatt(
    _services.map((s) => s.uuid.str),
    _services
        .where((s) => shortUuid(s.uuid.str) == 'fff0')
        .expand((s) => s.characteristics.map((c) => c.uuid.str)),
  );
  bool get _isBeacon =>
      _manualBeacon ??
      (_radio == null &&
          (_beaconGatt || beaconName(widget.device.platformName)));
  Future<void> _pair() async {
    setState(() {
      _pairing = true;
      _pairingStatus = '';
    });
    try {
      await widget.device.createBond();
      if (mounted)
        setState(
          () =>
              _pairingStatus =
                  'Pairing completed. You can now try reading and changing the beacon settings.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _pairingStatus =
                  'Pairing did not complete. Check the device PIN and try again.',
        );
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _characteristicBloc = CharacteristicBloc();

    // 如果外部传了 services 和 descCache，直接使用
    if (widget.services != null) {
      _services = widget.services!;
    }
    if (widget.descCache != null) {
      _descCache.addAll(widget.descCache!);
    }
    if (_services.isNotEmpty && _descCache.isEmpty) {
      unawaited(_loadDescriptionsInBackground());
    }

    _connectionStateSubscription = widget.device.connectionState.listen((
      state,
    ) async {
      _connectionState = state;
      if (Platform.isAndroid &&
          state == BluetoothConnectionState.connected &&
          !_hasRequestedMtu) {
        _hasRequestedMtu = true;
        try {
          // 请求更大 MTU
          final mtu = await widget.device.requestMtu(223, predelay: 0);
          _mtuSize = mtu;
        } catch (e) {
          // overlayService.showErrorNotification(
          //   (ctx) => "MTU request failed: $e",
          //   duration: const Duration(milliseconds: 2000),
          // );
        }
      } else if (state != BluetoothConnectionState.connected) {
        _hasRequestedMtu = false;
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        try {
          _rssi = await widget.device.readRssi();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {});
      }
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBeacon && (_radio != null || _manualBeacon == false)) {
      return DeviceSetupPage(
        device: widget.device,
        services: _services,
        descriptions: _descCache,
        radioFamily: _radio,
        initialModel: detectModel(widget.device.platformName, _radio),
      );
    }
    return DisconnectGuard(
      connected: widget.device.isConnected,
      child: BlocProvider<CharacteristicBloc>.value(
        value: _characteristicBloc,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Beacon setup'),
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
          ),
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                buildDeviceOverviewTile(context),
                if (!_isBeacon && _manualBeacon == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Device type could not be identified. Choose the type shown on its label.',
                        ),
                        FilledButton(
                          onPressed: () => setState(() => _manualBeacon = true),
                          child: const Text('Beacon — manual setup'),
                        ),
                        TextButton(
                          onPressed:
                              () => setState(() => _manualBeacon = false),
                          child: const Text('Tracker / gateway — device setup'),
                        ),
                      ],
                    ),
                  ),
                if (_isBeacon) ...[
                  if (_beaconGatt)
                    BeaconSnapshot(device: widget.device, services: _services),
                  if (_beaconGatt)
                    const ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Beacon profile detected'),
                      subtitle: Text(
                        'nRF52810 · parameters identified from GATT',
                      ),
                    ),
                  ExpansionTile(
                    title: const Text('Advanced guide & value helpers'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: BeaconGuide(
                          initialModel: detectBeaconModel(
                            widget.device.platformName,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          OutlinedButton.icon(
                            onPressed: !isConnected || _pairing ? null : _pair,
                            icon: const Icon(Icons.link),
                            label: const Text('Pair (if PIN required)'),
                          ),
                          if (_pairing) const LinearProgressIndicator(),
                          if (_pairingStatus.isNotEmpty) Text(_pairingStatus),
                        ],
                      ),
                    ),
                  ExpansionTile(
                    title: const Text('Advanced beacon commands'),
                    subtitle: Text(
                      _beaconGatt
                          ? 'Raw values and hexadecimal editing'
                          : 'Select only characteristics identified for this model',
                    ),
                    children: [buildServices()],
                  ),
                ],
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 0,
                  endIndent: 0,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disconnectOnExit();
    _characteristicBloc.close();
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    super.dispose();
  }

  void _disconnectOnExit() {
    if (_disconnectTriggeredOnExit) return;
    _disconnectTriggeredOnExit = true;
    unawaited(_disconnectSilently());
  }

  Future<void> _disconnectSilently() async {
    try {
      final state = await widget.device.connectionState.first;
      if (state == BluetoothConnectionState.connected ||
          state == BluetoothConnectionState.connecting) {
        await widget.device.disconnectAndUpdateStream(queue: false);
      }
    } catch (_) {
      // Ignore disconnect errors when leaving this page.
    }
  }

  // =============================
  // 生成新的 Service 显示结构（模仿 LightBlue）
  // =============================
  Widget buildServices() {
    if (_services.isEmpty) {
      return const Center(child: Text("No services found"));
    }

    List<Widget> serviceTiles = _buildServiceSync();
    return Column(children: serviceTiles);
  }

  // 同步构建服务和特征列表
  List<Widget> _buildServiceSync() {
    List<Widget> serviceTiles = [];

    for (var s in _services) {
      final serviceUuid = s.uuid.str.toUpperCase();

      // 过滤掉标准服务 1800 和 1801
      if (serviceUuid == "1800" || serviceUuid == "1801") continue;

      List<Widget> characteristicTiles = [];

      for (int i = 0; i < s.characteristics.length; i++) {
        final c = s.characteristics[i];
        final charUuid = c.uuid.str.toUpperCase();
        final isLast = i == s.characteristics.length - 1;

        final description =
            _beaconGatt && shortUuid(s.uuid.str) == 'fff0'
                ? beaconGatt[shortUuid(c.uuid.str)] ?? _descCache[c.uuid.str]
                : _descCache[c.uuid.str];

        // 构建属性文本
        final List<String> props = [];
        if (c.properties.read) {
          props.add('Read');
        }
        if (c.properties.write) {
          props.add('Write');
        }
        if (c.properties.writeWithoutResponse) {
          props.add('WriteWithoutResponse');
        }
        if (c.properties.notify) {
          props.add('Notify');
        }
        if (c.properties.indicate) {
          props.add('Indicate');
        }
        final propsText =
            props.isNotEmpty ? 'Properties: ${props.join(', ')}' : '';

        characteristicTiles.add(
          PeripheralCharacteristicListTile(
            title:
                description?.isNotEmpty == true ? description! : '0x$charUuid',
            value: propsText,
            onTap: () {
              if (!isConnected) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (detailContext) => BlocProvider.value(
                        value: _characteristicBloc,
                        child: CharacteristicDetailPage(
                          device: widget.device,
                          characteristic: c,
                          description: description,
                          descCache: _descCache,
                        ),
                      ),
                ),
              );
            },
            showDivider: !isLast,
          ),
        );
      }

      serviceTiles.add(
        PeripheralServiceTile(
          title: 'Service 0x$serviceUuid',
          titleStyle: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          children: characteristicTiles,
        ),
      );
    }

    return serviceTiles;
  }

  Future<void> initDescriptors() async {
    // 等 300~800ms 给系统稳定时间
    await Future.delayed(const Duration(milliseconds: 500));

    final services = await widget.device.discoverServices();

    final Map<String, String?> descCache = {};

    for (var s in services) {
      for (var c in s.characteristics) {
        for (var d in c.descriptors) {
          if (d.uuid.str.toUpperCase() == "2901") {
            try {
              await d.read().timeout(const Duration(seconds: 2));
              descCache[c.uuid.str] = String.fromCharCodes(d.lastValue);
              await Future.delayed(const Duration(milliseconds: 200));
            } catch (_) {
              descCache[c.uuid.str] = null;
            }
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _services = services;
      _descCache = descCache;
    });
  }

  Future<void> _loadDescriptionsInBackground({bool force = false}) async {
    if (_isLoadingDescriptions) return;
    if (_services.isEmpty) return;
    if (!force && _descCache.isNotEmpty) return;

    if (mounted) {
      setState(() {
        _isLoadingDescriptions = true;
      });
    }

    try {
      await _readAll2901WithRetry(_services);
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingDescriptions = false;
      });
    }
  }

  Future<void> _readAll2901WithRetry(List<BluetoothService> services) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      final loadedCount = await _readAll2901Once(services);
      if (loadedCount > 0 || _descCache.isNotEmpty) return;
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
  }

  Future<int> _readAll2901Once(List<BluetoothService> services) async {
    int loadedCount = 0;
    bool firstChecked = false;

    outer:
    for (final s in services) {
      for (final c in s.characteristics) {
        for (final d in c.descriptors) {
          if (d.uuid.str.toUpperCase() == "2901") {
            try {
              await d.read().timeout(const Duration(seconds: 2));

              if (!firstChecked) {
                firstChecked = true;
                if (d.lastValue.isEmpty) {
                  break outer;
                }
              }

              if (d.lastValue.isNotEmpty) {
                final didUpdate = _updateDescriptionCache(
                  c.uuid.str,
                  String.fromCharCodes(d.lastValue),
                );
                if (didUpdate) {
                  loadedCount++;
                }
              }
              await Future.delayed(const Duration(milliseconds: 40));
            } catch (_) {
              if (!firstChecked) {
                break outer;
              }
            }
          }
        }
      }
    }

    return loadedCount;
  }

  bool _updateDescriptionCache(String charUuid, String description) {
    final oldValue = _descCache[charUuid];
    if (oldValue == description) {
      return false;
    }
    if (!mounted) {
      _descCache[charUuid] = description;
      return true;
    }
    setState(() {
      _descCache[charUuid] = description;
    });
    return true;
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Widget buildDeviceOverviewTile(BuildContext context) {
    final mtuText = _mtuSize != null ? '$_mtuSize' : '--';
    final status = _connectionState.name;
    final statusLabel = '${status[0].toUpperCase()}${status.substring(1)}';
    final statusColors = _connectionStatusColors(_connectionState);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: buildRssiTile(context),
      title: Text(
        '${widget.device.platformName}\n${widget.device.remoteId.str}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'MTU $mtuText',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: statusColors.$2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          statusLabel,
          style: TextStyle(
            color: statusColors.$1,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  (Color, Color) _connectionStatusColors(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        return (Colors.blue, Colors.blue.withValues(alpha: 0.10));
      case BluetoothConnectionState.connecting:
        return (Colors.orange, Colors.orange.withValues(alpha: 0.12));
      case BluetoothConnectionState.disconnecting:
        return (Colors.deepOrange, Colors.deepOrange.withValues(alpha: 0.12));
      case BluetoothConnectionState.disconnected:
        return (Colors.redAccent, Colors.redAccent.withValues(alpha: 0.10));
    }
  }

  Widget buildRssiTile(BuildContext context) {
    final String rssiText =
        (isConnected && _rssi != null) ? '${_rssi!} dBm' : '-- dBm';
    final statusColor = _connectionStatusColors(_connectionState).$1;
    final statusIcon =
        _connectionState == BluetoothConnectionState.connected
            ? Icons.bluetooth_connected
            : (_connectionState == BluetoothConnectionState.connecting
                ? Icons.bluetooth_searching
                : Icons.bluetooth_disabled);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(statusIcon, color: statusColor),
        SizedBox(
          width: 58,
          child: Text(
            rssiText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String toHexString(List<int> bytes) {
    if (bytes.isEmpty) return "";
    return String.fromCharCodes(bytes); // 或者 Hex 格式
  }
}
