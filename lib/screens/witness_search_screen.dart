import 'package:flutter/material.dart';

import '../models/service_event.dart';
import '../models/service_match.dart';
import '../state/service_graph_controller.dart';
import '../util/dates.dart';
import '../widgets/event_sheet.dart';

class WitnessSearchScreen extends StatefulWidget {
  const WitnessSearchScreen({super.key, required this.controller});
  final ServiceGraphController controller;

  @override
  State<WitnessSearchScreen> createState() => _WitnessSearchScreenState();
}

class _WitnessSearchScreenState extends State<WitnessSearchScreen> {
  ServiceEvent? _event;
  List<WitnessCandidate>? _results;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _describe());
  }

  Future<void> _describe() async {
    final me = widget.controller.me!;
    final event = await showEventSheet(context, windows: [
      for (final s in me.stints) EventWindow(s, s.period),
    ]);
    if (event == null || !mounted) return;
    setState(() {
      _event = event;
      _results = null;
      _searching = true;
    });
    try {
      final r = await widget.controller.findWitnesses(event);
      if (mounted) setState(() => _results = r);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Find a witness')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Claims often depend on someone who saw what happened. Describe '
              'the event, and we’ll look for veterans who were in the same unit '
              'or place that day and agreed to be asked.',
            ),
            const SizedBox(height: 16),
            if (event == null)
              FilledButton.icon(
                onPressed: _describe,
                icon: const Icon(Icons.add),
                label: const Text('Describe the event'),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(event.description),
                  subtitle: Text('${fullDate(event.date)}, '
                      '${event.stint.unitName}, ${event.stint.locationName}'),
                  trailing: IconButton(
                    tooltip: 'Change the event',
                    onPressed: _describe,
                    icon: const Icon(Icons.edit),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_searching)
              const Center(child: CircularProgressIndicator())
            else if (results != null && results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nobody who has joined was in that unit or place on that date. '
                  'A Veterans Service Officer (VSO) can help you find witnesses '
                  'through unit rosters and associations.',
                  textAlign: TextAlign.center,
                ),
              )
            else if (results != null && event != null)
              for (final c in results)
                _CandidateTile(
                  candidate: c,
                  sent: widget.controller.wasSent(c.veteran.id, MatchRole.witness),
                  onRequest: () =>
                      widget.controller.requestStatement(c.veteran.id, event),
                ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.sent,
    required this.onRequest,
  });

  final WitnessCandidate candidate;
  final bool sent;
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final how = c.sameUnit ? 'Same unit' : 'Same location';
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(child: Text(c.veteran.initials)),
        title: Text('${c.veteran.alias}, ${c.veteran.branch.label}'),
        subtitle: Text('$how: ${c.stint.unitName}\n'
            '${rangeLabel(c.stint.period)}'
            '${c.verified ? '' : ', self-reported'}'),
        trailing: sent
            ? const Tooltip(
                message: 'Statement requested',
                child: Icon(Icons.check_circle),
              )
            : TextButton(
                onPressed: () async {
                  await onRequest();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Statement requested')));
                  }
                },
                child: const Text('Request'),
              ),
      ),
    );
  }
}
