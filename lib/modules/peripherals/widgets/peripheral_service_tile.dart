import 'package:flutter/material.dart';

class PeripheralServiceTile extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final List<Widget> children;

  const PeripheralServiceTile({
    super.key,
    required this.title,
    this.titleStyle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 保持左对齐，不居中
      children: [
        // 服务 header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(title, style: titleStyle),
        ),
        // 服务 header 和第一个特征值之间的分割线
        if (children.isNotEmpty)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            color: Colors.grey,
          ),
        ...children, // 特征值直接展示
        // 底部分割线
        const Divider(
          height: 1,
          thickness: 0.5,
          indent: 16,
          color: Colors.grey,
        ),
      ],
    );
  }
}
