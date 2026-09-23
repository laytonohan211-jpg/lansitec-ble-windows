import 'package:flutter/material.dart';

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
  final int pending;
  const DisconnectGuard({
    super.key,
    required this.child,
    required this.connected,
    this.busy = false,
    this.pending = 0,
  });
  @override
  State<DisconnectGuard> createState() => _DisconnectGuardState();
}

class _DisconnectGuardState extends State<DisconnectGuard> {
  bool allowed = false, asking = false;
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
    child: widget.child,
  );
}
