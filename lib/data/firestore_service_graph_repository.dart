import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/buddy_statement.dart';
import '../models/service_event.dart';
import '../models/service_match.dart';
import '../models/service_stint.dart';
import '../models/veteran_profile.dart';
import '../services/matching_engine.dart';
import 'service_graph_repository.dart';

/// Real backend for the Unit tab: Cloud Firestore, one anonymous user per install.
///
/// Collections
///   veterans/{uid}          alias, branch, separationDate, stints[], consent{}
///   statementRequests/{id}  requester, witness, event, status, statementText
///   connectionRequests/{id} fromId, toId, role
///
/// Dates are stored as 'yyyy-MM-dd' strings, not Timestamps, so a day can never
/// shift by one across time zones.
///
/// PROTOTYPE LIMIT: matching runs on the client, so a signed-in client can read
/// the service history of veterans who opted in. For production, move
/// MatchingEngine into a Cloud Function and return only the caller's matches.
class FirestoreServiceGraphRepository implements ServiceGraphRepository {
  FirestoreServiceGraphRepository({
    required this.uid,
    FirebaseFirestore? db,
    MatchingEngine engine = const MatchingEngine(),
  })  : _db = db ?? FirebaseFirestore.instance,
        _engine = engine;

  final String uid;
  final FirebaseFirestore _db;
  final MatchingEngine _engine;
  VeteranProfile? _me;

  DocumentReference<Map<String, dynamic>> get _meRef =>
      _db.collection('veterans').doc(uid);

  // ───────────────────────── Repository API ─────────────────────────

  @override
  Future<VeteranProfile> loadMe() async {
    await _seedPoolOnce();
    var snap = await _meRef.get();
    if (!snap.exists) {
      await _createDemoMe();
      snap = await _meRef.get();
    }
    return _me = _profile(snap.id, snap.data()!);
  }

  @override
  Future<VeteranProfile> saveConsent(GraphConsent consent) async {
    await _meRef.update({'consent': _consentMap(consent)});
    return _me = _me!.copyWith(consent: consent);
  }

  @override
  Future<List<ServiceMatch>> matchesFor(VeteranProfile me) async =>
      _engine.findMatches(me, await _pool());

  @override
  Future<List<WitnessCandidate>> witnessesFor(
          VeteranProfile me, ServiceEvent event) async =>
      _engine.findWitnesses(me, await _pool(), event);

