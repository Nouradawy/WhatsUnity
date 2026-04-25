import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'appwrite_function_helpers.dart';
import 'appwrite_media_function_ids.dart';
import 'media_upload_exception.dart';
import 'media_upload_metadata.dart';

/// Uploads **voice** and **video** to Gumlet via Appwrite Function `create_gumlet_asset`.
///
/// Expected function JSON response (flexible keys):
/// - `upload_url` | `put_url` | `signed_url` — destination for **PUT** of file bytes
/// - `asset_id` | `id` — Gumlet asset identifier
/// - `playback_url` | `playbackUrl` | `url` — HLS or playback URL (may be filled after processing)
class GumletService {
  GumletService({
    required Functions functions,
    required Dio dio,
    String? functionId,
  })  : _functions = functions,
        _dio = dio,
        _functionId = functionId ??
            resolveFunctionId(
              'APPWRITE_FUNCTION_CREATE_GUMLET_ASSET',
              AppwriteMediaFunctionIds.defaultCreateGumletAsset,
            );

  final Functions _functions;
  final Dio _dio;
  final String _functionId;

  Future<Map<String, dynamic>> uploadFile({
    required String path,
    required String filename,
    String? mimeType,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw MediaUploadException('Local file missing (sqflite path stale?): $path');
    }

    final mime = _normalizeUploadMime(mimeType, path, filename);
    final size = await file.length();
    if (size < 64) {
      throw MediaUploadException(
        'Recording file too small ($size bytes); encoder may not have finalized.',
      );
    }

    final res = await invokeAppwriteFunctionJson(
      functions: _functions,
      functionId: _functionId,
      payload: {
        'filename': filename,
        'mime': mime,
        'size': size,
      },
    );

    final err = res['error'];
    if (err != null) {
      final detail =
          res['gumlet_response'] ?? res['message'] ?? res['gumlet_body'] ?? res;
      throw MediaUploadException(
        'create_gumlet_asset failed ($err): $detail',
      );
    }

    final uploadUrl = pickString(res, ['upload_url', 'put_url', 'signed_url']);
    final assetId = pickString(res, ['asset_id', 'id']);
    var playbackUrl = pickPlaybackUrl(res);

    if (uploadUrl == null) {
      throw MediaUploadException(
        'create_gumlet_asset response missing upload_url: $res',
      );
    }
    if (assetId == null || assetId.isEmpty) {
      throw MediaUploadException(
        'create_gumlet_asset response missing asset_id: $res',
      );
    }

    // Gumlet/S3 pipelines often classify AAC-in-MP4 (.m4a) as the MP4 container type.
    final putMime = _putContentTypeForGumlet(mime, filename);

    await _dio.put<List<int>>(
      uploadUrl,
      data: await file.readAsBytes(),
      options: Options(
        headers: <String, Object?>{
          Headers.contentTypeHeader: putMime,
          Headers.contentLengthHeader: size,
        },
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    if (playbackUrl == null || playbackUrl.isEmpty) {
      throw MediaUploadException(
        'Gumlet upload succeeded but playback_url not ready yet (asset_id=$assetId). '
        'Poll Gumlet asset status or extend create_gumlet_asset to return output.playback_url.',
      );
    }

    return GumletUploadMetadata(
      assetId: assetId,
      playbackUrl: playbackUrl,
    ).toJson();
  }

  /// Gumlet and S3-style PUT URLs expect real audio types; [application/octet-stream]
  /// on AAC-in-MP4 (.m4a) often breaks downstream processing.
  static String _normalizeUploadMime(
    String? mimeType,
    String path,
    String filename,
  ) {
    final fromLookup = mimeType ?? lookupMimeType(path) ?? lookupMimeType(filename);
    var m = fromLookup ?? 'application/octet-stream';
    final leaf = filename.toLowerCase();
    if (leaf.endsWith('.m4a') || leaf.endsWith('.aac')) {
      if (m == 'application/octet-stream' ||
          m == 'audio/x-m4a' ||
          m == 'audio/m4a') {
        m = 'audio/mp4';
      }
    }
    if (leaf.endsWith('.mp3') &&
        (m == 'application/octet-stream' || m == 'audio/x-mp3')) {
      m = 'audio/mpeg';
    }
    return m;
  }

  static String _putContentTypeForGumlet(String mime, String filename) {
    final leaf = filename.toLowerCase();
    if (leaf.endsWith('.m4a') || leaf.endsWith('.aac')) {
      return 'video/mp4';
    }
    return mime;
  }
}
