import '../util/dates.dart';
import 'service_event.dart';

enum StatementStatus { requested, sent, declined }

class StatementRequest {
  StatementRequest({
    required this.id,
    required this.requesterId,
    required this.requesterAlias,
    required this.witnessId,
    required this.event,
    required this.createdAt,
    this.status = StatementStatus.requested,
  });

  final String id;
  final String requesterId;
  final String requesterAlias;
  final String witnessId;
  final ServiceEvent event;
  final DateTime createdAt;
  StatementStatus status;
  String? statementText;
}

/// The witness's answers. The app structures the statement; it never
/// writes the observation for them.
class BuddyStatementDraft {
  String witnessLegalName = '';
  String relationship = '';
  String howWeServed = '';
  bool firstHand = true;
  String observation = '';
  String afterEffects = '';

  static const minObservationLength = 80;

  List<String> problems() => [
        if (witnessLegalName.trim().isEmpty)
          'Add your full legal name. VA uses it to identify you.',
        if (relationship.trim().isEmpty) 'Say how you know the veteran.',
        if (observation.trim().length < minObservationLength)
          'Describe what you observed in a few sentences.',
      ];

  /// Plain-text draft laid out to match VA Form 21-10210
  /// (Lay/Witness Statement). Check the current form on va.gov.
  String render(StatementRequest request) {
    final e = request.event;
    final served = howWeServed.trim().isEmpty ? '(not provided)' : howWeServed.trim();
    final b = StringBuffer()
      ..writeln('LAY/WITNESS STATEMENT (DRAFT)')
      ..writeln('For transfer to VA Form 21-10210. The witness signs the official form.')
      ..writeln()
      ..writeln('Witness: ${witnessLegalName.trim()}')
      ..writeln('Relationship to the veteran: ${relationship.trim()}')
      ..writeln('How we served together: $served')
      ..writeln()
      ..writeln('Event, as described by the veteran: ${e.description}')
      ..writeln('Date: ${fullDate(e.date)}')
      ..writeln('Place: ${e.stint.locationName} (${e.stint.unitName})')
      ..writeln('Witness saw it first-hand: ${firstHand ? 'Yes' : 'No'}')
      ..writeln()
      ..writeln('What I observed:')
      ..writeln(observation.trim());
    if (afterEffects.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Changes I noticed afterward:')
        ..writeln(afterEffects.trim());
    }
    return b.toString();
  }
}
