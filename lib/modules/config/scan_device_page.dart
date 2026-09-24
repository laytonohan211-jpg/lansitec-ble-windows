import '../../utils/stable_scan_stream.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/config/bloc/device_bloc.dart';
import 'package:flutter_blue/modules/config/bloc/device_events.dart';
import 'package:flutter_blue/modules/config/bloc/device_states.dart';
import 'package:flutter_blue/modules/device/domain/failed_device.dart';
import 'package:flutter_blue/modules/device/domain/updated_device.dart';
import 'package:flutter_blue/utils/ble_scan_coordinator.dart';
import 'package:flutter_blue/utils/extra.dart';
import 'package:flutter_blue/utils/snackbar.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScanDevicePage extends StatefulWidget {
  const ScanDevicePage({super.key});

  @override
  State<ScanDevicePage> createState() => _ScanDevicePageState();
}

class _ScanDevicePageState extends State<ScanDevicePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final DeviceBloc deviceBloc;

  bool _isExpanded = true;
  bool _updatingExpanded = true;
  late TextEditingController _nameController;
  late TextEditingController _intervalController;
  final _nameFocus = FocusNode();
  final _intervalFocus = FocusNode();
  // V1.0 Lunci
  final Map<int, String> txPowerMapV10 = const {
    0x01: '-20 dBm',
    0x02: '-15 dBm',
    0x03: '-10 dBm',
    0x04: '-6 dBm',
    0x05: '-5 dBm',
    0x06: '-2 dBm',
    0x07: '0 dBm',
    0x08: '3 dBm',
    0x09: '4 dBm',
    0x0A: '5 dBm',
  };
  // V1.1 52810(8个)
  final Map<int, String> txPowerMapV11 = const {
    0x01: '-20 dBm',
    0x02: '-16 dBm',
    0x03: '-12 dBm',
    0x04: '-8 dBm',
    0x05: '-4 dBm',
    0x06: '0 dBm',
    0x07: '4 dBm',
  };
  int appleManufacturerId = 0x004C; // 苹果 iBeacon

  Map<int, String> get currentTxPowerMap =>
      deviceBloc.state.selectedHardware == 'V1.0'
          ? txPowerMapV10
          : txPowerMapV11;

  final BleScanCoordinator _scanCoordinator = BleScanCoordinator.instance;
  bool _scanRequested = false;
  bool _isBatchRunning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<Set<String>> _scanOwnersSubscription;
  List<ScanResult> _scanResults = [];
  ScanResult? updatingDevice;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController blueController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    deviceBloc = context.read<DeviceBloc>();

    _nameController = TextEditingController(text: deviceBloc.state.nameText);
    _intervalController = TextEditingController(
      text: deviceBloc.state.intervalText,
    );

    blueController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _scanRequested = _scanCoordinator.isOwnerActive(
      BleScanCoordinator.batchConfigOwner,
    );

    _scanResultsSubscription = stableScanStream<ScanResult>(FlutterBluePlus.scanResults,
      id: (r) => r.device.remoteId.str,
      compareNew: (a, b) => b.rssi.compareTo(a.rssi),
    ).listen(
      (results) {
        if (!mounted) return;
        final hasOwnership = _scanCoordinator.isOwnerActive(
          BleScanCoordinator.batchConfigOwner,
        );
        if (!hasOwnership && !_isBatchRunning) {
          return;
        }

        final nameFilter = deviceBloc.state.nameText.trim().toLowerCase();

        // 提前生成 Set 提升查找性能
        final updatedIds =
            deviceBloc.state.updatedDevices.map((e) => e.id).toSet();
        final versionMismatchIds =
            deviceBloc.state.failedDevices
                .where((e) => e.message == 'Version mismatch')
                .map((e) => e.id)
                .toSet();

        setState(() {
          _scanResults =
              results.where((r) {
                  final name = r.device.platformName;
                  if (name.isEmpty) return false;
                  if (!name.toLowerCase().startsWith(nameFilter)) return false;

                  final deviceId = r.device.remoteId.str;
                  if (updatedIds.contains(deviceId)) return false;
                  if (versionMismatchIds.contains(deviceId)) return false;

                  return true;
                }).toList();
        });
      },
      onError: (e) {
        Snackbar.show(ABC.d, prettyException("Scan Error:", e), success: false);
      },
    );

    _scanOwnersSubscription = _scanCoordinator.ownersStream.listen((owners) {
      if (mounted) {
        setState(() {
          _scanRequested = owners.contains(BleScanCoordinator.batchConfigOwner);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scanResultsSubscription.cancel();
    _scanOwnersSubscription.cancel();
    blueController.dispose();
    _nameController.dispose();
    _intervalController.dispose();
    if (_scanRequested) {
      unawaited(_scanCoordinator.stop(BleScanCoordinator.batchConfigOwner));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须加
    return Column(
      children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Device Configuration",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
        ),

        // Config content
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child:
                _isExpanded ? _buildConfigContent() : const SizedBox.shrink(),
          ),
        ),

        // Updating Header
        GestureDetector(
          onTap: () => setState(() => _updatingExpanded = !_updatingExpanded),
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Updating Device",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Icon(
                  _updatingExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
        ),

        // Updating content
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child:
                _updatingExpanded
                    ? _buildUpdatingContent()
                    : const SizedBox.shrink(),
          ),
        ),

        // Device List
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                "Device List: ${_scanResults.length}",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12), // 标题和加载动画间距
              if (_scanRequested)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blueAccent,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
            ],
          ),
        ),

        // Device ListView
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(3),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -4),
                      title: Text(
                        result.device.platformName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      leading: rssiIcon(result.rssi),
                      subtitle: Text(
                        result.device.remoteId.str,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.bluetooth),
                      onTap: () {},
                    ),
                    // 🔹 分割线，最后一行不显示
                    if (index != _scanResults.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 16, // 和 ListTile 的 leading 对齐
                        endIndent: 16, // 和 ListTile 内容对齐
                        color: Colors.grey,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigContent() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Device Name Filter
          BlocListener<DeviceBloc, DeviceState>(
            listenWhen: (p, c) => p.nameText != c.nameText,
            listener: (context, state) {
              // 仅在 controller 没有焦点时更新，避免用户输入被打断
              if (!_nameFocus.hasFocus &&
                  _nameController.text != state.nameText) {
                _nameController.text = state.nameText;
              }
            },
            child: TextField(
              focusNode: _nameFocus,
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Device Name Filter",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) {
                context.read<DeviceBloc>().add(UpdateScanConfig(nameText: v));
                print('过滤名称更新为: $v');
              },
            ),
          ),
          const SizedBox(height: 8),

          // Hardware Type dropdown
          BlocBuilder<DeviceBloc, DeviceState>(
            builder: (context, state) {
              return DropdownButtonFormField<String>(
                value: state.selectedHardware,
                decoration: InputDecoration(
                  labelText: "Hardware Type",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: "V1.0", child: Text("V1.0")),
                  DropdownMenuItem(value: "V1.1", child: Text("V1.1")),
                ],
                onChanged: (v) {
                  if (v == null) return;

                  // 根据新硬件选择对应的 TxPower Map
                  final txMap = v == 'V1.0' ? txPowerMapV10 : txPowerMapV11;

                  // 如果当前 selectedTxPower 不在新硬件 Map 中，使用第一个合法值
                  int newTxPower = state.selectedTxPower ?? txMap.keys.first;
                  if (!txMap.containsKey(state.selectedTxPower)) {
                    newTxPower = txMap.keys.first;
                  }

                  context.read<DeviceBloc>().add(
                    UpdateScanConfig(
                      selectedHardware: v,
                      selectedTxPower: newTxPower,
                    ),
                  );
                },
                style: const TextStyle(fontSize: 12, color: Colors.black),
              );
            },
          ),
          const SizedBox(height: 8),

          // Tx Power & Interval in one row
          Row(
            children: [
              // Tx Power checkbox + dropdown
              Expanded(
                child: BlocBuilder<DeviceBloc, DeviceState>(
                  builder: (context, state) {
                    return Row(
                      children: [
                        Checkbox(
                          value: state.txPowerEnabled,
                          onChanged:
                              (v) => context.read<DeviceBloc>().add(
                                UpdateScanConfig(txPowerEnabled: v!),
                              ),
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: state.selectedTxPower,
                            decoration: InputDecoration(
                              labelText: "Tx Power",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            items:
                                currentTxPowerMap.entries
                                    .map(
                                      (e) => DropdownMenuItem<int>(
                                        value: e.key,
                                        child: Text(
                                          e.value,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                state.txPowerEnabled
                                    ? (v) => context.read<DeviceBloc>().add(
                                      UpdateScanConfig(selectedTxPower: v),
                                    )
                                    : null,
                            disabledHint: const Text(
                              "Disabled",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Interval checkbox + text field
              Expanded(
                child: BlocListener<DeviceBloc, DeviceState>(
                  listenWhen:
                      (p, c) =>
                          p.intervalText != c.intervalText ||
                          p.intervalEnabled != c.intervalEnabled,
                  listener: (context, state) {
                    if (!_intervalFocus.hasFocus &&
                        _intervalController.text != state.intervalText) {
                      _intervalController.text = state.intervalText;
                    }
                  },
                  child: BlocBuilder<DeviceBloc, DeviceState>(
                    buildWhen:
                        (p, c) =>
                            p.intervalText != c.intervalText ||
                            p.intervalEnabled != c.intervalEnabled,
                    builder: (context, state) {
                      return Row(
                        children: [
                          Checkbox(
                            value: state.intervalEnabled,
                            onChanged: (v) {
                              context.read<DeviceBloc>().add(
                                UpdateScanConfig(intervalEnabled: v!),
                              );
                            },
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              focusNode: _intervalFocus,
                              controller: _intervalController,
                              keyboardType: TextInputType.number,
                              enabled: state.intervalEnabled,
                              decoration: InputDecoration(
                                labelText: "Interval (ms)",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (v) {
                                context.read<DeviceBloc>().add(
                                  UpdateScanConfig(intervalText: v),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildScanButton(),
              const SizedBox(width: 6),
              buildBatchButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatingContent() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          if (updatingDevice != null)
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              title: Text(
                updatingDevice!.device.platformName,
                style: const TextStyle(fontSize: 14, color: Colors.blue),
              ),
              leading: Text(
                updatingDevice!.rssi.toString(),
                style: TextStyle(color: Colors.blue),
              ),
              subtitle: Text(
                updatingDevice!.device.remoteId.str,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
              trailing: RotationTransition(
                turns: blueController,
                child: const Icon(Icons.bluetooth, color: Colors.blue),
              ),
              onTap: () {},
            )
          else
            const Text(
              "No device is being updated.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  ElevatedButton buildBatchButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (!_isBatchRunning) {
          onBatchStartPressed();
        } else {
          onBatchStopPressed();
        }
      },
      icon: Icon(
        _isBatchRunning ? Icons.stop : Icons.play_arrow,
        size: 16,
        color: Colors.white,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isBatchRunning ? Colors.redAccent : Color(0xFF409EFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      label: Text(
        _isBatchRunning ? "Stop Batch Config" : "Start Batch Config",
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget buildScanButton() {
    final bool scanning = _scanRequested;
    return ElevatedButton.icon(
      onPressed: () async {
        if (scanning) {
          await onStopPressed();
        } else {
          await onScanPressed();
        }
      },
      icon: Icon(
        scanning ? Icons.stop : Icons.play_arrow,
        size: 16,
        color: Colors.white,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: scanning ? Colors.redAccent : Color(0xFF409EFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      label: Text(
        scanning ? "Stop Scan" : "Start Scan",
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget rssiIcon(int rssi) {
    // 将 RSSI 映射为 0~5 级信号
    int level = 0;
    if (rssi >= -45) {
      level = 5;
    } else if (rssi >= -55) {
      level = 4;
    } else if (rssi >= -65) {
      level = 3;
    } else if (rssi >= -75) {
      level = 2;
    } else if (rssi >= -85) {
      level = 1;
    } else {
      level = 0;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end, // 底部对齐
      children: [
        // 信号条图标
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (index) {
            return Container(
              width: 2,
              height: (index + 1) * 3.0,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: index < level ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        // RSSI 数值
        Text(
          rssi.toString(),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Future onScanPressed() async {
    try {
      await _scanCoordinator.start(
        BleScanCoordinator.batchConfigOwner,
        timeout: const Duration(seconds: 30),
      );
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.d,
        prettyException("Start Scan Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      await _scanCoordinator.stop(BleScanCoordinator.batchConfigOwner);
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.d,
        prettyException("Stop Scan Error:", e),
        success: false,
      );
      print(e);
      print("backtrace: $backtrace");
    }
  }

  Future onBatchStartPressed() async {
    setState(() {
      _isBatchRunning = true;
    });
    startBatchConfig();
  }

  Future onBatchStopPressed() async {
    setState(() {
      _isBatchRunning = false;
    });
    stopBatchConfig();
  }

  Future startBatchConfig() async {
    if (_isBatchRunning == false) {
      return;
    }
    if (deviceBloc.state.txPowerEnabled == false &&
        deviceBloc.state.intervalEnabled == false) {
      return;
    }
    // 扫描设备
    ScanResult? scanResult = await scanDeviceWithRetry(maxAttempts: 3);
    if (scanResult == null) {
      showError('Device not scanned');
      await Future.delayed(Duration(seconds: 120));
      nextBatchConfig();
      return;
    }
    // 显示正在更新的设备
    setUpdatingDevice(scanResult);

    // 连接设备
    BluetoothDevice device = scanResult.device;
    final manufacturerData = scanResult.advertisementData.manufacturerData;
    final data = manufacturerData[appleManufacturerId];

    final result = extractMajorMinor(data);
    String major = result['major'] ?? '0';
    String minor = result['minor'] ?? '0';
    bool connected = await connectWithRetry(device);
    if (!connected) {
      showError('Connection failed: ${device.platformName}');
      handleConnectionFailed(device, major, minor);
      return;
    }
    // 配对设备
    bool bonded = await bondWithRetry(device, pin: '116321', maxAttempts: 3);
    if (!bonded) {
      print("设备 ${device.platformName} 配对失败。");
    }
    // 检查硬件版本
    String? firstChar = await getServiceFirstChar(device);
    final charUuid = getCharUuid(deviceBloc.state.selectedHardware);
    if (firstChar == null ||
        charUuid == null ||
        !firstChar.contains(charUuid)) {
      showError('Version mismatch: ${device.platformName}');
      handleVersionMismatch(device, major, minor);
      return;
    }

    if (deviceBloc.state.txPowerEnabled) {
      bool txPowerSuccess = await writeAndVerifyTxPower(device);
      if (!txPowerSuccess) {
        bool stillConnected = await checkDeviceConnected(device);
        if (stillConnected) {
          showError('Tx Power configuration failed: ${device.platformName}');
          handleWriteFailedWithoutDisconnect(
            device,
            'Tx Power write failed',
            major,
            minor,
          );
          return;
        } else {
          print("❌ Tx Power 检测到设备已断开");
          handleWriteFailedDisconnect(device, major, minor);
          return;
        }
      }
    }
    if (deviceBloc.state.intervalEnabled) {
      bool intervalSuccess = await writeAndVerifyInterval(device);
      if (!intervalSuccess) {
        bool stillConnected = await checkDeviceConnected(device);
        if (stillConnected) {
          showError('Interval configuration failed: ${device.platformName}');
          handleWriteFailedWithoutDisconnect(
            device,
            'Interval write failed',
            major,
            minor,
          );
          return;
        } else {
          print("❌ Interval 检测到设备已断开");
          handleWriteFailedDisconnect(device, major, minor);
          return;
        }
      }
    }
    print("🎯 升级完成: ${device.platformName}");
    showSuccess('Configuration successful: ${device.platformName}');
    handleConfigSuccessful(device, major, minor);
  }

  // 重试批量配置
  Future retryBatchConfig(
    BluetoothDevice device,
    String major,
    String minor,
  ) async {
    if (_isBatchRunning == false) {
      return;
    }
    // 连接设备
    bool connected = await connectWithRetry(device);
    if (!connected) {
      showError('Retry connection failed: ${device.platformName}');
      handleConnectionFailed(device, major, minor);
      return;
    }
    // 配对设备
    bool bonded = await bondWithRetry(device, pin: '116321', maxAttempts: 3);
    if (!bonded) {
      print("设备 ${device.platformName} 配对失败。");
    }
    // 写入配置
    if (deviceBloc.state.txPowerEnabled) {
      bool txPowerSuccess = await writeAndVerifyTxPower(device);
      if (!txPowerSuccess) {
        showError(
          'Retry Tx Power configuration failed: ${device.platformName}',
        );
        handleWriteFailedWithoutDisconnect(
          device,
          'Tx Power write failed',
          major,
          minor,
        );
        return;
      }
    }
    if (deviceBloc.state.intervalEnabled) {
      bool intervalSuccess = await writeAndVerifyInterval(device);
      if (!intervalSuccess) {
        showError(
          'Retry Interval configuration failed: ${device.platformName}',
        );
        handleWriteFailedWithoutDisconnect(
          device,
          'Interval write failed',
          major,
          minor,
        );
        return;
      }
    }
    print("🎯 升级完成: ${device.platformName}");
    showSuccess('Retry configuration successful: ${device.platformName}');
    handleConfigSuccessful(device, major, minor);
  }

  Future<bool> checkDeviceConnected(
    BluetoothDevice device, {
    int maxAttempts = 10, // 检测次数
    Duration delay = const Duration(seconds: 5), // 每次间隔
  }) async {
    for (int i = 1; i <= maxAttempts; i++) {
      final state = await device.connectionState.first;
      print("🔍 第 $i 次检测设备状态: $state");

      if (state == BluetoothConnectionState.disconnected) {
        print("⚠️ 设备已断开连接");
        return false; // 提前返回：发现断开
      }

      // 不是最后一次则延时
      if (i < maxAttempts) {
        await Future.delayed(delay);
      }
    }
    print("✅ 检测期间设备一直保持连接");
    return true; // 全部检测完成且都保持连接
  }

  void addDeviceToUpdatedList(
    BluetoothDevice device,
    String major,
    String minor,
  ) {
    final isAlreadyAdded = deviceBloc.state.updatedDevices.any(
      (d) => d.id == device.remoteId.str,
    );

    // ✅ 如果已存在，直接返回
    if (isAlreadyAdded) return;

    final txPowerString =
        currentTxPowerMap[deviceBloc.state.selectedTxPower] ?? '';

    final newDevice = UpdatedDevice(
      name: device.platformName,
      id: device.remoteId.str,
      txPower: deviceBloc.state.txPowerEnabled ? txPowerString : 'default',
      hardware: deviceBloc.state.selectedHardware,
      interval:
          deviceBloc.state.intervalEnabled
              ? int.tryParse(deviceBloc.state.intervalText) ?? 0
              : 0,
      major: major,
      minor: minor,
    );

    deviceBloc.add(AddUpdatedDevice(newDevice));
  }

  void removeFailedItem(BluetoothDevice device) {
    final isFailedDevices = deviceBloc.state.failedDevices.any(
      (d) => d.id == device.remoteId.str,
    );
    // ✅ 如果在失败列表中，移除它
    if (!isFailedDevices) return;
    deviceBloc.add(
      RemoveFailedDevice(
        FailedDevice(
          name: device.platformName,
          id: device.remoteId.str,
          txPower: 'default',
          hardware: 'default',
          interval: 0,
        ),
      ),
    );
  }

  void handleConnectionFailed(
    BluetoothDevice device,
    String major,
    String minor,
  ) {
    addFailedDevice(device, 'Connection failed', major, minor);
    removeScanItem(device);
    nextBatchConfig();
  }

  void handleVersionMismatch(
    BluetoothDevice device,
    String major,
    String minor,
  ) {
    addFailedDevice(device, 'Version mismatch', major, minor);
    clearUpdatingDevice();
    removeScanItem(device);
    disconnectDevice(device);
    nextBatchConfig();
  }

  void handleWriteFailedWithoutDisconnect(
    BluetoothDevice device,
    String message,
    String major,
    String minor,
  ) {
    addFailedDevice(device, message, major, minor);
    clearUpdatingDevice();
    removeScanItem(device);
    disconnectDevice(device);
    nextBatchConfig();
  }

  void handleWriteFailedDisconnect(
    BluetoothDevice device,
    String major,
    String minor,
  ) {
    clearUpdatingDevice();
    removeScanItem(device);
    retryBatchConfig(device, major, minor);
  }

  void handleConfigSuccessful(
    BluetoothDevice device,
    String major,
    String minor,
  ) {
    clearUpdatingDevice();
    removeScanItem(device);
    disconnectDevice(device);
    addDeviceToUpdatedList(device, major, minor);
    removeFailedItem(device);
    nextBatchConfig();
  }

  void removeScanItem(BluetoothDevice device) {
    setState(() {
      _scanResults.removeWhere((r) => r.device.remoteId == device.remoteId);
    });
  }

  Future disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnectAndUpdateStream();
    } catch (e, backtrace) {
      Snackbar.show(
        ABC.d,
        prettyException("Disconnect Error:", e),
        success: false,
      );
      print("$e backtrace: $backtrace");
    }
  }

  Future<void> nextBatchConfig({
    Duration delay = const Duration(seconds: 5),
  }) async {
    await Future.delayed(delay);
    await startBatchConfig();
  }

  Future stopBatchConfig() async {
    clearUpdatingDevice();
    onStopPressed();
  }

  Future<ScanResult?> scanDeviceWithRetry({
    int maxAttempts = 3,
    Duration scanDuration = const Duration(seconds: 30),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_isBatchRunning == false) {
        return null;
      }
      if (_scanResults.isEmpty) {
        await onScanPressed();
        await Future.delayed(scanDuration);
        await onStopPressed();
      }

      if (_scanResults.isNotEmpty) {
        return _scanResults.first;
      }

      print('第 $attempt 次扫描未找到设备。');
    }

    print('尝试 $maxAttempts 次都没有找到设备，停止执行后续操作。');
    return null;
  }

  Future<bool> connectWithRetry(BluetoothDevice device) async {
    const int maxAttempts = 3;
    int attempt = 0;

    while (attempt < maxAttempts) {
      if (_isBatchRunning == false) {
        return false;
      }
      attempt++;
      try {
        await device.connectAndUpdateStream();
        print('连接成功: ${device.platformName}');
        return true;
      } catch (e) {
        print('第 $attempt 次连接失败: $e');
        if (attempt >= maxAttempts) {
          print('连接失败超过 $maxAttempts 次');
          return false;
        }
      }
    }

    return false;
  }

  Future<bool> bondWithRetry(
    BluetoothDevice device, {
    required String pin,
    int maxAttempts = 3,
  }) async {
    if (Platform.isWindows) {
      // Pair in Windows Settings before starting a protected batch.
      // GATT writes still fail visibly if the device is not authorized.
      return true;
    }
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final bondState = await device.bondState.first;

        if (bondState == BluetoothBondState.bonded) {
          print("✅ 设备 ${device.platformName} 已配对");
          return true;
        }

        print("第 $attempt 次尝试配对 ${device.platformName}...");
        await device.createBond(pin: Uint8List.fromList(pin.codeUnits));
        // 等待 bondState 更新
        await Future.delayed(const Duration(seconds: 2));
        // 再检查一次
        final newBondState = await device.bondState.first;
        if (newBondState == BluetoothBondState.bonded) {
          print("✅ 设备 ${device.platformName} 配对成功");
          return true;
        } else {
          print("⚠️ 第 $attempt 次尝试后仍未配对成功");
        }
      } catch (e) {
        print("⚠️ 第 $attempt 次配对异常: $e");
      }
    }
    print("❌ 设备 ${device.platformName} 配对失败超过 $maxAttempts 次");
    return false;
  }

  Future<String?> getServiceFirstChar(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      var service = findServiceFFF0(services);
      if (service == null) return null;
      return service.characteristics.isNotEmpty
          ? service.characteristics.first.uuid.toString().toUpperCase()
          : null;
    } catch (e) {
      return null;
    }
  }

  BluetoothService? findServiceFFF0(List<BluetoothService> services) {
    for (var s in services) {
      String uuid = s.uuid.toString().toUpperCase();
      if (uuid.length == 4) uuid = "0000$uuid-0000-1000-8000-00805F9B34FB";
      if (uuid == "0000FFF0-0000-1000-8000-00805F9B34FB") {
        print("找到 FFF0 服务");
        return s;
      }
    }
    return null;
  }

  String? getCharUuid(String hardware) {
    switch (hardware) {
      case 'V1.0':
        return "FFF3";
      case 'V1.1':
        return "FFF5";
      default:
        return null;
    }
  }

  Future<BluetoothCharacteristic?> getIntervalChar(
    BluetoothDevice device,
  ) async {
    List<BluetoothService> services = await device.discoverServices();
    var service = findServiceFFF0(services);
    if (service == null) return null;
    return findIntervalFFF8(service);
  }

  Future<BluetoothCharacteristic?> getTxPowerChar(
    BluetoothDevice device,
  ) async {
    List<BluetoothService> services = await device.discoverServices();
    var service = findServiceFFF0(services);
    if (service == null) return null;
    return findTxPowerFFF9(service);
  }

  BluetoothCharacteristic? findIntervalFFF8(BluetoothService service) {
    for (var c in service.characteristics) {
      String uuid = c.uuid.toString().toUpperCase();
      if (uuid.length == 4) uuid = "0000$uuid-0000-1000-8000-00805F9B34FB";
      if (uuid == "0000FFF8-0000-1000-8000-00805F9B34FB") {
        print("找到 FFF8 特征值");
        return c;
      }
    }
    return null;
  }

  BluetoothCharacteristic? findTxPowerFFF9(BluetoothService service) {
    for (var c in service.characteristics) {
      String uuid = c.uuid.toString().toUpperCase();
      if (uuid.length == 4) uuid = "0000$uuid-0000-1000-8000-00805F9B34FB";
      if (uuid == "0000FFF9-0000-1000-8000-00805F9B34FB") {
        print("找到 FFF9 特征值");
        return c;
      }
    }
    return null;
  }

  Future<bool> writeAndVerifyInterval(BluetoothDevice device) async {
    try {
      // 获取特征值
      var txPower = await getIntervalChar(device);
      if (txPower == null) {
        print("❌ 未找到 FFF8 特征值");
        return false;
      }

      // 写入数据
      int valueMs = int.tryParse(deviceBloc.state.intervalText) ?? 5000;
      int value = (valueMs ~/ 100).clamp(0, 255);
      await txPower.write([value, 0x00, 0x00, 0x00]);
      print("➡️ FFF8 写入数据: $value");

      // 读取确认
      var readValue = await txPower.read();
      if (readValue.isNotEmpty && readValue[0] == value) {
        print("✅ 写入确认成功: $value");
        return true;
      } else {
        print("❌ 写入确认失败，读取值: $readValue");
        return false;
      }
    } catch (e) {
      print("Bond/Write 失败: $e");
      return false;
    }
  }

  Future<bool> writeAndVerifyTxPower(BluetoothDevice device) async {
    try {
      // 获取特征值
      var txPower = await getTxPowerChar(device);
      if (txPower == null) {
        print("❌ 未找到 FFF9 特征值");
        return false;
      }

      // 写入数据
      int value = deviceBloc.state.selectedTxPower ?? 0x02;
      await txPower.write([value]);
      print("➡️ FFF9 写入数据: $value");

      // 读取确认
      var readValue = await txPower.read();
      if (readValue.isNotEmpty && readValue[0] == value) {
        print("✅ 写入确认成功: $value");
        return true;
      } else {
        print("❌ 写入确认失败，读取值: $readValue");
        return false;
      }
    } catch (e) {
      print("Bond/Write 失败: $e");
      return false;
    }
  }

  addFailedDevice(
    BluetoothDevice device,
    String message,
    String major,
    String minor,
  ) {
    final isFailedDevices = deviceBloc.state.failedDevices.any(
      (d) => d.id == device.remoteId.str,
    );
    // ✅ 如果已存在，直接返回
    if (isFailedDevices) return;

    final txPowerString =
        currentTxPowerMap[deviceBloc.state.selectedTxPower] ?? '';
    final failedDevice = FailedDevice(
      name: device.platformName,
      id: device.remoteId.str,
      txPower: deviceBloc.state.txPowerEnabled ? txPowerString : 'default',
      hardware: deviceBloc.state.selectedHardware,
      interval:
          deviceBloc.state.intervalEnabled
              ? int.tryParse(deviceBloc.state.intervalText) ?? 0
              : 0,
      message: message,
      major: major,
      minor: minor,
    );
    deviceBloc.add(AddFailedDevice(failedDevice));
  }

  void clearUpdatingDevice() {
    if (mounted) {
      setState(() {
        updatingDevice = null;
      });
    }
  }

  void setUpdatingDevice(ScanResult scanResult) {
    if (mounted) {
      setState(() {
        updatingDevice = scanResult;
      });
    }
  }

  showSuccess(String message) {
    Snackbar.show(ABC.d, message, success: true);
  }

  showError(String message) {
    Snackbar.show(ABC.d, message, success: false);
  }

  Map<String, String> extractMajorMinor(List<int>? data) {
    if (data == null || data.length < 22) {
      return {'major': '0', 'minor': '0'}; // 数据不足，返回默认
    }

    // 提取 major、minor 字节
    final majorBytes = data.sublist(18, 20); // 索引18-19
    final minorBytes = data.sublist(20, 22); // 索引20-21

    final majorHex = bytesToHex4(majorBytes);
    final minorHex = bytesToHex4(minorBytes);

    return {'major': majorHex, 'minor': minorHex};
  }

  String bytesToHex4(List<int> bytes) {
    final value = (bytes[0] << 8) + bytes[1];
    return value.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
