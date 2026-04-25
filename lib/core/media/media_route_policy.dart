import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// Routes uploads to Gumlet (voice + video) vs Cloudflare R2 (everything else).
///
/// Aligns with [MIGRATION_PLAN.md](MIGRATION_PLAN.md) §5.1.
class MediaRoutePolicy {
  const MediaRoutePolicy();

  static const _gumletExtensions = {
    '.m4a',
    '.aac',
    '.mp4',
    '.mov',
  };

  /// Uses file path extension; falls back to [mimeType] when extension is ambiguous.
  bool shouldUseGumlet(String localFilePath, [String? mimeType]) {
    final ext = p.extension(localFilePath).toLowerCase();
    if (_gumletExtensions.contains(ext)) return true;

    final m = mimeType ?? lookupMimeType(localFilePath);
    if (m == null) return false;
    return m.startsWith('video/') ||
        m == 'audio/mp4' ||
        m == 'audio/x-m4a' ||
        m == 'audio/aac' ||
        m == 'audio/x-aac';
  }
}
