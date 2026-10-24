import 'service_stint.dart';
import 'veteran_profile.dart';

/// Something that happened during service that a claim may depend on.
class ServiceEvent {
  ServiceEvent({
    required this.date,
    required this.stint,
    required this.description,
  });

  final DateTime date;

  /// The requester's stint the event happened during.
  final ServiceStint stint;
  final String description;
}

/// Someone who was in the same unit or place on the event date.
class WitnessCandidate {
  WitnessCandidate({
    required this.veteran,
    required this.stint,
    required this.sameUnit,
    required this.sameLocation,
  });

  final VeteranProfile veteran;
  final ServiceStint stint;
  final bool sameUnit;
  final bool sameLocation;

  bool get verified => stint.verified;
  int get rank =>
      (sameUnit ? 2 : 0) + (sameLocation ? 1 : 0) + (verified ? 2 : 0);
}
