import 'package:flutter/material.dart';

import '../screens/claim_simulator_page.dart';
import '../screens/dd214_roadmap_page.dart';
import '../screens/home_screen.dart';
import '../screens/service_graph_home.dart';
import '../state/app_state.dart';
import '../state/service_graph_controller.dart';
import 'theme.dart';

/// Four tabs. Detail screens (matches, statements, settings) push on top.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.app, required this.graph});
  final AppState app;
  final ServiceGraphController graph;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        if (!widget.app.loaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final p = widget.app.profile;
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              HomeScreen(app: widget.app, graph: widget.graph, onGo: _go),
              Dd214RoadmapPage(app: widget.app),
              // New key when the discharge date changes, so the planner re-prefills.
              ClaimSimulatorPage(
                key: ValueKey(p?.separationDate),
                dischargeDate: p?.separationDate,
                servedInCombat: p?.combat ?? false,
              ),
              ServiceGraphHome(controller: widget.graph),
            ],
          ),
          bottomNavigationBar: _FloatingNav(index: _index, onTap: _go),
        );
      },
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.route_rounded, 'Roadmap'),
    (Icons.calculate_rounded, 'Planner'),
    (Icons.groups_rounded, 'Unit'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kInk,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 22, offset: Offset(0, 8))],
          ),
          child: Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: _items[i].$2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: i == index ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_items[i].$1, size: 26, color: i == index ? kPine : const Color(0xFFB8C5CC)),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: i == index ? kInk : const Color(0xFFB8C5CC),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
