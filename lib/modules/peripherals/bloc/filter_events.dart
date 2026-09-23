abstract class FilterEvent {}

class UpdateRssi extends FilterEvent {
  final int rssi;
  UpdateRssi(this.rssi);
}

class UpdateRssiEnabled extends FilterEvent {
  final bool enabled;
  UpdateRssiEnabled(this.enabled);
}
