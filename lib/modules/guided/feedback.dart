import 'dart:async';
import 'dart:convert';
import 'protocol.dart';

String wireHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
List<int> payloadBytes(List<int> input) {
  var bytes = input;
  // FF11 capture 2026-09-24: some replies wrap ASCII hex twice.
  // Never trim binary payloads: trailing zero bytes can be real values.
  for (var depth = 0; depth < 2; depth++) {
    if (bytes.isNotEmpty && bytes.first == 0x60) return bytes;
    try {
      final text = utf8.decode(bytes);
      final zero = text.indexOf('\u0000');
      if (zero >= 0 && text.substring(zero).runes.any((c) => c != 0)) {
        return input;
      }
      final h = (zero < 0 ? text : text.substring(0, zero)).trim();
      if (h.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) {
        return input;
      }
      bytes = [for (var i = 0; i < h.length; i += 2)
        int.parse(h.substring(i, i + 2), radix: 16)];
    } catch (_) { return input; }
  }
  return bytes.isNotEmpty && bytes.first == 0x60 ? bytes : input;
}

Map<int, String> parameterResponse(List<int> input, String model) {
  final b = payloadBytes(input), result = <int, String>{};
  if (b.length < 3 || b.first != 0x60) return result;
  final known = {for (final p in parameters(model)) p.id: p};
  final widths = {for (final p in known.values) p.id: p.width, 0: 2, 14: 8};
  var i = 1;
  while (i < b.length) {
    final id = b[i++], width = widths[b[i - 1]];
    if (width == null || i + width > b.length || result.containsKey(id))
      return {};
    final raw = wireHex(b.sublist(i, i + width));
    final p = known[id];
    if (p != null) {
      try {
        p.encode(
          p.kind == 'uuid' ? raw : '${int.parse(raw, radix: 16) * p.step}',
        );
      } catch (_) {
        return {};
      }
    }
    result[id] = raw;
    i += width;
  }
  return result;
}

Map<int, String> commandValues(String command, String model) {
  final h = cleanHex(command);
  describe(h, model);
  if (!h.startsWith('A0'))
    throw const FormatException('Not a setting command.');
  var i = 2;
  final result = <int, String>{};
  while (i < h.length - 4) {
    final id = int.parse(h.substring(i, i + 2), radix: 16);
    i += 2;
    final p = parameters(model).firstWhere((p) => p.id == id);
    result[id] = h.substring(i, i + p.width * 2);
    i += p.width * 2;
  }
  return result;
}

bool? explicitVerdict(String response) {
  final s = response.replaceAll('\u0000', '').trim().toLowerCase();
  final m = RegExp(
    r'^(?:configuration|configurate|configure|config)[\s:_=-]*(success(?:ful(?:ly)?)?|ok|fail(?:ed|ure)?|error)[.!]?$',
  ).firstMatch(s);
  return m == null ? null : RegExp(r'^(success|ok)').hasMatch(m.group(1)!);
}

enum ApplyOutcome {
  confirmed,
  verified,
  rejected,
  reported,
  unknown,
  disconnected,
}

class ApplyResult {
  final ApplyOutcome outcome;
  final Map<int, String> values;
  const ApplyResult(this.outcome, [this.values = const {}]);
  bool get acknowledged => verified || outcome == ApplyOutcome.reported;
  bool get verified =>
      outcome == ApplyOutcome.confirmed || outcome == ApplyOutcome.verified;
  String get label => switch (outcome) {
    ApplyOutcome.confirmed => 'Confirmed by device',
    ApplyOutcome.verified => 'Value verified',
    ApplyOutcome.rejected => 'Rejected by device',
    ApplyOutcome.reported =>
      'Success response received; saved value not verified',
    ApplyOutcome.unknown => 'Sent, but no recognised confirmation received.',
    ApplyOutcome.disconnected => 'Sent; disconnected before confirmation',
  };
}

