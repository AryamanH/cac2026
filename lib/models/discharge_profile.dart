/// What the app knows about the veteran's discharge. Filled in by the
/// DD-214 scan (or by hand) and shared by every tab.
/// Never holds the SSN, the photo, or raw OCR text.
class DischargeProfile {
  String branch;
  String mos;
  String character; // one of characterOptions, or '' if unknown
  DateTime? separationDate;
  int daysServed;
  bool combat;

  DischargeProfile({
    this.branch = '',
    this.mos = '',
    this.character = '',
    this.separationDate,
    this.daysServed = 0,
    this.combat = false,
  });

  Map<String, dynamic> toJson() => {
        'branch': branch,
        'mos': mos,
        'character': character,
        'sep': separationDate?.toIso8601String(),
        'days': daysServed,
        'combat': combat,
      };

  factory DischargeProfile.fromJson(Map<String, dynamic> j) => DischargeProfile(
        branch: j['branch'] ?? '',
        mos: j['mos'] ?? '',
        character: j['character'] ?? '',
        separationDate: j['sep'] == null ? null : DateTime.parse(j['sep']),
        daysServed: j['days'] ?? 0,
        combat: j['combat'] ?? false,
      );
}
