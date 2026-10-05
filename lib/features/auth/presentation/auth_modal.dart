import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/auth_provider.dart';
import '../../../core/supabase/auth_state.dart';
import '../../../core/supabase/supabase_config.dart';

class AuthModal extends ConsumerStatefulWidget {
  const AuthModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AuthModal(),
    );
  }

  @override
  ConsumerState<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends ConsumerState<AuthModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _configFormKey = GlobalKey<FormState>();

  bool _isConfiguring = false;
  bool _isConnecting = false;
  String? _configError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _urlController.text = SupabaseConfig.url;
    _anonKeyController.text = SupabaseConfig.anonKey;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final client = ref.watch(supabaseClientProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 8.0,
        bottom: bottomInset + 20.0,
      ),
      child: authState.isAuthenticated
          ? _buildAuthenticatedView(context, authState, colorScheme, theme)
          : (client == null || _isConfiguring)
              ? _buildConfigurationView(context, client != null, colorScheme, theme)
              : _buildUnauthenticatedView(context, authState, colorScheme, theme),
    );
  }

  Widget _buildAuthenticatedView(
    BuildContext context,
    CadenceAuthState state,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final user = state.user!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.email ?? 'Authenticated User',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'User ID: ${user.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_done_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  SupabaseConfig.url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _isConfiguring = true);
                },
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationView(
    BuildContext context,
    bool isAlreadyConfigured,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Form(
      key: _configFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Supabase Cloud Account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isAlreadyConfigured)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() => _isConfiguring = false);
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAlreadyConfigured
                ? 'Update your Supabase project configuration or disconnect.'
                : 'Connect your Supabase project to enable cross-device sync and cloud account creation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_configError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: colorScheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _configError!,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Supabase Project URL',
              hintText: 'https://xyzcompany.supabase.co',
              prefixIcon: Icon(Icons.link_rounded),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Enter your Supabase project URL';
              }
              final trimmed = val.trim();
              if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                return 'URL must begin with https:// or http://';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _anonKeyController,
            decoration: const InputDecoration(
              labelText: 'Anon / Publishable Key',
              hintText: 'sb_publishable_... or eyJhbGciOi...',
              prefixIcon: Icon(Icons.key_rounded),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            minLines: 1,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Enter your Supabase anon or publishable key';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isAlreadyConfigured) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(supabaseClientProvider.notifier)
                          .clearConfig();
                      setState(() {
                        _urlController.clear();
                        _anonKeyController.clear();
                        _isConfiguring = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _isConnecting
                      ? null
                      : () async {
                          if (_configFormKey.currentState?.validate() ?? false) {
                            setState(() {
                              _isConnecting = true;
                              _configError = null;
                            });

                            final success = await ref
                                .read(supabaseClientProvider.notifier)
                                .configure(
                                  url: _urlController.text.trim(),
                                  anonKey: _anonKeyController.text.trim(),
                                );

                            if (mounted) {
                              setState(() {
                                _isConnecting = false;
                                if (success) {
                                  _isConfiguring = false;
                                } else {
                                  _configError =
                                      'Failed to connect to Supabase. Check the URL and key.';
                                }
                              });
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Connected to Supabase project!'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isAlreadyConfigured
                          ? 'Save Settings'
                          : 'Connect Supabase'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).continueAsGuest();
                Navigator.pop(context);
              },
              child: const Text('Continue in Offline Guest Mode'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedView(
    BuildContext context,
    CadenceAuthState state,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Supabase Cloud Account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Configure Backend',
                onPressed: () {
                  setState(() => _isConfiguring = true);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to sync your data across devices, or continue in offline Guest Mode.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_done_rounded,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backend: ${SupabaseConfig.url}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isConfiguring = true),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Sign In'),
              Tab(text: 'Create Account'),
            ],
          ),
          const SizedBox(height: 16),
          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: colorScheme.onErrorContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                          color: colorScheme.onErrorContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (val) =>
                val == null || !val.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (val) =>
                val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final email = _emailController.text;
                        final pass = _passwordController.text;
                        if (_tabController.index == 0) {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .signIn(email: email, password: pass);
                        } else {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .signUp(email: email, password: pass);
                        }
                        if (ref.read(authNotifierProvider).isAuthenticated &&
                            context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_tabController.index == 0 ? 'Sign In' : 'Create Account'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).continueAsGuest();
                Navigator.pop(context);
              },
              child: const Text('Continue in Offline Guest Mode'),
            ),
          ),
        ],
      ),
    );
  }
}
