import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_page.dart';
import 'screens/terms_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final agreed = prefs.getBool('terms_agreed') ?? false;
  runApp(MyApp(showTerms: !agreed));
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
      ),
      home: showTerms ? const TermsPage() : const HomePage(),
    );
  }
}
