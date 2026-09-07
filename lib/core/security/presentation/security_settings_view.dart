import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../security_providers.dart';

/// Screen managing biometric lock security, database row statistics,
/// and full-fidelity JSON export/import data sovereignty.
class SecuritySettingsView extends ConsumerStatefulWidget {
  const SecuritySettingsView({super.key});

  @override
  ConsumerState<SecuritySettingsView> createState() =>
      _SecuritySettingsViewState();
}

class _SecuritySettingsViewState extends ConsumerState<SecuritySettingsView> {
  bool _isExporting = false;

  Future<void> _handleToggleAppLock(bool value) async {
    if (value) {
      // Require an immediate successful authentication before enabling the lock
      final bioService = ref.read(biometricServiceProvider);
      final canAuth = await bioService.canAuthenticate();

      if (!canAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Biometric authentication or device credentials are not supported or configured on this device.'),
            ),
          );
        }
        return;
      }

      final success = await bioService.authenticate(
        localizedReason: 'Verify identity to enable Biometric Lock',
      );

      if (mounted) {
        if (success) {
          ref.read(appLockEnabledProvider.notifier).setEnabled(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric App Lock enabled.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. App Lock was not enabled.'),
            ),
          );
        }
      }
    } else {
      ref.read(appLockEnabledProvider.notifier).setEnabled(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric App Lock disabled.')),
      );
    }
  }

  Future<void> _handleExportJson() async {
    setState(() => _isExporting = true);

    try {
      final exportService = ref.read(dataExportServiceProvider);
      final jsonString = await exportService.exportAllDataAsJson();
      final byteLength = utf8.encode(jsonString).length;
      final sizeKb = (byteLength / 1024).toStringAsFixed(1);

      if (mounted) {
        _showExportSuccessDialog(jsonString, sizeKb);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showExportSuccessDialog(String jsonString, String sizeKb) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Generated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complete database exported successfully ($sizeKb KB).'),
            const SizedBox(height: 12),
            const Text(
              'Your backup contains all entries, expenses, routes, routines, study history, accounts, debts, and screen time.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export JSON copied to clipboard!'),
                ),
              );
              Navigator.of(ctx).pop();
              try {
                await Clipboard.setData(ClipboardData(text: jsonString));
              } catch (_) {}
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy JSON'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              try {
                await SharePlus.instance.share(
                  ShareParams(
                    text: jsonString,
                    subject: 'Cadence Complete Database Backup',
                  ),
                );
              } catch (_) {
                // Fallback to clipboard if share sheet is unsupported
                await Clipboard.setData(ClipboardData(text: jsonString));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Share unavailable. JSON was copied to clipboard instead.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Backup'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.restore_page_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Restore Database'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: const Text(
                      'Warning: Restoring will overwrite existing local records with data from the backup file.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Paste Cadence JSON backup text below:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '{\n  "version": 1,\n  "tables": { ... }\n}',
                      hintStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final text = textController.text.trim();
                  if (text.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Please paste JSON text.')),
                    );
                    return;
                  }

                  Navigator.of(ctx).pop();
                  final exportService = ref.read(dataExportServiceProvider);
                  final success = await exportService.importDataFromJson(
                    text,
                    clearExisting: true,
                  );

                  if (mounted) {
                    if (success) {
                      ref.invalidate(databaseStatisticsProvider);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Database successfully restored!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Restore failed: Invalid JSON or schema mismatch.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.file_download_done_rounded),
                label: const Text('Restore Data'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appLockEnabled = ref.watch(appLockEnabledProvider);
    final statsAsync = ref.watch(databaseStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Data Sovereignty'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Biometric Section
          Text(
            'App Security',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: appLockEnabled
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: appLockEnabled
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: const Text(
                    'Biometric App Lock',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Require fingerprint, face, or device credentials to access app',
                  ),
                  value: appLockEnabled,
                  onChanged: _handleToggleAppLock,
                ),
                if (appLockEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_clock_rounded),
                    title: const Text('Lock Application Now'),
                    subtitle: const Text('Immediately trigger biometric lock barrier'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ref.read(isAppLockedProvider.notifier).lock();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Database Statistics Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Database Footprint',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh row counts',
                onPressed: () => ref.invalidate(databaseStatisticsProvider),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: statsAsync.when(
                data: (stats) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Journal Entries',
                            '${stats['entries'] ?? 0}',
                            Icons.edit_note_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Expenses',
                            '${stats['expenses'] ?? 0}',
                            Icons.receipt_long_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'GPS Routes',
                            '${stats['routes'] ?? 0}',
                            Icons.route_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Routines',
                            '${stats['routines'] ?? 0}',
                            Icons.check_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Study Sessions',
                            '${stats['studySessions'] ?? 0}',
                            Icons.menu_book_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Accounts & Debts',
                            '${(stats['accounts'] ?? 0) + (stats['debts'] ?? 0)}',
                            Icons.account_balance_wallet_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Screen Time Logs',
                            '${stats['screenTime'] ?? 0}',
                            Icons.timer_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Total Database Records',
                            '${stats['total'] ?? 0}',
                            Icons.storage_rounded,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Text('Error loading statistics: $err'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Data Sovereignty & Portability Section
          Text(
            'Data Sovereignty & Portability',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cadence is 100% offline-first and private. You own your entire database and can export or restore it anytime without relying on cloud servers.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.file_upload_outlined,
                        color: Colors.blue),
                  ),
                  title: const Text(
                    'Export Full Database (JSON)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Export all 18 tables into a universal JSON backup file',
                  ),
                  trailing: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _isExporting ? null : _handleExportJson,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.file_download_outlined,
                        color: Colors.teal),
                  ),
                  title: const Text(
                    'Restore Database from JSON',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Import a previous Cadence JSON backup with atomic rollback',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showImportDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String count,
    IconData icon, {
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isHighlighted
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isHighlighted ? FontWeight.bold : FontWeight.w500,
                    color: isHighlighted
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHighlighted ? colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
