import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.appTitle,
    required this.pollIntervalSeconds,
  });

  factory AppConfig.fromRuntime() {
    const pollValue = String.fromEnvironment('PENDING_POLL_SECONDS');
    const appTitleValue = String.fromEnvironment('APP_TITLE');
    const urlValue = String.fromEnvironment('SUPABASE_URL');
    const anonKeyValue = String.fromEnvironment('SUPABASE_ANON_KEY');
    const legacyKeyValue = String.fromEnvironment('SUPABASE_KEY');

    final dotenvEnv = dotenv.env;

    return AppConfig(
      supabaseUrl: _firstNonBlank(
        <String?>[
          urlValue,
          dotenvEnv['SUPABASE_URL'],
        ],
      ),
      supabaseAnonKey: _firstNonBlank(
        <String?>[
          anonKeyValue,
          legacyKeyValue,
          dotenvEnv['SUPABASE_ANON_KEY'],
          dotenvEnv['SUPABASE_KEY'],
        ],
      ),
      appTitle: _firstNonBlank(
        <String?>[
          appTitleValue,
          dotenvEnv['APP_TITLE'],
          'THV Cont Approval',
        ],
      ),
      pollIntervalSeconds: int.tryParse(
            _firstNonBlank(
              <String?>[
                pollValue,
                dotenvEnv['PENDING_POLL_SECONDS'],
                '12',
              ],
            ),
          ) ??
          12,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String appTitle;
  final int pollIntervalSeconds;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  String get envFileExample => 'SUPABASE_URL=https://your-project.supabase.co\n'
      'SUPABASE_ANON_KEY=your-anon-key\n'
      'APP_TITLE=THV Cont Approval\n'
      'PENDING_POLL_SECONDS=12';

  static String _firstNonBlank(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
