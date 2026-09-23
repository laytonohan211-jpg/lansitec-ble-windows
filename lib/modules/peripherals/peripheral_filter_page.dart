import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/filter_bloc.dart';
import 'bloc/filter_events.dart';
import 'bloc/filter_states.dart';

class PeripheralFilterPage extends StatelessWidget {
  const PeripheralFilterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 不再使用 Scaffold，由主页面的 Scaffold 管理
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BlocBuilder<FilterBloc, FilterState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RSSI 开关
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enable RSSI Filter',
                    style: TextStyle(fontSize: 16),
                  ),
                  Switch(
                    value: state.rssiEnabled,
                    activeColor: Colors.white, // 滑块颜色
                    activeTrackColor: Colors.blue, // 滑轨颜色
                    onChanged: (enabled) {
                      context.read<FilterBloc>().add(
                        UpdateRssiEnabled(enabled),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 最小 RSSI
              Text(
                'Minimum RSSI: ${state.minRssi} dBm',
                style: const TextStyle(fontSize: 16),
              ),
              Slider(
                min: -100,
                max: 0,
                divisions: 100,
                value: state.minRssi.toDouble(),
                activeColor: Colors.blue, // 已选部分颜色
                inactiveColor: Colors.grey, // 未选部分颜色
                onChanged:
                    state.rssiEnabled
                        ? (v) {
                          context.read<FilterBloc>().add(UpdateRssi(v.toInt()));
                        }
                        : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
