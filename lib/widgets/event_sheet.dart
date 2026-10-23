import 'package:flutter/material.dart';

import '../models/service_event.dart';
import '../models/service_stint.dart';
import '../util/dates.dart';

/// A stint plus the dates an event may be picked from.
class EventWindow {
  EventWindow(this.stint, this.range);
  final ServiceStint stint;
  final DateRange range;
}

Future<ServiceEvent?> showEventSheet(
  BuildContext context, {
  required List<EventWindow> windows,
}) {
  assert(windows.isNotEmpty);
  return showModalBottomSheet<ServiceEvent>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventSheet(windows: windows),
  );
}

class _EventSheet extends StatefulWidget {
  const _EventSheet({required this.windows});
  final List<EventWindow> windows;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  int _index = 0;
  DateTime? _date;
  final _description = TextEditingController();

  bool _tried = false;

  static const _minDescription = 10;

  EventWindow get _window => widget.windows[_index];

  /// What still needs filling in, or null when the event is complete.
  String? get _missing {
    final noDate = _date == null;
    final shortText = _description.text.trim().length < _minDescription;
    if (noDate && shortText) return 'Pick a date and describe what happened.';
    if (noDate) return 'Pick the date of the event.';
    if (shortText) return 'Describe what happened in a few more words.';
    return null;
  }

  void _continue() {
    if (_missing != null) {
      setState(() => _tried = true);
      return;
    }
    Navigator.pop(
      context,
      ServiceEvent(
        date: _date!,
        stint: _window.stint,
        description: _description.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final r = _window.range;
    final picked = await showDatePicker(
      context: context,
      firstDate: r.start,
      lastDate: r.end,
      initialDate: _date ?? r.start,
      helpText: 'Date of the event',
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What happened?', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Keep it short and factual. Your witness describes it in their own words.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          DropdownMenu<int>(
            initialSelection: _index,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Where you were'),
            dropdownMenuEntries: [
              for (var i = 0; i < widget.windows.length; i++)
                DropdownMenuEntry(
                  value: i,
                  label: '${widget.windows[i].stint.unitName}, '
                      '${widget.windows[i].stint.locationName}',
                ),
            ],
            onSelected: (i) => setState(() {
              _index = i ?? 0;
              _date = null;
            }),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(_date == null
                ? 'Pick a date (${rangeLabel(_window.range)})'
                : fullDate(_date!)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 280,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'What happened',
              hintText: 'e.g. IED blast near the motor pool; I was knocked down',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_tried && _missing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _missing!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}