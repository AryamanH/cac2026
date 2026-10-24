import 'service_stint.dart';

/// Every way a veteran can be found is a separate, explicit opt-in.
class GraphConsent {
  const GraphConsent({
    this.discoverable = false,
    this.peerConnection = false,
    this.buddyWitness = false,
    this.mentor = false,
    this.seekingMentor = false,
  });

  static const none = GraphConsent();

  /// Master switch. When false the veteran is invisible to everyone.
  final bool discoverable;
  final bool peerConnection;

  /// Others may ask this veteran for a buddy statement.
  final bool buddyWitness;

  /// Offers to mentor people a few years behind them.
  final bool mentor;
  final bool seekingMentor;

  GraphConsent copyWith({
    bool? discoverable,
    bool? peerConnection,
    bool? buddyWitness,
    bool? mentor,
    bool? seekingMentor,
  }) =>
      GraphConsent(
        discoverable: discoverable ?? this.discoverable,
        peerConnection: peerConnection ?? this.peerConnection,
        buddyWitness: buddyWitness ?? this.buddyWitness,
        mentor: mentor ?? this.mentor,
        seekingMentor: seekingMentor ?? this.seekingMentor,
      );
}

class VeteranProfile {
  VeteranProfile({
    required this.id,
    required this.alias,
    required this.branch,
    required this.separationDate,
    required List<ServiceStint> stints,
    this.consent = GraphConsent.none,
  }) : stints = List.unmodifiable(stints);

  final String id;

  /// What other people see, e.g. "Cpl. D.". Never the legal name.
  final String alias;
  final Branch branch;
  final DateTime separationDate;
  final List<ServiceStint> stints;
  final GraphConsent consent;

  String get initials {
    final parts = alias.split(' ').where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.last.replaceAll('.', '').toUpperCase();
  }

  VeteranProfile copyWith({GraphConsent? consent}) => VeteranProfile(
        id: id,
        alias: alias,
        branch: branch,
        separationDate: separationDate,
        stints: stints,
        consent: consent ?? this.consent,
      );
}
