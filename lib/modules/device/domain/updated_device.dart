class UpdatedDevice {
  final String name;
  final String id;
  final String txPower; // 修改为 String
  final String hardware; // 硬件版本
  final int interval; // 单位 ms
  final String major; // 新增字段
  final String minor; // 新增字段

  UpdatedDevice({
    required this.name,
    required this.id,
    required this.txPower,
    required this.hardware,
    this.interval = 0, // 默认间隔 0ms
    this.major = '', // 默认空字符串
    this.minor = '', // 默认空字符串
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'id': id,
    'txPower': txPower,
    'hardware': hardware,
    'interval': interval,
    'major': major,
    'minor': minor,
  };

  factory UpdatedDevice.fromMap(Map<dynamic, dynamic> map) => UpdatedDevice(
    name: map['name'] ?? '',
    id: map['id'] ?? '',
    txPower: map['txPower']?.toString() ?? '',
    hardware: map['hardware'] ?? 'V1.0',
    interval: map['interval'] ?? 0,
    major: map['major']?.toString() ?? '',
    minor: map['minor']?.toString() ?? '',
  );

  @override
  String toString() =>
      'UpdatedDevice(name: $name, id: $id, txPower: $txPower, hardware: $hardware, interval: $interval, major: $major, minor: $minor)';
}
