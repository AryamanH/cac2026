import '../models/buddy_statement.dart';
import '../models/service_event.dart';
import '../models/service_match.dart';
import '../models/service_stint.dart';
import '../models/veteran_profile.dart';
import '../services/matching_engine.dart';

/// Backend contract. Matching happens behind this interface so a real
/// implementation can run it server-side and return only the caller's
/// own matches.
abstract class ServiceGraphRepository {
  Future<VeteranProfile> loadMe();
  Future<VeteranProfile> saveConsent(GraphConsent consent);
  Future<List<ServiceMatch>> matchesFor(VeteranProfile me);
  Future<List<WitnessCandidate>> witnessesFor(
      VeteranProfile me, ServiceEvent event);
  Future<void> sendConnectionRequest({
    required String toId,
    required MatchRole role,
  });
  Future<StatementRequest> requestStatement({
    required String toId,
    required ServiceEvent event,
  });
  Future<List<StatementRequest>> incomingStatementRequests();
  Future<void> submitStatement(String requestId, String text);
  Future<void> declineStatement(String requestId);
}

/// Demo implementation with seeded data. Swap for an HTTP client.
class InMemoryServiceGraphRepository implements ServiceGraphRepository {
  InMemoryServiceGraphRepository({
    MatchingEngine engine = const MatchingEngine(),
    Duration latency = const Duration(milliseconds: 250),
  })  : _engine = engine,
        _latency = latency {
    _seed();
  }

  final MatchingEngine _engine;
  final Duration _latency;
  late VeteranProfile _me;
  late List<VeteranProfile> _pool;
  final List<StatementRequest> _requests = [];
  final Set<String> _connectionRequests = {};

  Future<T> _after<T>(T Function() f) async {
    await Future<void>.delayed(_latency);
    return f();
  }

  @override
  Future<VeteranProfile> loadMe() => _after(() => _me);

  @override
  Future<VeteranProfile> saveConsent(GraphConsent consent) =>
      _after(() => _me = _me.copyWith(consent: consent));

  @override
  Future<List<ServiceMatch>> matchesFor(VeteranProfile me) =>
      _after(() => _engine.findMatches(me, _pool));

  @override
  Future<List<WitnessCandidate>> witnessesFor(
          VeteranProfile me, ServiceEvent event) =>
      _after(() => _engine.findWitnesses(me, _pool, event));

  @override
  Future<void> sendConnectionRequest({
    required String toId,
    required MatchRole role,
  }) =>
      _after(() => _connectionRequests.add('$toId:${role.name}'));

  @override
  Future<StatementRequest> requestStatement({
    required String toId,
    required ServiceEvent event,
  }) =>
      _after(() {
        final r = StatementRequest(
          id: 'req-${_requests.length + 1}',
          requesterId: _me.id,
          requesterAlias: _me.alias,
          witnessId: toId,
          event: event,
          createdAt: DateTime.now(),
        );
        _requests.add(r);
        return r;
      });

  @override
  Future<List<StatementRequest>> incomingStatementRequests() => _after(() => [
        for (final r in _requests)
          if (r.witnessId == _me.id && r.status == StatementStatus.requested)
            r,
      ]);

  @override
  Future<void> submitStatement(String requestId, String text) => _after(() {
        _requests.firstWhere((r) => r.id == requestId)
          ..status = StatementStatus.sent
          ..statementText = text;
      });

  @override
  Future<void> declineStatement(String requestId) => _after(() {
        _requests.firstWhere((r) => r.id == requestId).status =
            StatementStatus.declined;
      });

  // ---------------------------------------------------------------- seed

  void _seed() {
    DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);
    const pen = ('PEN', 'Camp Pendleton, CA');
    const dji = ('DJI', 'Camp Lemonnier, Djibouti');
    const unit = ('M11111', '1st Bn, 5th Marines');

    ServiceStint stint(
      String id,
      (String, String) u,
      (String, String) loc,
      (String, String) role,
      DateTime start,
      DateTime end, {
      Branch branch = Branch.marineCorps,
      bool deployment = false,
      bool verified = true,
    }) =>
        ServiceStint(
          id: id,
          branch: branch,
          unitId: u.$1,
          unitName: u.$2,
          locationCode: loc.$1,
          locationName: loc.$2,
          roleCode: role.$1,
          roleName: role.$2,
          period: DateRange(start, end),
          isDeployment: deployment,
          verified: verified,
        );

