import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/record.dart';

class FirebaseStorageImpl {
  final _col = FirebaseFirestore.instance.collection('records');

  Future<List<RtoRecord>> loadRecords() async {
    final snap = await _col.orderBy('registrationDate', descending: true).get();
    return snap.docs
        .map((d) => RtoRecord.fromJson(d.data()..['id'] = d.id))
        .toList();
  }

  Future<void> saveRecords(List<RtoRecord> records) async {
    // Save each record by id (upsert)
    final batch = FirebaseFirestore.instance.batch();
    for (final r in records) {
      final ref = _col.doc(r.id);
      batch.set(ref, r.toJson());
    }
    await batch.commit();
  }

  Future<bool> exportBackup(String destPath) async {
    // Firestore doesn't support writing to local files from here; keep existing API
    return false;
  }

  Future<bool> importBackup(String srcPath) async {
    return false;
  }

  Future<bool> importBackupFromBytes(List<int> bytes) async {
    return false;
  }

  /// Delete a single record document by id from Firestore.
  Future<void> deleteRecord(String id) async {
    await _col.doc(id).delete();
  }
}
