import 'dart:async';
import 'feedback.dart';
import 'protocol.dart';

class SnapshotResult {
  final Map<String, List<int>> values;
  final bool incomplete;
  const SnapshotResult(this.values, this.incomplete);
}

Future<SnapshotResult> readSnapshotOnce(
  Map<String, Future<List<int>> Function()> readers, {
  required bool Function() active,
  Duration perRead = const Duration(seconds: 2),
  Duration budget = const Duration(seconds: 10),
}) async {
  final values = <String, List<int>>{};
  final clock = Stopwatch()..start();
  var failures = 0, incomplete = false;
  for (final entry in readers.entries) {
    if (!active() || clock.elapsed >= budget) {
      incomplete = true;
      break;
    }
    final remaining = budget - clock.elapsed;
    try {
      final bytes = await entry.value().timeout(
        remaining < perRead ? remaining : perRead,
      );
      if (!active()) {
        incomplete = true;
        break;
      }
      values[entry.key] = List.of(bytes);
    } on TimeoutException {
      incomplete = true;
      break;
    } catch (_) {
      incomplete = true;
      if (++failures >= 2) break;
    }
  }
  return SnapshotResult(values, incomplete);
}

class TrackingSnapshot {
  final Map<int, String> values;
  final Set<int> fresh;
  const TrackingSnapshot(this.values, this.fresh);
}

// Single-parameter BLE query confirmed by customer capture: B0010000 -> 60010B40.
// Do not batch IDs: tested Cat-1 firmware returns generic success for that form.
Future<TrackingSnapshot> queryTrackingOnce({
  required String model,
  required int maxBytes,
  required int Function() nextId,
  Iterable<int>? requestedIds,
  Duration settle = const Duration(milliseconds: 800),
  Duration budget = const Duration(seconds: 25),
  void Function(int, int)? progress,
  required Future<void> Function(String) write,
  required Future<List<int>> Function()? read,
  required Stream<List<int>> notifications,
  required Future<void> Function(bool) notify,
  required bool canNotify,
  required bool alreadyNotifying,
  required bool Function() active,
  List<int> baseline = const [],
  void Function(String)? trace,
  Duration wait = const Duration(seconds: 2),
}) async {
  final values = <int, String>{}, fresh = <int>{};
  if (maxBytes < 8) return TrackingSnapshot(values, fresh);
  final allowed = parameters(model).map((p) => p.id).toSet();
  final ids =
      (requestedIds ?? allowed).where(allowed.contains).toSet().toList();
  var previous = baseline;
  var misses = 0;
  final clock = Stopwatch()..start();
  var armed = false, enabled = false;
  var requested = <int>{};
  Completer<void>? done;
  void consume(List<int> bytes, bool notification) {
    if (!armed || !active()) return;
    trace?.call('QUERY ${notification ? 'NOTIFY' : 'READ'} ${wireHex(bytes)}');
    final parsed = parameterResponse(bytes, model);
    for (final e in parsed.entries) {
      if (requested.contains(e.key)) {
        values[e.key] = e.value;
        if (notification || wireHex(bytes) != wireHex(previous))
          fresh.add(e.key);
      }
    }
    if (requested.every(values.containsKey) && done?.isCompleted == false)
      done!.complete();
  }

  final sub = notifications.listen(
    (b) => consume(b, true),
    onError: (Object _) {},
  );
  try {
    if (canNotify && !alreadyNotifying) {
      try {
        await notify(true).timeout(wait);
        enabled = true;
      } catch (_) {}
    }
    for (var i = 0; i < ids.length; i++) {
      if (!active() || clock.elapsed >= budget) break;
      requested = {ids[i]};
      progress?.call(i + 1, ids.length);
      done = Completer<void>();
      final command =
          'B0${requested.map((id) => id.toRadixString(16).padLeft(2, '0')).join()}0000'
              .toUpperCase();
      describe(command, model);
      armed = true;
      trace?.call('QUERY WRITE $command');
      await write(command).timeout(wait);
      if (read != null && !done.isCompleted && active()) {
        await Future<void>.delayed(settle);
        if (!active()) break;
        // onValueReceived also emits read results; do not count them as fresh notifications.
        armed = false;
        final bytes = await read().timeout(wait);
        armed = true;
        consume(bytes, false);
        previous = List.of(bytes);
      }
      if (canNotify && !done.isCompleted && active()) {
        try {
          await done.future.timeout(wait);
        } on TimeoutException {}
      }
      armed = false;
      if (requested.every(values.containsKey)) {
        misses = 0;
      } else if (++misses >= 2) {
        break; // stop unsupported/no-response sessions; no retries
      }
    }
  } catch (_) {
    trace?.call('QUERY stopped: no complete parameter response');
  } finally {
    armed = false;
    unawaited(sub.cancel());
    if (enabled && active()) {
      try {
        await notify(false).timeout(wait);
      } catch (_) {}
    }
  }
  return TrackingSnapshot(values, fresh);
}
