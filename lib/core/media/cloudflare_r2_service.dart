import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'appwrite_function_helpers.dart';
import 'appwrite_media_function_ids.dart';
import 'media_upload_exception.dart';
import 'media_upload_metadata.dart';

/// Uploads static files to **Cloudflare R2** via a presigned PUT URL from Appwrite.
///
/// **Appwrite Function** (placeholder id `get_r2_signed_url`): server validates the user,
/// mints an [R2 presigned URL](https://developers.cloudflare.com/r2/api/s3/presigned-urls/),
/// returns JSON. Supported response shapes (first match wins):
/// - `signed_url` | `put_url` | `upload_url` — URL for **PUT** of raw bytes
/// - `url` | `public_url` | `file_url` — final object URL stored in Appwrite after upload
class CloudflareR2Service {
  CloudflareR2Service({
    required Functions functions,
    required Dio dio,
    String? functionId,
  })  : _functions = functions,
        _dio = dio,
        _functionId = functionId ??
            resolveFunctionId(
              'APPWRITE_FUNCTION_GET_R2_SIGNED_URL',
              AppwriteMediaFunctionIds.defaultGetR2SignedUrl,
            );

  final Functions _functions;
  final Dio _dio;
  final String _functionId;

  /// Reads [path], requests a signed URL, **PUT**s bytes to R2, returns R2 metadata map.
  Future<Map<String, dynamic>> uploadFile({
    required String path,
    required String filename,
    String? mimeType,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw MediaUploadException('Local file missing (sqflite path stale?): $path');
    }

    final mime = mimeType ?? lookupMimeType(path) ?? 'application/octet-stream';
    final size = await file.length();

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
      final detail = res['message'] ?? res;
      throw MediaUploadException(
        'get_r2_signed_url failed ($err): $detail',
      );
    }

    final signedUrl = pickString(res, ['signed_url', 'put_url', 'upload_url']);
    if (signedUrl == null) {
      throw MediaUploadException(
        'get_r2_signed_url response missing signed_url/put_url/upload_url: $res',
      );
    }

    final publicUrl = pickString(res, [
      'read_url',
      'url',
      'public_url',
      'file_url',
    ]);
    if (publicUrl == null || publicUrl.isEmpty) {
      throw MediaUploadException(
        'get_r2_signed_url response missing read_url/url/public_url: $res',
      );
    }

    await _dio.put<List<int>>(
      signedUrl,
      data: await file.readAsBytes(),
      options: Options(
        headers: <String, Object?>{
          Headers.contentTypeHeader: mime,
          Headers.contentLengthHeader: size,
        },
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    return R2UploadMetadata(url: publicUrl, mime: mime).toJson();
  }
}
