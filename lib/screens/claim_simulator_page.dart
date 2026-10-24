import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// claim_simulator_page.dart  —  "First 90 Days" Feature 2 (simplified UI)
//
// One page, two big modes:
//   • My Deadlines – next deadline up front, rest of the list underneath
//   • My Claim     – combined VA rating + monthly pay, with "planning to file"
//                    what-ifs. A button opens the toxic-exposure (PACT) check.
//
// Uses ONLY the Flutter SDK (material.dart): no pubspec changes needed.
// Optional prefill from the DD-214 scan:
//   ClaimSimulatorPage(dischargeDate: someDate, servedInCombat: true)
//
// !! VERIFY every rule and number against va.gov and 38 CFR before demoing !!
// =============================================================================

// ----------------------------------------------------------------------------
// DATA
// 2026 monthly VA disability pay, veteran alone (no dependents), effective
// Dec 1, 2025. A new COLA normally starts Dec 1, 2026 -> UPDATE THIS MAP then.
// ----------------------------------------------------------------------------
const Map<int, double> kMonthlyComp2026 = {
  10: 180.42,
  20: 356.66,
  30: 552.47,
  40: 795.84,
  50: 1132.90,
  60: 1435.02,
  70: 1808.45,
  80: 2102.15,
  90: 2362.30,
  100: 3938.58,
};

// Combat-veteran enhanced VA health-care enrollment window. VA fact sheets say
// 5 years; the PACT Act may have extended it. VERIFY on va.gov.
// The Roadmap tab reads this same constant, so fix it once, here.
const int kCombatEnrollmentYears = 5;

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _today() => _day(DateTime.now());
DateTime _addDays(DateTime d, int n) => d.add(Duration(days: n));
DateTime _addYears(DateTime d, int n) =>
    DateTime.utc(d.year + n, d.month, d.day);
int _daysBetween(DateTime a, DateTime b) => b.difference(a).inDays;

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String _pct(double v) => '${v.toStringAsFixed(1)}%';
String _plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

String _money(double v, {int decimals = 0}) {
  final parts = v.toStringAsFixed(decimals).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '\$$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

// Text style helper: big and readable by default.
TextStyle _t(double size, {FontWeight? w, Color? c}) => size >= 24
    ? GoogleFonts.fraunces(fontSize: size, fontWeight: w, color: c, height: 1.2)
    : TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.3);

ButtonStyle _bigFilled() => FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(60),
      textStyle: _t(20, w: FontWeight.w600),
    );

ButtonStyle _bigOutlined() => OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      textStyle: _t(19, w: FontWeight.w600),
    );

Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) async {
  final start = initial == null
      ? DateTime.now()
      : DateTime(initial.year, initial.month, initial.day); // avoid UTC shift
  final picked = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(1950),
    lastDate: DateTime(2100),
  );
  return picked == null ? null : _day(picked);
}

// ----------------------------------------------------------------------------
// LOGIC: VA combined rating (38 CFR 4.25 "whole person"), rounded to nearest 10.
// Not modeled: bilateral factor, SMC, TDIU, dependents.
// ----------------------------------------------------------------------------
class _Step {
  const _Step(this.rating, this.before, this.after);
  final int rating;
  final double before;
  final double after;
}

class CombinedResult {
  const CombinedResult(this.exact, this.rounded, this.steps);
  final double exact;
  final int rounded;
  final List<_Step> steps;
  double get monthly => kMonthlyComp2026[rounded] ?? 0;
}

CombinedResult combineRatings(List<int> ratings) {
  final sorted = [...ratings]..sort((a, b) => b.compareTo(a));
  double remaining = 100;
  final steps = <_Step>[];
  for (final r in sorted) {
    final before = remaining;
    remaining = remaining * (100 - r) / 100;
    steps.add(_Step(r, before, remaining));
  }
  final exact = 100 - remaining;
  int rounded = ((exact / 10) + 1e-9).round() * 10;
  if (rounded > 100) rounded = 100;
  return CombinedResult(exact, rounded, steps);
}

// ============================================================================
// THE PAGE
// ============================================================================
class ClaimSimulatorPage extends StatefulWidget {
  const ClaimSimulatorPage({
    super.key,
    this.dischargeDate,
    this.servedInCombat = false,
  });

  final DateTime? dischargeDate;
  final bool servedInCombat;

  @override
  State<ClaimSimulatorPage> createState() => _ClaimSimulatorPageState();
}

