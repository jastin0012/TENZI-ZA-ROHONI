import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenzi_za_rohoni/theme/app_theme.dart' as app_theme;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';
import 'package:tenzi_za_rohoni/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:tenzi_za_rohoni/features/settings/presentation/cubit/theme_state.dart';
import 'package:tenzi_za_rohoni/main_layout.dart';

class TenziZaRohoniApp extends StatelessWidget {
  final SharedPreferences prefs;
  final bool? initialIsDark;
  final bool skipMainInit;
  final _navigatorKey = GlobalKey<NavigatorState>();

  TenziZaRohoniApp({
    super.key,
    required this.prefs,
    this.initialIsDark,
    this.skipMainInit = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (context) {
            final cubit = ThemeCubit(prefs: prefs);
            // initialize after creation
            cubit.initialize(initialIsDark);
            return cubit;
          },
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)?.appTitle ?? 'RohoniFlow',
            debugShowCheckedModeBanner: false,
            theme: app_theme.AppTheme.lightTheme,
            darkTheme: app_theme.AppTheme.darkTheme,
            themeMode: themeState.themeMode,
            navigatorKey: _navigatorKey,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MainLayout(skipInit: skipMainInit),
          );
        },
      ),
    );
  }
}
