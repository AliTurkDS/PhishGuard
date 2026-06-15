// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../services/history_repository.dart';
import '../models/scan_record.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ScanRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = HistoryRepository.instance.getAll();
  }

  void _refresh() => setState(
      () => _future = HistoryRepository.instance.getAll());

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All scan records will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (ok == true) {
      await HistoryRepository.instance.deleteAll();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan history',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear all',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: FutureBuilder<List<ScanRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('No scans yet',
                      style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _HistoryTile(
              record: records[i],
              onDelete: () async {
                await HistoryRepository.instance
                    .deleteById(records[i].id!);
                _refresh();
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onDelete;

  const _HistoryTile({required this.record, required this.onDelete});

  Color get _labelColor => record.isSafe
      ? const Color(0xFF2E7D32)
      : const Color(0xFFC62828);

  IconData get _labelIcon =>
      record.isSafe ? Icons.check_circle_rounded : Icons.cancel_rounded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = _formatTime(record.scannedAt);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _labelColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _labelColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_labelIcon, color: _labelColor, size: 20),
        ),
        title: Text(
          record.url,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _labelColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${record.label[0].toUpperCase()}${record.label.substring(1)} · ${(record.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: _labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(timeStr,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5))),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: onDelete,
          tooltip: 'Remove',
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
