import 'package:shared_preferences/shared_preferences.dart';

import '../models/approver_profile.dart';

class LocalSettingsRepository {
  LocalSettingsRepository(this._preferences);

  static const _usernameKey = 'approver_username';
  static const _deviceLabelKey = 'device_label';

  final SharedPreferences _preferences;

  ApproverProfile loadProfile() {
    return ApproverProfile(
      username: _preferences.getString(_usernameKey) ?? '',
      deviceLabel:
          _preferences.getString(_deviceLabelKey) ?? 'flutter-manager-phone',
    );
  }

  Future<void> saveProfile(ApproverProfile profile) async {
    await _preferences.setString(_usernameKey, profile.username.trim());
    await _preferences.setString(_deviceLabelKey, profile.deviceLabel.trim());
  }
}
