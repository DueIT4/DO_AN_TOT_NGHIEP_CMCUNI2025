// detection_history_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/detection_history_service.dart';

class DetectionHistoryPage extends StatefulWidget {
  const DetectionHistoryPage({
    super.key,
    required this.service,
  });

  final DetectionHistoryService service;

  @override
  State<DetectionHistoryPage> createState() => _DetectionHistoryPageState();
}

class _DetectionHistoryPageState extends State<DetectionHistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  List<DetectionHistoryItem> _items = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool resetPage = false}) async {
    if (resetPage) _page = 1;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.service.getMyHistory(
        page: _page,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _items = result.items;
        _total = result.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _onDelete(DetectionHistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xoá bản ghi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.service.deleteDetection(item.detectionId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xoá')),
      );

      _loadData(); // load lại sau khi xoá
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xoá thất bại: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / PAGE_SIZE).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử dự đoán'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Ô tìm kiếm
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Tìm theo bệnh, file...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadData(resetPage: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _loadData(resetPage: true),
                  child: const Text('Tìm'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Không có dữ liệu'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              title: Text(
                                item.diseaseName ?? 'Không xác định',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Confidence: ${item.confidence != null ? (item.confidence! * 100).toStringAsFixed(1) + '%' : '-'}',
                                  ),
                                  Text(
                                    'Thời gian: ${item.createdAt}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Ảnh: ${item.fileUrl}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _onDelete(item),
                              ),
                            );
                          },
                        ),
            ),
            // Phân trang
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _page > 1 && !_loading
                      ? () {
                          setState(() {
                            _page--;
                          });
                          _loadData();
                        }
                      : null,
                  child: const Text('< Trước'),
                ),
                Text('Trang $_page/$_totalPages'),
                TextButton(
                  onPressed: _page < _totalPages && !_loading
                      ? () {
                          setState(() {
                            _page++;
                          });
                          _loadData();
                        }
                      : null,
                  child: const Text('Sau >'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
