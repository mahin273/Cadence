import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_provider.dart';
import '../models/route_models.dart';
import '../providers/route_recording_provider.dart';

/// Renders historical completed GPS routes.
class RecentRoutesList extends ConsumerWidget {
  const RecentRoutesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(completedRoutesStreamProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Routes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            routesAsync.when(
              data: (routes) => Text(
                '${routes.length} recorded',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        routesAsync.when(
          data: (routes) {
            if (routes.isEmpty) {
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24.0,
                    horizontal: 16.0,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 36,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No routes recorded yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start an outdoor session above to track your trail.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final route = routes[index];
                final activity = ActivityType.fromString(route.activityType);
                final dateFormat = DateFormat('MMM d, h:mm a');
                final formattedDate = dateFormat.format(route.startTime.toLocal());

                final distanceKm = route.totalDistanceMeters / 1000.0;
                final formattedDist = distanceKm >= 1.0
                    ? '${distanceKm.toStringAsFixed(2)} km'
                    : '${route.totalDistanceMeters.toStringAsFixed(0)} m';

                final durationMin = route.durationSeconds ~/ 60;
                final durationSec = route.durationSeconds % 60;
                final formattedDur =
                    '${durationMin.toString().padLeft(2, '0')}:${durationSec.toString().padLeft(2, '0')}';

                final formattedPace = RouteMath.formatPace(route.avgPaceSecondsPerKm);

                final IconData activityIcon = switch (activity) {
                  ActivityType.run => Icons.directions_run_rounded,
                  ActivityType.cycle => Icons.directions_bike_rounded,
                  ActivityType.walk => Icons.directions_walk_rounded,
                };

                return Dismissible(
                  key: ValueKey(route.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) async {
                    await ref.read(appDatabaseProvider).deleteRoute(route.id);
                  },
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          activityIcon,
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              route.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            formattedDist,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$formattedDur • $formattedPace',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Card(
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading routes: $err',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
