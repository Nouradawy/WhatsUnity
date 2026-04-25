import 'dart:io';

import 'package:uuid/uuid.dart';

import 'media_upload_exception.dart';

/// Copies the recorder output to a stable temp path **synchronously**.
///
/// Call this at the very start of [SocialMediaRecorder.sendRequestFunction], with **no**
/// `await` before it. Many recorders delete their cache file on the next event-loop turn
/// or when the callback future suspends; uploading [source.path] then fails with
/// "Local file missing".
File stageRecorderFileForUpload(File source) {
  if (!source.existsSync()) {
    throw MediaUploadException(
      'Recorder file already gone: ${source.path}. '
      'Ensure staging runs synchronously before any await.',
    );
  }
  final dest = File(
    '${Directory.systemTemp.path}/voice_upload_${const Uuid().v4()}.m4a',
  );
  try {
    source.copySync(dest.path);
  } on FileSystemException catch (e) {
    throw MediaUploadException('Could not stage recorder file', e);
  }
  return dest;
}
