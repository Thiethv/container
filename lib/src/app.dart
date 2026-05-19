import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'repositories/approval_repository.dart';
import 'repositories/local_settings_repository.dart';
import 'screens/approval_home_page.dart';

class SecurityContApprovalApp extends StatelessWidget {
  const SecurityContApprovalApp({
    required this.config,
    required this.approvalRepository,
    required this.settingsRepository,
    super.key,
  });

  final AppConfig config;
  final ApprovalRepository? approvalRepository;
  final LocalSettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0C6E62),
        surface: const Color(0xFFF6F3EC),
      ),
    );

    return MaterialApp(
      title: config.appTitle,
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF6F3EC),
        cardTheme: const CardTheme(
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFD8D3C6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF0C6E62), width: 1.4),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: ApprovalHomePage(
        config: config,
        approvalRepository: approvalRepository,
        settingsRepository: settingsRepository,
      ),
    );
  }
}
