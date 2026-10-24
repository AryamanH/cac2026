// lib/screens/dd214_roadmap_page.dart
//
// DD-214 scan -> confirm -> rules engine -> living roadmap.
// Everything runs on-device. The photo is deleted right after OCR and the
// raw OCR text is never stored. Only parsed fields are saved (via AppState).
//
// pubspec: cunning_document_scanner, google_mlkit_text_recognition,
//          google_mlkit_commons, shared_preferences, url_launcher
// iOS: NSCameraUsageDescription in Info.plist.

import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../models/discharge_profile.dart';
import '../state/app_state.dart';
import 'claim_simulator_page.dart' show kCombatEnrollmentYears;

// ───────────────────────── Constants ─────────────────────────

const characterOptions = [
  'HONORABLE',
  'GENERAL',
  'OTHER THAN HONORABLE',
  'BAD CONDUCT',
  'DISHONORABLE',
  'UNCHARACTERIZED',
];
// Longer matches first: "DISHONORABLE" and "OTHER THAN HONORABLE" contain "HONORABLE".
const _characterScanOrder = [
  'OTHER THAN HONORABLE',
  'BAD CONDUCT',
  'DISHONORABLE',
  'UNCHARACTERIZED',
  'GENERAL',
  'HONORABLE',
];
const branchOptions = ['Army', 'Navy', 'Air Force', 'Marine Corps', 'Coast Guard', 'Space Force'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String _title(String s) => s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

// ───────────────────────── Parser ─────────────────────────

class Dd214Parser {
  /// Text sitting directly under a label. On a DD-214 the value is printed
  /// below the small box label, so bounding boxes beat plain regex.
  static String? _below(List<TextLine> lines, List<String> labelKeys) {
    TextLine? label;
    for (final l in lines) {
      final s = l.text.toUpperCase();
      if (labelKeys.any(s.contains)) {
        label = l;
        break;
      }
    }
    if (label == null) return null;
    final lb = label.boundingBox;
    TextLine? best;
    var bestDy = double.infinity;
    for (final l in lines) {
      if (identical(l, label)) continue;
      final b = l.boundingBox;
      final dy = b.top - lb.bottom;
      final overlapsX = b.right > lb.left && b.left < lb.right + lb.width * 0.5;
      if (dy >= -4 && dy < lb.height * 6 && overlapsX && dy < bestDy) {
        best = l;
        bestDy = dy;
      }
    }
    return best?.text.toUpperCase();
  }

  static DateTime? _date(String? s) {
    if (s == null) return null;
    final a = RegExp(r'((?:19|20)\d{2})\s?(0[1-9]|1[0-2])\s?(0[1-9]|[12]\d|3[01])').firstMatch(s);
    if (a != null) return DateTime(int.parse(a[1]!), int.parse(a[2]!), int.parse(a[3]!));
    final b = RegExp(r'(\d{1,2})\s*([A-Z]{3})[A-Z]*\s*((?:19|20)\d{2})').firstMatch(s);
    if (b != null) {
      final m = _months.map((e) => e.toUpperCase()).toList().indexOf(b[2]!);
      if (m >= 0) return DateTime(int.parse(b[3]!), m + 1, int.parse(b[1]!));
    }
    return null;
  }

  static DischargeProfile parse(RecognizedText t) {
    final lines = [for (final b in t.blocks) ...b.lines];
    final all = t.text.toUpperCase();
    final p = DischargeProfile();

    // Block 24: character of service
    final charText = _below(lines, ['CHARACTER OF SERVICE']) ?? all;
    for (final c in _characterScanOrder) {
      if (charText.contains(c)) {
        p.character = c;
        break;
      }
    }

    // Block 12b: separation date
    p.separationDate = _date(_below(lines, ['SEPARATION DATE', 'DATE OF SEPARATION']));

    // Block 12c: net active service, "YYYY MM DD" (years, months, days)
    final svc = _below(lines, ['NET ACTIVE SERVICE']);
    final m = svc == null ? null : RegExp(r'(\d{2,4})\s+(\d{2})\s+(\d{2})').firstMatch(svc);
    if (m != null) {
      p.daysServed = int.parse(m[1]!) * 365 + int.parse(m[2]!) * 30 + int.parse(m[3]!);
    }

    // Block 2: branch
    final branchText = _below(lines, ['DEPARTMENT', 'COMPONENT']) ?? all;
    const keys = {
      'AIR FORCE': 'Air Force',
      'SPACE FORCE': 'Space Force',
      'MARINE': 'Marine Corps',
      'COAST GUARD': 'Coast Guard',
      'NAVY': 'Navy',
      'ARMY': 'Army',
    };
    for (final e in keys.entries) {
      if (branchText.contains(e.key)) {
        p.branch = e.value;
        break;
      }
    }

    // Block 11: MOS
    p.mos = _below(lines, ['PRIMARY SPECIALTY']) ?? '';

    // Block 3 (SSN) is never read. Combat service is asked, not guessed.
    return p;
  }
}

// ───────────────────────── Rules engine ─────────────────────────

bool _barred(DischargeProfile p) => p.character == 'DISHONORABLE' || p.character == 'BAD CONDUCT';
DateTime _afterSep(DischargeProfile p, int days) => p.separationDate!.add(Duration(days: days));

class Rule {
  final String id, title, why, url;
  final int priority;
  final bool Function(DischargeProfile) applies;
  final DateTime? Function(DischargeProfile) deadline;

  /// Date someone checked this rule against VA.gov. null = NOT verified yet.
  final String? verified;

  Rule({
    required this.id,
    required this.title,
    required this.why,
    required this.url,
    required this.priority,
    required this.applies,
    required this.deadline,
    this.verified,
  });
}

// VERIFY every rule against VA.gov, then fill in `verified`.
final rules = <Rule>[
  Rule(
    id: 'disability_claim',
    title: 'File a disability claim',
    why: 'If you have any injury or health issue from service, file within one year of leaving. '
        'Claims filed in that window can be paid back to the day after you separated.',
    url: 'https://www.va.gov/disability/how-to-file-claim/',
    priority: 95,
    applies: (p) => !_barred(p),
    deadline: (p) => _afterSep(p, 365),
  ),
  Rule(
    id: 'va_healthcare',
    title: 'Enroll in VA health care',
    why: 'Applying is free and doesn\'t commit you to anything. Veterans who served in a combat zone '
        'get an extra window of enhanced access after discharge, so earlier is better.',
    url: 'https://www.va.gov/health-care/apply/',
    priority: 90,
    applies: (p) => !_barred(p) && p.character != 'OTHER THAN HONORABLE',
    deadline: (p) => p.combat ? _afterSep(p, 365 * kCombatEnrollmentYears) : null, // VERIFY in claim_simulator_page.dart
  ),
  Rule(
    id: 'va_mental_health_oth',
    title: 'Ask about VA mental health care',
    why: 'With an other-than-honorable discharge you may not get full VA health care, '
        'but VA can still offer mental health care. Call and ask what you qualify for.',
    url: 'https://www.va.gov/health-care/health-needs-conditions/mental-health/',
    priority: 92,
    applies: (p) => p.character == 'OTHER THAN HONORABLE',
    deadline: (p) => null,
  ),
  Rule(
    id: 'gi_bill',
    title: 'Check your GI Bill benefits',
    why: 'The GI Bill can pay for school, training, or a housing allowance. '
        'How much you get depends on how long you served.',
    url: 'https://www.va.gov/education/how-to-apply/',
    priority: 80,
    applies: (p) => p.character == 'HONORABLE' && p.daysServed >= 90,
    deadline: (p) => null, // VERIFY: older discharges may have a time limit
  ),
  Rule(
    id: 'vet_center',
    title: 'Find your nearest Vet Center',
    why: 'Vet Centers offer free, confidential counseling and readjustment support, '
        'often with less paperwork than the VA hospital system.',
    url: 'https://www.va.gov/find-locations/?facilityType=vet_center',
    priority: 70,
    applies: (p) => !_barred(p),
    deadline: (p) => null,
  ),
  Rule(
    id: 'discharge_upgrade',
    title: 'Learn about a discharge upgrade',
    why: 'If your discharge isn\'t Honorable, you may be able to ask for a review. An upgrade can '
        'unlock benefits you don\'t currently have. You may still qualify for some now.',
    url: 'https://www.va.gov/discharge-upgrade-instructions/',
    priority: 75,
    applies: (p) => p.character.isNotEmpty && p.character != 'HONORABLE' && p.character != 'UNCHARACTERIZED',
    deadline: (p) => null,
  ),
  Rule(
    id: 'state_benefits',
    title: 'Look up your state benefits',
    why: 'Many states add their own benefits, like tuition breaks, property tax relief, '
        'and hiring preferences. These are separate from the VA.',
    url: 'https://www.va.gov/state-veterans-affairs-offices/',
    priority: 60,
    applies: (p) => !_barred(p),
    deadline: (p) => null,
  ),
];

class RoadmapItem {
  final Rule rule;
  final DateTime? deadline;
  bool done;
  RoadmapItem(this.rule, this.deadline, this.done);

  int? daysLeft(DateTime now) => deadline?.difference(now).inDays;

  double urgency(DateTime now) {
    if (done) return -1;
    final d = daysLeft(now);
    if (d == null) return rule.priority.toDouble();
    if (d < 0) return 1000;
    return rule.priority + 365 / (d + 1);
  }
}

List<RoadmapItem> buildRoadmap(DischargeProfile p, Set<String> done) => [
      for (final r in rules)
        if (p.separationDate != null && r.applies(p)) RoadmapItem(r, r.deadline(p), done.contains(r.id)),
    ];

// ───────────────────────── Page ─────────────────────────

enum _Stage { intro, confirm, roadmap }

class Dd214RoadmapPage extends StatefulWidget {
  const Dd214RoadmapPage({super.key, required this.app});
  final AppState app;
  @override
  State<Dd214RoadmapPage> createState() => _Dd214RoadmapPageState();
}

class _Dd214RoadmapPageState extends State<Dd214RoadmapPage> {
  late _Stage _stage = widget.app.profile == null ? _Stage.intro : _Stage.roadmap;
  DischargeProfile _draft = DischargeProfile();
  bool _busy = false;

  AppState get _app => widget.app;

  Future<void> _scan() async {
    setState(() => _busy = true);
    List<String>? paths;
    try {
      paths = await CunningDocumentScanner.getPictures(noOfPages: 1);
      if (paths == null || paths.isEmpty) return;
      final recognizer = TextRecognizer();
      try {
        final result = await recognizer.processImage(InputImage.fromFilePath(paths.first));
        _draft = Dd214Parser.parse(result);
      } finally {
        await recognizer.close();
      }
      if (mounted) setState(() => _stage = _Stage.confirm);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('We couldn\'t read that photo. Try again in better light, or enter your info by hand.'),
        ));
      }
    } finally {
      // Privacy: the photo never outlives the scan.
      for (final p in paths ?? <String>[]) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _manual() => setState(() {
        _draft = DischargeProfile();
        _stage = _Stage.confirm;
      });

  Future<void> _confirmed(DischargeProfile p) async {
    await _app.saveProfile(p);
    if (mounted) setState(() => _stage = _Stage.roadmap);
  }

  Future<void> _reset() async {
    await _app.reset();
    if (mounted) setState(() => _stage = _Stage.intro);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final profile = _app.profile;
        final stage = (_stage == _Stage.roadmap && profile == null) ? _Stage.intro : _stage;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Your roadmap'),
            actions: [
              if (stage == _Stage.roadmap)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      _draft = _app.profile!;
                      setState(() => _stage = _Stage.confirm);
                    } else {
                      _reset();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit my info')),
                    PopupMenuItem(value: 'reset', child: Text('Delete my data')),
                  ],
                ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (stage) {
              _Stage.intro => _Intro(busy: _busy, onScan: _scan, onManual: _manual),
              _Stage.confirm => _ConfirmForm(key: ValueKey(_draft), initial: _draft, onSave: _confirmed),
              _Stage.roadmap => _Roadmap(profile: profile!, done: _app.done, onToggle: _app.toggle),
            },
          ),
        );
      },
    );
  }
}

