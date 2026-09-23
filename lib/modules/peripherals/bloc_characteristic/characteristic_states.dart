import 'package:equatable/equatable.dart';

class CharacteristicState extends Equatable {
  final Map<String, List<String>> writtenLogs;
  final Map<String, List<String>> readLogs;
  final Map<String, List<String>> notifyLogs;

  const CharacteristicState({
    this.writtenLogs = const {},
    this.readLogs = const {},
    this.notifyLogs = const {},
  });

  CharacteristicState copyWith({
    Map<String, List<String>>? writtenLogs,
    Map<String, List<String>>? readLogs,
    Map<String, List<String>>? notifyLogs,
  }) {
    return CharacteristicState(
      writtenLogs: writtenLogs ?? this.writtenLogs,
      readLogs: readLogs ?? this.readLogs,
      notifyLogs: notifyLogs ?? this.notifyLogs,
    );
  }

  @override
  List<Object?> get props => [writtenLogs, readLogs, notifyLogs];
}
