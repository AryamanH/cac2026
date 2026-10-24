import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/service_match.dart';
import '../models/service_stint.dart';
import '../util/dates.dart';

/// Two bars on a shared time axis, plus the stretch you were together.
class OverlapTimeline extends StatelessWidget {
  const OverlapTimeline({
    super.key,
    required this.overlap,
    required this.otherLabel,
  });

  final StintOverlap overlap;
  final String otherLabel;

  static const _labelWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    final a = overlap.mine.period;
    final b = overlap.theirs.period;
    final shared = overlap.shared;
    final start = a.start.isBefore(b.start) ? a.start : b.start;
    final end = a.end.isAfter(b.end) ? a.end : b.end;
    final total = math.max(1, end.difference(start).inDays);
    double frac(DateTime d) => d.difference(start).inDays / total;

    final spoken = 'You: ${rangeLabel(a)}. $otherLabel: ${rangeLabel(b)}.'
        '${shared != null ? ' Together: ${rangeLabel(shared)}.' : ''}';

    return Semantics(
      label: spoken,
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, constraints) {
          final w = math.max(0.0, constraints.maxWidth - _labelWidth);

          Widget row(String label, DateRange r, Color color) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(label, overflow: TextOverflow.ellipsis, style: small),
                  ),
                  SizedBox(
                    width: w,
                    height: 12,
                    child: Stack(children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Positioned(
                        left: frac(r.start) * w,
                        width: math.max(3.0, (frac(r.end) - frac(r.start)) * w),
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('You', a, scheme.primary),
              row(otherLabel, b, scheme.secondary),
              if (shared != null) row('Together', shared, scheme.tertiary),
              Padding(
                padding: const EdgeInsets.only(left: _labelWidth, top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(monthYear(start), style: small),
                    Text(monthYear(end), style: small),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