// ───────────────────────── Intro ─────────────────────────

class _Intro extends StatelessWidget {
  final bool busy;
  final VoidCallback onScan, onManual;
  const _Intro({required this.busy, required this.onScan, required this.onManual});

  Widget _step(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLine),
            ),
            child: Icon(icon, color: kPine, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 16, height: 1.35, color: Color(0xFF4A5A63))),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const _FormMock(),
        const SizedBox(height: 24),
        Text('Turn your DD-214 into a dated to-do list.', style: serif(30, weight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 12),
        const Text(
          'Scan your discharge paperwork and see which benefits you may qualify for, and by when.',
          style: TextStyle(fontSize: 18, height: 1.45, color: Color(0xFF3B4A54)),
        ),
        const SizedBox(height: 22),
        _step(Icons.document_scanner_outlined, 'Scan your form', 'Lay it flat in good light.'),
        _step(Icons.fact_check_outlined, 'Check what we read', 'Fix anything that looks off.'),
        _step(Icons.format_list_numbered, 'Follow your roadmap', 'Steps are sorted by deadline.'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFDDE8E3), borderRadius: BorderRadius.circular(14)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, color: kPine),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your photo is read on your phone and deleted right away. It never leaves your device, '
                'and we never read your Social Security number.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : onScan,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.document_scanner_outlined),
          label: Text(busy ? 'Reading your form' : 'Scan my DD-214'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onManual,
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: kInk),
          child: const Text('Enter my info by hand'),
        ),
      ],
    );
  }
}

