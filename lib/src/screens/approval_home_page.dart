import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/approver_profile.dart';
import '../models/pending_request.dart';
import '../repositories/approval_repository.dart';
import '../repositories/local_settings_repository.dart';

const Map<String, String> _inspectionFieldLabels = <String, String>{
  'end_wall': 'Vách trước',
  'left_side': 'Bên trái',
  'right_side': 'Bên phải',
  'flooring': 'Sàn cont',
  'roof_sheet': 'Mái cont',
  'tunnel': 'Khe thông khí',
  'door': 'Cửa cont',
  'truck_cabin': 'Cabin xe',
  'truck_exterior': 'Bên ngoài xe',
  'truck_rear': 'Phía sau xe',
};

class ApprovalHomePage extends StatefulWidget {
  const ApprovalHomePage({
    required this.config,
    required this.approvalRepository,
    required this.settingsRepository,
    super.key,
  });

  final AppConfig config;
  final ApprovalRepository? approvalRepository;
  final LocalSettingsRepository settingsRepository;

  @override
  State<ApprovalHomePage> createState() => _ApprovalHomePageState();
}

class _ApprovalHomePageState extends State<ApprovalHomePage> {
  final TextEditingController _searchController = TextEditingController();

  late ApproverProfile _profile;
  Timer? _pollTimer;

  List<PendingRequest> _requests = const <PendingRequest>[];
  Set<String> _hiddenRequestKeys = <String>{};
  bool _isLoading = true;
  String? _errorMessage;
  String? _submittingContainer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _profile = widget.settingsRepository.loadProfile();
    _searchController.addListener(_handleSearchChanged);

    if (widget.approvalRepository == null) {
      _isLoading = false;
      return;
    }

    unawaited(_refreshRequests());
    _pollTimer = Timer.periodic(
      Duration(seconds: widget.config.pollIntervalSeconds),
      (_) => unawaited(_refreshRequests(silent: true)),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<PendingRequest> get _filteredRequests {
    if (_query.isEmpty) {
      return _requests;
    }

    return _requests.where((request) {
      final haystacks = <String>[
        request.containerNo,
        request.requestedBy,
        ...request.errorFields.entries.expand(
          (entry) => <String>[
            entry.key,
            _labelForField(entry.key),
            ...entry.value,
          ],
        ),
      ];
      return haystacks.any(
        (value) => value.toLowerCase().contains(_query),
      );
    }).toList();
  }

  void _handleSearchChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _refreshRequests({bool silent = false}) async {
    final repository = widget.approvalRepository;
    if (repository == null) {
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final requests = await repository.fetchPendingRequests();
      final fetchedKeys = requests.map(_requestKey).toSet();
      final activeHiddenKeys =
          _hiddenRequestKeys.where(fetchedKeys.contains).toSet();
      if (!mounted) {
        return;
      }
      setState(() {
        _hiddenRequestKeys = activeHiddenKeys;
        _requests = requests
            .where(
                (request) => !activeHiddenKeys.contains(_requestKey(request)))
            .toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _openProfileSheet() async {
    final updatedProfile = await showModalBottomSheet<ApproverProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ApproverProfileSheet(initialProfile: _profile),
    );

    if (updatedProfile == null) {
      return;
    }

    await widget.settingsRepository.saveProfile(updatedProfile);
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = updatedProfile;
    });
  }

  Future<void> _openDecisionSheet(PendingRequest request) async {
    final draft = await showModalBottomSheet<_DecisionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DecisionSheet(
        request: request,
        profile: _profile,
        isSubmitting: _submittingContainer == request.containerNo,
      ),
    );

    if (draft == null) {
      return;
    }

    await _submitDecision(request, draft);
  }

  Future<void> _submitDecision(
    PendingRequest request,
    _DecisionDraft draft,
  ) async {
    final repository = widget.approvalRepository;
    if (repository == null) {
      return;
    }

    if (!_profile.canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần nhập manager username trước khi duyệt.'),
        ),
      );
      await _openProfileSheet();
      return;
    }