  @override
  Future<void> sendConnectionRequest(
          {required String toId, required MatchRole role}) =>
      _db.collection('connectionRequests').add({
        'fromId': uid,
        'toId': toId,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<StatementRequest> requestStatement(
      {required String toId, required ServiceEvent event}) async {
    final ref = await _db.collection('statementRequests').add({
      'requesterId': uid,
      'requesterAlias': _me!.alias,
      'witnessId': toId,
      'event': _eventMap(event),
      'status': StatementStatus.requested.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return StatementRequest(
      id: ref.id,
      requesterId: uid,
      requesterAlias: _me!.alias,
      witnessId: toId,
      event: event,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<StatementRequest>> incomingStatementRequests() async {
    final q = await _db
        .collection('statementRequests')
        .where('witnessId', isEqualTo: uid)
        .where('status', isEqualTo: StatementStatus.requested.name)
        .get();
    return [for (final d in q.docs) _request(d.id, d.data())];
  }

  @override
  Future<void> submitStatement(String requestId, String text) =>
      _db.collection('statementRequests').doc(requestId).update({
        'status': StatementStatus.sent.name,
        'statementText': text,
        'sentAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> declineStatement(String requestId) => _db
      .collection('statementRequests')
      .doc(requestId)
      .update({'status': StatementStatus.declined.name});

  // ───────────────────────── Queries ─────────────────────────

  /// Only people who switched "discoverable" on. Security rules enforce the same.
  Future<List<VeteranProfile>> _pool() async {
    final q = await _db
        .collection('veterans')
        .where('consent.discoverable', isEqualTo: true)
        .get();
    return [
      for (final d in q.docs)
        if (d.id != uid) _profile(d.id, d.data())
    ];
  }

  // ───────────────────────── Demo seeding ─────────────────────────

  /// First install in a fresh project writes the demo veterans once.
  Future<void> _seedPoolOnce() async {
    final meta = _db.doc('meta/seed');
    if ((await meta.get()).exists) return;
    final demo = InMemoryServiceGraphRepository(latency: Duration.zero);
    final batch = _db.batch();
    for (final v in demo.demoPool) {
      batch.set(_db.collection('veterans').doc(v.id),
          {..._profileMap(v), 'isDemo': true});
    }
    batch.set(meta, {'at': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  /// Each new user gets the demo service history plus one incoming buddy request.
  Future<void> _createDemoMe() async {
    final demo = InMemoryServiceGraphRepository(latency: Duration.zero);
    final d = demo.demoMe;
    final mine = VeteranProfile(
      id: uid,
      alias: d.alias,
      branch: d.branch,
      separationDate: d.separationDate,
      stints: d.stints,
    );
    final batch = _db.batch();
    batch.set(_meRef, {..._profileMap(mine), 'isDemo': false});
    for (final r in demo.demoRequests) {
      batch.set(_db.collection('statementRequests').doc(), {
        'requesterId': r.requesterId,
        'requesterAlias': r.requesterAlias,
        'witnessId': uid,
        'event': _eventMap(r.event),
        'status': StatementStatus.requested.name,
        'createdAt': FieldValue.serverTimestamp(),
        'isDemo': true,
      });
    }
    await batch.commit();
  }

  // ───────────────────────── Serialization ─────────────────────────

  static String _ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime _d(String s) => DateTime.parse('${s}T00:00:00Z');

  static Map<String, dynamic> _consentMap(GraphConsent c) => {
        'discoverable': c.discoverable,
        'peerConnection': c.peerConnection,
        'buddyWitness': c.buddyWitness,
        'mentor': c.mentor,
        'seekingMentor': c.seekingMentor,
      };

  static GraphConsent _consent(Map<String, dynamic> m) => GraphConsent(
        discoverable: m['discoverable'] == true,
        peerConnection: m['peerConnection'] == true,
        buddyWitness: m['buddyWitness'] == true,
        mentor: m['mentor'] == true,
        seekingMentor: m['seekingMentor'] == true,
      );

  static Map<String, dynamic> _stintMap(ServiceStint s) => {
        'id': s.id,
        'branch': s.branch.name,
        'unitId': s.unitId,
        'unitName': s.unitName,
        'locationCode': s.locationCode,
        'locationName': s.locationName,
        'roleCode': s.roleCode,
        'roleName': s.roleName,
        'start': _ds(s.period.start),
        'end': _ds(s.period.end),
        'isDeployment': s.isDeployment,
        'verified': s.verified,
      };

  static ServiceStint _stint(Map<String, dynamic> m) => ServiceStint(
        id: m['id'] as String,
        branch: Branch.values.byName(m['branch'] as String),
        unitId: m['unitId'] as String,
        unitName: m['unitName'] as String,
        locationCode: m['locationCode'] as String,
        locationName: m['locationName'] as String,
        roleCode: m['roleCode'] as String,
        roleName: m['roleName'] as String,
        period: DateRange(_d(m['start'] as String), _d(m['end'] as String)),
        isDeployment: m['isDeployment'] == true,
        verified: m['verified'] == true,
      );

  static Map<String, dynamic> _profileMap(VeteranProfile v) => {
        'alias': v.alias,
        'branch': v.branch.name,
        'separationDate': _ds(v.separationDate),
        'stints': [for (final s in v.stints) _stintMap(s)],
        'consent': _consentMap(v.consent),
      };

  static VeteranProfile _profile(String id, Map<String, dynamic> m) =>
      VeteranProfile(
        id: id,
        alias: m['alias'] as String,
        branch: Branch.values.byName(m['branch'] as String),
        separationDate: _d(m['separationDate'] as String),
        stints: [
          for (final s in (m['stints'] as List))
            _stint(Map<String, dynamic>.from(s as Map)),
        ],
        consent: _consent(
            Map<String, dynamic>.from((m['consent'] ?? const {}) as Map)),
      );

  static Map<String, dynamic> _eventMap(ServiceEvent e) => {
        'date': _ds(e.date),
        'stint': _stintMap(e.stint),
        'description': e.description,
      };

  static ServiceEvent _event(Map<String, dynamic> m) => ServiceEvent(
        date: _d(m['date'] as String),
        stint: _stint(Map<String, dynamic>.from(m['stint'] as Map)),
        description: m['description'] as String,
      );

  static StatementRequest _request(String id, Map<String, dynamic> m) =>
      StatementRequest(
        id: id,
        requesterId: m['requesterId'] as String,
        requesterAlias: m['requesterAlias'] as String,
        witnessId: m['witnessId'] as String,
        event: _event(Map<String, dynamic>.from(m['event'] as Map)),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: StatementStatus.values.byName(m['status'] as String),
      )..statementText = m['statementText'] as String?;
}
