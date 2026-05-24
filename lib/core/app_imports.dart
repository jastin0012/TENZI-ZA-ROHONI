// Core Flutter
export 'dart:async';
export 'dart:convert';

// Flutter packages
export 'package:flutter/material.dart';
export 'package:flutter/services.dart';

// Third-party packages
export 'package:provider/provider.dart';
export 'package:shared_preferences/shared_preferences.dart';
export 'package:google_mobile_ads/google_mobile_ads.dart';
export 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Timezone - import directly in files that need it
// export 'package:timezone/timezone.dart' as tz;
// export 'package:timezone/data/latest.dart';

export 'package:package_info_plus/package_info_plus.dart';
export 'package:url_launcher/url_launcher.dart';
export 'package:share_plus/share_plus.dart';
// Avoid exporting TextDirection from intl which conflicts with dart:ui
export 'package:intl/intl.dart' hide TextDirection;
