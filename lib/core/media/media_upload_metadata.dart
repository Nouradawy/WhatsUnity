import 'media_upload_exception.dart';

/// [MediaUploadService] / provider metadata persisted on Appwrite docs and local sqflite (LWW).
abstract final class MediaStorageProviders {
  static const r2 = 'r2';
  static const gumlet = 'gumlet';
}

/// Canonical JSON keys for [toJson] / repository encoding.
abstract final class MediaUploadMetadataKeys {
  static const provider = 'provider';
  static const url = 'url';
  static const mime = 'mime';
  static const assetId = 'asset_id';
  static const playbackUrl = 'playback_url';
}

/// R2 row: `{ "provider": "r2", "url": "...", "mime": "..." }`.
class R2UploadMetadata {
  const R2UploadMetadata({
    required this.url,
    required this.mime,
  });

  final String url;
  final String mime;

  Map<String, dynamic> toJson() => {
        MediaUploadMetadataKeys.provider: MediaStorageProviders.r2,
        MediaUploadMetadataKeys.url: url,
        MediaUploadMetadataKeys.mime: mime,
      };

  static R2UploadMetadata fromJson(Map<String, dynamic> json) {
    final url = json[MediaUploadMetadataKeys.url] as String?;
    final mime = json[MediaUploadMetadataKeys.mime] as String?;
    if (url == null || url.isEmpty) {
      throw MediaUploadException('R2 metadata missing url');
    }
    return R2UploadMetadata(url: url, mime: mime ?? 'application/octet-stream');
  }
}

/// Gumlet row: `{ "provider": "gumlet", "asset_id": "...", "playback_url": "..." }`.
class GumletUploadMetadata {
  const GumletUploadMetadata({
    required this.assetId,
    required this.playbackUrl,
  });

  final String assetId;
  final String playbackUrl;

  Map<String, dynamic> toJson() => {
        MediaUploadMetadataKeys.provider: MediaStorageProviders.gumlet,
        MediaUploadMetadataKeys.assetId: assetId,
        MediaUploadMetadataKeys.playbackUrl: playbackUrl,
      };

  static GumletUploadMetadata fromJson(Map<String, dynamic> json) {
    final id = json[MediaUploadMetadataKeys.assetId] as String?;
    final url = json[MediaUploadMetadataKeys.playbackUrl] as String?;
    if (id == null || id.isEmpty) {
      throw MediaUploadException('Gumlet metadata missing asset_id');
    }
    if (url == null || url.isEmpty) {
      throw MediaUploadException('Gumlet metadata missing playback_url');
    }
    return GumletUploadMetadata(assetId: id, playbackUrl: url);
  }
}
