import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc/filter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc/filter_states.dart';
import 'package:flutter_blue/modules/peripherals/peripheral_filter_page.dart';
import 'package:flutter_blue/modules/peripherals/peripherals_page.dart';
import 'package:flutter_blue/utils/ble_scan_coordinator.dart';

class PeripheralsMainPage extends StatefulWidget {
  const PeripheralsMainPage({super.key});

  @override
  State<PeripheralsMainPage> createState() => _PeripheralsMainPageState();
}

class _PeripheralsMainPageState extends State<PeripheralsMainPage> {
  final ValueNotifier<int> selectedIndexNotifier = ValueNotifier(0);
  final BleScanCoordinator _scanCoordinator = BleScanCoordinator.instance;
  late StreamSubscription<Set<String>> _scanOwnersSubscription;
  bool _isDevicesScanRequested = false;

  void _switchToFilterPage() {
    selectedIndexNotifier.value = 1;
  }

  @override
  void initState() {
    super.initState();
    _isDevicesScanRequested = _scanCoordinator.isOwnerActive(
      BleScanCoordinator.devicesOwner,
    );
    _scanOwnersSubscription = _scanCoordinator.ownersStream.listen((owners) {
      if (mounted) {
        setState(() {
          _isDevicesScanRequested = owners.contains(
            BleScanCoordinator.devicesOwner,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _scanOwnersSubscription.cancel();
    selectedIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FilterBloc(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: ValueListenableBuilder<int>(
            valueListenable: selectedIndexNotifier,
            builder: (context, selectedIndex, _) {
              return Row(
                children: [
                  if (selectedIndex == 1)
                    GestureDetector(
                      onTap: () {
                        selectedIndexNotifier.value = 0;
                      },
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  if (selectedIndex == 1) const SizedBox(width: 12),
                  Text(
                    selectedIndex == 0 ? 'Devices' : 'Filter RSSI',
                    style: const TextStyle(color: Colors.black),
                  ),
                ],
              );
            },
          ),

          actions: [
            ValueListenableBuilder<int>(
              valueListenable: selectedIndexNotifier,
              builder: (_, selectedIndex, __) {
                // PeripheralsPage 显示扫描、排序、搜索等按钮
                if (selectedIndex == 0) {
                  return Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            if (_isDevicesScanRequested) {
                              await _scanCoordinator.stop(
                                BleScanCoordinator.devicesOwner,
                              );
                            } else {
                              await _scanCoordinator.start(
                                BleScanCoordinator.devicesOwner,
                              );
                            }
                          } catch (e) {
                            debugPrint("Devices scan toggle failed: $e");
                          }
                        },
                        icon: Icon(
                          _isDevicesScanRequested
                              ? Icons.stop
                              : Icons.play_arrow,
                          size: 16,
                          color: Colors.white,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isDevicesScanRequested
                                  ? Colors.red
                                  : Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(80, 35),
                        ),
                        label: Text(
                          _isDevicesScanRequested ? 'Stop Scan' : 'Start Scan',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 60),
                      // IconButton(
                      //   icon: const Icon(Icons.sort),
                      //   onPressed: () {},
                      // ),
                      BlocBuilder<FilterBloc, FilterState>(
                        builder: (context, state) {
                          return IconButton(
                            icon: Icon(
                              state.rssiEnabled
                                  ? Icons
                                      .filter_alt // 开启时显示实心
                                  : Icons.filter_alt_outlined, // 关闭时显示空心
                              color:
                                  state.rssiEnabled
                                      ? Colors.blue
                                      : Colors.black,
                            ),
                            onPressed: _switchToFilterPage, // 切换到 Filter 页面
                          );
                        },
                      ),

                      const SizedBox(width: 20),
                    ],
                  );
                } else {
                  // Filter 页面只显示空或保存按钮
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: selectedIndexNotifier,
          builder: (_, selectedIndex, __) {
            return IndexedStack(
              index: selectedIndex,
              children: const [
                PeripheralsPage(),
                PeripheralFilterPage(), // 这里不需要 Scaffold
              ],
            );
          },
        ),
      ),
    );
  }
}