/// A tiny stylized DD-214. A scan line sweeps once and highlights the two
/// fields the roadmap depends on.
class _FormMock extends StatelessWidget {
  const _FormMock();

  Widget _bar(double w) => Container(
        height: 8,
        width: w,
        decoration: BoxDecoration(color: const Color(0xFFE3E8EA), borderRadius: BorderRadius.circular(4)),
      );

  Widget _hit(String tag, double t, double at) => Opacity(
        opacity: ((t - at) * 4).clamp(0.0, 1.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDDE8E3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kPine),
          ),
          child: Row(children: [
            _bar(80),
            const Spacer(),
            Text(tag, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPine)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, t, _) => Container(
        height: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
        ),
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bar(110),
              const SizedBox(height: 9),
              _bar(240),
              const SizedBox(height: 16),
              _hit('Separation date', t, 0.35),
              const SizedBox(height: 10),
              _bar(180),
              const SizedBox(height: 10),
              _hit('Character of service', t, 0.7),
            ]),
          ),
          Positioned(
            top: 200 * t - 3,
            left: 0,
            right: 0,
            child: Container(height: 3, color: t >= 1 ? Colors.transparent : kPine),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Confirm form ─────────────────────────

class _ConfirmForm extends StatefulWidget {
  final DischargeProfile initial;
  final ValueChanged<DischargeProfile> onSave;
  const _ConfirmForm({super.key, required this.initial, required this.onSave});
  @override
  State<_ConfirmForm> createState() => _ConfirmFormState();
}

class _ConfirmFormState extends State<_ConfirmForm> {
  final _formKey = GlobalKey<FormState>();
  late final _mos = TextEditingController(text: widget.initial.mos);
  late final _years = TextEditingController(text: (widget.initial.daysServed ~/ 365).toString());
  late final _monthsC = TextEditingController(text: ((widget.initial.daysServed % 365) ~/ 30).toString());
  late String? _branch = branchOptions.contains(widget.initial.branch) ? widget.initial.branch : null;
  late String? _character = characterOptions.contains(widget.initial.character) ? widget.initial.character : null;
  late DateTime? _sep = widget.initial.separationDate;
  late bool _combat = widget.initial.combat;
  bool _tried = false;

  @override
  void dispose() {
    _mos.dispose();
    _years.dispose();
    _monthsC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _sep ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _sep = d);
  }

  void _save() {
    setState(() => _tried = true);
    if (!_formKey.currentState!.validate() || _sep == null) return;
    widget.onSave(DischargeProfile(
      branch: _branch ?? '',
      mos: _mos.text.trim(),
      character: _character!,
      separationDate: _sep,
      daysServed: (int.tryParse(_years.text) ?? 0) * 365 + (int.tryParse(_monthsC.text) ?? 0) * 30,
      combat: _combat,
    ));
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('Check what we found', style: serif(28, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Photos aren\'t perfect. Fix anything that looks wrong. Your checklist is built from these answers.',
            style: TextStyle(fontSize: 17, height: 1.4),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _branch,
            decoration: _deco('Branch'),
            items: [for (final b in branchOptions) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (v) => setState(() => _branch = v),
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _mos, decoration: _deco('Job or MOS (optional)')),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _deco('Separation date').copyWith(
                errorText: _tried && _sep == null ? 'Pick your separation date' : null,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_sep == null ? 'Tap to choose' : fmtDate(_sep!), style: const TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _character,
            isExpanded: true,
            decoration: _deco('Character of service'),
            validator: (v) => v == null ? 'Choose one' : null,
            items: [for (final c in characterOptions) DropdownMenuItem(value: c, child: Text(_title(c)))],
            onChanged: (v) => setState(() => _character = v),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _years,
                keyboardType: TextInputType.number,
                decoration: _deco('Years served'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _monthsC,
                keyboardType: TextInputType.number,
                decoration: _deco('Extra months'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _combat,
            title: const Text('I served in a combat zone', style: TextStyle(fontSize: 18)),
            subtitle: const Text('This can change when and how you can enroll in VA health care.'),
            onChanged: (v) => setState(() => _combat = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            child: const Text('Build my roadmap'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Roadmap ─────────────────────────

String? _nextLine(List<RoadmapItem> open, DateTime now) {
  final dated = open.where((i) => i.deadline != null).toList()..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  if (dated.isEmpty) return null;
  final i = dated.first;
  final d = i.daysLeft(now)!;
  if (d < 0) return '${i.rule.title} is past its window. Still worth trying.';
  return '${i.rule.title}: $d days left';
}

class _Roadmap extends StatelessWidget {
  final DischargeProfile profile;
  final Set<String> done;
  final void Function(String id, bool value) onToggle;
  const _Roadmap({required this.profile, required this.done, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); // recomputed every build = "living"
    final items = buildRoadmap(profile, done);
    final open = items.where((i) => !i.done).toList()..sort((a, b) => b.urgency(now).compareTo(a.urgency(now)));
    final soon = open.where((i) => (i.daysLeft(now) ?? 9999) <= 30).toList();
    final later = open.where((i) => (i.daysLeft(now) ?? 9999) > 30).toList();
    final finished = items.where((i) => i.done).toList();

    Widget section(String title, List<RoadmapItem> list) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 8),
              child: Row(children: [
                Text(title, style: serif(24, weight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('${list.length}',
                    style: const TextStyle(fontSize: 16, color: Colors.black45, fontWeight: FontWeight.w600)),
              ]),
            ),
            for (final i in list) _ItemCard(item: i, now: now, onToggle: onToggle),
          ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        _Summary(profile: profile, total: items.length, finished: finished.length, next: _nextLine(open, now)),
        if (profile.character == 'OTHER THAN HONORABLE' || profile.character == 'UNCHARACTERIZED')
          const _Note('Your discharge type limits some benefits, but you may still qualify for others. '
              'Each step below says what to ask.'),
        section('Do these first', soon),
        section('Coming up', later),
        section('Done', finished),
        const SizedBox(height: 24),
        const Text(
          'This is general information, not legal advice. Eligibility is decided by the VA. '
          'Tap a step to see the official page.',
          style: TextStyle(color: Colors.black54, height: 1.4, fontSize: 14),
        ),
      ],
    );
  }
}

/// Styled like a dog tag: the one memorable element on this screen.
class _Summary extends StatelessWidget {
  final DischargeProfile profile;
  final int total, finished;
  final String? next;
  const _Summary({required this.profile, required this.total, required this.finished, this.next});

  @override
  Widget build(BuildContext context) {
    const edge = Color(0xFF7C8B94);
    final frac = total == 0 ? 0.0 : finished / total;
    final bits = [
      if (profile.separationDate != null) 'Separated ${fmtDate(profile.separationDate!)}',
      if (profile.character.isNotEmpty) _title(profile.character),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A5A64), Color(0xFF1E2B33)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: edge, width: 1.5),
      ),
      child: Stack(children: [
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: kPaper, shape: BoxShape.circle, border: Border.all(color: edge, width: 1.5)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 40, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    profile.branch.isEmpty ? 'VETERAN' : profile.branch.toUpperCase(),
                    style: serif(26, weight: FontWeight.w800, color: Colors.white, letterSpacing: 2),
                  ),
                  if (profile.mos.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(profile.mos,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D3D8), fontSize: 16)),
                  ],
                  const SizedBox(height: 10),
                  for (final b in bits) Text(b, style: const TextStyle(color: Color(0xFFE6ECEF), height: 1.4, fontSize: 16)),
                ]),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: v,
                        strokeWidth: 7,
                        backgroundColor: const Color(0xFF3B4A54),
                        color: const Color(0xFF7FC4AE),
                      ),
                    ),
                    Text('$finished/$total',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                ),
              ),
            ]),
            if (next != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.flag_outlined, color: Color(0xFFF2C46D), size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(next!, style: const TextStyle(color: Colors.white, height: 1.3, fontSize: 16))),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6E8CC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kOchre),
        ),
        child: Text(text, style: const TextStyle(height: 1.4, fontSize: 16)),
      );
}

