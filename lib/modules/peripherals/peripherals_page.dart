import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc/filter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc/filter_states.dart';
import 'package:flutter_blue/utils/ble_scan_coordinator.dart';
import 'package:flutter_blue/utils/extra.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';

class PeripheralsPage extends StatefulWidget {
  const PeripheralsPage({super.key});

  @override
  State<PeripheralsPage> createState() => _PeripheralsPageState();
}

class _UserCanceledConnection implements Exception {}

class _PeripheralsPageState extends State<PeripheralsPage> {
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  List<ScanResult> scanResults = [];

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      if (!BleScanCoordinator.instance.isOwnerActive(
        BleScanCoordinator.devicesOwner,
      )) {
        return;
      }

      setState(() {
        scanResults =
            results.where((r) {
                final name = r.device.platformName;
                if (name.isEmpty) return false;
                return true;
              }).toList()
              ..sort((a, b) => b.rssi.compareTo(a.rssi));
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    _scanResultsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<FilterBloc, FilterState>(
        builder: (context, state) {
          // 获取共享的 rssiEnabled 和 minRssi
          final rssiEnabled = state.rssiEnabled;
          final minRssi = state.minRssi;

          // 计算过滤后的结果
          final searchText = searchController.text.trim().toLowerCase();
          final filteredResults =
              scanResults.where((r) {
                final name = r.device.platformName;
                if (name.isEmpty) return false;
                if (!name.toLowerCase().startsWith(searchText)) {
                  return false;
                }
                if (rssiEnabled && r.rssi < minRssi) return false;
                return true;
              }).toList();
          return Column(
            children: [
              // 上半部分：扫描到的设备 + 输入框
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanned Devices: ${filteredResults.isNotEmpty ? filteredResults.length : "None"}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 输入框部分
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search devices by name',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        // 🔹 右侧清空按钮
                        suffixIcon:
                            searchController.text.isEmpty
                                ? null
                                : IconButton(
                                  icon: const Icon(Icons.cancel),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {}); // 触发过滤刷新
                                  },
                                ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(3),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filteredResults.length,
                    itemBuilder: (context, index) {
                      final result = filteredResults[index];
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await BleScanCoordinator.instance.stop(
                                        BleScanCoordinator.devicesOwner,
                                      );
                                    } catch (e) {
                                      debugPrint(
                                        "Stop devices scan before connect failed: $e",
                                      );
                                    }
                                    onConnectPressed(result.device);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    side: BorderSide(
                                      color: Colors.blue,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text(
                                    'Connect',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 22),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            onTap: () {},
                          ),
                          // 🔹 分割线，最后一行不显示
                          if (index != filteredResults.length - 1)
                            const Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 16,
                              endIndent: 16,
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
        },
      ),
    );
  }

  void onConnectPressed(BluetoothDevice device) async {
    bool canceledByUser = false;

    void throwIfCanceled() {
      if (canceledByUser) {
        throw _UserCanceledConnection();
      }
    }

    // 显示连接中弹框
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Connecting…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(device.platformName, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              const SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    canceledByUser = true;
                    unawaited(device.disconnect().catchError((_) {}));
                    if (!mounted) return;
                    Navigator.of(context, rootNavigator: true).maybePop(false);
                  },
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      // 先断开可能残留连接
      try {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 300)); // 等待链路释放
      } catch (_) {}
      throwIfCanceled();

      // 2️⃣ 移除残留配对（仅 Android）
      try {
        BluetoothBondState state = await device.bondState.first;
        if (state == BluetoothBondState.bonded) {
          print("移除旧配对中...");
          await device.removeBond();
          await Future.delayed(const Duration(milliseconds: 500)); // 等待解除
        }
      } catch (_) {}
      throwIfCanceled();

      // 连接设备
      await device.connectAndUpdateStream();
      // 等待connected
      await device.connectionState.firstWhere(
        (s) => s == BluetoothConnectionState.connected,
      );
      throwIfCanceled();
      // 等待bonded
      try {
        await device.bondState
            .firstWhere((s) => s == BluetoothBondState.bonded)
            .timeout(const Duration(seconds: 20));
      } catch (_) {}
      throwIfCanceled();

      // small delay
      await Future.delayed(const Duration(milliseconds: 500));
      throwIfCanceled();
      // discover
      final services = await device.discoverServices();
      throwIfCanceled();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop(true);
      context.push(
        '/home/peripheral_characteristics',
        extra: {
          'device': device,
          'services': services,
          'descCache': <String, String?>{},
        },
      );
    } catch (e) {
      if (e is _UserCanceledConnection || canceledByUser) {
        return;
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop(false);
      debugPrint("Connect Error ${device.advName}: $e");
    }
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
}
