import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/circadian_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/sync/sync_state.dart';
import '../../auth/presentation/auth_modal.dart';
import '../../entries/presentation/entries_feed.dart';
import '../../entries/providers/entries_provider.dart';
import '../../tags/presentation/tag_explorer_view.dart';
import '../widgets/global_quick_add_modal.dart';
import '../widgets/hero_greeting_card.dart';
import '../widgets/today_vitals_bar.dart';
import '../../finance/presentation/finance_view.dart';
import '../../goals/widgets/goals_overview_section.dart';
import '../../calendar/presentation/planner_view.dart';
import '../../movement/presentation/movement_view.dart';
import '../../routines/presentation/routines_view.dart';
import '../../study/widgets/focus_timer_card.dart';
import '../../review/presentation/weekly_review_view.dart';
import '../../review/providers/weekly_review_providers.dart';
import '../../analytics/widgets/screen_time_card.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../intelligence/presentation/life_intelligence_screen.dart';
import '../../intelligence/providers/intelligence_providers.dart';

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
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Tag Explorer & Search',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TagExplorerView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Weekly Review',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WeeklyReviewView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(
        context,
        ref,
        phase,
        currentTime,
        colorScheme,
        theme,
        themeSettings,
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => GlobalQuickAddModal.show(
                context,
                onNavigateToTab: (idx) => setState(() {
                  _selectedTabIndex = idx;
                }),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Quick Add'),
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
    ColorScheme colorScheme,
    ThemeData theme,
    ThemeSettings themeSettings,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
          HeroGreetingCard(phase: phase, currentTime: currentTime),

          const SizedBox(height: 12),

          const TodayVitalsBar(),

          const SizedBox(height: 12),

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
                label: const Text('Quick Add'),
                onPressed: () => GlobalQuickAddModal.show(
                  context,
                  onNavigateToTab: (idx) => setState(() {
                    _selectedTabIndex = idx;
                  }),
                ),
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

          // Cross-Domain Life Intelligence & Correlations
          const _LifeIntelligenceBannerCard(),

          const SizedBox(height: 16),

          // Screen Time & Digital Wellbeing
          const ScreenTimeCard(),



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
}

class _WeeklyReviewBannerCard extends ConsumerWidget {
  const _WeeklyReviewBannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedWeek = ref.watch(selectedReviewWeekProvider);
    final summaryAsync = ref.watch(weeklySummaryProvider(selectedWeek));

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

class _LifeIntelligenceBannerCard extends ConsumerWidget {
  const _LifeIntelligenceBannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reportAsync = ref.watch(lifeIntelligenceProvider);

    return Card(
      elevation: 0,
      color: theme.colorScheme.tertiaryContainer.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.tertiary.withAlpha(60),
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
                    color: theme.colorScheme.tertiary.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.psychology_outlined,
                    color: theme.colorScheme.tertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Life Intelligence',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cross-domain behavioral correlations',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                reportAsync.maybeWhen(
                  data: (report) {
                    if (report.insights.isNotEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withAlpha(35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${report.insights.length} Patterns',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            reportAsync.maybeWhen(
              data: (report) {
                if (report.strongestCorrelation != null) {
                  return Text(
                    report.strongestCorrelation!.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }
                return Text(
                  'Analyze how your study sessions, screen time, water intake, and movement influence each other.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
              orElse: () => Text(
                'Analyze how your study sessions, screen time, water intake, and movement influence each other.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Explore Correlations & Insights'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LifeIntelligenceScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
