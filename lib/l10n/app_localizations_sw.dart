// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'RohoniFlow';

  @override
  String get loading => 'Inapakia...';

  @override
  String get errorTitle => 'Hitilafu';

  @override
  String get errorMessageDataFetch =>
      'Haikuweza kupakua data. Tafadhali angalia muunganisho wako wa intaneti na ujaribu tena.';

  @override
  String get retry => 'Jaribu Tena';

  @override
  String get searchError => 'Tatizo limetokea wakati wa kutafuta';

  @override
  String get homeTitle => 'Nyumbani';
}
