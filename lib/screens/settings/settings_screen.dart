import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tenzi_za_rohoni/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/error_handler.dart';
import '../../services/notification_service.dart';
import '../../core/app_prefs.dart';
import '../about/about_screen.dart';
import '../feedback/feedback_screen.dart';
import '../../core/service_locator.dart' as service_locator;
import '../../theme/colors.dart';
import '../../utils/navigation_lock.dart';
import '../../gen/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool>? onDarkModeChanged;
  const SettingsScreen({super.key, this.onDarkModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = false;
  bool _darkMode = false;
  bool _isLoading = false;
  Object? _error;

  late final NotificationService _notificationService;
  late final SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _isLoading = true);
      _notificationService = GetIt.I<NotificationService>();
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
    } catch (e, stack) {
      setState(() {
        _error = e;
      });
      ErrorHandler.instance.handleError(
        error: e,
        stackTrace: stack,
        context: 'Error initializing settings',
        showUser: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    try {
      setState(() {
        _darkMode = _prefs.getBool('darkMode') ?? false;
        _notificationsEnabled =
            _prefs.getBool(AppPrefs.notificationsEnabled) ?? false;
      });
    } catch (e, stack) {
      ErrorHandler.instance.handleError(
        error: e,
        stackTrace: stack,
        context: 'Error loading settings',
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _prefs.setBool('darkMode', _darkMode);
      await _prefs.setBool(
          AppPrefs.notificationsEnabled, _notificationsEnabled);
    } catch (e, stack) {
      ErrorHandler.instance.handleError(
        error: e,
        stackTrace: stack,
        context: 'Error saving settings',
        showUser: true,
      );
    }
  }

  Future<void> _handleNotificationsToggle(bool value) async {
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);

    try {
      if (value) {
        final granted = await _notificationService.requestPermissions();
        if (!granted) {
          if (mounted) setState(() => _notificationsEnabled = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Haikuruhusu arifa. Ruhusu arifa ndani ya mipangilio ya kifaa.'),
            ));
          }
          await _saveSettings();
          return;
        }

        await _notificationService.init();
        await _notificationService.scheduleDailyNotifications();
        await _notificationService.syncUnopenedWithToday();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Arifa zimewezeshwa. Utapokea arifa kila siku saa 6:00 pm.'),
          ));
        }
      } else {
        await _notificationService.cancelDailyNotifications();
        await _notificationService.cancelAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Arifa zimezimwa.'),
          ));
        }
      }
      await _saveSettings();
    } catch (e, stack) {
      if (mounted) setState(() => _notificationsEnabled = !value);
      ErrorHandler.instance.handleError(
        error: e,
        stackTrace: stack,
        context: 'Error updating notification settings',
        showUser: true,
      );
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _darkMode = value;
    });

    try {
      await _saveSettings();
      try {
        // Use ThemeCubit to update theme state and persist preference
        try {
          // If ThemeCubit is available in the widget tree, use it
          final themeCubit =
              BlocProvider.of<ThemeCubit>(context, listen: false);
          await themeCubit.toggleTheme();
        } catch (_) {
          // Fallback to legacy ValueNotifier if ThemeCubit isn't present
          final themeNotifier =
              service_locator.locator<ValueNotifier<ThemeMode>>();
          themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
        }
      } catch (_) {}
      widget.onDarkModeChanged?.call(value);
    } catch (e, stack) {
      setState(() => _darkMode = !value);
      ErrorHandler.instance.handleError(
        error: e,
        stackTrace: stack,
        context: 'Error updating theme',
        showUser: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Widget _buildSettingsList() {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  localizations?.notificationChannelName ?? 'Arifa Za Tenzi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ),
          _buildTopSettingCard(
            icon: Icons.notifications_active,
            title: localizations?.notificationsEnabled ?? 'Arifa za Tenzi',
            subtitle: 'Utapokea Arifa Za Tenzi kila siku saa 6:00 pm',
            value: _notificationsEnabled,
            onChanged: _handleNotificationsToggle,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mwonekano / Mandhari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ),
          _buildTopSettingCard(
            icon: Icons.dark_mode,
            title: 'Mwonekano',
            subtitle: 'Chagua mwonekano wa mwanga au giza',
            value: _darkMode,
            onChanged: _toggleDarkMode,
          ),
          const SizedBox(height: 20),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
            margin: EdgeInsets.zero,
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                _buildAboutTile(),
                const Divider(height: 1),
                _buildFeedbackTile(),
                const Divider(height: 1),
                _buildShareAppTile(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.onSurface, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTile() {
    final localizations = AppLocalizations.of(context);
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: ListTile(
        leading: Icon(Icons.info, color: iconColor),
        title: Text(localizations?.aboutApp ?? 'Kuhusu'),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: () async {
          await NavigationLock.instance.run(() async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
          });
        },
      ),
    );
  }

  Widget _buildFeedbackTile() {
    final localizations = AppLocalizations.of(context);
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: ListTile(
        leading: Icon(Icons.feedback, color: iconColor),
        title: Text(localizations?.feedback ?? 'Maoni Yako'),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: () async {
          await NavigationLock.instance.run(() async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FeedbackScreen()),
            );
          });
        },
      ),
    );
  }

  Widget _buildShareAppTile() {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: ListTile(
        leading: Icon(Icons.share, color: iconColor),
        title: const Text('Sambaza Programu'),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: () async {
          try {
            await Share.share(
              'Angalia programu hii nzuri: RohoniFlow — https://play.google.com/store/apps/details?id=com.rav850418082.tenzi_za_rohoni',
              subject: 'Programu ya RohoniFlow',
            );
          } catch (e, stack) {
            ErrorHandler.instance.handleError(
              error: e,
              stackTrace: stack,
              context: 'Error sharing app',
              showUser: true,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (_error != null) {
      return Scaffold(
        appBar:
            AppBar(title: Text(localizations?.settingsTitle ?? 'Mipangilio')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!kReleaseMode && _error != null) ...[
                Text(
                  _error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _initialize,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.settingsTitle ?? 'Mipangilio'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildSettingsList()),
              ],
            ),
    );
  }
}
