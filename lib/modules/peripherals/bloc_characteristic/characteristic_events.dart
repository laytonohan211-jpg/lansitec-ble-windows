import 'package:equatable/equatable.dart';

abstract class CharacteristicEvent extends Equatable {
  const CharacteristicEvent();

  @override
  List<Object?> get props => [];
}

/// 写入新值
class AddWrittenValue extends CharacteristicEvent {
  final String uuid;
  final String value;

  const AddWrittenValue({required this.uuid, required this.value});

  @override
  List<Object?> get props => [uuid, value];
}

/// 读取新值
class AddReadValue extends CharacteristicEvent {
  final String uuid;
  final String value;

  const AddReadValue({required this.uuid, required this.value});

  @override
  List<Object?> get props => [uuid, value];
}

/// 通知新值
class AddNotifyValue extends CharacteristicEvent {
  final String uuid;
  final String value;

  const AddNotifyValue({required this.uuid, required this.value});

  @override
  List<Object?> get props => [uuid, value];
}

class ClearNotifyValues extends CharacteristicEvent {
  final String uuid;

  const ClearNotifyValues({required this.uuid});
}
