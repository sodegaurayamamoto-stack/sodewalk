import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'screens/home_page.dart';
import 'screens/terms_page.dart';
import 'services/notification_service.dart';
import 'services/step_baseline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final prefs = await SharedPreferences.getInstance();
  final agreed = prefs.getBool('terms_agreed') ?? false;

  runApp(MyApp(showTerms: !agreed));

  NotificationService.initialize().then((_) {
    NotificationService.scheduleDailyNotification();
  }).catchError((e) {});

  AndroidAlarmManager.initialize().then((_) {
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    AndroidAlarmManager.periodic(
      const Duration(days: 1),
      0,
      captureMidnightStepBaseline,
      startAt: nextMidnight,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }).catchError((e) {});
}

class MyApp extends StatelessWidget {
  final bool showTerms;
  const MyApp({super.key, required this.showTerms});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'sodewalk',
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.textTheme),
        primaryTextTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.primaryTextTheme),
      ),
      home: showTerms ? const TermsPage() : const HomePage(),
    );
  }
}