Future<ApplyResult> exchangeConfiguration({
  required String command,
  required String model,
  required Future<void> Function() write,
  required Future<List<int>> Function()? read,
  required Stream<List<int>> notifications,
  required Stream<bool> connections,
  required Future<void> Function(bool) notify,
  required bool canNotify,
  bool alreadyNotifying = false,
  Duration timeout = const Duration(seconds: 10),
  Duration pollEvery = const Duration(milliseconds: 600),
  void Function(String)? trace,
}) async {
  final expected = commandValues(command, model),
      done = Completer<ApplyResult>();
  var armed = false, closed = false, reading = false;
  var baseline = '', fragments = '';
  var observed = <int, String>{};
  void finish(ApplyResult r) {
    if (!closed && !done.isCompleted) done.complete(r);
  }

  void consume(List<int> data, {bool fromRead = false}) {
    if (!armed || closed || done.isCompleted || data.isEmpty) return;
    trace?.call('${fromRead ? 'READ' : 'NOTIFY'} ${wireHex(data)}');
    final state = parameterResponse(data, model);
    if (state.isNotEmpty) {
      observed = state;
      if (expected.entries.every((e) => state[e.key] == e.value)) {
        finish(ApplyResult(ApplyOutcome.verified, state));
        return;
      }
    }
    final text =
        utf8.decode(data, allowMalformed: true).replaceAll('\u0000', '').trim();
    if (!fromRead) {
      fragments += text;
      if (fragments.length > 1024)
        fragments = fragments.substring(fragments.length - 1024);
    }
    final verdict =
        explicitVerdict(text) ?? (fromRead ? null : explicitVerdict(fragments));
    if (verdict == null) return;
    if (fromRead && text == baseline && verdict) {
      // Firmware can retain a generic success string. Surface it immediately,
      // without claiming this is a fresh acknowledgement or a parameter readback.
      finish(ApplyResult(ApplyOutcome.reported, state));
      return;
    }
    finish(
      ApplyResult(
        verdict ? ApplyOutcome.confirmed : ApplyOutcome.rejected,
        state,
      ),
    );
  }

  final stream = notifications.listen(
    (data) {
      if (!reading) consume(data);
    },
    onError: (Object _) {
      trace?.call('Notification unavailable');
    },
  );
  final link = connections.listen((connected) {
    if (armed && !connected)
      finish(const ApplyResult(ApplyOutcome.disconnected));
  });
  Future<void> poll({bool before = false}) async {
    if (read == null || closed || done.isCompleted) return;
    reading = true;
    try {
      final bytes = await read().timeout(const Duration(seconds: 2));
      if (before) {
        trace?.call('BEFORE READ ${wireHex(bytes)}');
        baseline =
            utf8
                .decode(bytes, allowMalformed: true)
                .replaceAll('\u0000', '')
                .trim();
      } else {
        consume(bytes, fromRead: true);
      }
    } catch (_) {
      trace?.call('Read unavailable');
    } finally {
      reading = false;
    }
  }

  Timer? deadline;
  Future<void>? polling;
  try {
    await poll(before: true);
    if (canNotify) {
      try {
        await notify(true);
      } catch (_) {
        trace?.call('Notifications unavailable; using readback');
      }
    }
    armed = true;
    trace?.call('WRITE $command');
    await write();
    trace?.call('WRITE COMPLETE');
    deadline = Timer(
      timeout,
      () => finish(ApplyResult(ApplyOutcome.unknown, observed)),
    );
    polling = () async {
      while (!closed && !done.isCompleted) {
        await poll();
        if (closed || done.isCompleted) break;
        await Future.any([
          Future<void>.delayed(pollEvery),
          done.future.then((_) {}),
        ]);
      }
    }();
    return await done.future;
  } finally {
    closed = true;
    armed = false;
    deadline?.cancel();
    if (!done.isCompleted)
      done.complete(const ApplyResult(ApplyOutcome.unknown));
    await stream.cancel();
    await link.cancel();
    await polling;
    if (canNotify && !alreadyNotifying) {
      try {
        await notify(false);
      } catch (_) {}
    }
  }
}
