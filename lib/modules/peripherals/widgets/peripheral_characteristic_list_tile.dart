import 'package:flutter/material.dart';

class PeripheralCharacteristicListTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final String? value; // ← 新增，用于显示特征描述
  final bool showDivider;

  const PeripheralCharacteristicListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          // 紧凑型 ListTile
          title: Text(title),
          subtitle:
              value != null
                  ? Text(
                    value!,
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  )
                  : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider)
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
