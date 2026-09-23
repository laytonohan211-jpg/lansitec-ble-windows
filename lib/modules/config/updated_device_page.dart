import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/locator.dart';
import 'package:flutter_blue/modules/config/bloc/device_bloc.dart';
import 'package:flutter_blue/modules/config/bloc/device_events.dart';
import 'package:flutter_blue/modules/config/bloc/device_states.dart';
import 'package:flutter_blue/modules/device/domain/updated_device.dart';
import 'package:flutter_blue/utils/services/overlay_service/i_overlay_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter_blue/utils/export_directory.dart';

class UpdatedDevicePage extends StatefulWidget {
  const UpdatedDevicePage({super.key});

  @override
  State<UpdatedDevicePage> createState() => _UpdatedDevicePageState();
}

class _UpdatedDevicePageState extends State<UpdatedDevicePage> {
  final overlayService = getIt<IOverlayService>();
  late final DeviceBloc deviceBloc;

  @override
  void initState() {
    super.initState();
    deviceBloc = context.read<DeviceBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        overlayService.showSuccessNotification(
          (context) => "Refreshed updated devices list",
          duration: const Duration(milliseconds: 2000),
        );
      },
      child: BlocBuilder<DeviceBloc, DeviceState>(
        builder: (context, state) {
          final updatedDevices = state.updatedDevices;

          return Column(
            children: [
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      "Updated Devices: ${updatedDevices.length}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildClearButton(context, updatedDevices),
                  const SizedBox(width: 6),
                  buildExportButton(context, updatedDevices),
                ],
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: updatedDevices.length,
                  separatorBuilder:
                      (_, __) => const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey,
                      ),
                  itemBuilder: (context, index) {
                    final device = updatedDevices[index];
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -4),
                      title: Text(
                        device.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Major: ${device.major} Minor: ${device.minor}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                          Text(
                            'HW: ${device.hardware} | ${device.txPower} | ${device.interval == 0 ? "Default" : "${device.interval} ms"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        device.id,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        tooltip: "Delete this device",
                        onPressed: () async {
                          bool? confirmed = await showDialog<bool>(
                            context: context,
                            useRootNavigator: true,
                            builder:
                                (_) => AlertDialog(
                                  title: const Text("Confirm Delete"),
                                  content: Text(
                                    "Are you sure you want to delete '${device.name}'?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).pop(false),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).pop(true),
                                      child: const Text("Confirm"),
                                    ),
                                  ],
                                ),
                          );

                          if (confirmed == true) {
                            deviceBloc.add(RemoveUpdatedDevice(device));
                            overlayService.showSuccessNotification(
                              (context) => "Deleted device: ${device.name}",
                              duration: const Duration(milliseconds: 2000),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildClearButton(
    BuildContext context,
    List<UpdatedDevice> updatedDevices,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        if (updatedDevices.isEmpty) {
          overlayService.showSuccessNotification(
            (context) => "No updated devices",
            duration: const Duration(milliseconds: 2000),
          );
          return;
        }
        bool? confirmed = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder:
              (_) => AlertDialog(
                title: const Text("Confirm Clear All"),
                content: const Text(
                  "Are you sure you want to clear all updated devices?",
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(true),
                    child: const Text("Confirm"),
                  ),
                ],
              ),
        );

        if (confirmed == true) {
          deviceBloc.add(ClearUpdatedDevices());
          overlayService.showSuccessNotification(
            (context) => "All updated devices cleared",
            duration: const Duration(milliseconds: 2000),
          );
        }
      },
      icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.white),
      label: const Text("Clear All", style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  Widget buildExportButton(
    BuildContext context,
    List<UpdatedDevice> updatedDevices,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        if (updatedDevices.isEmpty) {
          overlayService.showSuccessNotification(
            (context) => "No updated devices available for export",
            duration: const Duration(milliseconds: 2000),
          );
          return;
        }

        // 弹出确认对话框
        bool? confirmed = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder:
              (_) => AlertDialog(
                title: const Text("Confirm Export"),
                content: const Text(
                  "Are you sure you want to export all updated devices?",
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(true),
                    child: const Text("Confirm"),
                  ),
                ],
              ),
        );

        if (confirmed != true) return; // 用户取消

        // 生成 CSV 内容
        String csv = "Name,MAC,MAJOR,MINOR,TX Power,Interval(ms),Hardware\n";
        for (var d in updatedDevices) {
          csv +=
              "${d.name},${d.id},${d.major},${d.minor},${d.txPower},${d.interval},${d.hardware}\n";
        }

        try {
          final downloadsDir = await exportDirectory();

          String timestamp = DateFormat(
            'yyyyMMdd_HHmmss',
          ).format(DateTime.now());
          File file = File(
            "${downloadsDir.path}/updated_devices_$timestamp.csv",
          );
          await file.writeAsString(csv);

          // 成功提示
          overlayService.showSuccessNotification(
            (context) => "Export successful: ${file.path}",
            duration: const Duration(milliseconds: 5000),
          );
        } catch (e) {
          overlayService.showErrorNotification(
            (context) => "Export failed: $e",
            duration: const Duration(milliseconds: 2000),
          );
        }
      },
      icon: const Icon(Icons.download, size: 16, color: Colors.white),
      label: const Text("Export", style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF409EFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
