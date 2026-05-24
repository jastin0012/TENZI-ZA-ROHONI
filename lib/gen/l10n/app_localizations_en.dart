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

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get recentTitle => 'Recent';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get notificationChannelName => 'Daily Hymn';

  @override
  String get notificationChannelDescription =>
      'Daily evening hymn notification (heads-up)';

  @override
  String get notificationTitleDaily => 'Today\'s hymn';

  @override
  String get notificationBodyDaily => 'Tap to open today\'s hymn';

  @override
  String get notificationTitleTest => 'Test notification';

  @override
  String get notificationBodyTest => 'This is a test heads-up notification.';

  @override
  String get notificationActionOpen => 'Open';

  @override
  String get notificationActionMarkRead => 'Mark as read';

  @override
  String get noHymnsFound => 'No hymns found';

  @override
  String get hymnsLoadFailed => 'Failed to load hymns';

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get favoriteUpdateFailed => 'Failed to update favorites';

  @override
  String get favoriteLoadFailed => 'Failed to load favorite status';

  @override
  String get hymnOpenFailed => 'Failed to open hymn. Try again.';

  @override
  String get hymnCopyNoText => 'No text to copy';

  @override
  String get hymnCopied => 'Hymn copied to clipboard';

  @override
  String hymnCopyFailed(String error) {
    return 'Failed to copy hymn: $error';
  }

  @override
  String get hideAudio => 'Hide audio';

  @override
  String get showAudio => 'Show audio';

  @override
  String get shareHymn => 'Share hymn';

  @override
  String get copyHymn => 'Copy hymn';

  @override
  String get toggleFullScreen => 'Toggle full screen';

  @override
  String get decreaseFontSize => 'Decrease font size';

  @override
  String get increaseFontSize => 'Increase font size';

  @override
  String get hymnShareNoText => 'No text to share';

  @override
  String get hymnShareFailed => 'Failed to share hymn';

  @override
  String get noLyrics => 'No lyrics available for this hymn.';

  @override
  String get audioPlayer => 'Audio Player';

  @override
  String get searchHint => 'Search by number or title...';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get notificationsEnabled => 'Enable Notifications';

  @override
  String get aboutApp => 'About App';

  @override
  String get feedback => 'Feedback';
}
