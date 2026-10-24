import 'package:flutter/material.dart';

import '../models/service_match.dart';
import '../state/service_graph_controller.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';
import 'opt_in_screen.dart';
import 'statement_screens.dart';
import 'witness_search_screen.dart';

class ServiceGraphHome extends StatelessWidget {
  const ServiceGraphHome({super.key, required this.controller});
  final ServiceGraphController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.loading && controller.me == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final error = controller.error;
        if (error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: controller.load, child: const Text('Try again')),
                ]),
              ),
            ),
          );
        }

        final me = controller.me!;
        if (!me.consent.discoverable) return OptInScreen(controller: controller);

        final peers = controller.matchesFor(MatchRole.peer);
        final witnesses = controller.matchesFor(MatchRole.witness);
        final mentors = controller.matchesFor(MatchRole.mentor);
        final inbox = controller.inbox;

        void open(Widget screen) => Navigator.push(
            context, MaterialPageRoute<void>(builder: (_) => screen));

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Service Graph'),
              actions: [
                if (me.consent.buddyWitness)
                  IconButton(
                    tooltip: 'Statement requests',
                    onPressed: () => open(StatementInboxScreen(controller: controller)),
                    icon: Badge(
                      isLabelVisible: inbox.isNotEmpty,
                      label: Text('${inbox.length}'),
                      child: const Icon(Icons.inbox_outlined),
                    ),
                  ),
                IconButton(
                  tooltip: 'Privacy and matching',
                  onPressed: () => open(GraphSettingsScreen(controller: controller)),
                  icon: const Icon(Icons.tune),
                ),
              ],
              bottom: TabBar(tabs: [
                Tab(text: 'Peers (${peers.length})'),
                Tab(text: 'Witnesses (${witnesses.length})'),
                Tab(text: 'Mentors (${mentors.length})'),
              ]),
            ),
            body: TabBarView(children: [
              _MatchList(
                controller: controller,
                matches: peers,
                empty: me.consent.peerConnection
                    ? 'No one from your units has joined yet. Matches appear here as they do.'
                    : 'Turn on “Connect with people I served with” in Privacy and matching to see peers.',
              ),
              _MatchList(
                controller: controller,
                matches: witnesses,
                empty: 'People listed here have verified service that overlaps '
                    'yours and agreed to be asked. To search a specific date, use Find a witness.',
              ),
              _MatchList(
                controller: controller,
                matches: mentors,
                empty: me.consent.seekingMentor
                    ? 'No mentors from your unit or job have joined yet.'
                    : 'Turn on “I’d like a mentor” in Privacy and matching to see mentors.',
              ),
            ]),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => open(WitnessSearchScreen(controller: controller)),
              icon: const Icon(Icons.person_search),
              label: const Text('Find a witness'),
            ),
          ),
        );
      },
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.controller,
    required this.matches,
    required this.empty,
  });

  final ServiceGraphController controller;
  final List<ServiceMatch> matches;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(empty, textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: matches.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) => MatchCard(
          match: matches[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  MatchDetailScreen(controller: controller, match: matches[i]),
            ),
          ),
        ),
      ),
    );
  }
}
