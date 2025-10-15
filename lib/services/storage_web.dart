// Web implementation. Uses window.localStorage for persistence and creates
// downloadable blobs for export. importBackupFromBytes will accept file
// bytes (from a web file picker) and save as string into localStorage.
import 'dart:html' as html;
import 'dart:convert';
import '../models/record.dart';

class StorageImpl {
  static const _webStorageKey = 'rto_records';

  Future<List<RtoRecord>> loadRecords() async {
    try {
      final jsonStr = html.window.localStorage[_webStorageKey];
      if (jsonStr == null || jsonStr.isEmpty) return [];
      return RtoRecord.listFromJson(jsonStr);
    } catch (e) {
      return [];
    }
  }

  Future<void> saveRecords(List<RtoRecord> records) async {
    final jsonStr = RtoRecord.listToJson(records);
    html.window.localStorage[_webStorageKey] = jsonStr;
  }

  Future<bool> exportBackup(String filename) async {
    try {
      final jsonStr = html.window.localStorage[_webStorageKey];
      if (jsonStr == null) return false;
      final bytes = utf8.encode(jsonStr);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement;
      anchor.href = url;
      anchor.download = filename;
      anchor.style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> importBackup(String srcPath) async {
    // Not meaningful on web since we don't have filesystem paths. For web
    // callers use importBackupFromBytes with file contents.
    return false;
  }

  Future<bool> importBackupFromBytes(List<int> bytes) async {
    try {
      final jsonStr = utf8.decode(bytes);
      html.window.localStorage[_webStorageKey] = jsonStr;
      return true;
    } catch (e) {
      return false;
    }
  }
}
