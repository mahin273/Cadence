import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_provider.dart';
import 'time_block_tile.dart';
import 'create_event_dialog.dart';

/// Full interactive vertical 24-hour time-blocking schedule canvas.
class TimeBlockingTimeline extends ConsumerStatefulWidget {
  final DateTime selectedDate;

  const TimeBlockingTimeline({
    super.key,
    required this.selectedDate,
  });

  @override
  ConsumerState<TimeBlockingTimeline> createState() =>
      _TimeBlockingTimelineState();
}

class _TimeBlockingTimelineState extends ConsumerState<TimeBlockingTimeline> {
  final ScrollController _scrollController = ScrollController();
  static const int startHour = 6; // 06:00 AM
  static const int endHour = 24; // 12:00 AM midnight
  static const double hourHeight = 64.0;
  static const double pxPerMinute = hourHeight / 60.0;

  @override
  void initState() {
    super.initState();
    // Scroll to approximate current time or 8:00 AM on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final now = DateTime.now();
        final currentHour = now.hour;
        if (currentHour > startHour) {
          final targetOffset = ((currentHour - startHour) * hourHeight) - 80.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _createQuickBlock({
    required String title,
    required String category,
    required int durationMinutes,
  }) async {
    final now = DateTime.now();
    // Schedule from next rounded hour or selected date
    final baseHour = (widget.selectedDate.day == now.day) ? (now.hour + 1).clamp(6, 22) : 9;
    final startTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      baseHour,
      0,
    );
    final endTime = startTime.add(Duration(minutes: durationMinutes));

    await ref.read(calendarControllerProvider).createEvent(
          title: title,
          category: category,
          startTime: startTime,
          endTime: endTime,
        );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsForSelectedDateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;

    final totalTimelineHeight = (endHour - startHour) * hourHeight;

    return Column(
      children: [
        // Quick Block Template Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF3B82F6)),
                label: const Text('+ Deep Work (2h)'),
                onPressed: () => _createQuickBlock(
                  title: 'Deep Work Sprint',
                  category: 'work',
                  durationMinutes: 120,
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.school_outlined, size: 16, color: Color(0xFF8B5CF6)),
                label: const Text('+ Study Session (1h)'),
                onPressed: () => _createQuickBlock(
                  title: 'Focused Study',
                  category: 'study',
                  durationMinutes: 60,
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.checklist_rtl_rounded, size: 16, color: Color(0xFFFFB74D)),
                label: const Text('+ Routine Block (30m)'),
                onPressed: () => _createQuickBlock(
                  title: 'Daily Routine Block',
                  category: 'routine',
                  durationMinutes: 30,
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.directions_run_rounded, size: 16, color: Color(0xFF10B981)),
                label: const Text('+ Movement / Run (45m)'),
                onPressed: () => _createQuickBlock(
                  title: 'Movement Session',
                  category: 'movement',
                  durationMinutes: 45,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Scrollable 24-Hour Canvas
        Expanded(
          child: eventsAsync.when(
            data: (events) {
              final blocksWithConflicts =
                  TimeConflictDetector.detectConflicts(events);

              return SingleChildScrollView(
                controller: _scrollController,
                child: SizedBox(
                  height: totalTimelineHeight,
                  child: Stack(
                    children: [
                      // Grid background (Hour lines & labels)
                      ...List.generate(endHour - startHour, (index) {
                        final hour = startHour + index;
                        final top = index * hourHeight;
                        final timeString =
                            '${hour.toString().padLeft(2, '0')}:00';

                        return Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              final start = DateTime(
                                widget.selectedDate.year,
                                widget.selectedDate.month,
                                widget.selectedDate.day,
                                hour,
                                0,
                              );
                              CreateCalendarEventDialog.show(
                                context,
                                initialDate: start,
                              );
                            },
                            child: SizedBox(
                              height: hourHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 54,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12.0, top: 2.0),
                                      child: Text(
                                        timeString,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Current Time Indicator Line (if viewing today)
                      if (isToday && now.hour >= startHour && now.hour < endHour) ...[
                        Positioned(
                          top: ((now.hour - startHour) * 60 + now.minute) *
                              pxPerMinute,
                          left: 48,
                          right: 0,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Scheduled Time Blocks
                      ...blocksWithConflicts.map((block) {
                        final startMinutes =
                            block.startMinutesFromMidnight - (startHour * 60);
                        final top = (startMinutes * pxPerMinute)
                            .clamp(0.0, totalTimelineHeight);
                        final height = (block.durationMinutes * pxPerMinute)
                            .clamp(24.0, totalTimelineHeight - top);

                        // If block has conflict, adjust width/left for side-by-side display
                        final isShifted = block.hasConflict &&
                            block.conflictingEventIds.isNotEmpty &&
                            block.event.id.compareTo(block.conflictingEventIds.first) > 0;

                        return Positioned(
                          top: top,
                          left: isShifted ? 60 + 150.0 : 60.0,
                          right: isShifted ? 16.0 : (block.hasConflict ? 160.0 : 16.0),
                          height: height,
                          child: TimeBlockTile(
                            block: block,
                            width: double.infinity,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Error loading schedule: $err',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
