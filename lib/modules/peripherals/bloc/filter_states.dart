import 'package:equatable/equatable.dart';

class FilterState extends Equatable {
  final bool rssiEnabled; // 是否启用 RSSI 过滤
  final int minRssi; // 最小 RSSI

  const FilterState({this.rssiEnabled = false, this.minRssi = -88});

  FilterState copyWith({bool? rssiEnabled, int? minRssi}) {
    return FilterState(
      rssiEnabled: rssiEnabled ?? this.rssiEnabled,
      minRssi: minRssi ?? this.minRssi,
    );
  }

  @override
  List<Object> get props => [rssiEnabled, minRssi];
}
