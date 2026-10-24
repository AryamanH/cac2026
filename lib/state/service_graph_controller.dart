import 'package:flutter/foundation.dart';

import '../data/service_graph_repository.dart';
import '../models/buddy_statement.dart';
import '../models/service_event.dart';
import '../models/service_match.dart';
import '../models/veteran_profile.dart';

class ServiceGraphController extends ChangeNotifier {
  ServiceGraphController(this._repo);

  final ServiceGraphRepository _repo;

  bool _loading = true;
  String? _error;
  VeteranProfile? _me;
  List<ServiceMatch> _matches = const [];
  List<StatementRequest> _inbox = const [];
  final Set<String> _sent = {};

  bool get loading => _loading;
  String? get error => _error;
  VeteranProfile? get me => _me;
  List<StatementRequest> get inbox => _inbox;

  List<ServiceMatch> matchesFor(MatchRole role) =>
      _matches.where((m) => m.roles.contains(role)).toList();

  bool wasSent(String veteranId, MatchRole role) =>
      _sent.contains(_key(veteranId, role));

  static String _key(String id, MatchRole role) => '$id:${role.name}';

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _me = await _repo.loadMe();
      await _reload();
    } catch (e) {
      _error = 'The Service Graph didn’t load. Check your connection and try again.';
      debugPrint('ServiceGraph load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _reload();
    notifyListeners();
  }

  Future<void> _reload() async {
    final me = _me!;
    _matches = me.consent.discoverable ? await _repo.matchesFor(me) : const [];
    _inbox = me.consent.discoverable && me.consent.buddyWitness
        ? await _repo.incomingStatementRequests()
        : const [];
  }

  Future<void> updateConsent(GraphConsent consent) async {
    _me = await _repo.saveConsent(consent);
    await _reload();
    notifyListeners();
  }

  Future<void> leaveGraph() => updateConsent(GraphConsent.none);

  Future<void> connect(ServiceMatch match, MatchRole role) async {
    await _repo.sendConnectionRequest(toId: match.other.id, role: role);
    _sent.add(_key(match.other.id, role));
    notifyListeners();
  }

  Future<List<WitnessCandidate>> findWitnesses(ServiceEvent event) =>
      _repo.witnessesFor(_me!, event);

  Future<void> requestStatement(String witnessId, ServiceEvent event) async {
    await _repo.requestStatement(toId: witnessId, event: event);
    _sent.add(_key(witnessId, MatchRole.witness));
    notifyListeners();
  }

  Future<void> submitStatement(StatementRequest request, String text) async {
    await _repo.submitStatement(request.id, text);
    _inbox = await _repo.incomingStatementRequests();
    notifyListeners();
  }

  Future<void> declineStatement(StatementRequest request) async {
    await _repo.declineStatement(request.id);
    _inbox = await _repo.incomingStatementRequests();
    notifyListeners();
  }
}
