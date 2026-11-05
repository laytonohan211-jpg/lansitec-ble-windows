import 'package:flutter/material.dart';
import 'log_debug_page.dart' show supportInstructions;

Future<bool> confirmDeviceDisconnect(
  BuildContext context, {
  int pending = 0,
}) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Disconnect device?'),
            content: Text(
              pending > 0
                  ? '$pending unsent ${pending == 1 ? 'change will' : 'changes will'} be discarded.'
                  : 'The Bluetooth connection will close.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay connected'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    ) ??
    false;

class DisconnectGuard extends StatefulWidget {
  final Widget child;
  final bool connected, busy;
  final bool expectedDisconnect;
  final int pending;
  const DisconnectGuard({
    super.key,
    required this.child,
    required this.connected,
    this.busy = false,
    this.expectedDisconnect = false,
    this.pending = 0,
  });
  @override
  State<DisconnectGuard> createState() => _DisconnectGuardState();
}

class _DisconnectGuardState extends State<DisconnectGuard> {
  bool allowed = false, asking = false;
  bool lost = false;
  @override
  void didUpdateWidget(covariant DisconnectGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected && !widget.connected && !allowed && !widget.expectedDisconnect) lost = true;
    if (widget.connected) lost = false;
  }
  Future<void> leave() async {
    if (asking || widget.busy) return;
    asking = true;
    final approved = await confirmDeviceDisconnect(
      context,
      pending: widget.pending,
    );
    if (!mounted) return;
    asking = false;
    if (!approved) return;
    setState(() => allowed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        allowed || (!widget.connected && widget.pending == 0 && !widget.busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Column(children: [Expanded(child: widget.child),
      if (lost) Material(color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12),
          child: Row(children: [const Expanded(child: SelectableText('Bluetooth disconnected. $supportInstructions')),
            IconButton(tooltip: 'Dismiss', onPressed: () => setState(() => lost = false), icon: const Icon(Icons.close))])))),
    ]),
  );
}
