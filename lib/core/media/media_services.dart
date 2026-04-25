import 'package:dio/dio.dart';

import 'package:WhatsUnity/core/config/appwrite.dart';

import 'cloudflare_r2_service.dart';
import 'gumlet_service.dart';
import 'media_upload_service.dart';

/// Singleton wired in [main] after [initAppwrite].
late final MediaUploadService mediaUploadService;

void initMediaUploadService() {
  final dio = Dio();
  mediaUploadService = MediaUploadService(
    r2: CloudflareR2Service(
      functions: appwriteFunctions,
      dio: dio,
    ),
    gumlet: GumletService(
      functions: appwriteFunctions,
      dio: dio,
    ),
  );
}
