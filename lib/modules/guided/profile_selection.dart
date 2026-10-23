import 'package:flutter/material.dart';
import 'protocol.dart' show models;
import 'help_page.dart' show beaconModels;
import 'lorawan_protocol.dart';

enum DeviceConnectivity { cat1, nb, lora, beacon }

String connectivityLabel(DeviceConnectivity type) => switch (type) {
  DeviceConnectivity.cat1 => 'LTE Cat-1',
  DeviceConnectivity.nb => 'NB-IoT / LTE-M',
  DeviceConnectivity.lora => 'LoRaWAN',
  DeviceConnectivity.beacon => 'BLE beacon',
};

List<String> profileModels(DeviceConnectivity type) => switch (type) {
  DeviceConnectivity.lora => LoRaModel.values.map(loRaModelLabel).toList(),
  DeviceConnectivity.beacon => beaconModels,
  DeviceConnectivity.cat1 => models.where((m) => m.startsWith('LTE Cat-1')).toList(),
  DeviceConnectivity.nb => models.where((m) => m.startsWith('NB-IoT')).toList(),
};

LoRaModel? detectLoRaModel(String name) {
  final n = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  final found = <LoRaModel>[];
  for (final m in LoRaModel.values) {
    if (n.contains(m.name)) found.add(m);
  }
  return found.length == 1 ? found.single : null;
}

class ProfileSelection extends StatefulWidget {
  final String deviceName;
  final DeviceConnectivity? initialType;
  final String? initialModel;
  final bool connected;
  final void Function(DeviceConnectivity, String) onSelected;
  const ProfileSelection({super.key, required this.deviceName,
    this.initialType, this.initialModel, required this.connected,
    required this.onSelected});
  @override
  State<ProfileSelection> createState() => _ProfileSelectionState();
}

class _ProfileSelectionState extends State<ProfileSelection> {
  DeviceConnectivity? type;
  String? model;
  @override
  void initState() {
    super.initState();
    type = widget.initialType;
    model = type != null && profileModels(type!).contains(widget.initialModel)
        ? widget.initialModel : null;
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Device setup')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(widget.deviceName, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      const Text('Check the connectivity and model, then read the current settings.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<DeviceConnectivity>(
        value: type, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Connectivity'),
        items: [for (final t in DeviceConnectivity.values)
          DropdownMenuItem(value: t, child: Text(connectivityLabel(t)))],
        onChanged: (v) => setState(() { type = v; model = null; }),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey(type), value: model, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Device model'),
        items: [if (type != null) for (final m in profileModels(type!))
          DropdownMenuItem(value: m, child: Text(m))],
        onChanged: type == null ? null : (v) => setState(() => model = v),
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: widget.connected && type != null && model != null
        ? () => widget.onSelected(type!, model!) : null,
        child: const Text('Read current settings')),
      if (!widget.connected) const Text('Disconnected. Reconnect to continue.'),
    ]),
  );
}
