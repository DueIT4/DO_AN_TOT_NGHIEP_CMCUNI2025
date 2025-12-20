import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/detection_history_service.dart';
import 'package:mobile_web_flutter/core/api_base.dart';
import 'dart:html' as html; // chỉ dùng cho Flutter Web

import 'package:mobile_web_flutter/core/toast.dart'; // ✅ toast

class AdminDetectionHistoryPage extends StatefulWidget {
  const AdminDetectionHistoryPage({super.key});

  @override
  State<AdminDetectionHistoryPage> createState() =>
      _AdminDetectionHistoryPageState();
}

class _AdminDetectionHistoryPageState extends State<AdminDetectionHistoryPage> {
  final DetectionHistoryService _svc = DetectionHistoryService();

  int _currentPage = 1;
  String _search = '';
  bool _loading = false;
  String? _error;

  DetectionHistoryList? _data;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg, ToastType type) {
    if (!mounted) return;
    AppToast.show(context, message: msg, type: type);
  }

  Future<void> _fetch({int? page}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final p = page ?? _currentPage;

    try {
      final res = await _svc.getAllHistoryAdmin(
        page: p,
        search: _search.isEmpty ? null : _search,
      );

      if (!mounted) return;
      setState(() {
        _currentPage = p;
        _data = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
      _toast('Lỗi tải dữ liệu: $e', ToastType.error);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onDelete(DetectionHistoryItem item) async {
    // ✅ dùng dialogContext để pop, tránh lỗi Navigator/go_router assert
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá bản ghi'),
        content: const Text('Bạn chắc chắn muốn xoá lịch sử dự đoán này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _svc.deleteDetectionAdmin(item.detectionId);
      if (!mounted) return;

      _toast('Đã xoá bản ghi.', ToastType.success);
      await _fetch(page: _currentPage); // reload an toàn
    } catch (e) {
      if (!mounted) return;
      _toast('Lỗi xoá: $e', ToastType.error);
    }
  }

  Widget _buildThumb(DetectionHistoryItem item) {
    if (item.fileUrl.isEmpty) {
      return const SizedBox(
        width: 72,
        height: 72,
        child: Icon(Icons.image_not_supported),
      );
    }

    final fullUrl = '${ApiBase.baseURL}${item.fileUrl}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        fullUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 72,
          height: 72,
          child: Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _buildStatusTag(DetectionHistoryItem item) {
    final conf = item.confidence;
    if (conf == null) {
      return const Text(
        'Không rõ',
        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
      );
    }

    Color bg;
    Color fg;

    if (conf >= 0.8) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (conf >= 0.5) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Độ tin cậy: ${(conf * 100).toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 11, color: fg),
      ),
    );
  }

  Future<void> _onExportTrain(DetectionHistoryItem item) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      await _svc.exportToTrainData(item.detectionId);
      if (!mounted) return;
      _toast('Đã lưu ảnh vào dataset train.', ToastType.success);
    } catch (e) {
      if (!mounted) return;
      _toast('Lỗi export: $e', ToastType.error);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onDownloadDatasetTrain() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      await _svc.downloadDatasetTrain();
      if (!mounted) return;
      _toast('Đang tải dataset train...', ToastType.info);
    } catch (e) {
      if (!mounted) return;
      _toast('Lỗi tải dataset: $e', ToastType.error);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? [];
    final total = _data?.total ?? 0;

    // NOTE: PAGE_SIZE giả định là const/global trong project bạn
    final totalPages =
        total == 0 ? 1 : ((total + PAGE_SIZE - 1) / PAGE_SIZE).floor();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.8),
                  child: Row(
                    children: [
                      Text(
                        'Lịch sử dự đoán',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Tải dataset train',
                        child: IconButton.filledTonal(
                          onPressed: _loading ? null : _onDownloadDatasetTrain,
                          icon: const Icon(Icons.download, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Tìm theo bệnh, user, email, SĐT...',
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (_) {
                            _search = _searchCtrl.text.trim();
                            _fetch(page: 1);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading
                            ? null
                            : () {
                                _search = _searchCtrl.text.trim();
                                _fetch(page: 1);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Icon(Icons.search, size: 20),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Tải lại',
                        onPressed:
                            _loading ? null : () => _fetch(page: _currentPage),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Lỗi: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                else if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Chưa có lịch sử dự đoán nào.'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final it = items[index];
                            final userLabel = [it.username, it.email, it.phone]
                                .where((x) => x != null && x.isNotEmpty)
                                .join(' • ');

                            return ListTile(
                              leading: _buildThumb(it),
                              title: Text(
                                it.diseaseName ?? 'Không xác định',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (userLabel.isNotEmpty)
                                    Text(
                                      userLabel,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  Text(
                                    'Thời gian: ${it.createdAt.toLocal()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStatusTag(it),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Lưu làm data train',
                                    icon: const Icon(
                                      Icons.download_for_offline,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    onPressed: _loading
                                        ? null
                                        : () => _onExportTrain(it),
                                  ),
                                  IconButton(
                                    tooltip: 'Xoá',
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    onPressed:
                                        _loading ? null : () => _onDelete(it),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tổng: $total bản ghi • Trang $_currentPage / $totalPages',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _currentPage > 1 && !_loading
                                      ? () => _fetch(page: _currentPage - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  onPressed:
                                      _currentPage < totalPages && !_loading
                                          ? () => _fetch(page: _currentPage + 1)
                                          : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
