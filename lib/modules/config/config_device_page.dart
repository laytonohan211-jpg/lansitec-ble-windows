import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/config/bloc/device_bloc.dart';
import 'package:flutter_blue/modules/config/bloc/device_states.dart';
import 'package:flutter_blue/modules/config/failed_device_page.dart';
import 'package:flutter_blue/modules/config/scan_device_page.dart';
import 'package:flutter_blue/modules/config/updated_device_page.dart';
import 'package:flutter_blue/utils/snackbar.dart';

class ConfigDevicePage extends StatefulWidget {
  const ConfigDevicePage({super.key});

  @override
  State<ConfigDevicePage> createState() => _ConfigDevicePageState();
}

class _ConfigDevicePageState extends State<ConfigDevicePage> {
  final List<String> categories = ['Devices', 'Updated', 'Failed'];

  final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyD,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: ValueListenableBuilder<int>(
            valueListenable: selectedIndexNotifier,
            builder: (context, selectedIndex, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(categories.length, (index) {
                  bool isActive = selectedIndex == index;
                  return _buildCategoryTab(index, isActive);
                }),
              );
            },
          ),
        ),

        body: ValueListenableBuilder<int>(
          valueListenable: selectedIndexNotifier,
          builder: (_, selectedIndex, __) {
            return IndexedStack(
              index: selectedIndex,
              children: const [
                ScanDevicePage(),
                UpdatedDevicePage(),
                FailedDevicePage(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryTab(int index, bool isActive) {
    return GestureDetector(
      onTap: () {
        selectedIndexNotifier.value = index;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blueGrey : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              categories[index],
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (index == 1)
              BlocBuilder<DeviceBloc, DeviceState>(
                buildWhen:
                    (previous, current) =>
                        previous.updatedDevices.length !=
                        current.updatedDevices.length,
                builder: (_, state) {
                  if (state.updatedDevices.isEmpty) return SizedBox.shrink();
                  return _buildBadge(state.updatedDevices.length);
                },
              ),
            if (index == 2)
              BlocBuilder<DeviceBloc, DeviceState>(
                buildWhen:
                    (previous, current) =>
                        previous.failedDevices.length !=
                        current.failedDevices.length,
                builder: (_, state) {
                  if (state.failedDevices.isEmpty) return SizedBox.shrink();
                  return _buildBadge(state.failedDevices.length);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Positioned(
      top: -11,
      right: -16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    selectedIndexNotifier.dispose();
    super.dispose();
  }
}
