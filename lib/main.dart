import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/app_config.dart';
import 'src/repositories/approval_repository.dart';
import 'src/repositories/local_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  final config = AppConfig.fromRuntime();
  final sharedPreferences = await SharedPreferences.getInstance();
  ApprovalRepository? approvalRepository;

  if (config.isSupabaseConfigured) {
    approvalRepository = SupabaseApprovalRepository(
      SupabaseClient(config.supabaseUrl, config.supabaseAnonKey),
    );
  }

  runApp(
    SecurityContApprovalApp(
      config: config,
      approvalRepository: approvalRepository,
      settingsRepository: LocalSettingsRepository(sharedPreferences),
    ),
  );
}
