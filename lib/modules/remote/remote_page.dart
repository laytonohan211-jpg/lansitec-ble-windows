import 'package:flutter/material.dart';
import 'package:flutter_blue/modules/guided/preferences.dart';

/// Local support instructions. No network client or automatic submission.
class RemotePage extends StatelessWidget {
  const RemotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Local data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Bluetooth device information and settings are processed on this device. '
                'Saved profiles, nicknames and batch history stay here until you remove them. '
                'Use the batch history screens to clear their records. Exported files and '
                'clipboard copies must be removed separately.'),
            TextButton(onPressed: () async {
              final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete saved profiles and nicknames?'),
                content: const Text('This removes local saved profiles and device nicknames. '
                    'It does not change device settings or delete exported files or email.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
              if (confirmed != true) return;
              try {
                final box = await GuidedPreferences.box();
                await box.clear();
                await box.compact();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved profiles and nicknames deleted')));
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not delete local data. Please try again.')));
              }
            }, child: const Text('Delete saved profiles and nicknames')),
            TextButton(onPressed: () => showLicensePage(context: context,
              applicationName: 'Ls BLE Guided'), child: const Text('Third-party licenses')),
            const SizedBox(height: 16),
            Text('Optional diagnostic reports',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('If you need help, open the affected device page and use its '
                'diagnostic report copy option. For device logs, open Log & Debug '
                'when available and copy the relevant entries.'),
            SizedBox(height: 16),
            Text('Review the report before sharing it. It may contain device '
                'identifiers, settings or location information. Remove passwords, '
                'keys and information that is not needed for your request.'),
            SizedBox(height: 16),
            Text('You can paste the report into your own email application and '
                'send it to:'),
            SelectableText('alessandro.paperi@lansitec.com'),
            SizedBox(height: 16),
            Text('Sending a report is optional. This page does not upload data '
                'or send email. Bluetooth configuration does not require a '
                'remote service.'),
            SizedBox(height: 16),
            Text('Reports you choose to email are handled by Lansitec as support '
                'and commercial correspondence in its company systems. Internal '
                'access is limited to the app and commercial contact and, when '
                'needed, their supervisors. Contact the address above with '
                'questions about your report or to request its deletion.'),
          ],
        ),
      ),
    );
  }
}
