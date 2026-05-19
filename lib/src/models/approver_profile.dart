class ApproverProfile {
  const ApproverProfile({
    this.username = '',
    this.deviceLabel = 'flutter-manager-phone',
  });

  final String username;
  final String deviceLabel;

  bool get canSubmit => username.trim().isNotEmpty;

  ApproverProfile copyWith({
    String? username,
    String? deviceLabel,
  }) {
    return ApproverProfile(
      username: username ?? this.username,
      deviceLabel: deviceLabel ?? this.deviceLabel,
    );
  }
}
