// This file is a tiny facade that conditionally imports the platform-specific
// implementation. The actual logic lives in storage_io.dart (mobile/desktop)
// and storage_web.dart (web). This avoids calling path_provider on web and
// prevents MissingPluginException when running in Chrome.
import 'storage_io.dart' if (dart.library.html) 'storage_web.dart';
import 'storage_firebase.dart' if (dart.library.html) 'storage_io.dart';
import '../models/record.dart';

class StorageService {
  // Toggle this to true to use Firestore-backed storage (requires Firebase setup)
  static const _useFirebase = true;

  final StorageImpl? _local = _useFirebase ? null : StorageImpl();
  final FirebaseStorageImpl? _firebase = _useFirebase
      ? FirebaseStorageImpl()
      : null;

  Future<List<RtoRecord>> loadRecords() =>
      _useFirebase ? _firebase!.loadRecords() : _local!.loadRecords();

  Future<void> saveRecords(List<RtoRecord> records) => _useFirebase
      ? _firebase!.saveRecords(records)
      : _local!.saveRecords(records);

  Future<bool> exportBackup(String destPath) =>
      _useFirebase ? Future.value(false) : _local!.exportBackup(destPath);

  Future<bool> importBackup(String srcPath) =>
      _useFirebase ? Future.value(false) : _local!.importBackup(srcPath);

  Future<bool> importBackupFromBytes(List<int> bytes) =>
      _useFirebase ? Future.value(false) : _local!.importBackupFromBytes(bytes);

  /// Delete single record by id. When using Firebase this should remove the
  /// document; for local storage we save the updated list after removal.
  Future<void> deleteRecord(String id) =>
      _useFirebase ? _firebase!.deleteRecord(id) : _local!.deleteRecord(id);
}
