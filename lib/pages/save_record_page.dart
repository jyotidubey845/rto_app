import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import '../services/storage.dart';
import '../services/notification_service.dart';

class SaveRecordPage extends StatefulWidget {
  final RtoRecord? existing;
  final List<RtoRecord> currentList;

  const SaveRecordPage({super.key, this.existing, required this.currentList});

  @override
  State<SaveRecordPage> createState() => _SaveRecordPageState();
}

class _SaveRecordPageState extends State<SaveRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _registrationDateCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _rcCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();

  DateTime? _dob;
  DateTime? _registrationDate;

  String _toPascalCase(String s) {
    if (s.isEmpty) return '';
    final buffer = StringBuffer();
    var capitalizeNext = true;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch.trim().isEmpty) {
        // preserve whitespace as-is
        buffer.write(ch);
        capitalizeNext = true;
      } else {
        buffer.write(capitalizeNext ? ch.toUpperCase() : ch.toLowerCase());
        capitalizeNext = false;
      }
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _fatherCtrl.text = e.fatherName;
      _registrationDate = e.registrationDate;
      _registrationDateCtrl.text = e.registrationDate
          .toIso8601String()
          .split('T')
          .first;
      _dob = e.dob;
      _dobCtrl.text = e.dob.toIso8601String().split('T').first;
      // strip leading +91 if present so the field shows only the 10 digits
      _mobileCtrl.text = e.mobile.replaceAll(RegExp(r'^\+91\s*'), '');
      _rcCtrl.text = e.rcNumber;
      _paidCtrl.text = e.paidAmount.toString();
      _commentsCtrl.text = e.comments;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _dobCtrl.dispose();
    _registrationDateCtrl.dispose();
    _mobileCtrl.dispose();
    _rcCtrl.dispose();
    _paidCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _pickRegistrationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _registrationDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _registrationDate = picked;
        _registrationDateCtrl.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? const Uuid().v4();
    // normalize mobile: remove leading zeros and ensure +91 prefix
    var rawMobile = _mobileCtrl.text.trim();
    rawMobile = rawMobile.replaceAll(RegExp(r"^0+"), '');
    final mobileWithCountry = rawMobile.startsWith('+91')
        ? rawMobile
        : '+91$rawMobile';

    final rec = RtoRecord(
      id: id,
      name: _toPascalCase(_nameCtrl.text.trim()),
      fatherName: _toPascalCase(_fatherCtrl.text.trim()),
      registrationDate: _registrationDate ?? DateTime.now(),
      dob: _dob ?? DateTime.now(),
      mobile: mobileWithCountry,
      rcNumber: _rcCtrl.text.trim().toUpperCase(),
      paidAmount: double.tryParse(_paidCtrl.text.trim()) ?? 0.0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      comments: _commentsCtrl.text.trim(),
    );

    final list = List<RtoRecord>.from(widget.currentList);
    final idx = list.indexWhere((r) => r.id == rec.id);
    if (idx >= 0) {
      list[idx] = rec;
    } else {
      list.add(rec);
    }

    try {
      await StorageService().saveRecords(list);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Record saved')));
      Navigator.of(context).pop(list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Record' : 'Edit Record'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onChanged: (v) {
                    final formatted = _toPascalCase(v);
                    if (formatted != v) {
                      final base = _nameCtrl.selection.baseOffset;
                      final newOffset = base.clamp(0, formatted.length);
                      _nameCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: newOffset),
                      );
                    }
                  },
                ),
                TextFormField(
                  controller: _fatherCtrl,
                  decoration: const InputDecoration(labelText: 'Father Name'),
                  onChanged: (v) {
                    final formatted = _toPascalCase(v);
                    if (formatted != v) {
                      final base = _fatherCtrl.selection.baseOffset;
                      final newOffset = base.clamp(0, formatted.length);
                      _fatherCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: newOffset),
                      );
                    }
                  },
                ),
                TextFormField(
                  controller: _registrationDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Registration Date',
                  ),
                  readOnly: true,
                  onTap: _pickRegistrationDate,
                ),
                TextFormField(
                  controller: _dobCtrl,
                  decoration: const InputDecoration(labelText: 'DOB'),
                  readOnly: true,
                  onTap: _pickDob,
                ),
                TextFormField(
                  controller: _mobileCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile',
                    prefixText: '+91 ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length != 10) return 'Enter 10 digit mobile';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _rcCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Application Number',
                  ),
                  onChanged: (v) {
                    final up = v.toUpperCase();
                    if (up != v) {
                      final base = _rcCtrl.selection.baseOffset;
                      final newOffset = base.clamp(0, up.length);
                      _rcCtrl.value = TextEditingValue(
                        text: up,
                        selection: TextSelection.collapsed(offset: newOffset),
                      );
                    }
                  },
                ),
                TextFormField(
                  controller: _paidCtrl,
                  decoration: const InputDecoration(labelText: 'Paid Amount'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _commentsCtrl,
                  decoration: const InputDecoration(labelText: 'Comments'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.existing != null) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm delete'),
                              content: const Text('Delete this record?'),
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
                            try {
                              await StorageService().deleteRecord(
                                widget.existing!.id,
                              );
                              // cancel scheduled notification for this record
                              final nid =
                                  widget.existing!.id.hashCode & 0x7fffffff;
                              await NotificationService().cancelNotification(
                                nid,
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Record deleted')),
                              );
                              // return the updated list to the caller by removing locally
                              final list =
                                  List<RtoRecord>.from(widget.currentList)
                                    ..removeWhere(
                                      (r) => r.id == widget.existing!.id,
                                    );
                              Navigator.of(context).pop(list);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('DELETE'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _save,
                        child: const Text('SAVE'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