class _ClaimSimulatorPageState extends State<ClaimSimulatorPage> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Planner', style: _t(24, w: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'My Deadlines',
                    icon: Icons.event_note,
                    selected: _mode == 0,
                    onTap: () => setState(() => _mode = 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeButton(
                    label: 'My Claim',
                    icon: Icons.calculate,
                    selected: _mode == 1,
                    onTap: () => setState(() => _mode = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _mode,
              children: [
                _DeadlinesView(
                  dischargeDate: widget.dischargeDate,
                  servedInCombat: widget.servedInCombat,
                ),
                const _ClaimView(),
              ],
            ),
          ),
          const _Disclaimer(),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary : scheme.secondaryContainer;
    final fg = selected ? scheme.onPrimary : scheme.onSecondaryContainer;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, size: 30, color: fg),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: _t(19, w: FontWeight.w700, c: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: scheme.tertiaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          'Estimates only, not legal advice. Confirm with your town\'s '
          'Veterans\' Services Officer.',
          textAlign: TextAlign.center,
          style: _t(16, c: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}

// ============================================================================
// MODE 1: MY DEADLINES
// ============================================================================
class _Milestone {
  const _Milestone(this.date, this.title, this.detail);
  final DateTime date;
  final String title;
  final String detail;
}

class _DeadlinesView extends StatefulWidget {
  const _DeadlinesView({this.dischargeDate, this.servedInCombat = false});
  final DateTime? dischargeDate;
  final bool servedInCombat;

  @override
  State<_DeadlinesView> createState() => _DeadlinesViewState();
}

class _DeadlinesViewState extends State<_DeadlinesView> {
  DateTime? _discharge;
  late bool _combat;
  bool _showPast = false;
  int _transDays = 0; // coverage right after discharge: 0 or 180
  int _vaDays = 60; // days until VA coverage starts

  @override
  void initState() {
    super.initState();
    _discharge =
        widget.dischargeDate == null ? null : _day(widget.dischargeDate!);
    _combat = widget.servedInCombat;
  }

  // Dates computed from the discharge date. VERIFY each rule on va.gov.
  List<_Milestone> _milestones(DateTime d) {
    final list = <_Milestone>[
      _Milestone(
        _addDays(d, 120),
        'Free military life insurance ends',
        'Your free SGLI coverage stops. You can switch to VGLI, a lifetime '
            'plan that you pay for.',
      ),
      _Milestone(
        _addDays(d, 180),
        'Apply for VA dental care',
        'Eligible veterans must apply within 180 days of leaving. After that, '
            'this one-time benefit is gone.',
      ),
      _Milestone(
        _addDays(d, 240),
        'Switch life insurance, no health questions',
        'Convert to VGLI within 240 days and you do not have to prove you are '
            'in good health.',
      ),
      _Milestone(
        _addYears(d, 1),
        'File your disability claim',
        'File within 1 year and you can be paid back to the day after you '
            'left. File later and that back pay is usually lost.',
      ),
      _Milestone(
        _addDays(_addYears(d, 1), 120),
        'Last day to switch life insurance',
        'After the 240 days you can still switch until this date, but you '
            'must prove good health.',
      ),
    ];
    if (_combat) {
      list.add(
        _Milestone(
          _addYears(d, kCombatEnrollmentYears),
          'Enroll in VA health care (combat window)',
          'Combat veterans get a special window to enroll. After it closes, '
              'getting in gets harder. Verify the exact length on va.gov.',
        ),
      );
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final d = _discharge;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: d == null ? _emptyState() : _content(d),
    );
  }

  List<Widget> _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When did you leave the military?',
                style: _t(26, w: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'We will show the deadlines that start counting from that day.',
                style: _t(18),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: _bigFilled(),
                icon: const Icon(Icons.event, size: 28),
                label: const Text('Pick my discharge date'),
                onPressed: () async {
                  final p = await _pickDate(context, null);
                  if (p != null) setState(() => _discharge = p);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: _t(18),
                ),
                onPressed: () =>
                    setState(() => _discharge = _addDays(_today(), -20)),
                child: Text(
                  'Try a sample date',
                  style: _t(18, c: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _content(DateTime d) {
    final scheme = Theme.of(context).colorScheme;
    final today = _today();
    final all = _milestones(d);
    final upcoming = all.where((m) => !m.date.isBefore(today)).toList();
    final past = all.where((m) => m.date.isBefore(today)).toList();
    final next = upcoming.isEmpty ? null : upcoming.first;
    final later = upcoming.length > 1 ? upcoming.sublist(1) : <_Milestone>[];

    return [
      Row(
        children: [
          Expanded(child: Text('Left service: ${_fmt(d)}', style: _t(18))),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 52),
              textStyle: _t(18, w: FontWeight.w600),
            ),
            onPressed: () async {
              final p = await _pickDate(context, d);
              if (p != null) setState(() => _discharge = p);
            },
            child: const Text('Change'),
          ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('I served in a combat zone', style: _t(18)),
        value: _combat,
        onChanged: (v) => setState(() => _combat = v),
      ),
      const SizedBox(height: 8),
      if (next != null)
        _NextDeadlineCard(m: next, today: today)
      else
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'All of these deadlines have passed. Ask your Veterans\' '
              'Services Officer what is still open.',
              style: _t(20, c: scheme.onPrimaryContainer),
            ),
          ),
        ),
      if (later.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('After that', style: _t(22, w: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final m in later) _DeadlineRow(m: m, today: today),
      ],
      if (past.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => setState(() => _showPast = !_showPast),
          child: Text(
            _showPast
                ? 'Hide past deadlines'
                : 'Show past deadlines (${past.length})',
            style: _t(18, w: FontWeight.w600),
          ),
        ),
        if (_showPast)
          for (final m in past) _DeadlineRow(m: m, today: today),
      ],
      const SizedBox(height: 16),
      _gapCard(d),
      const SizedBox(height: 24),
    ];
  }

  Widget _gapCard(DateTime d) {
    final scheme = Theme.of(context).colorScheme;
    final gap = (_vaDays - _transDays).clamp(0, 100000);

    Widget chips(
      List<int> values,
      int current,
      String Function(int) label,
      void Function(int) onPick,
    ) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v), style: _t(18)),
              labelPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 10,
              ),
              selected: current == v,
              onSelected: (_) => setState(() => onPick(v)),
            ),
        ],
      );
    }

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          'Will I have a health coverage gap?',
          style: _t(20, w: FontWeight.w700),
        ),
        children: [
          Text('Coverage right after you leave', style: _t(18)),
          const SizedBox(height: 8),
          chips(
            [0, 180],
            _transDays,
            (v) => v == 0 ? 'None' : 'Up to 180 days',
            (v) => _transDays = v,
          ),
          const SizedBox(height: 16),
          Text('VA health care starts after', style: _t(18)),
          const SizedBox(height: 8),
          chips([30, 60, 90], _vaDays, (v) => '$v days', (v) => _vaDays = v),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: gap == 0 ? scheme.primaryContainer : scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              gap == 0
                  ? 'No gap with these numbers.'
                  : 'You could be uninsured for ${_plural(gap, 'day')}: '
                      '${_fmt(_addDays(d, _transDays))} to '
                      '${_fmt(_addDays(d, _vaDays))}. Apply for VA health '
                      'care as early as you can.',
              style: _t(
                19,
                w: FontWeight.w600,
                c: gap == 0
                    ? scheme.onPrimaryContainer
                    : scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tone {
  const _Tone(this.bg, this.fg, this.dot, this.label);
  final Color bg;
  final Color fg;
  final Color dot;
  final String label;
}

_Tone _toneFor(BuildContext context, int days) {
  final s = Theme.of(context).colorScheme;
  if (days <= 30) {
    return _Tone(
      s.errorContainer,
      s.onErrorContainer,
      Colors.red.shade700,
      'URGENT',
    );
  }
  if (days <= 90) {
    return _Tone(
      s.tertiaryContainer,
      s.onTertiaryContainer,
      Colors.orange.shade800,
      'COMING SOON',
    );
  }
  return _Tone(
    s.primaryContainer,
    s.onPrimaryContainer,
    Colors.teal.shade700,
    'UPCOMING',
  );
}

String _countdown(int days) => days == 0
    ? 'Today'
    : days == 1
        ? '1 day left'
        : '$days days left';

class _NextDeadlineCard extends StatelessWidget {
  const _NextDeadlineCard({required this.m, required this.today});
  final _Milestone m;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = _daysBetween(today, m.date);
    final tone = _toneFor(context, days);
    final months = days ~/ 30;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT DEADLINE  ·  ${tone.label}',
            style: _t(16, w: FontWeight.w800, c: tone.fg),
          ),
          const SizedBox(height: 8),
          Text(
            m.title,
            style: _t(26, w: FontWeight.w800, c: tone.fg),
          ),
          const SizedBox(height: 12),
          Text(
            _countdown(days),
            style: _t(44, w: FontWeight.w900, c: tone.fg),
          ),
          Text(
            '${_fmt(m.date)}${days >= 90 ? '  ·  about ${_plural(months, 'month')}' : ''}',
            style: _t(18, c: tone.fg),
          ),
          const SizedBox(height: 12),
          Text(m.detail, style: _t(18, c: tone.fg)),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.m, required this.today});
  final _Milestone m;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = _daysBetween(today, m.date);
    final passed = days < 0;
    final tone = _toneFor(context, days);
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: passed ? Colors.grey : tone.dot,
          child: Icon(
            passed ? Icons.check : Icons.event,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(m.title, style: _t(19, w: FontWeight.w700)),
        subtitle: Text(
          passed
              ? 'Passed ${_fmt(m.date)}'
              : '${_fmt(m.date)}  ·  ${_countdown(days)}',
          style: _t(17),
        ),
        children: [Text(m.detail, style: _t(18))],
      ),
    );
  }
}

