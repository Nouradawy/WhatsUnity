import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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
    final mime = mimeType ?? lookupMimeType(path) ?? 'application/octet-stream';
    final sourcePayload = await _readUploadPayload(path);
    final uploadPayload = _prepareCompressedUploadPayload(
      sourceBytes: sourcePayload.bytes,
      mimeType: mime,
    );
    final size = uploadPayload.size;

    final res = await invokeAppwriteFunctionJson(
      functions: _functions,
      functionId: _functionId,
      payload: {
        'filename': filename,
        'mime': uploadPayload.mimeType,
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
      data: uploadPayload.bytes,
      options: Options(
        headers: <String, Object?>{
          Headers.contentTypeHeader: uploadPayload.mimeType,
          Headers.contentLengthHeader: size,
          if (uploadPayload.contentEncoding != null)
            Headers.contentEncodingHeader: uploadPayload.contentEncoding,
        },
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    return R2UploadMetadata(url: publicUrl, mime: uploadPayload.mimeType).toJson();
  }

  Future<({List<int> bytes, int size})> _readUploadPayload(String path) async {
    if (kIsWeb) {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw MediaUploadException('Selected web file is empty or unreadable: $path');
      }
      return (bytes: bytes, size: bytes.length);
    }

    final file = File(path);
    if (!await file.exists()) {
      throw MediaUploadException('Local file missing (sqflite path stale?): $path');
    }
    final bytes = await file.readAsBytes();
    return (bytes: bytes, size: bytes.length);
  }

  _CompressedUploadPayload _prepareCompressedUploadPayload({
    required List<int> sourceBytes,
    required String mimeType,
  }) {
    final imageCompressed = _compressImagePayload(
      sourceBytes: sourceBytes,
      mimeType: mimeType,
    );
    if (imageCompressed != null) {
      return imageCompressed;
    }

    final gzipped = GZipEncoder().encode(sourceBytes);
    if (gzipped.length + 64 < sourceBytes.length) {
      return _CompressedUploadPayload(
        bytes: gzipped,
        mimeType: mimeType,
        contentEncoding: 'gzip',
      );
    }

    return _CompressedUploadPayload(bytes: sourceBytes, mimeType: mimeType);
  }

  _CompressedUploadPayload? _compressImagePayload({
    required List<int> sourceBytes,
    required String mimeType,
  }) {
    if (!mimeType.startsWith('image/')) return null;
    if (mimeType == 'image/svg+xml' || mimeType == 'image/gif') return null;

    final decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
    if (decoded == null) return null;

    List<int>? encoded;
    var targetMime = mimeType;

    if (mimeType == 'image/png') {
      encoded = img.encodePng(decoded, level: 6);
    } else {
      // JPEG/WebP/unknown image payloads are normalized to JPEG for broad
      // compatibility and predictable byte reduction.
      encoded = img.encodeJpg(decoded, quality: 82);
      targetMime = 'image/jpeg';
    }

    if (encoded.isEmpty) return null;
    if (encoded.length + 512 >= sourceBytes.length) return null;

    return _CompressedUploadPayload(bytes: encoded, mimeType: targetMime);
  }
}

class _CompressedUploadPayload {
  const _CompressedUploadPayload({
    required this.bytes,
    required this.mimeType,
    this.contentEncoding,
  });

  final List<int> bytes;
  final String mimeType;
  final String? contentEncoding;

  int get size => bytes.length;
}
