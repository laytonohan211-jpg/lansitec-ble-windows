import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue/modules/peripherals/bloc/filter_events.dart';
import 'package:flutter_blue/modules/peripherals/bloc/filter_states.dart';

class FilterBloc extends Bloc<FilterEvent, FilterState> {
  FilterBloc() : super(const FilterState()) {
    on<UpdateRssi>((event, emit) {
      emit(state.copyWith(minRssi: event.rssi));
    });
    on<UpdateRssiEnabled>((event, emit) {
      emit(state.copyWith(rssiEnabled: event.enabled));
    });
  }
}
