import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tenzi_za_rohoni/app.dart';
import 'package:tenzi_za_rohoni/core/app_prefs.dart';
import 'package:tenzi_za_rohoni/main_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test: renders Home title',
      (WidgetTester tester) async {
    // Setup mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'darkMode': false,
      AppPrefs.notificationsEnabled: false,
    });
    final prefs = await SharedPreferences.getInstance();

    // Pump the real app but skip heavy service initialization for tests
    await tester.pumpWidget(TenziZaRohoniApp(prefs: prefs, skipMainInit: true));
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(MainLayout).evaluate().isNotEmpty) {
        break;
      }
    }

    // Verify a stable widget from the Home layout is present
    expect(find.byType(MainLayout), findsOneWidget);
  });
}
