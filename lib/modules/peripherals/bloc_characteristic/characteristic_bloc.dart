import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc_characteristic/characteristic_events.dart';
import 'package:flutter_blue/modules/peripherals/bloc_characteristic/characteristic_states.dart';

/// ============================
/// CharacteristicBloc
/// ============================
class CharacteristicBloc
    extends Bloc<CharacteristicEvent, CharacteristicState> {
  /// 日志最大条数
  static const int maxWriteLogCount = 2;
  static const int maxReadLogCount = 2;
  static const int maxNotifyLogCount = 2000;

  CharacteristicBloc() : super(const CharacteristicState()) {
    on<AddWrittenValue>(_onAddWrittenValue);
    on<AddReadValue>(_onAddReadValue);
    on<AddNotifyValue>(_onAddNotifyValue);
    on<ClearNotifyValues>(_onClearNotifyValues);
  }

  void _onAddWrittenValue(
    AddWrittenValue event,
    Emitter<CharacteristicState> emit,
  ) {
    final newMap = Map<String, List<String>>.from(state.writtenLogs);

    final list = List<String>.from(newMap[event.uuid] ?? []);
    list.insert(0, event.value);
    if (list.length > maxWriteLogCount) {
      list.removeLast();
    }
    newMap[event.uuid] = list;

    emit(state.copyWith(writtenLogs: newMap));
  }

  void _onAddReadValue(AddReadValue event, Emitter<CharacteristicState> emit) {
    final newMap = Map<String, List<String>>.from(state.readLogs);

    final list = List<String>.from(newMap[event.uuid] ?? []);
    list.insert(0, event.value);
    if (list.length > maxReadLogCount) {
      list.removeLast();
    }
    newMap[event.uuid] = list;

    emit(state.copyWith(readLogs: newMap));
  }

  void _onAddNotifyValue(
    AddNotifyValue event,
    Emitter<CharacteristicState> emit,
  ) {
    final newMap = Map<String, List<String>>.from(state.notifyLogs);

    final list = List<String>.from(newMap[event.uuid] ?? []);
    list.insert(0, event.value);
    if (list.length > maxNotifyLogCount) {
      list.removeLast();
    }
    newMap[event.uuid] = list;

    emit(state.copyWith(notifyLogs: newMap));
  }

  void _onClearNotifyValues(
    ClearNotifyValues event,
    Emitter<CharacteristicState> emit,
  ) {
    final newMap = Map<String, List<String>>.from(state.notifyLogs);

    newMap[event.uuid] = [];

    emit(state.copyWith(notifyLogs: newMap));
  }
}
