import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pending_request.dart';

abstract class ApprovalRepository {
  Future<List<PendingRequest>> fetchPendingRequests();

  Future<void> submitDecision({
    required PendingRequest request,
    required String action,
    required String actorUsername,
    required String deviceLabel,
    String? reason,
  });
}

class SupabaseApprovalRepository implements ApprovalRepository {
  SupabaseApprovalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PendingRequest>> fetchPendingRequests() async {
    final response = await _client
        .from('security_cont_pending_requests')
        .select(
          'container_no, requested_by, requested_at, status, error_fields, '
          'resolved_by, resolved_at, resolved_action, resolved_reason, '
          'updated_at, created_at',
        )
        .eq('status', 'PENDING')
        .order('requested_at', ascending: true)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map(
          (row) => PendingRequest.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> submitDecision({
    required PendingRequest request,
    required String action,
    required String actorUsername,
    required String deviceLabel,
    String? reason,
  }) async {
    final normalizedAction = action.trim().toLowerCase();
    final normalizedActor = actorUsername.trim();

    if (normalizedActor.isEmpty) {
      throw Exception('Cần nhập manager username trước khi duyệt.');
    }
    if (normalizedAction != 'approve' && normalizedAction != 'reject') {
      throw Exception('Action không hợp lệ. Chỉ hỗ trợ approve hoặc reject.');
    }

    final trimmedReason = reason?.trim();

    await _client.from('security_cont_approval_events').insert({
      'container_no': request.containerNo,
      'action': normalizedAction,
      'actor_username': normalizedActor,
      'reason':
          trimmedReason == null || trimmedReason.isEmpty ? null : trimmedReason,
      'source': 'MOBILE_APP',
      'device_id':
          deviceLabel.trim().isEmpty ? 'flutter-mobile' : deviceLabel.trim(),
      'payload': {
        'platform': 'flutter',
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'requested_by': request.requestedBy,
        'requested_at': request.requestedAt?.toUtc().toIso8601String(),
        'issue_count': request.issueCount,
        'error_fields': request.errorFields,
      },
    });
  }
}
