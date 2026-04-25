import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'cloudflare_r2_service.dart';
import 'gumlet_service.dart';
import 'media_route_policy.dart';
/// Hybrid **media router**: Gumlet for voice + video, Cloudflare R2 for static files.
///
/// Intended for:
/// - UI uploads (recorded voice, picked images, etc.)
/// - [SyncEngine] replay: call [uploadFromLocalPath] with the **local path** from sqflite;
///   the service verifies the file exists before uploading.
///
/// After success, merge the returned `Map` into the Appwrite document and local row using
/// your **LWW** fields (`version`, `remote_updated_at`, …) per [MIGRATION_PLAN.md](MIGRATION_PLAN.md).
class MediaUploadService {
  MediaUploadService({
    required CloudflareR2Service r2,
    required GumletService gumlet,
    MediaRoutePolicy? routePolicy,
  })  : _r2 = r2,
        _gumlet = gumlet,
        _policy = routePolicy ?? const MediaRoutePolicy();

  final CloudflareR2Service _r2;
  final GumletService _gumlet;
  final MediaRoutePolicy _policy;

  /// Uploads a local file and returns provider metadata JSON for persistence.
  ///
  /// [localFilePath] must exist on disk (e.g. pending upload queue from sqflite).
  Future<Map<String, dynamic>> uploadFromLocalPath({
    required String localFilePath,
    String? filenameOverride,
    String? mimeType,
  }) async {
    final mime = mimeType ?? lookupMimeType(localFilePath);
    final filename = filenameOverride ?? p.basename(localFilePath);

    if (_policy.shouldUseGumlet(localFilePath, mime)) {
      return _gumlet.uploadFile(
        path: localFilePath,
        filename: filename,
        mimeType: mime,
      );
    }

    return _r2.uploadFile(
      path: localFilePath,
      filename: filename,
      mimeType: mime,
    );
  }
}
