import 'package:flutter/material.dart';

import '../models/service_match.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});

  final ServiceMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = match.other;
    final more = match.overlaps.length - 1;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(child: Text(o.initials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.alias, style: theme.textTheme.titleMedium),
                      Text(o.branch.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                match.fullyVerified
                    ? Tooltip(
                        message: 'Service verified',
                        child: Icon(Icons.verified, color: theme.colorScheme.primary),
                      )
                    : Tooltip(
                        message: 'Some service is self-reported',
                        child: Icon(Icons.help_outline, color: theme.colorScheme.outline),
                      ),
              ]),
              const SizedBox(height: 12),
              Text(match.strongest.summary),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'and $more more ${more == 1 ? 'overlap' : 'overlaps'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in match.roles)
                    Chip(
                      label: Text(r.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
