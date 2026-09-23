class FailedDevice {
  final String name;
  final String id;
  final String txPower; // String 类型
  final String hardware; // 硬件版本
  final int interval; // 单位 ms
  final String message; // 错误信息
  final int count; // 计数
  final String major; // 新增字段
  final String minor; // 新增字段

  FailedDevice({
    required this.name,
    required this.id,
    required this.txPower,
    required this.hardware,
    this.interval = 0, // 默认间隔 0ms
    this.message = '', // 默认空字符串
    this.count = 0, // 默认 0
    this.major = '', // 默认空字符串
    this.minor = '', // 默认空字符串
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'id': id,
    'txPower': txPower,
    'hardware': hardware,
    'interval': interval,
    'message': message,
    'count': count,
    'major': major,
    'minor': minor,
  };

  factory FailedDevice.fromMap(Map<dynamic, dynamic> map) => FailedDevice(
    name: map['name'] ?? '',
    id: map['id'] ?? '',
    txPower: map['txPower']?.toString() ?? '',
    hardware: map['hardware'] ?? 'V1.0',
    interval: map['interval'] ?? 0,
    message: map['message'] ?? '',
    count: map['count'] ?? 0,
    major: map['major']?.toString() ?? '',
    minor: map['minor']?.toString() ?? '',
  );

  @override
  String toString() =>
      'FailedDevice(name: $name, id: $id, txPower: $txPower, hardware: $hardware, interval: $interval, message: $message, count: $count, major: $major, minor: $minor)';
}
