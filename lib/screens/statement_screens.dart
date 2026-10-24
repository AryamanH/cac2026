import 'package:flutter/material.dart';

import '../models/buddy_statement.dart';
import '../state/service_graph_controller.dart';
import '../util/dates.dart';

/// Requests other veterans sent to me, as a potential witness.
class StatementInboxScreen extends StatelessWidget {
  const StatementInboxScreen({super.key, required this.controller});
  final ServiceGraphController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final inbox = controller.inbox;
        return Scaffold(
          appBar: AppBar(title: const Text('Statement requests')),
          body: inbox.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No requests right now. When someone asks you to describe '
                      'an event from your service together, it shows up here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(children: [
                  for (final r in inbox)
                    ListTile(
                      leading: const Icon(Icons.mark_email_unread_outlined),
                      title: Text('${r.requesterAlias} asked for your statement'),
                      subtitle: Text(
                          '${fullDate(r.event.date)}, ${r.event.stint.locationName}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => BuddyStatementScreen(
                              controller: controller, request: r),
                        ),
                      ),
                    ),
                ]),
        );
      },
    );
  }
}

/// The witness fills this in. The app structures; the witness writes.
class BuddyStatementScreen extends StatefulWidget {
  const BuddyStatementScreen({
    super.key,
    required this.controller,
    required this.request,
  });

  final ServiceGraphController controller;
  final StatementRequest request;

  @override
  State<BuddyStatementScreen> createState() => _BuddyStatementScreenState();
}

class _BuddyStatementScreenState extends State<BuddyStatementScreen> {
  final _draft = BuddyStatementDraft();
  bool _showProblems = false;
  bool _sending = false;

  String get _alias => widget.request.requesterAlias;

  Widget _field(
    String label,
    void Function(String) onChanged, {
    String? hint,
    int minLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          minLines: minLines,
          maxLines: minLines == 1 ? 1 : null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (v) {
            onChanged(v);
            if (_showProblems) setState(() {});
          },
        ),
      );

  Future<void> _preview() async {
    if (_draft.problems().isNotEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    final text = _draft.render(widget.request);
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check your statement'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Send to $_alias'),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await widget.controller.submitStatement(widget.request, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sent to $_alias. You still need to sign the official VA form.'),
      ));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _decline() async {
    await widget.controller.declineStatement(widget.request);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.request.event;
    final problems = _showProblems ? _draft.problems() : const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Buddy statement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_alias is asking about this:', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(e.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 6),
                Text('${fullDate(e.date)}, ${e.stint.unitName}, ${e.stint.locationName}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Write only what you saw or know yourself, in your own words. '
            'Knowingly false statements to VA are a federal crime.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _field('Your full legal name', (v) => _draft.witnessLegalName = v),
          _field('How you know them', (v) => _draft.relationship = v,
              hint: 'e.g. Same squad, 2nd Platoon'),
          _field('How you served together', (v) => _draft.howWeServed = v,
              hint: 'Your unit, job, and dates', minLines: 2),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I saw this happen myself'),
            subtitle: const Text(
                'Turn off if you learned about it soon after, for example at the aid station.'),
            value: _draft.firstHand,
            onChanged: (v) => setState(() => _draft.firstHand = v),
          ),
          const SizedBox(height: 8),
          _field('What you observed', (v) => _draft.observation = v,
              hint: 'What you saw, heard, and did. Where you were standing. Who else was there.',
              minLines: 5),
          _field('Changes you noticed afterward (optional)',
              (v) => _draft.afterEffects = v,
              hint: 'Changes in health, behavior, or duties you saw later.',
              minLines: 3),
          for (final p in problems)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _preview,
            child: const Text('Check your statement'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _sending ? null : _decline,
            child: const Text('Decline this request'),
          ),
        ],
      ),
    );
  }
}
