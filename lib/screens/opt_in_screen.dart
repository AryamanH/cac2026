import 'package:flutter/material.dart';

import '../state/service_graph_controller.dart';
import '../widgets/consent_form.dart';

class OptInScreen extends StatelessWidget {
  const OptInScreen({super.key, required this.controller});
  final ServiceGraphController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Service Graph')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Find the people who were there', style: text.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Your unit scattered the day you got out. The Service Graph '
              'matches you with veterans whose service overlapped with '
              'yours: the same unit or place, at the same time.',
            ),
            const SizedBox(height: 16),
            const PrivacyNote(),
            const SizedBox(height: 8),
            ConsentForm(
              initial: controller.me!.consent,
              submitLabel: 'Join the Service Graph',
              onSubmit: controller.updateConsent,
            ),
          ],
        ),
      ),
    );
  }
}

class GraphSettingsScreen extends StatelessWidget {
  const GraphSettingsScreen({super.key, required this.controller});
  final ServiceGraphController controller;

  Future<void> _leave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the Service Graph?'),
        content: const Text(
          'Nobody will be able to find you, and pending requests are '
          'withdrawn. Statements you already sent stay with the people you sent them to.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.leaveGraph();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and matching')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PrivacyNote(),
          const SizedBox(height: 8),
          ConsentForm(
            initial: controller.me!.consent,
            submitLabel: 'Save changes',
            onSubmit: (c) async {
              await controller.updateConsent(c);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Changes saved')));
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _leave(context),
            icon: const Icon(Icons.logout),
            label: const Text('Leave the Service Graph'),
          ),
        ],
      ),
    );
  }
}
