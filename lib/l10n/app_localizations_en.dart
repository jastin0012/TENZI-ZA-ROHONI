// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RohoniFlow';

  @override
  String get loading => 'Loading...';

  @override
  String get errorTitle => 'Error';

  @override
  String get errorMessageDataFetch =>
      'Failed to load data. Please check your connection and try again.';

  @override
  String get retry => 'Try Again';

  @override
  String get searchError => 'An error occurred while searching';

  @override
  String get homeTitle => 'Home';
}