    setState(() {
      _submittingContainer = request.containerNo;
    });

    try {
      await repository.submitDecision(
        request: request,
        action: draft.action,
        actorUsername: _profile.username,
        deviceLabel: _profile.deviceLabel,
        reason: draft.reason,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.action == 'approve'
                ? 'Đã gửi duyệt cont ${request.containerNo}. Chờ backend sync.'
                : 'Đã gửi từ chối cont ${request.containerNo}. Chờ backend sync.',
          ),
        ),
      );

      final requestKey = _requestKey(request);
      setState(() {
        _hiddenRequestKeys = <String>{..._hiddenRequestKeys, requestKey};
        _requests =
            _requests.where((item) => _requestKey(item) != requestKey).toList();
      });

      await _refreshRequests(silent: true);
      unawaited(
        Future<void>.delayed(
          Duration(seconds: widget.config.pollIntervalSeconds),
          () => _refreshRequests(silent: true),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi quyết định thất bại: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingContainer = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.appTitle),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshRequests,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _openProfileSheet,
            tooltip: 'Manager',
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: widget.approvalRepository == null
          ? _buildSetupView(context)
          : RefreshIndicator(
              onRefresh: _refreshRequests,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: <Widget>[
                  _buildApproverCard(context),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _buildErrorCard(context),
                  ],
                  const SizedBox(height: 12),
                  if (_isLoading && _requests.isEmpty)
                    const _LoadingState()
                  else if (_filteredRequests.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredRequests.map(_buildRequestCard),
                ],
              ),
            ),
    );
  }

  Widget _buildApproverCard(BuildContext context) {
    final username = _profile.username.ifBlank('Chưa chọn manager');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _openProfileSheet,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF0C6E62),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profile.canSubmit
                          ? 'Nhấn để đổi username duyệt'
                          : 'Nhấn để nhập username duyệt',
                      style: const TextStyle(color: Color(0xFF6C716C)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EFE5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${_requests.length} cont',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Card(
      color: const Color(0xFFFFECE7),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Không tải được danh sách',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9B3321),
                  ),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Lỗi không xác định'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _refreshRequests,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _query.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.inbox_rounded,
              size: 52,
              color: Color(0xFF809088),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery
                  ? 'Không tìm thấy cont phù hợp'
                  : 'Chưa có cont chờ duyệt',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Thử đổi từ khoá tìm kiếm hoặc chờ backend đồng bộ thêm dữ liệu.'
                  : 'Khi bảo vệ lưu cont lỗi từ web app, danh sách pending sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(PendingRequest request) {
    final isSubmitting = _submittingContainer == request.containerNo;
    final firstEntry = request.errorFields.entries.isEmpty
        ? null
        : request.errorFields.entries.first;
    final firstIssueLabel = firstEntry == null
        ? 'Không có chi tiết lỗi'
        : _labelForField(firstEntry.key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isSubmitting ? null : () => _openDecisionSheet(request),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        request.containerNo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F3EF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${request.issueCount} lỗi',
                        style: const TextStyle(
                          color: Color(0xFF0C6E62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(request.requestedAt),
                  style: const TextStyle(color: Color(0xFF6C716C)),
                ),
                const SizedBox(height: 4),
                Text(
                  firstIssueLabel,
                  style: const TextStyle(
                    color: Color(0xFF3F4540),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        isSubmitting
                            ? 'Đang gửi quyết định...'
                            : 'Chạm để duyệt',
                        style: const TextStyle(
                          color: Color(0xFF68736B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Cần cấu hình Supabase',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'App chưa có SUPABASE_URL hoặc SUPABASE_ANON_KEY. Với GitHub Pages, cách đơn giản nhất là đặt 2 giá trị này trong file .env của project trước khi flutter build web.',
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102521),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SelectableText(
                    widget.config.envFileExample,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(height: 18),
                const _SetupChecklistItem(
                  text:
                      'Dùng SUPABASE_ANON_KEY hoặc SUPABASE_KEY dạng anon, không dùng service-role key trong Flutter.',
                ),
                const _SetupChecklistItem(
                  text:
                      'Nếu deploy web bằng GitHub Pages, cứ giữ web/index.html với base href mặc định /. Script deploy của anh có thể sửa lại base href sau build.',
                ),
                const _SetupChecklistItem(
                  text:
                      'Manager username trong app phải trùng core.users.username ở local PostgreSQL nếu vẫn dùng manual-username mode.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _labelForField(String field) {
    return _inspectionFieldLabels[field] ?? field.replaceAll('_', ' ');
  }

  String _requestKey(PendingRequest request) {
    return '${request.containerNo}|${request.requestedAt?.toUtc().toIso8601String() ?? ''}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Chưa có';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(value);
  }
}

class _DecisionDraft {
  const _DecisionDraft({required this.action, required this.reason});

  final String action;
  final String reason;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SetupChecklistItem extends StatelessWidget {
  const _SetupChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ApproverProfileSheet extends StatefulWidget {
  const _ApproverProfileSheet({required this.initialProfile});

  final ApproverProfile initialProfile;

  @override
  State<_ApproverProfileSheet> createState() => _ApproverProfileSheetState();
}

class _ApproverProfileSheetState extends State<_ApproverProfileSheet> {
  late final TextEditingController _usernameController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initialProfile.username,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F6F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D4C7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Cập nhật manager profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Username phải trùng với tài khoản local PostgreSQL có quyền duyệt cont.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Manager username',
                    hintText: 'Ví dụ: manager1',
                  ),
                ),
                if (_errorText != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Color(0xFFB13E2A)),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final username = _usernameController.text.trim();
                    if (username.isEmpty) {
                      setState(() {
                        _errorText = 'Manager username là bắt buộc.';
                      });
                      return;
                    }

                    Navigator.of(context).pop(
                      ApproverProfile(
                        username: username,
                        deviceLabel:
                            widget.initialProfile.deviceLabel.trim().isEmpty
                                ? 'flutter-manager-phone'
                                : widget.initialProfile.deviceLabel.trim(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: const Text('Lưu manager profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({
    required this.request,
    required this.profile,
    required this.isSubmitting,
  });

  final PendingRequest request;
  final ApproverProfile profile;
  final bool isSubmitting;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  late final TextEditingController _reasonController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F6F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D4C7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.request.containerNo,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.request.issueCount} lỗi cần duyệt',
                  style: const TextStyle(color: Color(0xFF6C716C)),
                ),
                const SizedBox(height: 14),
                if (!widget.profile.canSubmit)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5DA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Chưa có manager username. Hãy quay lại và cấu hình trước khi gửi quyết định.',
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Chi tiết lỗi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: widget.request.errorFields.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _inspectionFieldLabels[entry.key] ??
                                    entry.key.replaceAll('_', ' '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value
                                    .map(
                                      (value) => Chip(
                                        label: Text(value),
                                        backgroundColor:
                                            const Color(0xFFF3EFE5),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Lý do',
                    hintText: 'Bắt buộc khi reject, tuỳ chọn khi approve',
                  ),
                ),
                if (_errorText != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Color(0xFFB13E2A)),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: widget.isSubmitting || !widget.profile.canSubmit
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            _DecisionDraft(
                              action: 'approve',
                              reason: _reasonController.text.trim(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.check_circle_rounded),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF0C6E62),
                  ),
                  label: const Text('Approve cont'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: widget.isSubmitting || !widget.profile.canSubmit
                      ? null
                      : () {
                          if (_reasonController.text.trim().isEmpty) {
                            setState(() {
                              _errorText = 'Reject cần nhập lý do.';
                            });
                            return;
                          }
                          Navigator.of(context).pop(
                            _DecisionDraft(
                              action: 'reject',
                              reason: _reasonController.text.trim(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.cancel_rounded),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFFB74B2A),
                  ),
                  label: const Text('Reject cont'),
                ),
                TextButton(
                  onPressed: widget.isSubmitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifBlank(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
