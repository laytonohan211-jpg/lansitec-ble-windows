import 'dart:async';

/// Refresh signal ordering every three seconds, with deterministic ties.
Stream<List<T>> stableScanStream<T>(
  Stream<List<T>> source, {
  required String Function(T) id,
  required int Function(T, T) compareNew,
  Duration interval = const Duration(seconds: 3),
}) {
  late StreamController<List<T>> controller;
  StreamSubscription<List<T>>? subscription;
  Timer? timer;
  List<T>? pending;
  void publish() {
    timer = null;
    final items = pending;
    pending = null;
    if (items == null) return;
    final byId = {for (final item in items) id(item): item};
    final sorted = byId.values.toList()..sort((a,b) {
      final rank = compareNew(a,b);
      return rank != 0 ? rank : id(a).compareTo(id(b));
    });
    controller.add(sorted);
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
