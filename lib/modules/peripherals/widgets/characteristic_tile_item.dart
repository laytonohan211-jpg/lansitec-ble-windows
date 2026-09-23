import 'package:flutter/material.dart';
import 'package:flutter_blue/modules/peripherals/peripheral_characteristic_detail_page.dart';
import 'package:flutter_blue/modules/peripherals/widgets/peripheral_characteristic_list_tile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class CharacteristicTileItem extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final String charUuid;
  final String propsText;
  final bool isLast;
  final BluetoothDevice device;

  const CharacteristicTileItem({
    super.key,
    required this.characteristic,
    required this.charUuid,
    required this.propsText,
    required this.isLast,
    required this.device,
  });

  @override
  State<CharacteristicTileItem> createState() => _CharacteristicTileItemState();
}

class _CharacteristicTileItemState extends State<CharacteristicTileItem> {
  String? description;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadDescription();
  }

  Future<void> _loadDescription() async {
    // 尝试读取 Descriptor 2901
    for (var d in widget.characteristic.descriptors) {
      if (d.uuid.str.toUpperCase() == "2901") {
        try {
          await d.read();
          final desc = String.fromCharCodes(d.lastValue);
          if (mounted) {
            setState(() {
              description = desc.isNotEmpty ? desc : null;
              loading = false;
            });
          }
          return;
        } catch (_) {}
      }
    }

    // 未找到描述符
    if (mounted) {
      setState(() {
        description = null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PeripheralCharacteristicListTile(
      title: description ?? "0x${widget.charUuid}",
      value: widget.propsText,
      showDivider: !widget.isLast,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => CharacteristicDetailPage(
                  device: widget.device,
                  characteristic: widget.characteristic,
                  description: description,
                ),
          ),
        );
      },
    );
  }
}
