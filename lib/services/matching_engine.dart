import 'dart:math' as math;

import '../models/service_event.dart';
import '../models/service_match.dart';
import '../models/service_stint.dart';
import '../models/veteran_profile.dart';

class MatchingConfig {
  const MatchingConfig({
    this.minSharedDays = 14,
    this.mentorMinYearsAhead = 2,
    this.mentorMaxYearsAhead = 10,
    this.unverifiedPenalty = 0.5,
  });

  /// Shorter overlaps (a week of TDY at the same base) are noise.
  final int minSharedDays;
  final double mentorMinYearsAhead;
  final double mentorMaxYearsAhead;

  /// Score multiplier when either side is self-reported.
  final double unverifiedPenalty;
}

/// Pure Dart, no Flutter imports, so the same code can run server-side.
/// In production, run it on the server: clients should only ever receive
/// their own matches, never the full pool of service histories.
class MatchingEngine {
  const MatchingEngine([this.config = const MatchingConfig()]);

  final MatchingConfig config;

  List<ServiceMatch> findMatches(
    VeteranProfile me,
    Iterable<VeteranProfile> pool,
  ) {
    final results = <ServiceMatch>[];
    for (final other in pool) {
      if (other.id == me.id || !other.consent.discoverable) continue;

      final overlaps = <StintOverlap>[];
      for (final a in me.stints) {
        for (final b in other.stints) {
          final o = compareStintsOrNull(a, b);
          if (o != null) overlaps.add(o);
        }
      }
      if (overlaps.isEmpty) continue;

      final roles = _rolesFor(me, other, overlaps);
      if (roles.isEmpty) continue;

      overlaps.sort((x, y) => y.score.compareTo(x.score));
      final score =
          math.min(1.0, overlaps.first.score + 0.05 * (overlaps.length - 1));
      results.add(ServiceMatch(
        other: other,
        overlaps: overlaps,
        roles: roles,
        score: score,
      ));
    }
    results.sort((x, y) => y.score.compareTo(x.score));
    return results;
  }

  /// Returns null when the two stints have nothing meaningful in common.
  StintOverlap? compareStintsOrNull(ServiceStint mine, ServiceStint theirs) {
    final sameUnit = mine.unitId == theirs.unitId;
    final sameLocation = mine.locationCode == theirs.locationCode;
    final sameRole =
        mine.branch == theirs.branch && mine.roleCode == theirs.roleCode;
    if (!sameUnit && !sameLocation && !sameRole) return null;

    final together = mine.period.intersect(theirs.period);
    final concurrent = (sameUnit || sameLocation) &&
        together != null &&
        together.days >= config.minSharedDays;

    double score;
    if (concurrent) {
      // They were actually there at the same time.
      score = sameUnit ? 0.6 : 0.35;
      if (sameRole) score += 0.15;
      if (mine.isDeployment && theirs.isDeployment) score += 0.15;
      score += 0.1 * math.min(1.0, together!.days / 365);
    } else if (sameUnit || sameRole) {
      // Same unit or job in different years: relevant for mentoring only.
      score = sameUnit ? 0.25 : 0.1;
    } else {
      // Same base, different years: too weak to surface.
      return null;
    }
    if (!mine.verified || !theirs.verified) score *= config.unverifiedPenalty;

    return StintOverlap(
      mine: mine,
      theirs: theirs,
      kinds: {
        if (sameUnit) OverlapKind.sameUnit,
        if (sameLocation) OverlapKind.sameLocation,
        if (sameRole) OverlapKind.sameRole,
      },
      shared: concurrent ? together : null,
      score: math.min(1.0, score),
    );
  }

  Set<MatchRole> _rolesFor(
    VeteranProfile me,
    VeteranProfile other,
    List<StintOverlap> overlaps,
  ) {
    final concurrent = overlaps.any((o) => o.concurrent);
    final verifiedConcurrent =
        overlaps.any((o) => o.concurrent && o.bothVerified);
    final unitOrJob = overlaps.any((o) =>
        o.kinds.contains(OverlapKind.sameUnit) ||
        o.kinds.contains(OverlapKind.sameRole));

    return {
      if (concurrent &&
          me.consent.peerConnection &&
          other.consent.peerConnection)
        MatchRole.peer,
      // Only verified overlaps are offered as witnesses, because a buddy
      // statement is evidence and VA will weigh who the witness is.
      if (verifiedConcurrent && other.consent.buddyWitness) MatchRole.witness,
      if (unitOrJob &&
          me.consent.seekingMentor &&
          other.consent.mentor &&
          _mentorDistance(me, other))
        MatchRole.mentor,
    };
  }

  bool _mentorDistance(VeteranProfile me, VeteranProfile other) {
    final years =
        me.separationDate.difference(other.separationDate).inDays / 365.25;
    return years >= config.mentorMinYearsAhead &&
        years <= config.mentorMaxYearsAhead;
  }

  /// People who were in the same unit or place on the event date and
  /// agreed to be asked. Self-reported service is included but ranked last.
  List<WitnessCandidate> findWitnesses(
    VeteranProfile me,
    Iterable<VeteranProfile> pool,
    ServiceEvent event,
  ) {
    final ownsStint = me.stints.any((s) => s.id == event.stint.id);
    if (!ownsStint || !event.stint.period.contains(event.date)) {
      throw ArgumentError('The event must fall inside your own service.');
    }

    final out = <WitnessCandidate>[];
    for (final other in pool) {
      if (other.id == me.id ||
          !other.consent.discoverable ||
          !other.consent.buddyWitness) {
        continue;
      }
      for (final s in other.stints) {
        if (!s.period.contains(event.date)) continue;
        final sameUnit = s.unitId == event.stint.unitId;
        final sameLocation = s.locationCode == event.stint.locationCode;
        if (!sameUnit && !sameLocation) continue;
        out.add(WitnessCandidate(
          veteran: other,
          stint: s,
          sameUnit: sameUnit,
          sameLocation: sameLocation,
        ));
        break;
      }
    }
    out.sort((a, b) => b.rank.compareTo(a.rank));
    return out;
  }
}
