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

  @override
  String get favoritesTitle => 'Pendwa';

  @override
  String get recentTitle => 'Zilizopita';

  @override
  String get settingsTitle => 'Mipangilio';

  @override
  String get notificationChannelName => 'Tenzi za Kila Siku';

  @override
  String get notificationChannelDescription =>
      'Arifa ya jioni ya kila siku ya tenzi (heads-up)';

  @override
  String get notificationTitleDaily => 'Tenzi nzuri ya leo';

  @override
  String get notificationBodyDaily => 'Bonyeza kufungua tenzi ya leo';

  @override
  String get notificationTitleTest => 'Jaribio la Arifa';

  @override
  String get notificationBodyTest => 'Hii ni arifa ya majaribio (heads-up).';

  @override
  String get notificationActionOpen => 'Fungua';

  @override
  String get notificationActionMarkRead => 'Alama imesomwa';

  @override
  String get noHymnsFound => 'Hakuna nyimbo zilizopatikana';

  @override
  String get hymnsLoadFailed => 'Imeshindikana kupakia nyimbo';

  @override
  String get addedToFavorites => 'Umeongeza tenzi hii katika Tenzi Pendwa';

  @override
  String get removedFromFavorites => 'Umeondoa tenzi hii kutoka Tenzi Pendwa';

  @override
  String get favoriteUpdateFailed => 'Imeshindikana kusasisha vipendwa';

  @override
  String get favoriteLoadFailed => 'Imeshindikana kupakia hali ya kipendwa';

  @override
  String get hymnOpenFailed => 'Imeshindikana kufungua tenzi. Jaribu tena.';

  @override
  String get hymnCopyNoText => 'Hakuna maandishi ya kunakili';

  @override
  String get hymnCopied => 'Tenzi imenakiliwa kikamilifu';

  @override
  String hymnCopyFailed(String error) {
    return 'Imeshindikana kunakili tenzi: $error';
  }

  @override
  String get hideAudio => 'Ficha sauti';

  @override
  String get showAudio => 'Onyesha sauti';

  @override
  String get shareHymn => 'Shiriki tenzi';

  @override
  String get copyHymn => 'Nakili tenzi';

  @override
  String get toggleFullScreen => 'Badilisha skrini nzima';

  @override
  String get decreaseFontSize => 'Punguza ukubwa wa maandishi';

  @override
  String get increaseFontSize => 'Ongeza ukubwa wa maandishi';

  @override
  String get hymnShareNoText => 'Hakuna maandishi ya kushiriki';

  @override
  String get hymnShareFailed => 'Imeshindikana kushiriki tenzi';

  @override
  String get noLyrics => 'Hakuna maandishi ya tenzi hii.';

  @override
  String get audioPlayer => 'Kichezeshi cha Sauti';

  @override
  String get searchHint => 'Tafuta kwa namba au kichwa...';

  @override
  String get themeLight => 'Nuru';

  @override
  String get themeDark => 'Giza';

  @override
  String get themeSystem => 'Mfumo';

  @override
  String get notificationsEnabled => 'Washa Arifa';

  @override
  String get aboutApp => 'Kuhusu Programu';

  @override
  String get feedback => 'Maoni';
}
