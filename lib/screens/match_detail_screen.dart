import 'package:flutter/material.dart';

import '../models/service_match.dart';
import '../state/service_graph_controller.dart';
import '../util/dates.dart';
import '../widgets/event_sheet.dart';
import '../widgets/overlap_timeline.dart';

class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({
    super.key,
    required this.controller,
    required this.match,
  });

  final ServiceGraphController controller;
  final ServiceMatch match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final o = match.other;
    final me = controller.me!;
    final gap = me.separationDate.difference(o.separationDate).inDays;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(o.alias)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${o.branch.label}. ${match.fullyVerified ? 'Service verified.' : 'Some service is self-reported.'}',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('Where your service overlapped', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final ov in match.overlaps)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ov.summary),
                      const SizedBox(height: 4),
                      Text(
                        'You: ${ov.mine.roleName}, ${ov.mine.unitName}\n'
                        '${o.alias}: ${ov.theirs.roleName}, ${ov.theirs.unitName}'
                        '${ov.theirs.verified ? '' : ' (self-reported)'}',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      OverlapTimeline(overlap: ov, otherLabel: o.alias),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (match.roles.contains(MatchRole.peer))
              _ActionCard(
                icon: Icons.handshake_outlined,
                title: 'Send a connection request',
                body: 'If ${o.alias} accepts, you can message each other.',
                doneLabel: 'Request sent',
                done: controller.wasSent(o.id, MatchRole.peer),
                onPressed: () async {
                  await controller.connect(match, MatchRole.peer);
                  return true;
                },
              ),
            if (match.roles.contains(MatchRole.mentor))
              _ActionCard(
                icon: Icons.school_outlined,
                title: 'Ask ${o.alias} to mentor you',
                body: '${o.alias} got out ${durationLabel(gap)} before you '
                    'and offered to help people from their unit or job.',
                doneLabel: 'Request sent',
                done: controller.wasSent(o.id, MatchRole.mentor),
                onPressed: () async {
                  await controller.connect(match, MatchRole.mentor);
                  return true;
                },
              ),
            if (match.roles.contains(MatchRole.witness))
              _ActionCard(
                icon: Icons.edit_note,
                title: 'Request a buddy statement',
                body: 'Ask about a specific event from when you served together.',
                doneLabel: 'Statement requested',
                done: controller.wasSent(o.id, MatchRole.witness),
                onPressed: () async {
                  final event = await showEventSheet(context, windows: [
                    for (final ov in match.concurrentOverlaps)
                      EventWindow(ov.mine, ov.shared!),
                  ]);
                  if (event == null) return false;
                  await controller.requestStatement(o.id, event);
                  return true;
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.doneLabel,
    required this.done,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String doneLabel;
  final bool done;

  /// Returns false when the person backed out.
  final Future<bool> Function() onPressed;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final ok = await widget.onPressed();
      if (ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.doneLabel)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('That didn’t go through. Check your connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(widget.body),
                  const SizedBox(height: 12),
                  if (widget.done)
                    Row(children: [
                      const Icon(Icons.check_circle, size: 18),
                      const SizedBox(width: 6),
                      Text(widget.doneLabel),
                    ])
                  else
                    FilledButton.tonal(
                      onPressed: _busy ? null : _run,
                      child: Text(widget.title),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