// ============================================================================
// MODE 2: MY CLAIM
// ============================================================================
class _Claim {
  _Claim(this.rating, {this.planned = false});
  int rating; // 10..100 in steps of 10
  bool planned; // true = "planning to file" (what-if)
}

class _ClaimView extends StatefulWidget {
  const _ClaimView();

  @override
  State<_ClaimView> createState() => _ClaimViewState();
}

class _ClaimViewState extends State<_ClaimView> {
  // Demo default: 50% rated + 30% planned -> shows 70%, not 80%.
  final List<_Claim> _claims = [_Claim(50), _Claim(30, planned: true)];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = combineRatings(
      _claims.where((c) => !c.planned).map((c) => c.rating).toList(),
    );
    final all = combineRatings(_claims.map((c) => c.rating).toList());
    final hasPlan = _claims.any((c) => c.planned);
    final hasRated = _claims.any((c) => !c.planned);
    final delta = all.monthly - current.monthly;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'What could my claim be worth?',
          style: _t(26, w: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text('Add each condition and its VA rating.', style: _t(18)),
        const SizedBox(height: 12),
        for (var i = 0; i < _claims.length; i++) _claimCard(i),
        if (_claims.length < 6)
          OutlinedButton.icon(
            style: _bigOutlined(),
            icon: const Icon(Icons.add, size: 28),
            label: const Text('Add another condition'),
            onPressed: () =>
                setState(() => _claims.add(_Claim(10, planned: true))),
          ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasPlan ? 'WITH YOUR PLAN' : 'YOUR COMBINED RATING',
                style: _t(16, w: FontWeight.w800, c: scheme.onPrimaryContainer),
              ),
              Text(
                '${all.rounded}%',
                style: _t(64, w: FontWeight.w900, c: scheme.onPrimaryContainer),
              ),
              Text(
                '${_money(all.monthly)} a month',
                style: _t(28, w: FontWeight.w700, c: scheme.onPrimaryContainer),
              ),
              Text(
                '${_money(all.monthly * 12)} a year, tax-free',
                style: _t(18, c: scheme.onPrimaryContainer),
              ),
              if (hasPlan) ...[
                const Divider(height: 28),
                Text(
                  hasRated
                      ? 'Now: ${current.rounded}%  ·  ${_money(current.monthly)} a month'
                      : 'Now: nothing rated yet',
                  style: _t(18, c: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  delta > 0
                      ? '+${_money(delta)} a month'
                      : 'No change in monthly pay',
                  style: _t(
                    26,
                    w: FontWeight.w800,
                    c: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text('Show the math', style: _t(19, w: FontWeight.w700)),
            children: [
              for (final s in all.steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '${s.rating}%:  ${_pct(s.before)} × ${100 - s.rating}% = ${_pct(s.after)} left',
                    style: _t(18),
                  ),
                ),
              if (all.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '100 − ${_pct(all.steps.last.after)} = ${_pct(all.exact)}, '
                  'rounded to ${all.rounded}%',
                  style: _t(18, w: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Pay is the 2026 rate for a veteran with no dependents. '
                'Dependents add more at 30% and above.',
                style: _t(16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: scheme.secondaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const _PactSheet(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.travel_explore,
                    size: 36,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toxic exposure check',
                          style: _t(
                            20,
                            w: FontWeight.w800,
                            c: scheme.onSecondaryContainer,
                          ),
                        ),
                        Text(
                          'Did you serve somewhere that may qualify?',
                          style: _t(17, c: scheme.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 32,
                    color: scheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _claimCard(int i) {
    final c = _claims[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Condition ${i + 1}',
                    style: _t(20, w: FontWeight.w700),
                  ),
                ),
                if (_claims.length > 1)
                  IconButton(
                    tooltip: 'Remove condition ${i + 1}',
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 52,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _claims.removeAt(i)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Already rated',
                          textAlign: TextAlign.center,
                          style: _t(17),
                        ),
                      ),
                      labelPadding: const EdgeInsets.symmetric(vertical: 10),
                      selected: !c.planned,
                      onSelected: (_) => setState(() => c.planned = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Planning to file',
                          textAlign: TextAlign.center,
                          style: _t(17),
                        ),
                      ),
                      labelPadding: const EdgeInsets.symmetric(vertical: 10),
                      selected: c.planned,
                      onSelected: (_) => setState(() => c.planned = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Lower rating',
                    iconSize: 32,
                    constraints: const BoxConstraints(
                      minWidth: 60,
                      minHeight: 60,
                    ),
                    icon: const Icon(Icons.remove),
                    onPressed: c.rating > 10
                        ? () => setState(() => c.rating -= 10)
                        : null,
                  ),
                  Semantics(
                    label: 'Rating ${c.rating} percent',
                    child: Text(
                      '${c.rating}%',
                      style: _t(40, w: FontWeight.w800),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Raise rating',
                    iconSize: 32,
                    constraints: const BoxConstraints(
                      minWidth: 60,
                      minHeight: 60,
                    ),
                    icon: const Icon(Icons.add),
                    onPressed: c.rating < 100
                        ? () => setState(() => c.rating += 10)
                        : null,
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

// ============================================================================
// TOXIC EXPOSURE (PACT) CHECK: limited prototype, opens as a pop-up sheet.
// VERIFY each rule on va.gov. Condition lists are EXAMPLES only.
// ============================================================================
class _PactRule {
  _PactRule({
    required this.short,
    required this.title,
    required this.start,
    this.end,
    this.minDays = 1,
    required this.conditions,
    required this.note,
  });

  final String short;
  final String title;
  final DateTime start;
  final DateTime? end;
  final int minDays;
  final List<String> conditions;
  final String note;

  String get windowText => end == null
      ? 'on or after ${_fmt(start)}'
      : '${_fmt(start)} to ${_fmt(end!)}';
}

final List<_PactRule> _pactRules = [
  _PactRule(
    short: 'Gulf region',
    title: 'Iraq, Kuwait, Saudi Arabia, Qatar, UAE, Bahrain, Oman, or Somalia',
    start: DateTime.utc(1990, 8, 2),
    conditions: const [
      'Asthma',
      'Chronic bronchitis and COPD',
      'Chronic sinusitis and rhinitis',
      'Interstitial lung disease',
      'Certain cancers (e.g., lymphoma, kidney)',
    ],
    note: 'Burn pit and airborne hazard presumptions.',
  ),
  _PactRule(
    short: 'Afghanistan',
    title: 'Afghanistan (VA lists other countries too)',
    start: DateTime.utc(2001, 9, 11),
    conditions: const [
      'Asthma',
      'Chronic bronchitis and COPD',
      'Chronic sinusitis and rhinitis',
      'Interstitial lung disease',
      'Certain cancers (e.g., lymphoma, kidney)',
    ],
    note: 'Burn pit and airborne hazard presumptions.',
  ),
  _PactRule(
    short: 'Vietnam',
    title: 'Vietnam (in country or inland waterways)',
    start: DateTime.utc(1962, 1, 9),
    end: DateTime.utc(1975, 5, 7),
    conditions: const [
      'Ischemic heart disease',
      'Type 2 diabetes',
      'Parkinson\'s disease',
      'Prostate cancer',
      'Hypertension',
    ],
    note: 'Agent Orange presumptions. Other locations have their own rules '
        'and are not in this prototype.',
  ),
  _PactRule(
    short: 'Camp Lejeune',
    title: 'Camp Lejeune, NC (30+ days)',
    start: DateTime.utc(1953, 8, 1),
    end: DateTime.utc(1987, 12, 31),
    minDays: 30,
    conditions: const [
      'Kidney cancer',
      'Bladder cancer',
      'Liver cancer',
      'Adult leukemia',
      'Non-Hodgkin\'s lymphoma',
      'Parkinson\'s disease',
    ],
    note: 'Contaminated water. Needs 30+ days in the window.',
  ),
];

const List<String> _evidenceItems = [
  'Proof of where and when I served',
  'A current diagnosis from a provider',
  'Medical records for the condition',
];

class _PactSheet extends StatefulWidget {
  const _PactSheet();

  @override
  State<_PactSheet> createState() => _PactSheetState();
}

class _PactSheetState extends State<_PactSheet> {
  _PactRule? _rule;
  DateTime? _start;
  DateTime? _end;
  final Set<int> _have = {};

  int _overlap(_PactRule r) {
    if (_start == null || _end == null) return 0;
    final s = _start!.isAfter(r.start) ? _start! : r.start;
    final rEnd = r.end ?? DateTime.utc(9999);
    final e = _end!.isBefore(rEnd) ? _end! : rEnd;
    final n = e.difference(s).inDays + 1;
    return n > 0 ? n : 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _rule;
    final badRange = _start != null && _end != null && _end!.isBefore(_start!);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Toxic exposure check',
                  style: _t(26, w: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                iconSize: 32,
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text('Prototype: 4 locations only.', style: _t(16)),
          const SizedBox(height: 16),
          Text('Where did you serve?', style: _t(20, w: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final rule in _pactRules)
                ChoiceChip(
                  label: Text(rule.short, style: _t(18)),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  selected: _rule == rule,
                  onSelected: (_) => setState(() {
                    _rule = rule;
                    _have.clear();
                  }),
                ),
            ],
          ),
          if (r != null) ...[
            const SizedBox(height: 12),
            Text(r.title, style: _t(18)),
            Text('Qualifying dates: ${r.windowText}', style: _t(17)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: _bigOutlined(),
              icon: const Icon(Icons.flight_takeoff),
              label: Text(
                _start == null ? 'Date I arrived' : 'Arrived: ${_fmt(_start!)}',
              ),
              onPressed: () async {
                final p = await _pickDate(context, _start);
                if (p != null) setState(() => _start = p);
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: _bigOutlined(),
              icon: const Icon(Icons.flight_land),
              label: Text(
                _end == null ? 'Date I left' : 'Left: ${_fmt(_end!)}',
              ),
              onPressed: () async {
                final p = await _pickDate(context, _end ?? _start);
                if (p != null) setState(() => _end = p);
              },
            ),
            if (badRange)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'The end date is before the start date.',
                  style: _t(18, c: scheme.error),
                ),
              ),
            if (_start != null && _end != null && !badRange) ...[
              const SizedBox(height: 20),
              _result(scheme, r),
            ],
          ],
        ],
      ),
    );
  }

  Widget _result(ColorScheme scheme, _PactRule r) {
    final ov = _overlap(r);
    final ok = ov >= r.minDays;
    final bg = ok ? scheme.primaryContainer : scheme.errorContainer;
    final fg = ok ? scheme.onPrimaryContainer : scheme.onErrorContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ok ? 'Possible match' : 'No match here',
                style: _t(26, w: FontWeight.w800, c: fg),
              ),
              const SizedBox(height: 6),
              Text(
                ok
                    ? 'Your service overlaps the qualifying dates by '
                        '${_plural(ov, 'day')}.'
                    : r.minDays > 1
                        ? 'This one needs at least ${r.minDays} days in the '
                            'window. You have ${_plural(ov, 'day')}.'
                        : 'Your dates do not overlap the qualifying window.',
                style: _t(18, c: fg),
              ),
            ],
          ),
        ),
        if (ok) ...[
          const SizedBox(height: 16),
          Text(
            'Conditions the VA may presume',
            style: _t(20, w: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final c in r.conditions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('•  $c', style: _t(18)),
            ),
          const SizedBox(height: 6),
          Text(
            '${r.note} These are examples. The VA list is longer.',
            style: _t(16),
          ),
          const SizedBox(height: 20),
          Text(
            'What you still need  (${_have.length} of ${_evidenceItems.length} ready)',
            style: _t(20, w: FontWeight.w700),
          ),
          for (var i = 0; i < _evidenceItems.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(_evidenceItems[i], style: _t(18)),
              value: _have.contains(i),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _have.add(i);
                } else {
                  _have.remove(i);
                }
              }),
            ),
        ],
      ],
    );
  }
}