const _ruleIcons = <String, IconData>{
  'disability_claim': Icons.assignment_outlined,
  'va_healthcare': Icons.local_hospital_outlined,
  'va_mental_health_oth': Icons.psychology_outlined,
  'gi_bill': Icons.school_outlined,
  'vet_center': Icons.groups_outlined,
  'discharge_upgrade': Icons.workspace_premium_outlined,
  'state_benefits': Icons.map_outlined,
};

class _ItemCard extends StatefulWidget {
  final RoadmapItem item;
  final DateTime now;
  final void Function(String id, bool value) onToggle;
  const _ItemCard({required this.item, required this.now, required this.onToggle});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final r = item.rule;
    final d = item.daysLeft(widget.now);
    String? pill;
    Color color = kPine;
    if (item.done) {
      color = const Color(0xFF9AA8AF);
    } else if (d == null) {
      pill = 'No deadline';
      color = const Color(0xFF6B7A83);
    } else if (d < 0) {
      pill = 'Overdue by ${-d} days. Still worth trying.';
      color = kBrick;
    } else if (d <= 30) {
      pill = '$d days left';
      color = kBrick;
    } else if (d <= 120) {
      pill = '$d days left';
      color = kOchre;
    } else {
      pill = 'By ${fmtDate(item.deadline!)}';
    }

    // No IntrinsicHeight and no fixed heights: the card sizes itself to its
    // content, so large text sizes can't overflow.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(left: 0, top: 0, bottom: 0, width: 6, child: ColoredBox(color: color)),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 14, 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Transform.scale(
                    scale: 1.15,
                    child: Checkbox(
                      value: item.done,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: (v) => widget.onToggle(r.id, v ?? false),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(_ruleIcons[r.id] ?? Icons.check_circle_outline, size: 22, color: color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.title,
                              style: serif(19, color: item.done ? Colors.black45 : kInk, height: 1.2).copyWith(
                                decoration: item.done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ]),
                        if (pill != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withAlpha(28),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(pill,
                                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14.5)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded, size: 30),
                    ),
                  ),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 18, 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.why, style: const TextStyle(height: 1.45, fontSize: 16.5, color: Color(0xFF2B3A43))),
                        const SizedBox(height: 10),
                        Text(
                          r.verified == null
                              ? 'Rule not yet checked against VA.gov'
                              : 'Checked against VA.gov on ${r.verified}',
                          style: const TextStyle(fontSize: 13.5, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication),
                          child: const Text('Open the official page'),
                        ),
                      ]),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      ]),
    );
  }
}