    const rifleman = ('0311', 'Rifleman');
    const leader = ('0369', 'Infantry Unit Leader');

    final myDeployment = stint('me-2', unit, dji, rifleman,
        d(2022, 3, 1), d(2022, 9, 30), deployment: true);

    _me = VeteranProfile(
      id: 'me',
      alias: 'Sgt. R.',
      branch: Branch.marineCorps,
      separationDate: d(2026, 8, 15),
      stints: [
        stint('me-1', unit, pen, rifleman, d(2020, 6, 1), d(2022, 2, 28)),
        myDeployment,
        stint('me-3', unit, pen, leader, d(2022, 10, 1), d(2026, 8, 15)),
      ],
    );

    const all = GraphConsent(
        discoverable: true, peerConnection: true, buddyWitness: true);

    final v1Deployment = stint('v1-2', unit, dji, rifleman,
        d(2022, 3, 1), d(2022, 9, 30), deployment: true);

    _pool = [
      // Same unit, same deployment, verified: peer and witness.
      VeteranProfile(
        id: 'v1',
        alias: 'Cpl. D.',
        branch: Branch.marineCorps,
        separationDate: d(2023, 5, 1),
        consent: all,
        stints: [
          stint('v1-1', unit, pen, rifleman, d(2021, 1, 10), d(2022, 2, 28)),
          v1Deployment,
          stint('v1-3', unit, pen, rifleman, d(2022, 10, 1), d(2023, 5, 1)),
        ],
      ),
      // Same unit, got out ~5 years earlier: mentor and witness.
      VeteranProfile(
        id: 'v2',
        alias: 'SSgt. M.',
        branch: Branch.marineCorps,
        separationDate: d(2021, 11, 30),
        consent: const GraphConsent(
            discoverable: true, buddyWitness: true, mentor: true),
        stints: [
          stint('v2-1', unit, pen, leader, d(2016, 4, 1), d(2021, 11, 30)),
        ],
      ),
      // Navy corpsman attached to the unit, self-reported: peer only.
      VeteranProfile(
        id: 'v3',
        alias: 'HM2 K.',
        branch: Branch.navy,
        separationDate: d(2024, 2, 1),
        consent: all,
        stints: [
          stint('v3-1', unit, dji, ('HM-8404', 'FMF Corpsman'),
              d(2022, 3, 1), d(2022, 9, 30),
              branch: Branch.navy, deployment: true, verified: false),
        ],
      ),
      // Nine days at the same base: below threshold, never shown.
      VeteranProfile(
        id: 'v4',
        alias: 'LCpl. T.',
        branch: Branch.marineCorps,
        separationDate: d(2023, 1, 1),
        consent: all,
        stints: [
          stint('v4-1', ('M22222', '2nd Bn, 1st Marines'), pen, rifleman,
              d(2020, 6, 1), d(2020, 6, 9)),
        ],
      ),
      // Same job, different unit and years, offers mentoring.
      VeteranProfile(
        id: 'v5',
        alias: 'Sgt. A.',
        branch: Branch.marineCorps,
        separationDate: d(2019, 6, 30),
        consent: const GraphConsent(discoverable: true, mentor: true),
        stints: [
          stint('v5-1', ('M33333', '3rd Bn, 4th Marines'),
              ('29P', 'Twentynine Palms, CA'), rifleman,
              d(2015, 7, 1), d(2019, 6, 30)),
        ],
      ),
      // Same unit and dates but not discoverable: invisible.
      VeteranProfile(
        id: 'v6',
        alias: 'Cpl. P.',
        branch: Branch.marineCorps,
        separationDate: d(2024, 1, 1),
        stints: [
          stint('v6-1', unit, pen, rifleman, d(2020, 1, 1), d(2024, 1, 1)),
        ],
      ),
    ];

    // Cpl. D. has asked me to witness something from our deployment.
    _requests.add(StatementRequest(
      id: 'req-incoming-1',
      requesterId: 'v1',
      requesterAlias: 'Cpl. D.',
      witnessId: 'me',
      createdAt: d(2026, 10, 12),
      event: ServiceEvent(
        date: d(2022, 7, 14),
        stint: v1Deployment,
        description:
            'Vehicle rollover during convoy training. I hit my head and was seen at the aid station.',
      ),
    ));
  }
}
