import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/circadian_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/sync/sync_state.dart';
import '../../auth/presentation/auth_modal.dart';
import '../../entries/presentation/quick_log_modal.dart';
import '../../entries/presentation/entries_feed.dart';
import '../../entries/providers/entries_provider.dart';
import '../../finance/presentation/finance_view.dart';
import '../../goals/widgets/goals_overview_section.dart';
import '../../calendar/presentation/planner_view.dart';
import '../../movement/presentation/movement_view.dart';
import '../../routines/presentation/routines_view.dart';
import '../../study/widgets/focus_timer_card.dart';
import '../../review/presentation/weekly_review_view.dart';
import '../../review/providers/weekly_review_providers.dart';
import '../../analytics/widgets/screen_time_card.dart';
import '../../../core/security/presentation/security_settings_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeSettingsProvider);
    final currentTime = themeSettings.simulatedTime ?? DateTime.now();
    final phase = CircadianTheme.getPhase(currentTime);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final timeFormatter = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.graphic_eq_rounded, size: 28),
            SizedBox(width: 8),
            Text(
              'Cadence',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final syncInfo = ref.watch(syncNotifierProvider);
              final unsyncedCount =
                  ref.watch(unsyncedEntriesCountProvider).value ?? 0;

              Widget syncIcon;
              if (syncInfo.status == SyncStatus.syncing) {
                syncIcon = const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              } else if (syncInfo.status == SyncStatus.offline) {
                syncIcon = const Icon(Icons.cloud_off_outlined);
              } else if (syncInfo.status == SyncStatus.error) {
                syncIcon = const Icon(Icons.sync_problem, color: Colors.orange);
              } else {
                syncIcon = const Icon(Icons.cloud_sync_outlined);
              }

              return IconButton(
                icon: Badge(
                  isLabelVisible: unsyncedCount > 0,
                  label: Text('$unsyncedCount'),
                  child: syncIcon,
                ),
                tooltip: syncInfo.message ?? 'Sync now',
                onPressed: () =>
                    ref.read(syncNotifierProvider.notifier).syncNow(),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authNotifierProvider);
              return IconButton(
                icon: Icon(
                  authState.isAuthenticated
                      ? Icons.account_circle
                      : Icons.account_circle_outlined,
                  color: authState.isAuthenticated ? colorScheme.primary : null,
                ),
                tooltip: authState.isAuthenticated
                    ? 'Account: ${authState.user?.email}'
                    : 'Account / Guest Mode',
                onPressed: () => AuthModal.show(context),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Theme Modes',
            onPressed: () => _showThemeModal(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Weekly Review',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WeeklyReviewView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Security & Backup',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SecuritySettingsView()),
            ),
          ),
        ],
      ),
      body: _buildBody(
        context,
        ref,
        phase,
        currentTime,
        timeFormatter,
        colorScheme,
        theme,
        themeSettings,
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => QuickLogModal.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Quick Log'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _selectedTabIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl_rounded),
            label: 'Routines',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run_rounded),
            label: 'Movement',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Planner',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    CircadianPhase phase,
    DateTime currentTime,
    DateFormat timeFormatter,
    ColorScheme colorScheme,
    ThemeData theme,
    ThemeSettings themeSettings,
  ) {
    switch (_selectedTabIndex) {
      case 1:
        return const RoutinesView();
      case 2:
        return const MovementView();
      case 3:
        return const FinanceView();
      case 4:
        return const PlannerView();
      case 0:
      default:
        return _buildTodayDashboard(
          context,
          ref,
          phase,
          currentTime,
          timeFormatter,
          colorScheme,
          theme,
          themeSettings,
        );
    }
  }

  Widget _buildTodayDashboard(
    BuildContext context,
    WidgetRef ref,
    CircadianPhase phase,
    DateTime currentTime,
    DateFormat timeFormatter,
    ColorScheme colorScheme,
    ThemeData theme,
    ThemeSettings themeSettings,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
          // Circadian Status Banner
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _getPhaseIcon(phase),
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getPhaseTitle(phase),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          timeFormatter.format(currentTime),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getPhaseDescription(phase),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Preview Circadian Shifts (Color.lerp)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                        label: const Text('Day (12:00)'),
                        onPressed: () {
                          ref.read(themeSettingsProvider.notifier).setSimulatedTime(
                                DateTime(2026, 1, 1, 12, 0),
                              );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.wb_twilight_rounded, size: 16),
                        label: const Text('Dusk (20:00)'),
                        onPressed: () {
                          ref.read(themeSettingsProvider.notifier).setSimulatedTime(
                                DateTime(2026, 1, 1, 20, 0),
                              );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.bedtime_outlined, size: 16),
                        label: const Text('Night (23:00)'),
                        onPressed: () {
                          ref.read(themeSettingsProvider.notifier).setSimulatedTime(
                                DateTime(2026, 1, 1, 23, 0),
                              );
                        },
                      ),
                      if (themeSettings.simulatedTime != null)
                        ActionChip(
                          avatar: const Icon(Icons.restore_rounded, size: 16),
                          label: const Text('Reset Time'),
                          onPressed: () {
                            ref
                                .read(themeSettingsProvider.notifier)
                                .resetToActualTime();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // M3 Expressive Elevation & Color Palette Showcase
          Text(
            'Material 3 Expressive Tokens',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ColorRoleCard(
                  title: 'Primary',
                  color: colorScheme.primary,
                  onColor: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColorRoleCard(
                  title: 'Container',
                  color: colorScheme.primaryContainer,
                  onColor: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColorRoleCard(
                  title: 'Surface Tier',
                  color: colorScheme.surfaceContainerHigh,
                  onColor: colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Drift Offline Database Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Local SQLite (Drift)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ref.watch(entriesStreamProvider).when(
                            data: (entries) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${entries.length} entries',
                                style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            loading: () => const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (err, _) => const Text('Error', style: TextStyle(color: Colors.red)),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reactive offline SQLite table with UUID keys & JSON converters.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.water_drop_outlined, size: 18),
                    label: const Text('Log Quick Water Entry'),
                    onPressed: () async {
                      await ref.read(entryControllerProvider).logEntry(
                            type: 'water',
                            value: 1.0,
                            unit: 'glass',
                            tags: ['Health', 'Hydration'],
                            note: 'Quick hydration log',
                          );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Offline Sync Engine Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sync_rounded,
                              color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Offline Sync Engine',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final syncInfo = ref.watch(syncNotifierProvider);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _syncStatusColor(
                                  syncInfo.status, colorScheme),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              syncInfo.status.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final syncInfo = ref.watch(syncNotifierProvider);
                      final unsynced =
                          ref.watch(unsyncedEntriesCountProvider).value ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            syncInfo.message ??
                                'Automatic push/pull with Last-Write-Wins conflict resolution.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Unsynced in SQLite: $unsynced',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: unsynced > 0
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Sync Now'),
                                onPressed: () {
                                  ref
                                      .read(syncNotifierProvider.notifier)
                                      .syncNow();
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Activity & Telemetry Feed Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Today's Activity Feed",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Quick Log'),
                onPressed: () => QuickLogModal.show(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const EntriesFeed(),

          const SizedBox(height: 16),

          // Daily Goals & Progress Tracker
          const GoalsOverviewSection(),

          const SizedBox(height: 16),

          // Pomodoro & Deep Focus Study Tracker
          const FocusTimerCard(),

          const SizedBox(height: 16),

          // Weekly Review & Life Rhythm Pulse
          const _WeeklyReviewBannerCard(),

          const SizedBox(height: 16),

          // Screen Time & Digital Wellbeing
          const ScreenTimeCard(),

          const SizedBox(height: 16),

          // Foundation Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Architecture Initialized',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _ChecklistItem(
                    title: 'Riverpod ProviderScope configured',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Dynamic color & circadian lerp active',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Material 3 tonal elevation applied',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Offline Drift SQLite database active',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Supabase Auth & GoTrue client wired',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Offline-first Drift & Supabase sync engine active',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Shared entries & multi-category feed active',
                    completed: true,
                  ),
                  const _ChecklistItem(
                    title: 'Daily goals & automated streak tracking active',
                    completed: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }

  Color _syncStatusColor(SyncStatus status, ColorScheme colors) {
    switch (status) {
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.syncing:
        return colors.primary;
      case SyncStatus.offline:
        return Colors.grey;
      case SyncStatus.error:
        return colors.error;
      case SyncStatus.idle:
        return colors.secondary;
    }
  }

  IconData _getPhaseIcon(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return Icons.wb_sunny_rounded;
      case CircadianPhase.dusk:
        return Icons.wb_twilight_rounded;
      case CircadianPhase.night:
        return Icons.nightlight_round;
      case CircadianPhase.dawn:
        return Icons.wb_sunny_outlined;
    }
  }

  String _getPhaseTitle(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return 'Daylight Phase';
      case CircadianPhase.dusk:
        return 'Warm Dusk Transition';
      case CircadianPhase.night:
        return 'Deep AMOLED Night';
      case CircadianPhase.dawn:
        return 'Dawn Emergence';
    }
  }

  String _getPhaseDescription(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return 'Optimized for high readability and active tracking under natural daylight.';
      case CircadianPhase.dusk:
        return 'Warmer amber undertones interpolate smoothly to minimize blue light strain.';
      case CircadianPhase.night:
        return 'Low-contrast AMOLED black palette designed for bed-time reflection.';
      case CircadianPhase.dawn:
        return 'Gradual sunrise luminance gently waking your daily cadence.';
    }
  }

  void _showThemeModal(BuildContext context, WidgetRef ref) {
    final settings = ref.read(themeSettingsProvider);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance & Circadian Engine',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                RadioGroup<AppThemeMode>(
                  groupValue: settings.mode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeSettingsProvider.notifier).setThemeMode(mode);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Column(
                    children: [
                      RadioListTile<AppThemeMode>(
                        title: Text('Circadian Rhythm (Automatic by Time)'),
                        subtitle: Text('Smoothly shifts Day → Dusk → Night'),
                        value: AppThemeMode.circadian,
                      ),
                      RadioListTile<AppThemeMode>(
                        title: Text('Light Theme'),
                        value: AppThemeMode.light,
                      ),
                      RadioListTile<AppThemeMode>(
                        title: Text('Dark Theme'),
                        value: AppThemeMode.dark,
                      ),
                      RadioListTile<AppThemeMode>(
                        title: Text('Follow System'),
                        value: AppThemeMode.system,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColorRoleCard extends StatelessWidget {
  final String title;
  final Color color;
  final Color onColor;

  const _ColorRoleCard({
    required this.title,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: onColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            style: TextStyle(
              color: onColor.withAlpha(200),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String title;
  final bool completed;

  const _ChecklistItem({
    required this.title,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: completed
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: completed
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReviewBannerCard extends ConsumerWidget {
  const _WeeklyReviewBannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final summaryAsync = ref.watch(weeklySummaryProvider(now));

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Life Rhythm',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        summaryAsync.maybeWhen(
                          data: (d) => d.dateRangeLabel,
                          orElse: () => 'This Week',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                summaryAsync.maybeWhen(
                  data: (data) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data.compositeScore} / 100',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Synthesize focus, movement, finances, and routine consistency into one actionable review.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('Open Weekly Review'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WeeklyReviewView()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
