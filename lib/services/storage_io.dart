import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/record.dart';

class StorageImpl {
  static const _fileName = 'records_backup.json';

  Future<Directory> _getAppDir() async =>
      await getApplicationDocumentsDirectory();

  Future<File> _localFile() async {
    final dir = await _getAppDir();
    return File('${dir.path}/$_fileName');
  }

  Future<List<RtoRecord>> loadRecords() async {
    try {
      final file = await _localFile();
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      return RtoRecord.listFromJson(contents);
    } catch (e) {
      return [];
    }
  }

  Future<void> saveRecords(List<RtoRecord> records) async {
    final file = await _localFile();
    await file.writeAsString(RtoRecord.listToJson(records));
  }

  Future<bool> exportBackup(String destPath) async {
    try {
      final src = await _localFile();
      if (!await src.exists()) return false;
      final dest = File(destPath);
      await dest.writeAsBytes(await src.readAsBytes());
      return true;
    } catch (e) {
      // Try fallback: on Android, writing to arbitrary external dirs can fail
      // because of scoped storage. Attempt to write to the user's Downloads
      // directory which is usually permitted.
      try {
        final parts = destPath.split('/');
        final filename = parts.isNotEmpty ? parts.last : _fileName;
        final extDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (extDirs != null && extDirs.isNotEmpty) {
          final downloads = extDirs.first;
          final fallback = File('${downloads.path}/$filename');
          final src = await _localFile();
          if (!await src.exists()) return false;
          await fallback.writeAsBytes(await src.readAsBytes());
          return true;
        }
      } catch (e2) {
        // ignore
      }
      return false;
    }
  }

  Future<bool> importBackup(String srcPath) async {
    try {
      final src = File(srcPath);
      if (!await src.exists()) return false;
      final dest = await _localFile();
      await dest.writeAsBytes(await src.readAsBytes());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> importBackupFromBytes(List<int> bytes) async {
    try {
      final dest = await _localFile();
      await dest.writeAsBytes(bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a record by id and persist the updated list.
  Future<void> deleteRecord(String id) async {
    final file = await _localFile();
    if (!await file.exists()) return;
    try {
      final contents = await file.readAsString();
      final list = RtoRecord.listFromJson(contents);
      list.removeWhere((r) => r.id == id);
      await file.writeAsString(RtoRecord.listToJson(list));
    } catch (e) {
      // ignore errors
    }
  }
}
