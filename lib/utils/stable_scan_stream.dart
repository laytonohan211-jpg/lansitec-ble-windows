import 'dart:async';

/// Coalesce advertisements into one UI update per second and keep row order.
/// New devices are appended; RSSI changes never move an existing button.
Stream<List<T>> stableScanStream<T>(
  Stream<List<T>> source, {
  required String Function(T) id,
  required int Function(T, T) compareNew,
  Duration interval = const Duration(seconds: 1),
}) {
  late StreamController<List<T>> controller;
  StreamSubscription<List<T>>? subscription;
  Timer? timer;
  List<T>? pending;
  var order = <String>[];
  void publish() {
    timer = null;
    final items = pending;
    pending = null;
    if (items == null) return;
    final byId = {for (final item in items) id(item): item};
    order.removeWhere((key) => !byId.containsKey(key));
    final existing = order.toSet();
    final added = byId.values.where((x) => !existing.contains(id(x))).toList()
      ..sort(compareNew);
    order.addAll(added.map(id));
    controller.add([for (final key in order) byId[key]!]);
  }
  controller = StreamController<List<T>>(
    onListen: () {
      subscription = source.listen((items) {
        pending = List.of(items);
        timer ??= Timer(interval, publish);
      }, onError: controller.addError, onDone: () {
        timer?.cancel();
        publish();
        controller.close();
      });
    },
    onCancel: () async {
      timer?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
