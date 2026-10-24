import '../util/dates.dart';
import 'service_stint.dart';
import 'veteran_profile.dart';

enum OverlapKind {
  sameUnit('Same unit'),
  sameLocation('Same location'),
  sameRole('Same job');

  const OverlapKind(this.label);
  final String label;
}

enum MatchRole {
  peer('Peer'),
  witness('Possible witness'),
  mentor('Mentor');

  const MatchRole(this.label);
  final String label;
}

/// How one of my stints relates to one of theirs.
class StintOverlap {
  StintOverlap({
    required this.mine,
    required this.theirs,
    required this.kinds,
    required this.shared,
    required this.score,
  });

  final ServiceStint mine;
  final ServiceStint theirs;
  final Set<OverlapKind> kinds;

  /// The days both people were in the same unit or place. Null when the
  /// link is only "same unit or job, different years".
  final DateRange? shared;
  final double score;

  bool get concurrent => shared != null;
  bool get bothVerified => mine.verified && theirs.verified;
  int get sharedDays => shared?.days ?? 0;

  String get summary {
    final what = kinds.map((k) => k.label).join(', ');
    final where = kinds.contains(OverlapKind.sameUnit)
        ? theirs.unitName
        : kinds.contains(OverlapKind.sameLocation)
            ? theirs.locationName
            : theirs.roleName;
    final s = shared;
    if (s != null) return '$what: $where, ${durationLabel(s.days)} together';
    return '$what: $where, ${rangeLabel(theirs.period)}';
  }
}

class ServiceMatch {
  ServiceMatch({
    required this.other,
    required List<StintOverlap> overlaps,
    required this.roles,
    required this.score,
  })  : assert(overlaps.isNotEmpty),
        overlaps = List.unmodifiable(overlaps);

  final VeteranProfile other;

  /// Sorted strongest first.
  final List<StintOverlap> overlaps;
  final Set<MatchRole> roles;
  final double score;

  StintOverlap get strongest => overlaps.first;
  Iterable<StintOverlap> get concurrentOverlaps =>
      overlaps.where((o) => o.concurrent);
  bool get fullyVerified => overlaps.every((o) => o.bothVerified);
}
