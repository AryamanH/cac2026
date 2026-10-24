/// One continuous assignment: a unit, a place, a job, a date range.
/// A veteran's service history is a list of these.
library;

enum Branch {
  army('Army'),
  navy('Navy'),
  airForce('Air Force'),
  marineCorps('Marine Corps'),
  coastGuard('Coast Guard'),
  spaceForce('Space Force');

  const Branch(this.label);
  final String label;
}

/// Inclusive calendar-day range, normalised to UTC midnight so day math
/// is not thrown off by time zones or daylight saving.
class DateRange {
  DateRange(DateTime start, DateTime end)
      : start = _day(start),
        end = _day(end),
        assert(!end.isBefore(start), 'end must not be before start');

  final DateTime start;
  final DateTime end;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  int get days => end.difference(start).inDays + 1;

  bool contains(DateTime date) {
    final d = _day(date);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  DateRange? intersect(DateRange other) {
    final s = start.isAfter(other.start) ? start : other.start;
    final e = end.isBefore(other.end) ? end : other.end;
    return e.isBefore(s) ? null : DateRange(s, e);
  }
}

class ServiceStint {
  ServiceStint({
    required this.id,
    required this.branch,
    required this.unitId,
    required this.unitName,
    required this.locationCode,
    required this.locationName,
    required this.roleCode,
    required this.roleName,
    required this.period,
    this.isDeployment = false,
    this.verified = false,
  });

  final String id;
  final Branch branch;

  /// Unit identification code (UIC) or equivalent. Matching uses this,
  /// never the free-text name.
  final String unitId;
  final String unitName;

  /// Installation / deployment location code.
  final String locationCode;
  final String locationName;

  /// MOS, rating, or AFSC.
  final String roleCode;
  final String roleName;

  final DateRange period;
  final bool isDeployment;

  /// True when confirmed from an official record (DD-214 scan, VA
  /// Veteran Confirmation, personnel record). Self-reported otherwise.
  final bool verified;
}
