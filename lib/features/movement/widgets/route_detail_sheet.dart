import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../models/route_models.dart';
import '../providers/route_recording_provider.dart';
import 'route_map_view.dart';

/// Modal bottom sheet presenting a comprehensive interactive map and telemetry review.
class RouteDetailSheet extends ConsumerWidget {
  final Route route;

  const RouteDetailSheet({super.key, required this.route});

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route?'),
        content: Text(
          'Are you sure you want to delete "${route.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await ref.read(appDatabaseProvider).deleteRoute(route.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pointsAsync = ref.watch(routePointsFutureProvider(route.id));

    final activity = ActivityType.fromString(route.activityType);
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');
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

    final double avgSpeedKmh = route.durationSeconds > 0
        ? (route.totalDistanceMeters / 1000.0) / (route.durationSeconds / 3600.0)
        : 0.0;
    final formattedSpeed = '${avgSpeedKmh.toStringAsFixed(1)} km/h';

    final IconData activityIcon = switch (activity) {
      ActivityType.run => Icons.directions_run_rounded,
      ActivityType.cycle => Icons.directions_bike_rounded,
      ActivityType.walk => Icons.directions_walk_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      padding: EdgeInsets.only(
        top: 16.0,
        left: 20.0,
        right: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(activityIcon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: colorScheme.error,
                tooltip: 'Delete Route',
                onPressed: () => _showDeleteDialog(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Map View
          pointsAsync.when(
            data: (points) => RouteMapView(
              points: points,
              height: 240,
            ),
            loading: () => Container(
              height: 240,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Container(
              height: 240,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Center(
                child: Text('Failed to load route points: $err'),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Metrics Summary Grid
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TelemetryTile(
                      label: 'DISTANCE',
                      value: formattedDist,
                      color: colorScheme.primary,
                    ),
                    _TelemetryTile(
                      label: 'DURATION',
                      value: formattedDur,
                      color: colorScheme.onSurface,
                    ),
                    _TelemetryTile(
                      label: 'AVG PACE',
                      value: formattedPace,
                      color: colorScheme.secondary,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TelemetryTile(
                      label: 'AVG SPEED',
                      value: formattedSpeed,
                      color: colorScheme.tertiary,
                    ),
                    pointsAsync.maybeWhen(
                      data: (pts) => _TelemetryTile(
                        label: 'BREADCRUMBS',
                        value: '${pts.length} pts',
                        color: colorScheme.onSurfaceVariant,
                      ),
                      orElse: () => _TelemetryTile(
                        label: 'BREADCRUMBS',
                        value: '--',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    _TelemetryTile(
                      label: 'SYNC STATUS',
                      value: route.isSynced ? 'Cloud Synced' : 'Local Only',
                      color: route.isSynced ? Colors.green : Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TelemetryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
