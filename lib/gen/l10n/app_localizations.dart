import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Christian Hymns'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @errorMessageDataFetch.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data. Please check your connection and try again.'**
  String get errorMessageDataFetch;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get retry;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while searching'**
  String get searchError;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @recentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Daily Hymn'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily evening hymn notification (heads-up)'**
  String get notificationChannelDescription;

  /// No description provided for @notificationTitleDaily.
  ///
  /// In en, this message translates to:
  /// **'Today\'s hymn'**
  String get notificationTitleDaily;

  /// No description provided for @notificationBodyDaily.
  ///
  /// In en, this message translates to:
  /// **'Tap to open today\'s hymn'**
  String get notificationBodyDaily;

  /// No description provided for @notificationTitleTest.
  ///
  /// In en, this message translates to:
  /// **'Test notification'**
  String get notificationTitleTest;

  /// No description provided for @notificationBodyTest.
  ///
  /// In en, this message translates to:
  /// **'This is a test heads-up notification.'**
  String get notificationBodyTest;

  /// No description provided for @notificationActionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationActionOpen;

  /// No description provided for @notificationActionMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationActionMarkRead;

  /// No description provided for @noHymnsFound.
  ///
  /// In en, this message translates to:
  /// **'No hymns found'**
  String get noHymnsFound;

  /// No description provided for @hymnsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load hymns'**
  String get hymnsLoadFailed;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// No description provided for @favoriteUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update favorites'**
  String get favoriteUpdateFailed;

  /// No description provided for @favoriteLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load favorite status'**
  String get favoriteLoadFailed;

  /// No description provided for @hymnOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open hymn. Try again.'**
  String get hymnOpenFailed;

  /// No description provided for @hymnCopyNoText.
  ///
  /// In en, this message translates to:
  /// **'No text to copy'**
  String get hymnCopyNoText;

  /// No description provided for @hymnCopied.
  ///
  /// In en, this message translates to:
  /// **'Hymn copied to clipboard'**
  String get hymnCopied;

  /// No description provided for @hymnCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy hymn: {error}'**
  String hymnCopyFailed(String error);

  /// No description provided for @hideAudio.
  ///
  /// In en, this message translates to:
  /// **'Hide audio'**
  String get hideAudio;

  /// No description provided for @showAudio.
  ///
  /// In en, this message translates to:
  /// **'Show audio'**
  String get showAudio;

  /// No description provided for @shareHymn.
  ///
  /// In en, this message translates to:
  /// **'Share hymn'**
  String get shareHymn;

  /// No description provided for @copyHymn.
  ///
  /// In en, this message translates to:
  /// **'Copy hymn'**
  String get copyHymn;

  /// No description provided for @toggleFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Toggle full screen'**
  String get toggleFullScreen;

  /// No description provided for @decreaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get decreaseFontSize;

  /// No description provided for @increaseFontSize.
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get increaseFontSize;

  /// No description provided for @hymnShareNoText.
  ///
  /// In en, this message translates to:
  /// **'No text to share'**
  String get hymnShareNoText;

  /// No description provided for @hymnShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share hymn'**
  String get hymnShareFailed;

  /// No description provided for @noLyrics.
  ///
  /// In en, this message translates to:
  /// **'No lyrics available for this hymn.'**
  String get noLyrics;

  /// No description provided for @audioPlayer.
  ///
  /// In en, this message translates to:
  /// **'Audio Player'**
  String get audioPlayer;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by number or title...'**
  String get searchHint;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationsEnabled;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
