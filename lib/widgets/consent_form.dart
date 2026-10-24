import 'package:flutter/material.dart';

import '../models/veteran_profile.dart';

class ConsentForm extends StatefulWidget {
  const ConsentForm({
    super.key,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  final GraphConsent initial;
  final String submitLabel;
  final Future<void> Function(GraphConsent consent) onSubmit;

  @override
  State<ConsentForm> createState() => _ConsentFormState();
}

class _ConsentFormState extends State<ConsentForm> {
  late GraphConsent _c = widget.initial;
  bool _saving = false;

  bool get _anyPurpose =>
      _c.peerConnection || _c.buddyWitness || _c.mentor || _c.seekingMentor;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_c.copyWith(discoverable: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _toggle(String title, String subtitle, bool value,
          GraphConsent Function(bool v) update) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (v) => setState(() => _c = update(v)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toggle(
          'Connect with people I served with',
          'Match on the same unit or place, at the same time.',
          _c.peerConnection,
          (v) => _c.copyWith(peerConnection: v),
        ),
        _toggle(
          'Let people ask me for a buddy statement',
          'Only about times we were in the same unit or place. You can say no to any request.',
          _c.buddyWitness,
          (v) => _c.copyWith(buddyWitness: v),
        ),
        _toggle(
          'Offer to mentor',
          'Show me to people who got out 2–10 years after me from my unit or job.',
          _c.mentor,
          (v) => _c.copyWith(mentor: v),
        ),
        _toggle(
          'I’d like a mentor',
          'Show me people who got out 2–10 years before me from my unit or job.',
          _c.seekingMentor,
          (v) => _c.copyWith(seekingMentor: v),
        ),
        const SizedBox(height: 16),
        if (!_anyPurpose)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Turn on at least one option to join.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        FilledButton(
          onPressed: _anyPurpose && !_saving ? _submit : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Other veterans see your alias, branch, and where your service '
              'overlapped with theirs. Never your name, SSN, or DD-214. '
              'Contact details are shared only when you both accept.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
