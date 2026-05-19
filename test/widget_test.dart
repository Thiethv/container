import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_cont_approval/src/app.dart';
import 'package:mobile_cont_approval/src/config/app_config.dart';
import 'package:mobile_cont_approval/src/repositories/local_settings_repository.dart';

void main() {
  testWidgets('shows setup guidance when Supabase config is missing', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      SecurityContApprovalApp(
        config: const AppConfig(
          supabaseUrl: '',
          supabaseAnonKey: '',
          appTitle: 'THV Cont Approval',
          pollIntervalSeconds: 12,
        ),
        approvalRepository: null,
        settingsRepository: LocalSettingsRepository(preferences),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('THV Cont Approval'), findsOneWidget);
    expect(find.text('Cần cấu hình Supabase'), findsOneWidget);
    expect(
      find.textContaining(
        'App chưa có SUPABASE_URL hoặc SUPABASE_ANON_KEY',
      ),
      findsOneWidget,
    );
  });
}
