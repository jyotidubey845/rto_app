import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/record.dart';
import '../services/storage.dart';
import 'save_record_page.dart';
import '../services/notification_service.dart';
// file_picker removed — export/import removed from UI

class RecordsListPage extends StatefulWidget {
  const RecordsListPage({super.key});

  @override
  State<RecordsListPage> createState() => _RecordsListPageState();
}

class _RecordsListPageState extends State<RecordsListPage> {
  List<RtoRecord> _records = [];
  String _filter = '';
  String _daysFilter = '';
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _newestFirst = true;
  bool _sortByStartDate = false;

  String _toPascalCase(String s) {
    if (s.trim().isEmpty) return '';
    return s
        .trim()
        .split(RegExp(r"\s+"))
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await StorageService().loadRecords();
    setState(() {
      _records = r;
      _sort();
      _loading = false;
    });
  }

  void _sort() {
    if (_sortByStartDate) {
      _records.sort(
        (a, b) => _newestFirst
            ? b.registrationDate.compareTo(a.registrationDate)
            : a.registrationDate.compareTo(b.registrationDate),
      );
    } else {
      _records.sort(
        (a, b) => _newestFirst
            ? b.createdAt.compareTo(a.createdAt)
            : a.createdAt.compareTo(b.createdAt),
      );
    }
  }

  Future<void> _openAdd() async {
    final res = await Navigator.of(context).push<List<RtoRecord>>(
      MaterialPageRoute(builder: (_) => SaveRecordPage(currentList: _records)),
    );
    if (!mounted) return;
    if (res != null) setState(() => _records = res);
  }

  // age-by-createdAt helper removed; we now show registration age only in the card

  @override
  Widget build(BuildContext context) {
    List<RtoRecord> filtered = _records;
    if (_filter.isNotEmpty) {
      filtered = filtered.where((r) {
        final f = _filter.toLowerCase();
        final amount = r.paidAmount.toStringAsFixed(2);
        return r.name.toLowerCase().contains(f) ||
            r.fatherName.toLowerCase().contains(f) ||
            r.rcNumber.toLowerCase().contains(f) ||
            amount.contains(f) ||
            r.id.toLowerCase().contains(f);
      }).toList();
    }
    if (_daysFilter.isNotEmpty) {
      final days = int.tryParse(_daysFilter);
      if (days != null) {
        final now = DateTime.now();
        filtered = filtered.where((r) {
          final diff = now.difference(r.registrationDate).inDays;
          return diff == days;
        }).toList();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Delete selected',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm delete'),
                    content: Text(
                      'Delete ${_selectedIds.length} selected records?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'DELETE',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  final toDelete = List<String>.from(_selectedIds);
                  final failed = <String>[];
                  for (final id in toDelete) {
                    try {
                      await StorageService().deleteRecord(id);
                      try {
                        await NotificationService().cancelNotification(
                          id.hashCode & 0x7fffffff,
                        );
                      } catch (_) {
                        // ignore notification cancel errors
                      }
                    } catch (e) {
                      failed.add(id);
                    }
                  }
                  final success = toDelete
                      .where((id) => !failed.contains(id))
                      .toSet();
                  // reload full list from storage for consistency
                  await _load();
                  setState(() {
                    _selectedIds.removeAll(success);
                  });
                  if (failed.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete ${failed.length} records',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          // Export/import removed
          IconButton(
            icon: Icon(
              _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: () => setState(() {
              _newestFirst = !_newestFirst;
              _sort();
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'start') {
                setState(() {
                  _sortByStartDate = true;
                  _sort();
                });
              }
              if (v == 'created') {
                setState(() {
                  _sortByStartDate = false;
                  _sort();
                });
              }
            },
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem(
                value: 'start',
                checked: _sortByStartDate,
                child: const Text('Sort by Registration Date'),
              ),
              CheckedPopupMenuItem(
                value: 'created',
                checked: !_sortByStartDate,
                child: const Text('Sort by Saved Date'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search',
                            hintText:
                                'Name, Father, Application No, Amount, ID',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _filter = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Days',
                            hintText: 'e.g. 2',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              setState(() => _daysFilter = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => setState(() => _daysFilter = ''),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No records'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final r = filtered[idx];
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _toPascalCase(r.name),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Father: ${_toPascalCase(r.fatherName)}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'DOB: ${DateFormat.yMMMd().format(r.dob)}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Application No: ${r.rcNumber} • Paid: ${r.paidAmount.toStringAsFixed(2)}',
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Reg: ${DateFormat.yMMMd().format(r.registrationDate)}',
                                        ),
                                        const SizedBox(width: 8),
                                        Builder(
                                          builder: (_) {
                                            final days = DateTime.now()
                                                .difference(r.registrationDate)
                                                .inDays;
                                            final isOld = days >= 30;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isOld
                                                    ? Colors.red[50]
                                                    : Colors.green[50],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$days day${days == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  color: isOld
                                                      ? Colors.red[800]
                                                      : Colors.green[800],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _selectedIds.contains(r.id),
                                          onChanged: (v) => setState(() {
                                            if (v == true) {
                                              _selectedIds.add(r.id);
                                            } else {
                                              _selectedIds.remove(r.id);
                                            }
                                          }),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            final res =
                                                await Navigator.of(
                                                  context,
                                                ).push<List<RtoRecord>>(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        SaveRecordPage(
                                                          existing: r,
                                                          currentList: _records,
                                                        ),
                                                  ),
                                                );
                                            if (!mounted) return;
                                            if (res != null) {
                                              setState(() => _records = res);
                                            }
                                          },
                                          icon: const Icon(Icons.edit),
                                          label: const Text('EDIT'),
                                        ),
                                        const SizedBox(width: 12),
                                        // Call button: use Material green color for emphasis
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            final uri = Uri(
                                              scheme: 'tel',
                                              path: r.mobile,
                                            );
                                            final isMounted = mounted;
                                            final can = await canLaunchUrl(uri);
                                            if (!isMounted) return;
                                            if (can) {
                                              await launchUrl(uri);
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Cannot launch dialer',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.call),
                                          label: const Text('CALL'),
                                        ),
                                        const Spacer(),
                                        // Export removed
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'Confirm delete',
                                                    ),
                                                    content: const Text(
                                                      'Delete this record?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'CANCEL',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'DELETE',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                            if (confirm == true) {
                                              try {
                                                await StorageService()
                                                    .deleteRecord(r.id);
                                                // attempt to cancel notification but ignore errors
                                                try {
                                                  await NotificationService()
                                                      .cancelNotification(
                                                        r.id.hashCode &
                                                            0x7fffffff,
                                                      );
                                                } catch (_) {
                                                  // ignore notification cancel errors
                                                }
                                                if (!mounted) return;
                                                // reload from storage to reflect latest state
                                                await _load();
                                              } catch (e) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to delete: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}
