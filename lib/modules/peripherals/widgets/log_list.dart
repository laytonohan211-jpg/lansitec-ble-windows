import 'package:flutter/material.dart';

/// 日志列表
/// - logs: 日志内容，每条格式 "HH:mm:ss.SSS  value"
/// - maxHeight: 可选，限制日志区域最大高度（超出高度可以滚动）
class LogList extends StatelessWidget {
  final List<String> logs;
  final double? maxHeight;

  const LogList({super.key, required this.logs, this.maxHeight});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Column(
        children: const [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity(vertical: -4),
            subtitle: Text(
              "No values",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
          Divider(height: 2, thickness: 0.5, indent: 1, color: Colors.grey),
        ],
      );
    }

    Widget buildLogItem(String v) {
      final splitIndex = v.indexOf('  ');
      final time = splitIndex != -1 ? v.substring(0, splitIndex) : '';
      final value = splitIndex != -1 ? v.substring(splitIndex + 2) : v;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: const VisualDensity(vertical: -4),
            title: Text(
              time,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            subtitle: Text(
              value,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
          const Divider(
            height: 2,
            thickness: 0.5,
            indent: 1,
            color: Colors.grey,
          ),
        ],
      );
    }

    Widget logList = ListView.builder(
      shrinkWrap: true, // 自动收缩高度
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return buildLogItem(logs[index]);
      },
    );

    if (maxHeight != null) {
      return SizedBox(
        height: maxHeight,
        child: ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) => buildLogItem(logs[index]),
        ),
      );
    }

    return logList;
  }
}
