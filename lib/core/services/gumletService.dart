/// Prefer [mediaUploadService] from `package:WhatsUnity/core/media/media_services.dart`
/// and [MediaUploadService.uploadFromLocalPath] with the recorded file path.
///
/// Legacy entrypoint used a public URL and direct Gumlet API keys; that path was removed
/// for security. Voice flow: upload local `.m4a` via Appwrite Function `create_gumlet_asset`.
@Deprecated('Use mediaUploadService.uploadFromLocalPath(localFilePath: file.path, ...)')
Future<String?> uploadVoiceNoteGumlet(String voiceUrl) async {
  throw UnsupportedError(
    'uploadVoiceNoteGumlet is removed. Use mediaUploadService.uploadFromLocalPath '
    'with the local recording file and Appwrite-backed Gumlet (see MIGRATION_PLAN §5.1b).',
  );
}
