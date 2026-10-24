import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/service_match.dart';
import '../state/app_state.dart';
import '../state/service_graph_controller.dart';
import 'dd214_roadmap_page.dart' show buildRoadmap, fmtDate;

/// Tab indexes used with [onGo]: 1 Roadmap, 2 Planner, 3 Unit.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.app, required this.graph, required this.onGo});
  final AppState app;
  final ServiceGraphController graph;
  final ValueChanged<int> onGo;

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, graph]),
      builder: (context, _) => ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _hero(context),
              const SizedBox(height: 28),
              Text('Your tools', style: serif(26, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              _tile(
                icon: Icons.route_rounded,
                color: kPine,
                title: 'Roadmap',
                body: _roadmapLine(),
                onTap: () => onGo(1),
              ),
              _tile(
                icon: Icons.calculate_rounded,
                color: kOchre,
                title: 'Planner',
                body: 'Deadlines, rating math, and a toxic exposure check.',
                onTap: () => onGo(2),
              ),
              _tile(
                icon: Icons.groups_rounded,
                color: kSlate,
                title: 'Your unit',
                body: _graphLine(),
                badge: graph.inbox.length,
                onTap: () => onGo(3),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8E3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lock_rounded, color: kPine),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your DD-214 photo is read on this phone and deleted right away. '
                      'Other veterans only see what you choose to share.',
                      style: TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 20, 24, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A7667), Color(0xFF1D3F36)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
        ),
        child: Stack(children: [
          const Positioned(
            right: -14,
            top: -8,
            child: Icon(Icons.star_rounded, size: 130, color: Color(0x14FFFFFF)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting(),
                style: const TextStyle(color: Color(0xFFCFE3DB), fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('The First 90 Days',
                style: serif(36, weight: FontWeight.w800, color: Colors.white, height: 1.1)),
            const SizedBox(height: 10),
            const Text(
              'Your benefits, your claim, and the people who served with you.',
              style: TextStyle(color: Color(0xFFE3EEE9), fontSize: 17, height: 1.4),
            ),
          ]),
        ]),
      );

  String _roadmapLine() {
    final p = app.profile;
    if (p == null) return 'Scan your DD-214 to get your personal checklist.';
    final items = buildRoadmap(p, app.done);
    final left = items.where((i) => !i.done).length;
    return left == 0 ? 'Every step is done.' : '$left of ${items.length} steps left.';
  }

  String _graphLine() {
    final me = graph.me;
    if (me == null || !me.consent.discoverable) {
      return 'Find veterans who were there, and ask for a buddy statement.';
    }
    final people = {
      for (final r in MatchRole.values)
        for (final m in graph.matchesFor(r)) m.other.id,
    }.length;
    return people == 0 ? 'No matches yet. We\u2019ll show them here.' : '$people people from your service.';
  }

  Widget _hero(BuildContext context) {
    final p = app.profile;
    if (p == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: kInk,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Start with your DD-214',
              style: serif(28, weight: FontWeight.w800, color: Colors.white, height: 1.15)),
          const SizedBox(height: 10),
          const Text(
            'Scan it once. Your roadmap, deadlines, and claim planner all build from it.',
            style: TextStyle(color: Color(0xFFC9D3D8), fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => onGo(1),
            icon: const Icon(Icons.document_scanner_rounded),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kInk,
              minimumSize: const Size.fromHeight(58),
            ),
            label: const Text('Scan my DD-214'),
          ),
        ]),
      );
    }

    final now = DateTime.now();
    final next = buildRoadmap(p, app.done).where((i) => !i.done && i.deadline != null).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    final i = next.isEmpty ? null : next.first;
    final days = i?.daysLeft(now);
    final urgent = days != null && days <= 30;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kInk,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i == null ? 'Nothing urgent' : 'Next deadline',
            style: const TextStyle(color: Color(0xFFC9D3D8), fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(i == null ? 'You\u2019re on track.' : i.rule.title,
            style: serif(26, weight: FontWeight.w800, color: Colors.white, height: 1.2)),
        if (i != null) ...[
          const SizedBox(height: 12),
          Text(
            days! < 0 ? 'Past its window' : days == 0 ? 'Today' : '$days days left',
            style: serif(40,
                weight: FontWeight.w900, color: urgent ? const Color(0xFFF2C46D) : const Color(0xFF7FC4AE)),
          ),
          Text(fmtDate(i.deadline!), style: const TextStyle(color: Color(0xFFC9D3D8), fontSize: 17)),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => onGo(1),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: kInk,
            minimumSize: const Size.fromHeight(58),
          ),
          child: const Text('Open my roadmap'),
        ),
      ]),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(16)),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(icon, color: color, size: 30),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: serif(21, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 16, height: 1.35, color: Color(0xFF3B4A54))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, size: 32, color: kInk),
          ]),
        ),
      ),
    );
  }
}
