// File test để xem nhanh TermsAndPrivacyPage
import 'package:flutter/material.dart';
import 'ui/terms_and_privacy_page.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const TestTermsApp());
}

class TestTermsApp extends StatelessWidget {
  const TestTermsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Terms Page',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7CCD2B)),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TermsAndPrivacyPage(),
    );
  }
}
